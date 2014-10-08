module dfix;

import std.lexer;
import std.d.lexer;
import std.array;
import std.stdio;
import std.getopt;

int main(string[] args)
{
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

	File input = File(args[1], "rb");
	ubyte[] inputBytes = uninitializedArray!(ubyte[])(input.size);
	input.rawRead(inputBytes);
	input.close();
	File output = File(args[1], "wb");
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	LexerConfig config;
	config.fileName = args[1];
	config.stringBehavior = StringBehavior.source;
	auto tokens = byToken(inputBytes, config, &cache).array;

	void writeToken(size_t index)
	{
		output.write(tokens[index].text is null
			? str(tokens[index].type)
			: tokens[index].text);
	}

	void skip(alias Open, alias Close)(ref size_t index)
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

	void skipWhitespace(ref size_t index, bool print = true)
	{
		while (index < tokens.length && (tokens[index] == tok!"whitespace" || tokens[index] == tok!"comment"))
		{
			if (print) writeToken(index);
			index++;
		}
	}

	void skipIdentifierList(ref size_t index)
	{
		loop: while (index < tokens.length) switch (tokens[index].type)
		{
		case tok!".":
			index++;
			skipWhitespace(index, false);
			break;
		case tok!"identifier":
			index++;
			size_t i = index;
			skipWhitespace(i, false);
			if (tokens[i] == tok!"!")
			{
				index = i + 1;
				skipWhitespace(i, false);
				if (tokens[i] == tok!"(")
				{
					index = i;
					skip!("(", ")")(index);
				}
			}
			if (tokens[index] != tok!".")
				break loop;
			break;
		default:
			break loop;
		}
	}

	for (size_t i = 0; i < tokens.length; i++)
	{
		switch (tokens[i].type)
		{
		case tok!"catch":
			if (!dip65)
				break;
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
			writeToken(i);
			i++;
			skipWhitespace(i);
			while (true)
			{
				if (tokens[i] == tok!"stringLiteral")
				{
					output.write("~ ");
					writeToken(i);
					i++;
				}
				else
					break;
				skipWhitespace(i);
			}
			break;
		case tok!"pure":
		case tok!"nothrow":
			if (!dip64)
				break;
			output.write("@");
			output.write(str(tokens[i].type));
			break;
		case tok!"alias":
			bool oldStyle = true;
			writeToken(i); // alias
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
				writeToken(k);
				i = k;
			}
			else
			{
				skipWhitespace(i);

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
					skipIdentifierList(beforeEnd);
					break loop2;
				case tok!"typeof":
					beforeEnd++;
					skip!("(", ")")(beforeEnd);
					skipWhitespace(beforeEnd, false);
					if (tokens[beforeEnd] == tok!".")
						skipIdentifierList(beforeEnd);
					break loop2;
				case tok!"@":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"identifier")
						beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(beforeEnd);
					skipWhitespace(beforeEnd, false);
					break;
				case tok!"const":
				case tok!"immutable":
				case tok!"inout":
				case tok!"shared":
				case tok!"extern":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(beforeEnd);
					skipWhitespace(beforeEnd, false);
					break;
				default:
					break loop2;
				}

				i = beforeEnd;

				skipWhitespace(i, false);

				if (tokens[i] == tok!"*" || tokens[i] == tok!"["
					|| tokens[i] == tok!"function" || tokens[i] == tok!"delegate")
				{
					beforeEnd = i;
				}

				loop3: while (beforeEnd < tokens.length) switch (tokens[beforeEnd].type)
				{
				case tok!"*": beforeEnd++; break;
				case tok!"[": skip!("[", "]")(beforeEnd); break;
				case tok!"function":
				case tok!"delegate":
					beforeEnd++;
					skip!("(", ")")(beforeEnd);
					loop4: while (beforeEnd < tokens.length) switch (tokens[beforeEnd].type)
					{
					case tok!"const":
					case tok!"nothrow":
					case tok!"pure":
					case tok!"immutable":
					case tok!"inout":
					case tok!"shared":
						beforeEnd++;
						skipWhitespace(beforeEnd, false);
						break;
					case tok!"@":
						beforeEnd++;
						if (tokens[beforeEnd] == tok!"(")
						{
							skip!("(", ")")(beforeEnd);
						}
						else
						{
							beforeEnd++; // identifier
							if (tokens[beforeEnd] == tok!"(")
								skip!("(", ")")(beforeEnd);
						}
						skipWhitespace(beforeEnd, false);
						break;
					default:
						break loop4;
					}
					break;
				default:
					break loop3;
				}

				i = beforeEnd;
				skipWhitespace(i, false);

				writeToken(i);
				output.write(" = ");
				foreach (l; beforeStart .. beforeEnd)
					writeToken(l);
			}
			break;
		default:
			writeToken(i);
			break;
		}
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
