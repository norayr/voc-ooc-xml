.PHONY: clean test

mkdirs:
	for i in sym obj; do if test ! -d $$i; then mkdir $$i; fi; done

clean:
	rm -Rf sym obj TestCodecs TestParser
	cd tests && ${MAKE} clean

test: mkdirs
	cd tests && ${MAKE} test
