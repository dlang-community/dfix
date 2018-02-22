DMD ?= dmd

FLAGS := -Ilibdparse/src/\
	-Istdx-allocator/source/\
	-wi\
	-g\
	-dip25\
	-ofbin/dfix

FILES := src/dfix.d \
	$(shell find libdparse/src/ -name "*.d") \
	$(shell find stdx-allocator/source/ -name "*.d")

dfix_binary:
	rm -rf bin
	mkdir -p bin
	${DMD} ${FILES} ${FLAGS}
	rm -f bin/dfix.o

clean:
	rm -rf bin
	rm -rf test/testfile.d

test: dfix_binary
	cp test/testfile_master.d test/testfile.d
	./bin/dfix test/testfile.d
	diff test/testfile.d test/testfile_expected.d
	# Make sure that running dfix on the output of dfix changes nothing.
	./bin/dfix test/testfile.d
	diff test/testfile.d test/testfile_expected.d
