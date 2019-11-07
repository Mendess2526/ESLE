#!/bin/bash
clients=(1 5 10 15 20 25 30)

if [ $# -eq 0 ];then
	database="testdb"
else
	database=$1
fi
#read_nopgpool
{
	echo "set terminal png"
	echo "set title 'Reads'"
	echo "set output 'read_2slaves.png'"
	echo "set xrange [1:31]"
	echo "set xlabel \"Clients\""
	echo "set ylabel \"Latency [ms]\""
	echo "plot 'data_read_2slaves.gp' using 1:2 title \"Latency\" pt 7 ps 1"
} > read_2slaves.gp

if [ -f data_read_pgpool_2slaves.gp ]; then
	rm data_read_pgpool_2slaves.gp
fi
for i in "${clients[@]}"; do
	latency=$(sudo su postgres -c "pgbench -c $i -S $database" 2>/dev/null | awk '/latency/ {print $4}')
	echo "$i $latency" >> data_read_2slaves.gp
done
gnuplot read_2slaves.gp 

#write_nopgpool
{
	echo "set terminal png" 
	echo "set title 'Writes'"
	echo "set output 'write_2slaves.png'"
	echo "set xrange [1:31]"
	echo "set xlabel \"Clients\""
	echo "set ylabel \"Latency [ms]\""
	echo "plot 'data_write_2slaves.gp' using 1:2 title \"Latency\" pt 7 ps 1"
} > write_2slaves.gp

if [ -f data_write_2slaves.gp ]; then
	rm data_write_2slaves.gp
fi
for i in "${clients[@]}"; do
	latency=$(sudo su postgres -c "pgbench -c $i -N $database" 2>/dev/null | awk '/latency/ {print $4}')
	echo "$i $latency" >> data_write_2slaves.gp
done
gnuplot write_2slaves.gp 
 
file1="data_write_2slaves.gp"
file1col1=()
file1col2=()
while IFS= read -r line; do
	#echo "$line" | awk '{print $1}'
	#echo "col2: $col2"
	file1col1+=($(echo "$line" | awk '{print $1}'))
	file1col2+=($(echo "$line" | awk '{print $2}'))
	#echo "col1: $col1"
done < "$file1"

file2="data_read_2slaves.gp"
file2col1=()
file2col2=()
while IFS= read -r line; do
	file2col1+=($(echo "$line" | awk '{print $1}'))
	file2col2+=($(echo "$line" | awk '{print $2}'))
done < "$file2"

line=()
end=${#file1col1[@]}
if [ -f data_rw_2slaves.gp ]; then
	rm data_rw_2slaves.gp
fi
for i in $(seq 0 $end); do
	#line[i]="${file1col1[i]} ${file1col2[i]} ${file2col2[i]}"
	echo "${file1col1[i]} ${file1col2[i]} ${file2col2[i]}" >> data_rw_2slaves.gp
	#line+=($(echo "${file1col1[i]} ${file1col1[i]} ${file2col2[i]}"))
done

for i in "${line[@]}"; do
	echo "$i"
done

{
	echo "set terminal png"
	echo "set title 'Reads and Writes'"
	echo "set output 'rw_2slaves.png'"
	echo "set xrange [1:31]"
	echo "set xlabel \"Clients\""
	echo "set ylabel \"Latency [ms]\""
	echo "plot 'data_rw_2slaves.gp' using 1:2 title \"write\" pt 7 ps 1, '' using 1:3 title \"read\" pt 7 ps 1"
} > rw_2slaves.gp

gnuplot rw_2slaves.gp 
