TEST_PROG=../../TestParser
scripts=./not-wf.sh ./valid.sh

.PHONY: all clean test ${TEST_PROG}

cxml.html:
	(cd .. && gzip -cd 3rd-party-archives/sun.tar.gz | tar xfv -)
	mv valid/sun-valid.xml .
	mv not-wf/sun-not-wf.xml .

test-output:
	mkdir test-output test-output/valid test-output/not-wf

${TEST_PROG}:
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

clean:
	for i in cxml.html error invalid not-wf/*.xml not-wf/*.dtd not-wf/decl.ent sun-*.xml valid; do rm -Rf "$$i"; done
	rm -Rf test-output

test: cxml.html test-output ${TEST_PROG}
	set -e; for i in ${scripts}; do env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" $$i || exit 1; done
