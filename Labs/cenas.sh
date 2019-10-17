#!/bin/bash

echo "#Clients Throughput"
for n in {1..40}
do
    echo "Running for $n clients" 1>&2
    docker run \
        --cpus=0.01 \
        yokogawa/siege --concurrent=$n --delay=1 --time=1m http://172.17.0.3:80 2>&1 \
        | tee out$n \
        | grep 'Transaction rate' \
        | grep -Po '[0-9.]+' \
        | sed "s/^/$n /"
done
