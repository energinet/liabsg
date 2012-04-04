#! /bin/bash

PACKAGES=packages-deb-arm

if [ "$#" -eq 0 ]; then
    echo $"Usage: search.sh <package>"
    return 1
fi

deb=`cat $PACKAGES/Filelist | awk -v deb=$1 '{if ($1 == "Package:" && $2 == deb) {found=1}; if ($1 == "Filename:" && found == 1) {found = 0; print $2}}'`

if [ "$deb" == "" ]; then
    grep -e "$1" $PACKAGES/Contents-arm
else
    echo $deb
fi
