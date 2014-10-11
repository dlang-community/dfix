module dfix;

import std.lexer;
import std.d.lexer;
import std.d.parser;
import std.d.ast;
import std.stdio;

int main(string[] args)
{
	import std.getopt : getopt;
	import std.parallelism : parallel;

	// http://wiki.dlang.org/DIP64
	bool dip64;
	// http://wiki.dlang.org/DIP65
	bool dip65;

	bool help;

	try
		getopt(args, "dip64", &dip64, "dip65", &dip65, "help|h", &help);
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

	foreach (sourceFile; parallel(args[1 .. $]))
	{
		upgradeFile(sourceFile, dip64, dip65);
	}

	return 0;
}

void printHelp()
{
	stdout.writeln(`
Dfix automatically upgrades D source code to comply with new language changes.
Files are modified in place, so have backup copies ready, or use a source
control system.

Usage:

    dfix [Options] FILES

Options:

    --dip64
        Rewrites attributes to be compliant with DIP64.
    --dip65
        Rewrites catch blocks to be compliant with DIP65.
    --help -h
        Prints this help message
`);
}

void upgradeFile(string fileName, bool dip64, bool dip65)
{
	import std.algorithm : filter;
	import std.array : array, uninitializedArray;
	import std.d.formatter : Formatter;

	File input = File(fileName, "rb");
	ubyte[] inputBytes = uninitializedArray!(ubyte[])(input.size);
	input.rawRead(inputBytes);
	input.close();
	File output = File(fileName, "wb");
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	LexerConfig config;
	config.fileName = fileName;
	config.stringBehavior = StringBehavior.source;
	auto tokens = byToken(inputBytes, config, &cache).array;
	auto parseTokens = tokens.filter!(a => a != tok!"whitespace"
		&& a != tok!"comment" && a != tok!"specialTokenSequence").array;

	auto mod = parseModule(parseTokens, fileName, null, &doesNothing);
	auto visitor = new DFixVisitor;
	visitor.visit(mod);
	relocateMarkers(visitor.markers, tokens);

	SpecialMarker[] markers = visitor.markers;

	auto formatter = new Formatter!(File.LockingTextWriter)(File.LockingTextWriter.init);

	for (size_t i = 0; i < tokens.length; i++)
	{
		if (markers.length > 0 && i == markers[0].index)
		{
			formatter.sink = output.lockingTextWriter();
			foreach (node; markers[0].nodes)
				formatter.format(node);
			formatter.sink = File.LockingTextWriter.init;
			markers = markers[1 .. $];
			skipWhitespace(output, tokens, i);
			writeToken(output, tokens[i]);
			i++;
			suffixLoop: while (i < tokens.length) switch (tokens[i].type)
			{
				case tok!"(": skip!("(", ")")(tokens, i); break;
				case tok!"[": skip!("[", "]")(tokens, i); break;
				case tok!"*": i++; break;
				default: break suffixLoop;
			}
		}

		switch (tokens[i].type)
		{
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
		case tok!"stringLiteral":
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
			if (i < tokens.length)
				goto default;
			else
				break;
		case tok!"override":
		case tok!"final":
		case tok!"deprecated":
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
					skipIdentifierList(output, tokens, beforeEnd);
					break loop2;
				case tok!"typeof":
					beforeEnd++;
					skip!("(", ")")(tokens, beforeEnd);
					skipWhitespace(output, tokens, beforeEnd, false);
					if (tokens[beforeEnd] == tok!".")
						skipIdentifierList(output, tokens, beforeEnd);
					break loop2;
				case tok!"@":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"identifier")
						beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(tokens, beforeEnd);
					skipWhitespace(output, tokens, beforeEnd, false);
					break;
				case tok!"const":
				case tok!"immutable":
				case tok!"inout":
				case tok!"shared":
				case tok!"extern":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(tokens, beforeEnd);
					skipWhitespace(output, tokens, beforeEnd, false);
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
				case tok!"*": beforeEnd++; break;
				case tok!"[": skip!("[", "]")(tokens, beforeEnd); break;
				case tok!"function":
				case tok!"delegate":
					beforeEnd++;
					skip!("(", ")")(tokens, beforeEnd);
					loop4: while (beforeEnd < tokens.length) switch (tokens[beforeEnd].type)
					{
					case tok!"const":
					case tok!"nothrow":
					case tok!"pure":
					case tok!"immutable":
					case tok!"inout":
					case tok!"shared":
						beforeEnd++;
						skipWhitespace(output, tokens, beforeEnd, false);
						break;
					case tok!"@":
						beforeEnd++;
						if (tokens[beforeEnd] == tok!"(")
						{
							skip!("(", ")")(tokens, beforeEnd);
						}
						else
						{
							beforeEnd++; // identifier
							if (tokens[beforeEnd] == tok!"(")
								skip!("(", ")")(tokens, beforeEnd);
						}
						skipWhitespace(output, tokens, beforeEnd, false);
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
	cStyleArray
}

/**
 * Identifies ranges of tokens in the source tokens that need to be rewritten
 */
struct SpecialMarker
{
	/// Range type
	SpecialMarkerType type;

	/// Begin byte position (inclusive)
	size_t index;

	const(TypeSuffix[]) nodes;
}

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
		if (param.cstyle.length == 0)
			return;
		markers ~= SpecialMarker(SpecialMarkerType.cStyleArray, param.name.index,
			param.cstyle);
	}

	alias visit = ASTVisitor.visit;

	SpecialMarker[] markers;
}

void relocateMarkers(SpecialMarker[] markers, const(Token)[] tokens)
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

void writeToken(File output, ref const(Token) token)
{
	output.write(token.text is null ? str(token.type) : token.text);
}

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

void skipWhitespace(File output, const(Token)[] tokens, ref size_t index, bool print = true)
{
	while (index < tokens.length && (tokens[index] == tok!"whitespace" || tokens[index] == tok!"comment"))
	{
		if (print) output.writeToken(tokens[index]);
		index++;
	}
}
void skipIdentifierList(File output, const(Token)[] tokens, ref size_t index)
{
	loop: while (index < tokens.length) switch (tokens[index].type)
	{
	case tok!".":
		index++;
		skipWhitespace(output, tokens, index, false);
		break;
	case tok!"identifier":
		index++;
		size_t i = index;
		skipWhitespace(output, tokens, i, false);
		if (tokens[i] == tok!"!")
		{
			index = i + 1;
			skipWhitespace(output, tokens, i, false);
			if (tokens[i] == tok!"(")
			{
				index = i;
				skip!("(", ")")(tokens, index);
			}
		}
		if (tokens[index] != tok!".")
			break loop;
		break;
	default:
		break loop;
	}
}


void doesNothing(string, size_t, size_t, string, bool) {}
