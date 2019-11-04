#!/bin/bash
clients=(1 5 10 15 20 25 30)
echo "set terminal pdf" > pgbench.gp
echo "set output 'function.pdf'" >> pgbench.gp
echo "set xrange [1:31]" >> pgbench.gp
echo "set xlabel \"Clients\"" >> pgbench.gp
echo "set ylabel \"Latency [ms]\"" >> pgbench.gp
echo "plot 'data.gp' using 1:2 title \"Latency\" pt 7 ps 1" >> pgbench.gp
if [ $# -eq 0 ];then
	database="testdb"
else
	database=$1
fi

if [ -f data.gp ]; then
	rm data.gp
fi
for i in "${clients[@]}"; do
	latency=$(sudo su postgres -c "pgbench -c $i $database" 2>/dev/null | awk '/latency/ {print $4}')
	#sudo su postgres -c "pgbench -c $i testdb" 2>/dev/null | awk '/latency/ {print $4}' >> pgbench.txt
	echo "$i $latency" >> data.gp
done
gnuplot pgbench.gp

