module dfix;

import std.lexer;
import std.d.lexer;
import std.array;
import std.stdio;

void main(string[] args)
{
	File input = File(args[1]);
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
		case tok!"alias":
			bool oldStyle = true;
			writeToken(i); // alias
				i++;
			size_t j = i + 1;
			loop: while (j < tokens.length) switch (tokens[j].type)
			{
			case tok!"=": j++; oldStyle = false;
			case tok!";": break loop;
			default: j++; break;
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
				case tok!"const":
				case tok!"immutable":
				case tok!"inout":
				case tok!"shared":
					beforeEnd++;
					if (tokens[beforeEnd] == tok!"(")
						skip!("(", ")")(beforeEnd);
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
}

