#!/bin/sh

err_count=0
for i in `cat invalid.list`; do
  rm -f test-output/$i test-output/$i.err
  if test $i == p16pass1.xml; then
    echo "skipping: $i [not well-formed, uses reserved PI target name]"
  elif $TEST_PROG "$i" >test-output/$i 2>test-output/$i.err; then
    echo "ok: $i [wf]"
  else
    err_count=`expr $err_count + 1`
    echo "failed: $i [wf] (exit code is non-zero)"
  fi

  rm -f test-output/$i test-output/$i.err
  if $TEST_PROG -v "$i" >test-output/invalid/$i 2>test-output/invalid/$i.err; then
    err_count=`expr $err_count + 1`
    echo "failed: $i [valid] (exit code is zero)"
  else
    if $DIFF "invalid/out-err/`basename $i`.err" test-output/invalid/$i.err; then
      echo "ok: $i [valid]"
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i [valid]"
    fi
  fi
done

test $err_count = "0"
exit $?
