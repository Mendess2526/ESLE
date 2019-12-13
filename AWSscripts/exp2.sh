#!/bin/sh

git clone https://github.com/pauin/PostDock
cd PostDock || exit 1
sed -i 's/REQUIRE_MIN_BACKENDS: 3/REQUIRE_MIN_BACKENDS: 1/g' docker-compose/latest.yml
docker-compose -f ./docker-compose/latest.yml up -d pgmaster pgslave1 pgpool
sleep 1m
docker update -m 512m --cpus 0.2 $(docker ps -q)
IP="$(docker inspect dockercompose_pgpool_1 | jq '.[0].NetworkSettings.Networks.dockercompose_cluster.IPAddress' -r)"
pgbench -i -U monkey_user -h "$IP" monkey_db
pgbench -T60 -c 80 -h "$IP" -U monkey_user monkey_db
pgbench -T60 -S -c 80 -h "$IP" -U monkey_user monkey_db
