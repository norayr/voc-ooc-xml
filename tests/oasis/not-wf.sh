#!/bin/sh

err_count=0
for i in `cat not-wf.list`; do
  rm -f test-output/$i test-output/$i.err
  if $TEST_PROG "$i" >test-output/$i 2>test-output/$i.err; then
    err_count=`expr $err_count + 1`
    echo "failed: $i (exit code is zero)"
  else
    if $DIFF "out-err/`basename $i`.err" test-output/$i.err; then
      echo "ok: $i"
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i"
    fi
  fi
done

test $err_count = "0"
exit $?
