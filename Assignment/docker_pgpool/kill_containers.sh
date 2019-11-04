#!/bin/bash

while read -r node
do
    docker stop "$node" && docker rm "$node"
    sudo rm -rf keys/"$node"
done < nodes
