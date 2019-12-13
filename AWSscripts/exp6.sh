#!/bin/sh

git clone https://github.com/paunin/PostDock
cd PostDock || exit 1
sed -i 's/connection_cache = on/connection_cache = off/g' src/pgpool/configs/pgpool.conf
docker-compose -f ./docker-compose/latest.yml up -d pgmaster pgslave1 pgslave2 pgslave3 pgslave4 pgpool ; sleep 1m
docker update -m 512g --cpus 0.2 $(docker ps -q)
IP="$(docker inspect dockercompose_pgpool_1 | jq '.[0].NetworkSettings.Networks.dockercompose_cluster.IPAddress' -r)"
pgbench -i -U monkey_user -h "$IP" monkey_db
pgbench -T60 -c 80 -h "$IP" -U monkey_user monkey_db
pgbench -T60 -S -c 80 -h "$IP" -U monkey_user monkey_db
