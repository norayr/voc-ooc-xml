TEST_PROG=../../TestURI

.PHONY: all clean test ${TEST_PROG} 

all: test

${TEST_PROG} :
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

test-output:
	mkdir test-output test-output/wf test-output/not-wf test-output/abs2rel

test: test-output ${TEST_PROG} 
	env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" ./wf.sh
	env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" ./not-wf.sh
	env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" ./abs2rel.sh

clean:
	rm -Rf test-output
