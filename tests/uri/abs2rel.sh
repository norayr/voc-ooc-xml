#!/bin/sh

count=0
err_count=0
for i in abs2rel/*.txt; do
  rm -f test-output/$i
  test_uri=`grep "^TEST	" $i | sed -e "s/^TEST	//g"`
  base_uri=`grep "^BASE	" $i | sed -e "s/^BASE	//g"`
  if $TEST_PROG "$test_uri" "$base_uri" abs2rel >test-output/$i; then
    if $DIFF "`dirname $i`/out-xml/`basename $i`" test-output/$i; then
      echo "ok: $i"
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i"
    fi
  else
    err_count=`expr $err_count + 1`
    echo "failed: $i (exit code is non-zero)"
  fi
done

test $err_count = "0"
exit $?
