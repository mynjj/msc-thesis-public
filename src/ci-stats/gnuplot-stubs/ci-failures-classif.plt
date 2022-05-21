# dat file has a single row with All, Failed, FailedAppTest quantities

set term png
set output "ci-failures-classif.png"
set style fill pattern 2
set boxwidth 0.9
set xrange [-1:1]
set yrange [0:{Y_HEIGHT}]
unset xtics

plot "ci-failures-classif.dat" using 1 linecolor 'black' with boxes title "All", \
     "ci-failures-classif.dat" using 2 linecolor 'black' with boxes title "Failed", \
     "ci-failures-classif.dat" using 3 linecolor 'black' with boxes title "Failed App Test"
