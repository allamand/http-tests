#!/bin/bash

DIR=`pwd`

echo $DIR


if [[ -d results ]]; then
    echo "results :  exists pruge it!!"
    rm -rf results/*2010*
fi

if [[ -f Global_result.txt ]]; then
    echo "Global_result.txt :  exists pruge it!!"
    rm -f Global_result.txt
fi
