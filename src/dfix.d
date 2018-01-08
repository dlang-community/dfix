module dfix;

import std.experimental.lexer;
import dparse.lexer;
import dparse.parser;
import dparse.ast;
import std.stdio;
import std.format;
import std.file;

int main(string[] args)
{
	import std.getopt : getopt;
	import std.parallelism : parallel;

	// http://wiki.dlang.org/DIP64
	bool dip64;
	// http://wiki.dlang.org/DIP65
	bool dip65 = true;
	//https://github.com/dlang/DIPs/blob/master/DIPs/DIP1003.md
	bool dip1003 = true;

	bool help;

	try
	{
		getopt(args,
			"dip64", &dip64,
			"dip65", &dip65,
			"dip1003", &dip1003,
			"help|h", &help,
		);
	}
	catch (Exception e)
	{
		stderr.writeln(e.msg);
		return 1;
	}

	if (help)
	{
		printHelp();
		return 0;
	}

	if (args.length < 2)
	{
		stderr.writeln("File path is a required argument");
		return 1;
	}

	string[] files;

	foreach (arg; args[1 .. $])
	{
		if (isDir(arg))
		{
			foreach (f; dirEntries(arg, "*.{d,di}", SpanMode.depth))
				files ~= f;
		}
		else
			files ~= arg;
	}

	foreach (f; parallel(files))
	{
		try
			upgradeFile(f, dip64, dip65, dip1003);
		catch (Exception e)
			stderr.writeln("Failed to upgrade ", f, ":(", e.file, ":", e.line, ") ", e.msg);
	}

	return 0;
}

/**
 * Prints help message
 */
void printHelp()
{
	stdout.writeln(`
Dfix automatically upgrades D source code to comply with new language changes.
Files are modified in place, so have backup copies ready or use a source
control system.

Usage:

    dfix [Options] FILES DIRECTORIES

Options:

    --dip64
        Rewrites attributes to be compliant with DIP64. This defaults to
        "false". Do not use this feature if you want your code to compile.
		It exists as a proof-of-concept for enabling DIP64.
    --dip65
        Rewrites catch blocks to be compliant with DIP65. This defaults to
        "true". Use --dip65=false to disable this fix.
    --dip1003
        Rewrites body blocks to be compliant with DIP1003. This defaults to
        "true". Use --dip1003=false to disable this fix.
    --help -h
        Prints this help message
`);
}

/**
 * Fixes the given file.
 */
