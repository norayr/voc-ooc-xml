#!/bin/sh

SUBDIR="invalid"

err_count=0
for d in $SUBDIR; do
  for i in $d/???.xml; do
    rm -f test-output/$i test-output/$i.err
    #echo $TEST_PROG -v "$i"
    if $TEST_PROG -v "$i" >test-output/$i 2>test-output/$i.err; then
      err_count=`expr $err_count + 1`
      echo "failed: $i (exit code is zero)"
    else
      if $DIFF "$d/out-err/`basename $i`.err" test-output/$i.err; then
	echo "ok: $i"
      else
	err_count=`expr $err_count + 1`
	echo "failed: $i"
      fi
    fi
  done
done

test $err_count = "0"
exit $?
