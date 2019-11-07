#!/bin/bash

sudo true
./nodes.sh "$(cat /tmp/num_nodes)" | while read -r node
do
    docker stop "$node" && docker rm "$node"
    sudo rm -rf keys/"$node"
done
rm keys/pgpool-gen.conf
rm /tmp/num_nodes
