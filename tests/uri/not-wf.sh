#!/bin/sh

err=0
for i in not-wf/*.txt; do
  rm -f test-output/$i test-output/$i.err
  test_uri=`grep "^TEST	" $i | sed -e "s/^TEST	//g"`
  base_uri=`grep "^BASE	" $i | sed -e "s/^BASE	//g"`
  if $TEST_PROG "$test_uri" "$base_uri" >/dev/null 2>test-output/$i.err; then
    err=1
    echo "failed: $i (exit code is zero)"
  else
    if $DIFF "`dirname $i`/out-err/`basename $i`.err" test-output/$i.err; then
      echo "ok: $i"
    else
      err=1
      echo "failed: $i"
    fi
  fi
done

exit $err
