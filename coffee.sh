#!/usr/bin/env bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 dev/deploy"
    exit 1
fi

if [ $1 = "dev" ]
then
	coffee -o coffee -wc coffee
elif [ $1 = "deploy" ]
then
	coffee -o coffee -c coffee
	echo "Coffee done"
	for i in `ls coffee/*.js`
	do
		uglifyjs $i -o $i
		echo "Uglified $i"
	done
else
	echo "dev or deploy?"
	exit 1
fi
