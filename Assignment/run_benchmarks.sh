#!/bin/sh

set -e
rm -rf results
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

    pgbench -i -U postgres -p 9999 -h "$PGPOOL_IP" postgres

    ./benchmarks/multiple_slaves.sh postgres "$PGPOOL_IP" 9999 postgres \
        "results/multiple_slaves_${i}slaves/"
    ./kill_containers.sh
done

