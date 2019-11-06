#!/bin/bash
n_slaves=${1:-2}
case $n_slaves in
    ''|*[!0-9]*)
        echo number of slaves has to be an integer, got: "'$n_slaves'"
        exit 1
        ;;
esac
echo master
for i in $(seq 1 "$n_slaves")
do
    echo "slave$i"
done
echo pgpool-1
echo pgpool-2
