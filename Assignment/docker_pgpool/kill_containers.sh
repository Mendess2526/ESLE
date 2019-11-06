#!/bin/bash

./nodes.sh "$1" | while read -r node
do
    docker stop "$node" && docker rm "$node"
    sudo rm -rf keys/"$node"
done
