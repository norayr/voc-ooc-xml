subdirs=uri codecs xmltest sun oasis miscxml bulk protocol namespaces

export DIFF=diff -c

.PHONY: clean test

clean:
	for i in ${subdirs}; do (cd $$i && ${MAKE} clean); done

test:
	set -e; for i in ${subdirs}; do (cd $$i && ${MAKE} test) || exit 1; done
