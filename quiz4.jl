using StatsPlots
using Distributions

quiz4data = [1.0, 12.02, 6.26, 1.44, 6.55, 8.11, 0.8, 0.23, 2.86, 0.24, 0.63, 0.82, 1.51, 1.11, 2.98, 4.65, 2.94, 0.64, 2.37, 4.22, 1.78, 3.04, 0.66, 0.52, 1.07, 3.18, 0.15, 6.43, 3.72, 1.21]

qqplot(Exponential(3.0), 
quiz4data)

qqplot(Pareto(1.5,1.0),
quiz4data)


qqplot(Normal(3,3),
quiz4data)