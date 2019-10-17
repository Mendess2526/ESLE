#!/bin/sh

if [ $# -lt 3 ]
then
    echo usage: "$0" y d k [outpfile]
    exit 1
fi
gnuplot -e "y = $1; d = $2; k = $3; set output '${4:-output.pdf}'" lab3.gp