void upgradeFile(string fileName, bool dip64, bool dip65, bool dip1003)
{
	import std.algorithm : filter, canFind;
	import std.range : retro;
	import std.array : array, uninitializedArray;
	import dparse.formatter : Formatter;
	import std.exception : enforce;
	import dparse.rollback_allocator : RollbackAllocator;
	import std.functional : toDelegate;

	File input = File(fileName, "rb");
	ubyte[] inputBytes = uninitializedArray!(ubyte[])(cast(size_t) input.size);
	input.rawRead(inputBytes);
	input.close();
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	LexerConfig config;
	config.fileName = fileName;
	config.stringBehavior = StringBehavior.source;
	auto tokens = byToken(inputBytes, config, &cache).array;
	auto parseTokens = tokens.filter!(a => a != tok!"whitespace"
		&& a != tok!"comment" && a != tok!"specialTokenSequence").array;

	RollbackAllocator allocator;
	uint errorCount;
	auto mod = parseModule(parseTokens, fileName, &allocator, toDelegate(&reportErrors), &errorCount);
	if (errorCount > 0)
	{
		stderr.writefln("%d parse errors encountered. Aborting upgrade of %s",
			errorCount, fileName);
		return;
	}

	File output = File(fileName, "wb");
	auto visitor = new DFixVisitor;
	visitor.visit(mod);
	relocateMarkers(visitor.markers, tokens);

	SpecialMarker[] markers = visitor.markers;

	auto formatter = new Formatter!(File.LockingTextWriter)(File.LockingTextWriter.init);

	void writeType(T)(File output, T tokens, ref size_t i)
	{
		if (isBasicType(tokens[i].type))
		{
			writeToken(output, tokens[i]);
			i++;
		}
		else if ((tokens[i] == tok!"const" || tokens[i] == tok!"immutable"
				|| tokens[i] == tok!"shared" || tokens[i] == tok!"inout")
				&& tokens[i + 1] == tok!"(")
		{
			writeToken(output, tokens[i]);
			i++;
			skipAndWrite!("(", ")")(output, tokens, i);
		}
		else
		{
			skipIdentifierChain(output, tokens, i, true);
			if (i < tokens.length && tokens[i] == tok!"!")
			{
				writeToken(output, tokens[i]);
				i++;
				if (i + 1 < tokens.length && tokens[i + 1] == tok!"(")
					skipAndWrite!("(", ")")(output, tokens, i);
				else if (tokens[i].type == tok!"identifier")
					skipIdentifierChain(output, tokens, i, true);
				else
				{
					writeToken(output, tokens[i]);
					i++;
				}
			}
		}
		skipWhitespace(output, tokens, i);
		// print out suffixes
		while (i < tokens.length && (tokens[i] == tok!"*" || tokens[i] == tok!"["))
		{
			if (tokens[i] == tok!"*")
			{
				writeToken(output, tokens[i]);
				i++;
			}
			else if (tokens[i] == tok!"[")
				skipAndWrite!("[", "]")(output, tokens, i);
		}
	}

	for (size_t i = 0; i < tokens.length; i++)
	{
		markerLoop: foreach (marker; markers)
		{
			with (SpecialMarkerType) final switch (marker.type)
			{
			case bodyEnd:
				if (tokens[i].index != marker.index)
					break;
				assert (tokens[i].type == tok!"}", format("%d %s", tokens[i].line, str(tokens[i].type)));
				writeToken(output, tokens[i]);
				i++;
				if (i < tokens.length && tokens[i] == tok!";")
					i++;
				markers = markers[1 .. $];
				break markerLoop;
			case functionAttributePrefix:
				if (tokens[i].index != marker.index)
					break;
				// skip over token to be moved
				i++;
				skipWhitespace(output, tokens, i, false);

				// skip over function return type
				writeType(output, tokens, i);
				skipWhitespace(output, tokens, i);

				// skip over function name
				skipIdentifierChain(output, tokens, i, true);
				skipWhitespace(output, tokens, i, false);

				// skip first paramters
				skipAndWrite!("(", ")")(output, tokens, i);

				immutable bookmark = i;
				skipWhitespace(output, tokens, i, false);

				// If there is a second set of parameters, go back to the bookmark
				// and print out the whitespace
				if (i < tokens.length && tokens[i] == tok!"(")
				{
					i = bookmark;
					skipWhitespace(output, tokens, i);
					skipAndWrite!("(", ")")(output, tokens, i);
					skipWhitespace(output, tokens, i, false);
				}
				else
					i = bookmark;

				// write out the attribute being moved
				output.write(" ", marker.functionAttribute);

				// if there was no whitespace, add it after the moved attribute
				if (i < tokens.length && tokens[i] != tok!"whitespace" && tokens[i] != tok!";")
					output.write(" ");

				markers = markers[1 .. $];
				break markerLoop;
			case cStyleArray:
				if (i != marker.index)
					break;
				formatter.sink = output.lockingTextWriter();
				foreach (node; retro(marker.nodes))
					formatter.format(node);
				formatter.sink = File.LockingTextWriter.init;
				skipWhitespace(output, tokens, i);
				writeToken(output, tokens[i]);
				i++;
				suffixLoop: while (i < tokens.length) switch (tokens[i].type)
				{
					case tok!"(": skipAndWrite!("(", ")")(output, tokens, i); break;
					case tok!"[": skip!("[", "]")(tokens, i); break;
					case tok!"*": i++; break;
					default: break suffixLoop;
				}
				markers = markers[1 .. $];
				break markerLoop;
			}
		}

		if (i >= tokens.length)
			break;

		switch (tokens[i].type)
		{
		case tok!"asm":
			skipAsmBlock(output, tokens, i);
			goto default;
		case tok!"catch":
			if (!dip65)
				goto default;
			size_t j = i + 1;
			while (j < tokens.length && (tokens[j] == tok!"whitespace" || tokens[j] == tok!"comment"))
				j++;
			if (j < tokens.length && tokens[j].type != tok!"(")
			{
				output.write("catch (Throwable)");
				break;
			}
			else
				goto default;
		case tok!"deprecated":
			if (dip64)
				output.write("@");
			output.writeToken(tokens[i]);
			i++;
			if (i < tokens.length && tokens[i] == tok!"(")
				skipAndWrite!("(", ")")(output, tokens, i);
			if (i < tokens.length)
				goto default;
			else
				break;
		case tok!"body":
			if (dip1003)
				output.write("do");
			else
				output.write("body");
			break;
		case tok!"stringLiteral":
			immutable size_t stringBookmark = i;
			while (tokens[i] == tok!"stringLiteral")
			{
				i++;
				skipWhitespace(output, tokens, i, false);
			}
			immutable bool parensNeeded = stringBookmark + 1 != i && tokens[i] == tok!".";
			i = stringBookmark;
			if (parensNeeded)
				output.write("(");
			output.writeToken(tokens[i]);
			i++;
			skipWhitespace(output, tokens, i);
			while (tokens[i] == tok!"stringLiteral")
			{
				output.write("~ ");
				output.writeToken(tokens[i]);
				i++;
				skipWhitespace(output, tokens, i);
			}
			if (parensNeeded)
				output.write(")");
			if (i < tokens.length)
				goto default;
			else
				break;
		case tok!"override":
		case tok!"final":
		case tok!"abstract":
		case tok!"align":
		case tok!"pure":
		case tok!"nothrow":
			if (!dip64)
				goto default;
			output.write("@");
			output.write(str(tokens[i].type));
			break;
		case tok!"alias":
			bool multipleAliases = false;
			bool oldStyle = true;
			output.writeToken(tokens[i]); // alias
				i++;
			size_t j = i + 1;

			int depth;
			loop: while (j < tokens.length) switch (tokens[j].type)
			{
			case tok!"(":
				depth++;
				j++;
				break;
			case tok!")":
				depth--;
				if (depth < 0)
				{
					oldStyle = false;
					break loop;
				}
				j++;
				break;
			case tok!"=":
			case tok!"this":
				j++;
				oldStyle = false;
				break;
			case tok!",":
				j++;
				if (depth == 0)
					multipleAliases = true;
				break;
			case tok!";":
				break loop;
			default:
				j++;
				break;
			}

			if (!oldStyle) foreach (k; i .. j + 1)
			{
				output.writeToken(tokens[k]);
				i = k;
			}
			else
			{
				skipWhitespace(output, tokens, i);

				size_t beforeStart = i;
				size_t beforeEnd = beforeStart;

				loop2: while (beforeEnd < tokens.length) switch (tokens[beforeEnd].type)
				{
				case tok!"bool":
				case tok!"byte":
				case tok!"ubyte":
				case tok!"short":
				case tok!"ushort":
				case tok!"int":
				case tok!"uint":
				case tok!"long":
				case tok!"ulong":
				case tok!"char":
				case tok!"wchar":
				case tok!"dchar":
				case tok!"float":
				case tok!"double":
				case tok!"real":
				case tok!"ifloat":
				case tok!"idouble":
				case tok!"ireal":
				case tok!"cfloat":
				case tok!"cdouble":
				case tok!"creal":
				case tok!"void":
					beforeEnd++;
					break loop2;
				case tok!".":
					beforeEnd++;
					goto case;
				case tok!"identifier":
					skipIdentifierChain(output, tokens, beforeEnd);
					break loop2;
				case tok!"typeof":
					beforeEnd++;
					skip!("(", ")")(tokens, beforeEnd);
					skipWhitespace(output, tokens, beforeEnd, false);
					if (tokens[beforeEnd] == tok!".")
						skipIdentifierChain(output, tokens, beforeEnd);
					break loop2;
				case tok!"@":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"identifier")
						beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(tokens, beforeEnd);
					skipWhitespace(output, tokens, beforeEnd, false);
					break;
				case tok!"static":
				case tok!"const":
				case tok!"immutable":
				case tok!"inout":
				case tok!"shared":
				case tok!"extern":
				case tok!"nothrow":
				case tok!"pure":
				case tok!"__vector":
					beforeEnd++;
					skipWhitespace(output, tokens, beforeEnd, false);
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(tokens, beforeEnd);
					if (beforeEnd >= tokens.length)
						break loop2;
					size_t k = beforeEnd;
					skipWhitespace(output, tokens, k, false);
					if (k + 1 < tokens.length && tokens[k + 1].type == tok!";")
						break loop2;
					else
						beforeEnd = k;
					break;
				default:
					break loop2;
				}

				i = beforeEnd;

				skipWhitespace(output, tokens, i, false);

				if (tokens[i] == tok!"*" || tokens[i] == tok!"["
					|| tokens[i] == tok!"function" || tokens[i] == tok!"delegate")
				{
					beforeEnd = i;
				}

				loop3: while (beforeEnd < tokens.length) switch (tokens[beforeEnd].type)
				{
				case tok!"*":
					beforeEnd++;
					size_t m = beforeEnd;
					skipWhitespace(output, tokens, m, false);
					if (m < tokens.length && (tokens[m] == tok!"*"
						|| tokens[m] == tok!"[" || tokens[m] == tok!"function"
						|| tokens[m] == tok!"delegate"))
					{
						beforeEnd = m;
					}
					break;
				case tok!"[":
					skip!("[", "]")(tokens, beforeEnd);
					size_t m = beforeEnd;
					skipWhitespace(output, tokens, m, false);
					if (m < tokens.length && (tokens[m] == tok!"*"
						|| tokens[m] == tok!"[" || tokens[m] == tok!"function"
						|| tokens[m] == tok!"delegate"))
					{
						beforeEnd = m;
					}
					break;
				case tok!"function":
				case tok!"delegate":
					beforeEnd++;
					skipWhitespace(output, tokens, beforeEnd, false);
					skip!("(", ")")(tokens, beforeEnd);
					size_t l = beforeEnd;
					skipWhitespace(output, tokens, l, false);
					loop4: while (l < tokens.length) switch (tokens[l].type)
					{
					case tok!"const":
					case tok!"nothrow":
					case tok!"pure":
					case tok!"immutable":
					case tok!"inout":
					case tok!"shared":
						beforeEnd = l + 1;
						l = beforeEnd;
						skipWhitespace(output, tokens, l, false);
						if (l < tokens.length && tokens[l].type == tok!"identifier")
						{
							beforeEnd = l - 1;
							break loop4;
						}
						break;
					case tok!"@":
						beforeEnd = l + 1;
						skipWhitespace(output, tokens, beforeEnd, false);
						if (tokens[beforeEnd] == tok!"(")
							skip!("(", ")")(tokens, beforeEnd);
						else
						{
							beforeEnd++; // identifier
							skipWhitespace(output, tokens, beforeEnd, false);
							if (tokens[beforeEnd] == tok!"(")
								skip!("(", ")")(tokens, beforeEnd);
						}
						l = beforeEnd;
						skipWhitespace(output, tokens, l, false);
						if (l < tokens.length && tokens[l].type == tok!"identifier")
						{
							beforeEnd = l - 1;
							break loop4;
						}
						break;
					default:
						break loop4;
					}
					break;
				default:
					break loop3;
				}

				i = beforeEnd;
				skipWhitespace(output, tokens, i, false);

				output.writeToken(tokens[i]);
				output.write(" = ");
				foreach (l; beforeStart .. beforeEnd)
					output.writeToken(tokens[l]);

				if (multipleAliases)
				{
					i++;
					skipWhitespace(output, tokens, i, false);
					while (tokens[i] == tok!",")
					{
						i++; // ,
						output.write(", ");
						skipWhitespace(output, tokens, i, false);
						output.writeToken(tokens[i]);
						output.write(" = ");
						foreach (l; beforeStart .. beforeEnd)
							output.writeToken(tokens[l]);
					}
				}
			}
			break;
		default:
			output.writeToken(tokens[i]);
			break;
		}
	}
}

