#!/bin/sh

err_count=0
for i in `cat valid.list`; do
  rm -f test-output/$i
  if $TEST_PROG  "$i" >test-output/$i; then
    echo "ok: $i [wf]"
  else
    err_count=`expr $err_count + 1`
    echo "failed: $i [wf] (exit code is non-zero)"
    exit 1
  fi
  
  rm -f test-output/$i
  if $TEST_PROG  -v "$i" >test-output/$i; then
    echo "ok: $i [valid]"
  else
    err_count=`expr $err_count + 1`
    echo "failed: $i [valid] (exit code is non-zero)"
    exit 1
  fi
done

test $err_count = "0"
exit $?
