set terminal png
set title 'Reads and Writes'
set output 'rw_nslaves.png'
set xrange [1:31]
set xlabel "Clients"
set ylabel "Latency [ms]"
plot 'data_rw_nslaves.gp' using 1:2 title "write" pt 7 ps 1, '' using 1:3 title "read" pt 7 ps 1
