TEST_PROG=../../TestCodecs

.PHONY: all clean test ${TEST_PROG} 

all: test

${TEST_PROG} :
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

test: ${TEST_PROG} 
	${TEST_PROG} >/dev/null
