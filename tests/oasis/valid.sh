#!/bin/sh

err_count=0
for i in `cat valid.list`; do
  rm -f test-output/$i
  if $TEST_PROG  "$i" >test-output/$i; then
    echo "ok: $i"
  else
    err_count=`expr $err_count + 1`
    echo "failed: $i (exit code is non-zero)"
    exit 1
  fi
done

test $err_count = "0"
exit $?
