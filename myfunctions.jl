function fun1(x, y)
    output = x^2 + y^2
    return output
end

function lehmer(x, a, m)
    return mod(a*x, m)
end

#the lehmer fn will generate a sequence when repeatedly called
m = 25
n = 6
a = 3
x = 1
x = lehmer(x, a, m)
println(x)
x = lehmer(x, a, m)
println(x)
x = lehmer(x, a, m)
println(x)

function LCG(x, a, m, c)
    return mod(a*x + c, m)
end 

m = 25
a = 4
x = 3
c = 0
x = LCG(x, a, m,c)
println(x)
x = LCG(x, a, m, c)
println(x)
x = LCG(x, a, m, c)
println(x)
x = LCG(x, a, m, c)
println(x)
x = LCG(x, a, m, c)
println(x)