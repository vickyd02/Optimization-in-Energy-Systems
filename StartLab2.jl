# Starting lab #3



SITES = ["PP-A", "PP-B", "PP-C", "INJ-A", "INJ-B", "NODE-A"]
nSITES = length(SITES)


PipesFrom =     [2, 6, 1, 6, 3]
PipesTo =       [6, 5, 6, 3, 4]


# Check  that  the  number  of  starting  and  ending  points  is equal
if size(PipesTo)[1] != size(PipesFrom)[1]
    println("ERROR: Pipes  are  not  defined  correctly.")
end

EmissionRate = [0.25, 0.75, 4, 0, 0, 0]
InjectionRate = [0, 0, 0, 3.5, 1.5, 0]


# Check  to make  sure  supply  equals  demand
check = sum(values(EmissionRate)) == sum(values(InjectionRate))
println("Check: supply  equals  demand: ", check)
println("---")

#Define shipment variable
@variable(m, Ship[1:nPipes]);

@constraint(m, [s=1:nSITES], EmissionRate[s] + sum(Ship[i] for i=findall(PipesTo.==s)) == InjectionRate[s] + sum(Ship[i] for i=findall(PipesFrom.==s)))