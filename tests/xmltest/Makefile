TEST_PROG=../../TestParser
scripts=./not-wf.sh ./valid.sh

export DIFF=diff -u

.PHONY: all clean test ${TEST_PROG}

readme.html:
	(cd .. && gzip -cd 3rd-party-archives/xmltest.tar.gz | tar xfv -)
	patch -p1 <../3rd-party-archives/xmltest.diff

test-output:
	mkdir test-output test-output/valid test-output/valid/ext-sa test-output/valid/not-sa test-output/valid/sa test-output/not-wf test-output/not-wf/sa test-output/not-wf/ext-sa test-output/not-wf/not-sa

${TEST_PROG}:
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

clean:
	for i in canonxml.html invalid not-wf/sa/*.xml not-wf/not-sa/*.xml not-wd/ext-sa/*.xml readme.html valid; do rm -Rf "$$i"; done
	rm -Rf test-output

test: readme.html test-output ${TEST_PROG}
	set -e; for i in ${scripts}; do env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" $$i || exit 1; done
