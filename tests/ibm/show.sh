#!/bin/sh
for i in ibm/not-wf/*/*.xml; do
    echo "[$i]"
    cat "$i"
    echo
    echo "--------------------------------------------------------------------"
    j="`echo "$i"|sed -e 's:^ibm/:reference/:'`".err
    echo "[$j]"
    cat "$j"
    echo
    echo "####################################################################"
done