/**
 * The types of special token ranges identified by the parsing pass
 */
enum SpecialMarkerType
{
	/// Function declarations such as "const int foo();"
	functionAttributePrefix,
	/// Variable and parameter declarations such as "int bar[]"
	cStyleArray,
	/// The location of a closing brace for an interface, class, struct, union,
	/// or enum.
	bodyEnd
}

/**
 * Identifies ranges of tokens in the source tokens that need to be rewritten
 */
struct SpecialMarker
{
	/// Range type
	SpecialMarkerType type;

	/// Begin byte position (before relocateMarkers) or token index
	/// (after relocateMarkers)
	size_t index;

	/// The type suffix AST nodes that should be moved
	const(TypeSuffix[]) nodes;

	/// The function attribute such as const, immutable, or inout to move
	string functionAttribute;
}

/**
 * Scans a module's parsed AST and looks for C-style array variables and
 * parameters, storing the locations in the markers array.
 */
class DFixVisitor : ASTVisitor
{
	// C-style arrays variables
	override void visit(const VariableDeclaration varDec)
	{
		if (varDec.declarators.length == 0)
			return;
		markers ~= SpecialMarker(SpecialMarkerType.cStyleArray,
			varDec.declarators[0].name.index, varDec.declarators[0].cstyle);
	}

