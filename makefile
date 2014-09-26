FLAGS = -Ilibdparse/src/\
	-g

FILES = src/dfix.d\
	libdparse/src/std/allocator.d\
	libdparse/src/std/lexer.d\
	libdparse/src/std/d/lexer.d\
	libdparse/src/std/d/parser.d\
	libdparse/src/std/d/ast.d

all:
	dmd ${FILES} ${FLAGS}
