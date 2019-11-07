#!/bin/bash
file1="gnuwrite.gp"
file1col1=()
file1col2=()
while IFS= read -r line; do
	#echo "$line" | awk '{print $1}'
	#echo "col2: $col2"
	file1col1+=($(echo "$line" | awk '{print $1}'))
	file1col2+=($(echo "$line" | awk '{print $2}'))
	#echo "col1: $col1"
done < "$file1"

file2="gnuread.gp"
file2col1=()
file2col2=()
while IFS= read -r line; do
	file2col1+=($(echo "$line" | awk '{print $1}'))
	file2col2+=($(echo "$line" | awk '{print $2}'))
done < "$file2"

line=()
end=${#file1col1[@]}
if [ -f rw.gp ]; then
	rm rw.gp
fi
for i in $(seq 0 $end); do
	#line[i]="${file1col1[i]} ${file1col2[i]} ${file2col2[i]}"
	echo "${file1col1[i]} ${file1col2[i]} ${file2col2[i]}" >> rwdata.gp
	#line+=($(echo "${file1col1[i]} ${file1col1[i]} ${file2col2[i]}"))
done

for i in "${line[@]}"; do
	echo "$i"
done

{
	echo "set title 'benchmark'"
	echo "show title"
	echo "set output 'function.png'"
	echo "set xrange [1:31]"
	echo "set xlabel \"Clients\""
	echo "set ylabel \"Latency [ms]\""
	echo "plot 'rwdata.gp' using 1:2 title \"write\" pt 7 ps 1 using 1:3 title \"read\" pt 7 ps 1"
} > rw.gp

gnuplot rw.gp 
