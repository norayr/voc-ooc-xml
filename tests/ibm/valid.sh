#!/bin/sh

err_count=0
for j in ibm/valid/*/*.xml; do
  i="`echo "$j"|sed -e s:^ibm/::`"
  if test ! -d test-output/`dirname "$i"`; then
    mkdir test-output/`dirname "$i"`
  fi
  
  rm -f test-output/$i
  if test "$j" == "ibm/valid/P02/ibm02v01.xml"; then
    echo "skipping: $i [encoding errors?]"
  elif $TEST_PROG -2 "$j" >test-output/$i; then
    if $DIFF "`dirname $j`/out/`basename $i`" test-output/$i; then
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
  if test "$j" == "ibm/valid/P02/ibm02v01.xml"; then
    echo "skipping: $i [encoding errors?]"
  elif test "$j" == "ibm/valid/P58/ibm58v01.xml"; then
    echo "skipping: $i [duplicate tokens in NOTATION declaration]"
  elif $TEST_PROG -v -2 "$j" >test-output/$i; then
    if $DIFF "`dirname $j`/out/`basename $i`" test-output/$i; then
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

test $err_count = "0"
exit $?
