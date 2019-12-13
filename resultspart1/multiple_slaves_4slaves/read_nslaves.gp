set terminal png
set title 'Reads'
set output 'read_nslaves.png'
set xrange [1:31]
set xlabel "Clients"
set ylabel "Latency [ms]"
plot 'data_read_nslaves.gp' using 1:2 title "Latency" pt 7 ps 1
