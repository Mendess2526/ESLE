#!/bin/bash
clients=(1 5 10 15 20 25 30)
{
    echo "set terminal pdf"
    echo "set output 'function.pdf'"
    echo "set xrange [1:31]"
    echo "set xlabel \"Clients\""
    echo "set ylabel \"Latency [ms]\""
    echo "plot 'data.gp' using 1:2 title \"Latency\" pt 7 ps 1"
} > pgbench.gp

rm data.gp
DELEGATE_IP="$(cat ../docker_pgpool/delegate_ip)"

echo "INITIALIZING DB"
pgbench -i postgres -h "$DELEGATE_IP" -p 9999 -U postgres
for i in "${clients[@]}"; do
    echo "BENCHMARKING $i CLIENT"
	latency=$(pgbench -c "$i" -h "$DELEGATE_IP" -p 9999 -U postgres | awk '/latency/ {print $4}')
	#sudo su postgres -c "pgbench -c $i testdb" 2>/dev/null | awk '/latency/ {print $4}' >> pgbench.txt
	echo "$i $latency" >> data.gp
done
gnuplot pgbench.gp

