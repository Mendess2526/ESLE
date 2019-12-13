set terminal png
set title 'Writes'
set output 'write_nslaves.png'
set xrange [1:31]
set xlabel "Clients"
set ylabel "Latency [ms]"
plot 'data_write_nslaves.gp' using 1:2 title "Latency" pt 7 ps 1
