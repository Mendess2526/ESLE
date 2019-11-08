#!/bin/bash

! [ -f /tmp/num_nodes ] && exit 0
true
./nodes.sh "$(cat /tmp/num_nodes)" | while read -r node
do
    docker stop "$node" && docker rm "$node"
done
rm -f keys/pgpool-gen.conf
rm -f /tmp/num_nodes
