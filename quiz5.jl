using Distributions
alpha = 0.01
crit = quantile(Normal(), 1-alpha/2)

lower = (12.45-13.97) - crit*(sqrt(49+12.9)/sqrt(10000))
upper = (12.45-13.97) + crit*(sqrt(49+12.9)/sqrt(10000))

