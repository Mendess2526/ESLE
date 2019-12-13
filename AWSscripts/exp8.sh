#!/bin/sh

git clone https://github.com/paunin/PostDock
cd PostDock || exit 1
docker-compose -f ./docker-compose/latest.yml up -d pgmaster pgslave1 pgslave2 pgslave3 pgslave4 pgpool ; sleep 1m
docker update -m 1g --cpus 0.8 $(docker ps -q)
IP="$(docker inspect dockercompose_pgpool_1 | jq '.[0].NetworkSettings.Networks.dockercompose_cluster.IPAddress' -r)"
pgbench -i -U monkey_user -h "$IP" monkey_db
pgbench -T60 -c 80 -h "$IP" -U monkey_user monkey_db
pgbench -T60 -S -c 80 -h "$IP" -U monkey_user monkey_db
