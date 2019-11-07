#!/bin/sh

./kill_containers.sh
./pgpool.sh
PGPOOL_IP="$(docker inspect pgpool \
    | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r -e)"

pgbench -i -U postgres -p 9999 -h "$PGPOOL_IP" postgres

cd benchmarks || exit 1
./multiple_slaves.sh postgres

