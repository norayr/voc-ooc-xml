#!/bin/sh

SUBDIR="valid"

err_count=0
for d in $SUBDIR; do
  for i in $d/*.xml; do
    rm -f test-output/$i
    if $TEST_PROG -2 "$i" >test-output/$i; then
      if $DIFF "$d/out/`basename $i`" test-output/$i; then
	echo "ok: $i [wf]"
      else
	err_count=`expr $err_count + 1`
	echo "failed: $i [wf]"
        exit 1
      fi
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i [wf] (exit code is non-zero)"
      exit 1
    fi

    rm -f test-output/$i
    if test $i = valid/empty.xml; then
      echo "skipping: $i [invalid, element content does not match S]"
    elif $TEST_PROG -v -2 "$i" >test-output/$i; then
      if $DIFF "$d/out/`basename $i`" test-output/$i; then
	echo "ok: $i [valid]"
      else
	err_count=`expr $err_count + 1`
	echo "failed: $i [valid]"
        exit 1
      fi
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i [valid] (exit code is non-zero)"
      exit 1
    fi
  done
done

test $err_count = "0"
exit $?
