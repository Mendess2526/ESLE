#!/bin/bash

set -e
if [ "$1" != "" ]; then
    if [ "$2" != "" ]; then
        from="$1"
        to="$2"
    else
        from=0
        to="$1"
    fi
else
    from=0
    to=2
fi

./kill_containers.sh
for i in $(seq "$from" "$to"); do
    ./pgpool.sh "$i"
    PGPOOL_IP="$(docker inspect pgpool \
        | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r -e)"

    echo -e "\e[34mINITIALIZING DB\e[0m"

    pgbench -i -U postgres -p 9999 -h "$PGPOOL_IP" postgres

    echo -e "\e[34mRUNNING BENCHMARKS\e[0m"
    result_dir="results/multiple_slaves_${i}slaves/"
    rm -vrf "$result_dir"

    ./benchmarks/multiple_slaves.sh postgres "$PGPOOL_IP" 9999 postgres "$result_dir"

    ./kill_containers.sh
done

