#!/bin/sh

err_count=0
for j in ibm/invalid/*/*.xml; do
  i="`echo "$j"|sed -e s:^ibm/::`"
  if test ! -d test-output/`dirname "$i"`; then
    mkdir test-output/`dirname "$i"`
  fi
  
  rm -f test-output/$i test-output/$i.err
  if test "$i" == "invalid/P32/ibm32i02.xml"; then
    echo "skipping: $i [refers to non-declared entity if not following external references]"
  elif $TEST_PROG -i "$j" >test-output/$i 2>test-output/$i.err; then
      echo "ok: $i [wf]"
  else
      err_count=`expr $err_count + 1`
      echo "failed: $i [wf] (exit code is non-zero)"
  fi

  if $TEST_PROG -v "$j" >test-output/$i 2>test-output/$i.err; then
    err_count=`expr $err_count + 1`
    echo "failed: $i [valid] (exit code is zero)"
  else
    if $DIFF "reference/$i.err" test-output/$i.err; then
      echo "ok: $i [valid]"
    else
      err_count=`expr $err_count + 1`
      echo "failed: $i [valid]"
    fi
  fi
done

test $err_count = "0"
exit $?
