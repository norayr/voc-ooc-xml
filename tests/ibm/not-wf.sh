#!/bin/sh

err_count=0
for j in ibm/not-wf/*/*.xml; do
  i="`echo "$j"|sed -e s:^ibm/::`"
  if test ! -d test-output/`dirname "$i"`; then
    mkdir test-output/`dirname "$i"`
  fi
  
  rm -f test-output/$i test-output/$i.err
  if $TEST_PROG "$j" >test-output/$i 2>test-output/$i.err; then
    err_count=`expr $err_count + 1`
    echo "failed: $i (exit code is zero)"
  else
    if $DIFF "reference/$i.err" test-output/$i.err; then
      echo "ok: $i"
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i"
    fi
  fi
done

test $err_count = "0"
exit $?
