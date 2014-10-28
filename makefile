FLAGS = -Ilibdparse/src/\
	-g\
	-ofbin/dfix

FILES = src/dfix.d\
	libdparse/src/std/allocator.d\
	libdparse/src/std/lexer.d\
	libdparse/src/std/d/lexer.d\
	libdparse/src/std/d/parser.d\
	libdparse/src/std/d/formatter.d\
	libdparse/src/std/d/ast.d

dfix_binary:
	rm -rf bin
	mkdir -p bin
	dmd ${FILES} ${FLAGS}
	rm -f bin/dfix.o

clean:
	rm -rf bin
	rm -rf test/testfile.d

test: dfix_binary
	cp test/testfile_master.d test/testfile.d
	./bin/dfix test/testfile.d
	diff test/testfile.d test/testfile_expected.d
