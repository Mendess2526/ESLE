#!/bin/bash
clients=(1 5 10 15 20 25 30)
echo "set terminal png" > pgbench.gp
echo "set title 'benchmark'" >> pgbench.gp
echo "show title" >> pgbench.gp
echo "set output 'function.png'" >> pgbench.gp
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
	echo "$i $latency" >> data.gp
done
gnuplot pgbench.gp 

echo "set terminal png" > read.gp
echo "set title 'Reads'" >> read.gp
echo "show title" >> read.gp
echo "set output 'read.png'" >> read.gp
echo "set xrange [1:31]" >> read.gp
echo "set xlabel \"Clients\"" >> read.gp
echo "set ylabel \"Latency [ms]\"" >> read.gp
echo "plot 'gnuread.gp' using 1:2 title \"Latency\" pt 7 ps 1" >> read.gp
if [ -f gnuread.gp ]; then
	rm gnuread.gp
fi
for i in "${clients[@]}"; do
	latency=$(sudo su postgres -c "pgbench -c $i -S $database" 2>/dev/null | awk '/latency/ {print $4}')
	echo "$i $latency" >> gnuread.gp
done
gnuplot read.gp 

echo "set terminal png" > write.gp
echo "set title 'Writes'" >> write.gp
echo "show title" >> write.gp
echo "set output 'write.png'" >> write.gp
echo "set xrange [1:31]" >> write.gp
echo "set xlabel \"Clients\"" >> write.gp
echo "set ylabel \"Latency [ms]\"" >> write.gp
echo "plot 'gnuwrite.gp' using 1:2 title \"Latency\" pt 7 ps 1" >> write.gp
if [ -f gnuwrite.gp ]; then
	rm gnuwrite.gp
fi
for i in "${clients[@]}"; do
	latency=$(sudo su postgres -c "pgbench -c $i -N $database" 2>/dev/null | awk '/latency/ {print $4}')
	echo "$i $latency" >> gnuwrite.gp
done
gnuplot write.gp 
