#!/bin/bash  

if [ "$1" = 'test' ]; then

    echo "Executing tests"
    if [[ -z $DIR ]]; then
	DIR="ALL"
    fi
    if [[ -z $TEST ]]; then
	TEST="ALL"
    fi
    if [[ -z $PLATEFORME ]]; then
	PLATEFORME="DEV"
    fi

    cd tests && exec ./test_http.sh -d $DIR -t $TEST -p $PLATEFORME

fi

exec "$@"
