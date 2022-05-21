set term png size width,500
set autoscale xfix
set autoscale yfix
set datafile separator ','
set output outputfilename

set title plottitle
set style data boxplot
set boxwidth 1.5
stats inputfilename nooutput
set xtics 0,5,STATS_columns*5 format ""
do for[i=1:STATS_columns] {
    stats inputfilename every ::0::0 u (a=strcol(i),1) nooutput
    set xtics add (a i*5)
}
plot for [i=1:STATS_columns] inputfilename every ::1 using (i*5.0):i notitle