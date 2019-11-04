set terminal pdf
set output 'function.pdf'
set xrange [1:31]
set xlabel "Clients"
set ylabel "Latency [ms]"
plot 'data.gp' using 1:2 title "Latency" pt 7 ps 1
