TEST_PROG=../../TestParser
scripts=./not-wf.sh ./valid.sh ./invalid.sh

.PHONY: all clean test ${TEST_PROG}

ibm/ibm_oasis_readme.txt:
	gzip -cd ../3rd-party-archives/ibm.tar.gz | tar xfv -

test-output:
	mkdir test-output test-output/valid test-output/not-wf test-output/invalid

${TEST_PROG}:
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

clean:
	rm -Rf ibm test-output

test: ibm/ibm_oasis_readme.txt test-output ${TEST_PROG}
	set -e; for i in ${scripts}; do env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" $$i || exit 1; done
