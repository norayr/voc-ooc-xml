TEST_PROG=../../TestParser
scripts=./not-wf.sh ./valid.sh

export DIFF=diff -u

.PHONY: all clean test ${TEST_PROG}

oasis.xml:
	(cd .. && gzip -cd 3rd-party-archives/oasis.tar.gz | tar xfv -)

valid.list: oasis.xml
	perl ../filter_tests.pl oasis.xml

test-output:
	mkdir test-output test-output/valid

${TEST_PROG}:
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

clean:
	for i in *.xml *.dtd; do rm -Rf "$$i"; done
	rm -Rf test-output

test: oasis.xml valid.list test-output ${TEST_PROG}
	set -e; for i in ${scripts}; do env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" $$i || exit 1; done
