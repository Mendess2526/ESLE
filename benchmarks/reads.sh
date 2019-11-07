file1="data_read_nopgpool.gp"
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

file3="data_read_nslaves.gp"
file3col1=()
file3col2=()
while IFS= read -r line; do
	file3col1+=($(echo "$line" | awk '{print $1}'))
	file3col2+=($(echo "$line" | awk '{print $2}'))
done < "$file3"

line=()
end=${#file1col1[@]}
if [ -f data_reads.gp ]; then
	rm data_reads.gp
fi
for i in $(seq 0 $end); do
	#line[i]="${file1col1[i]} ${file1col2[i]} ${file2col2[i]}"
	echo "${file1col1[i]} ${file1col2[i]} ${file2col2[i]} ${file3col2[i]}" >> data_reads.gp
	#line+=($(echo "${file1col1[i]} ${file1col1[i]} ${file2col2[i]}"))
done

for i in "${line[@]}"; do
	echo "$i"
done

{
	echo "set terminal png"
	echo "set title 'Reads'"
	echo "set output 'reads.png'"
	echo "set xrange [1:31]"
	echo "set xlabel \"Clients\""
	echo "set ylabel \"Latency [ms]\""
	echo "plot 'data_reads.gp' using 1:2 title \"No Pgpool\" pt 7 ps 1, '' using 1:3 title \"2 slaves\" pt 7 ps 1, '' using 1:4 title \"N slaves\" pt 7 ps 1"
} > reads.gp

gnuplot reads.gp 