	// C-style array parameters
	override void visit(const Parameter param)
	{
		if (param.cstyle.length > 0)
			markers ~= SpecialMarker(SpecialMarkerType.cStyleArray, param.name.index,
				param.cstyle);
		param.accept(this);
	}

	// interface, union, class, struct body closing braces
	override void visit(const StructBody structBody)
	{
		structBody.accept(this);
		markers ~= SpecialMarker(SpecialMarkerType.bodyEnd, structBody.endLocation);
	}

	// enum body closing braces
	override void visit(const EnumBody enumBody)
	{
		enumBody.accept(this);
		// skip over enums whose body is a single semicolon
		if (enumBody.endLocation == 0 && enumBody.startLocation == 0)
			return;
		markers ~= SpecialMarker(SpecialMarkerType.bodyEnd, enumBody.endLocation);
	}

	// Confusing placement of function attributes
	override void visit(const Declaration dec)
	{
		if (dec.functionDeclaration is null)
			goto end;
		if (dec.attributes.length == 0)
			goto end;
		foreach (attr; dec.attributes)
		{
			if (attr.attribute == tok!"")
				continue;
			if (attr.attribute == tok!"const"
				|| attr.attribute == tok!"inout"
				|| attr.attribute == tok!"immutable")
			{
				markers ~= SpecialMarker(SpecialMarkerType.functionAttributePrefix,
					attr.attribute.index, null, str(attr.attribute.type));
			}
		}
	end:
		dec.accept(this);
	}

