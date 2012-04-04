#!/bin/sh

FILE=$1
KERNELVER=$2

for WORD in `cat $FILE`; do
    if echo $WORD | grep -q ":"; then
        echo ""
    fi
    echo -n "/lib/modules/$KERNELVER/$WORD"
done