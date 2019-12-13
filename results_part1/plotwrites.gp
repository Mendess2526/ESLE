set terminal "png"
set title 'Writes'
set key left Left
set output 'writes.png'
set xrange [1:31]
set xlabel "Clients"
set ylabel "Latency [ms]"
plot 'writes.gp' using 1:2 title "0 slaves" pt 7 ps 1, '' using 1:3 title "1 slaves" pt 7 ps 1, '' using 1:4 title "2 slaves" pt 7 ps 1, '' using 1:5 title "3 slaves" pt 7 ps 1 