.PHONY: clean test

clean:
	rm -Rf sym/* obj/* TestCodecs TestParser
	cd tests && ${MAKE} clean

test:
	cd tests && ${MAKE} test
