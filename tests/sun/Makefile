TEST_PROG=../../TestParser
#scripts=./invalid.sh
scripts=./not-wf.sh ./valid.sh ./invalid.sh

.PHONY: all clean test ${TEST_PROG}

cxml.html:
	(cd .. && gzip -cd 3rd-party-archives/sun.tar.gz | tar xfv -)
	patch -p1 <../3rd-party-archives/sun.diff
	mv valid/sun-valid.xml .
	mv not-wf/sun-not-wf.xml .
	rm -f not-wf/lang0[1-6].xml  # no longer not-wf since First Ed. E73
	rm -f invalid/pe01.*	     # external pe well-formed by definition

test-output:
	mkdir test-output test-output/valid test-output/not-wf test-output/invalid

${TEST_PROG}:
	cd `dirname ${TEST_PROG}` && ${OOC} -MOv `basename ${TEST_PROG}`

clean:
	for i in cxml.html error invalid/*.* not-wf/*.* sun-*.xml valid; do rm -Rf "$$i"; done
	rm -Rf test-output

test: cxml.html test-output ${TEST_PROG}
	set -e; for i in ${scripts}; do env TEST_PROG="${TEST_PROG}" DIFF="${DIFF}" $$i || exit 1; done
