set terminal pdf
set output 'thoughput.pdf'
set xlabel 'Clients'
set ylabel 'Throughput (op/s)'
set title 'Application Throughput
plot 'output2.dat' using ($1):($2) title "throughput" with linespoints
