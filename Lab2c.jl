# Example from ENERGY 191/291 lab reader
# Example 3: Pipeline shipment in Julia/JuMP
# Variant 3c: Includes dictionary for string names

# Adam R. Brandt
# Department of Energy Resources Engineering
# Stanford University
# File version 6
# Updated March 30 2021

####### INITIALIZE PACKAGES ######

# Add these packages the first time you run the code. Then can be commented out, though perhaps simpler to leave in.
import Pkg;
Pkg.add("JuMP");
Pkg.add("GLPK");


####### INITIALIZE PACKAGES ######

using JuMP
using GLPK


###### SETS #########

# The set of CO2 sources, tranShipment points, and injection
SITES = ["PP-A", "PP-B", "PP-C", "INJ-A", "INJ-B", "NODE-A"]
nSITES = length(SITES)

# The set of existing CO2 pipelines - One array with node from which pipeline starts, second array with node at which pipeline ends.
PipesFrom  = ["PP-B", "NODE-A", "NODE-A", "INJ-B", "PP-A", "NODE-A", "NODE-A", "PP-C",  "PP-C", "INJ-A"]    # nodes from which pipe starts
PipesTo    = ["NODE-A", "PP-B", "INJ-B", "NODE-A", "NODE-A", "PP-A", "PP-C", "NODE-A", "INJ-A", "PP-C"]  # node to which pipe goes

# Check that the number of starting and ending points is equal
if size(PipesTo)[1] != size(PipesFrom)[1]
  println("ERROR: Pipes are not defined correctly.")
end

# Count the number of pipes
nPipes = size(PipesTo)[1]

###### PARAMETERS and DATA ###############

# The emissions from each generation source [Mtonne CO2]
EmissionRate = Dict()
EmissionRate["PP-A"] = 0.25;
EmissionRate["PP-B"] = 0.75;
EmissionRate["PP-C"] = 4;
EmissionRate["INJ-A"] = 0;
EmissionRate["INJ-B"] = 0;
EmissionRate["NODE-A"] = 0;

# The maximum amount of CO2 to be stored in every site [Mtonne CO2]
InjectionRate = Dict()
InjectionRate["PP-A"] = 0;
InjectionRate["PP-B"] = 0;
InjectionRate["PP-C"] = 0;
InjectionRate["INJ-A"]=3.5;
InjectionRate["INJ-B"]=1.5;
InjectionRate["NODE-A"] = 0;

# Check to make sure supply equals demand
check = sum(values(EmissionRate)) == sum(values(InjectionRate))
println("Check: supply equals demand: ", check)
println("---")

# Distance of each pipeline link [km]
Distance = zeros(nPipes); # Initialize array of Distances
Distance[1]=80; #PP-B, NODE-A,
Distance[2]=80; #NODE-A, PP-B,
Distance[3]=60; #NODE-A, INJ-B
Distance[4]=60; #INJ-B, NODE-A
Distance[5]=15; #PP-A, NODE-A
Distance[6]=15; #NODE-A, PP-A
Distance[7]=75; #NODE-A, PP-C
Distance[8]=75; #PP-C, NODE-A
Distance[9]=100; #PP-C, INJ-A
Distance[10]=100; #INJ-A, PP-C

# Pressure drop [MPa per km]
PressureDrop = 0.035;

# The cost of providing pressure [$/MPa-Mt]
CostPressure = 200000;

# The cost of Shipment (computed parameter) [$/Mt-km]
CostShipment = Distance*PressureDrop*CostPressure;

#### INITIALIZE MODEL ####
m = Model(GLPK.Optimizer)

###### VARIABLES #####

# The amount Shipped between each source and each injector [Mt]
@variable(m, Ship[i=1:nPipes] >= 0)

###### CONSTRAINTS #######

# Shipment of CO2 must balance
@constraint(m, [s=SITES], EmissionRate[s] + sum(Ship[i] for i=findall(PipesTo.==s)) == InjectionRate[s] + sum(Ship[i] for i=findall(PipesFrom.==s)))

######### OBJECTIVE FUNCTION ################

# Minimize the total costs of Shipping CO2 [Mt-km/*$/Mt-km = $]
@objective(m, Min, sum(Ship[i]*CostShipment[i] for i=1:nPipes)) 

# Solve the model
optimize!(m)


#### PRINTING RESULTS ####
ObjValue = objective_value(m)
DecisionValues = value.(Ship)

println("Shipping cost: ", round(ObjValue))
println("Ship:")
for i=1:nPipes
  print(PipesFrom[i]," - ",PipesTo[i]," :",DecisionValues[i],"\n")
end
