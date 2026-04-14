# Example from ENERGY 191/291 lab reader
# Example 3: Pipeline shipment in Julia/JuMP
# Variant 3b: With bi-directional pipes and positive shipment constraint

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


# Make sure Julia can use these packages
using JuMP
using GLPK


###### SETS #########

# The set of CO2 sources, tranShipment points, and injection
SITES = ["PP-A", "PP-B", "PP-C", "INJ-A", "INJ-B", "NODE-A"]
nSITES = length(SITES)

# The set of existing CO2 pipelines - One array with node from which pipeline starts, second array with node at which pipeline ends.
PipesFrom  = [2, 6, 6, 5, 1, 6, 6, 3, 3, 4]  # nodes from which pipe starts
PipesTo    = [6, 2, 5, 6, 6, 1, 3, 6, 4, 3]  # node to which pipe goes

# Check that the number of starting and ending points is equal
if size(PipesTo)[1] != size(PipesFrom)[1]
  println("ERROR: Pipes are not defined correctly.")
end

# Count the number of pipes
nPipes = size(PipesTo)[1]


###### PARAMETERS and DATA ###############

# The emissions from each generation source [Mtonne CO2]
EmissionRate = [0.25 0.75 4 0 0 0]

# The maximum amount of CO2 to be stored in every site [Mtonne CO2]
InjectionRate =  [0 0 0 3.5 1.5 0]

# Check to make sure supply equals demand
check = sum(EmissionRate) == sum(InjectionRate)
println("Check: supply equals demand: ", check)
println("---")

# Distance of each pipeline link [km]
Distance = [80 80 60 60 15 15 75 75  100 100]

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
@variable(m, Ship[1:nPipes]  >= 0)

###### CONSTRAINTS #######

# Shipment of CO2 must balance
@constraint(m, [s=1:nSITES], EmissionRate[s] + sum(Ship[i] for i=findall(PipesTo.==s)) == InjectionRate[s] + sum(Ship[i] for i=findall(PipesFrom.==s)))

######### OBJECTIVE FUNCTION ################

# Minimize the total costs of Shipping CO2 [Mt-km/*$/Mt-km = $]
@objective(m, Min, sum(Ship[i]*CostShipment[i] for i=1:nPipes)) 

# Solve the model
optimize!(m)


#### PRINTING RESULTS ####
ObjValue = objective_value(m)
DecisionValues = value.(Ship)

println("Shipping cost: ", round(ObjValue))
println("---")
println("Ship:")
for i=1:nPipes
  print(PipesFrom[i]," - ",PipesTo[i]," :",DecisionValues[i],"\n")
end
