#!/bin/bash

while read -r node
do
    docker stop "$node" && docker rm "$node"
    rm -rf keys/"$node"
done < nodes