	alias visit = ASTVisitor.visit;

	/// Parts of the source file identified as needing a rewrite
	SpecialMarker[] markers;
}

/**
 * Converts the marker index from a byte index into the source code to an index
 * into the tokens array.
 */
void relocateMarkers(SpecialMarker[] markers, const(Token)[] tokens) pure nothrow @nogc
{
	foreach (ref marker; markers)
	{
		if (marker.type != SpecialMarkerType.cStyleArray)
			continue;
		size_t index = 0;
		while (tokens[index].index != marker.index)
			index++;
		marker.index = index - 1;
	}
}

/**
 * Writes a token to the output file.
 */
void writeToken(File output, ref const(Token) token)
{
	output.write(token.text is null ? str(token.type) : token.text);
}

void skipAndWrite(alias Open, alias Close)(File output, const(Token)[] tokens, ref size_t index)
{
	int depth = 1;
	writeToken(output, tokens[index]);
	index++;
	while (index < tokens.length && depth > 0) switch (tokens[index].type)
	{
	case tok!Open:
		depth++;
		writeToken(output, tokens[index]);
		index++;
		break;
	case tok!Close:
		depth--;
		writeToken(output, tokens[index]);
		index++;
		break;
	default:
		writeToken(output, tokens[index]);
		index++;
		break;
	}
}

/**
 * Skips balanced parens, braces, or brackets. index will be incremented to
 * index tokens just after the balanced closing token.
 */
void skip(alias Open, alias Close)(const(Token)[] tokens, ref size_t index)
{
	int depth = 1;
	index++;
	while (index < tokens.length && depth > 0) switch (tokens[index].type)
	{
	case tok!Open: depth++;  index++; break;
	case tok!Close: depth--; index++; break;
	default:                 index++; break;
	}
}

