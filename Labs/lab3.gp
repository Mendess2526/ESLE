set terminal pdf
#y = 995.6487801145; d = 0.0267159441; k = 0.0007690939
set xrange[0:32]
set xlabel '#Nodes'
set ylabel 'Throughtput'
plot (y * x) / (1 + d * (x - 1) + k * x * (x - 1))
