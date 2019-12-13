#!/bin/sh

git clone https://github.com/paunin/PostDock
cd PostDock || exit 1
sed -i 's/REQUIRE_MIN_BACKENDS: 3/REQUIRE_MIN_BACKENDS: 1/g' docker-compose/latest.yml
docker-compose -f ./docker-compose/latest.yml up -d pgmaster pgslave1 pgpool; sleep 1m
docker update -m 1g --cpus 0.2 $(docker ps -q)
pgbench -i -U monkey_user -h 172.21.0.2 monkey_db
pgbench -T60 -c 80 -h 172.21.0.2 -U monkey_user monkey_db
pgbench -T60 -S -c 80 -h 172.21.0.2 -U monkey_user monkey_db
