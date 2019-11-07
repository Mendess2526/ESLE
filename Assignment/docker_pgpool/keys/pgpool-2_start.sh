#!/bin/sh
/usr/sbin/pgpool -f /etc/pgpool2/pgpool.conf > pgpool.log 2>&1 &
sleep 5
n_nodes="$(pcp_node_count 10 localhost 9898 pgpool pgpool)"
for i in $(seq 0 $(( n_nodes - 1 ))) ; do
    pcp_node_info 10 localhost 9898 pgpool pgpool "$i"
done