/**
 * Skips whitespace tokens, incrementing index until it indexes tokens at a
 * non-whitespace token.
 */
void skipWhitespace(File output, const(Token)[] tokens, ref size_t index, bool print = true)
{
	while (index < tokens.length && (tokens[index] == tok!"whitespace" || tokens[index] == tok!"comment"))
	{
		if (print) output.writeToken(tokens[index]);
		index++;
	}
}

/**
 * Advances index until it indexs the token just after an identifier or template
 * chain.
 */
void skipIdentifierChain(File output, const(Token)[] tokens, ref size_t index, bool print = false)
{
	loop: while (index < tokens.length) switch (tokens[index].type)
	{
	case tok!".":
		if (print)
			writeToken(output, tokens[index]);
		index++;
		skipWhitespace(output, tokens, index, false);
		break;
	case tok!"identifier":
		if (print)
			writeToken(output, tokens[index]);
		index++;
		size_t i = index;
		skipWhitespace(output, tokens, i, false);
		if (tokens[i] == tok!"!")
		{
			i++;
			if (print)
				writeToken(output, tokens[index]);
			index++;
			skipWhitespace(output, tokens, i, false);
			if (tokens[i] == tok!"(")
			{
				if (print)
					skipAndWrite!("(", ")")(output, tokens, i);
				else
					skip!("(", ")")(tokens, i);
				index = i;
			}
			else
			{
				i++;
				if (print)
					writeToken(output, tokens[index]);
				index++;
			}
		}
		if (tokens[i] != tok!".")
			break loop;
		break;
	case tok!"whitespace":
		index++;
		break;
	default:
		break loop;
	}
}

/**
 * Skips over an attribute
 */
void skipAttribute(File output, const(Token)[] tokens, ref size_t i)
{
	switch (tokens[i].type)
	{
	case tok!"@":
		output.writeToken(tokens[i]);
		i++; // @
		skipWhitespace(output, tokens, i, true);
		switch (tokens[i].type)
		{
		case tok!"identifier":
			output.writeToken(tokens[i]);
			i++; // identifier
			skipWhitespace(output, tokens, i, true);
			if (tokens[i].type == tok!"(")
				goto case tok!"(";
			break;
		case tok!"(":
			int depth = 1;
			output.writeToken(tokens[i]);
			i++;
			while (i < tokens.length && depth > 0) switch (tokens[i].type)
			{
			case tok!"(": depth++; output.writeToken(tokens[i]); i++; break;
			case tok!")": depth--; output.writeToken(tokens[i]); i++; break;
			default:               output.writeToken(tokens[i]); i++; break;
			}
			break;
		default:
			break;
		}
		break;
	case tok!"nothrow":
	case tok!"pure":
		output.writeToken(tokens[i]);
		i++;
		break;
	default:
		break;
	}
}

/**
 * Skips over (and prints) an asm block
 */
void skipAsmBlock(File output, const(Token)[] tokens, ref size_t i)
{
	import std.exception : enforce;

	output.write("asm");
	i++; // asm
	skipWhitespace(output, tokens, i);
	loop: while (true) switch (tokens[i].type)
	{
	case tok!"@":
	case tok!"nothrow":
	case tok!"pure":
		skipAttribute(output, tokens, i);
		skipWhitespace(output, tokens, i);
		break;
	case tok!"{":
		break loop;
	default:
		break loop;
	}
	enforce(tokens[i].type == tok!"{");
	output.write("{");
	i++; // {
	int depth = 1;
	while (depth > 0 && i < tokens.length) switch (tokens[i].type)
	{
	case tok!"{": depth++; goto default;
	case tok!"}": depth--; goto default;
	default: writeToken(output, tokens[i]); i++; break;
	}
}

/**
 * Dummy message output function for the lexer/parser
 */
void reportErrors(string fileName, size_t lineNumber, size_t columnNumber,
	string message, bool isError)
{
	import std.stdio : stderr;

	if (!isError)
		return;
	stderr.writefln("%s(%d:%d)[error]: %s", fileName, lineNumber, columnNumber, message);
}
