#!/bin/bash
set -e
[ -f /tmp/createTables.sql ] || curl https://cdn.discordapp.com/attachments/623612643965665298/641413465277202432/createTables.sql > /tmp/createTables.sql;
ip="$(docker inspect pgpool | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r -e)";
echo -e '\e[34m CREATING DB\e[0m';
psql -h "$ip" -p 9999 -U postgres -c 'CREATE DATABASE daw_db';

echo -e '\e[34m CHECKING\e[0m';
ssh root@"$(docker inspect master | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r)" "psql -U postgres -c '\\l'"

echo -e '\e[34m CREATING TABLES\e[0m';
sleep 2
psql -h "$ip" -p 9999 -U postgres -d daw_db -f /tmp/createTables.sql

echo -e '\e[34m CHECKING\e[0m'
ssh root@"$(docker inspect slave1 | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r)" "psql -U postgres -d daw_db -c '\\dt'"

echo -e '\e[34m INSERTING INTO daw_State\e[0m';
psql -h "$ip" -p 9999 -U postgres -d daw_db -c "INSERT INTO daw_State(name) VALUES ('archived'), ('closed'), ('opened')";

echo -e '\e[34m CHECKING\e[0m'
ssh root@"$(docker inspect slave2 | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r)" "psql -U postgres -d daw_db -c 'select * from daw_state'"
