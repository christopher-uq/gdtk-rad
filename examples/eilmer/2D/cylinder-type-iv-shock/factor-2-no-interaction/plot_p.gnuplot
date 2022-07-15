set term postscript eps enhanced 20
set output "surface_pressure.eps"
set style line 1 linetype 1 linewidth 3.0
set title "Surface pressure"
set xlabel "angle, degrees"
set ylabel "p, Pa"
set yrange [0:1000]
set key top right
plot "surface.data" using 1:2 title "120x240" with lines
