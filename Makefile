.PHONY: clean test

mkdirs:
	for i in sym obj; do if test ! -d $$i; then mkdir $$i; fi; done

clean:
	rm -Rf sym obj doc TestCodecs TestParser TestURI
	cd tests && ${MAKE} clean

test: mkdirs
	cd tests && ${MAKE} test

dist: clean
	f="ooc-libxml-`date +%Y%m%d`.tar"; cd .. && tar -c -v -f $$f libxml && bzip2 -9 $$f
