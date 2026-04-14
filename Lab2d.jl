# Example from ENERGY 191/291 lab reader
# Example 3: Pipeline shipment in Julia/JuMP
# Variant 3d: Most general approach

# Adam R. Brandt
# Department of Energy Resources Engineering
# Stanford University
# File version 7
# Updated April 26th 2023

####### INITIALIZE PACKAGES ######

# Add these packages the first time you run the code. Then can be commented out, though perhaps simpler to leave in.
import Pkg;
Pkg.add("JuMP");
Pkg.add("GLPK");


# Make sure Julia can use these packages
using JuMP
using GLPK


###### SETS #########

# The set of CO2 sources, transshipment points, and injection sites
SITES = ["PP-A", "PP-B", "PP-C", "INJ-A", "INJ-B", "NODE-A"]
nSITES = length(SITES)


# Distance of each pipeline link [km]
# Rows and cols in order defined in sites above
# [PP-A, PP-B, PP-C, INJ-A, INJ-B, NODE-A]
# Position [i,j] in  [row,col] notation represents 
# pipe from location i to location j
# So row 1 says PP-A is 15 km from NODE-A
Distance =      [  0 0 0 0 0 15;
                0 0 0 0 0 80;
                0 0 0 100 0 75;
                0 0 100 0 0 0;
                0 0 0 0 0 60;
                15 80 75 0 60 0]


# Existence matrix for each pipeline
# Rows and cols in order defined in sites above
# [PP-A, PP-B, PP-C, INJ-A, INJ-B, NODE-A]
# Position [i,j] in  [row,col] notation represents 
# pipe from location i to location j
# So, row 1 says that PP-A connects only to NODE-A
PipeExists = [  0 0 0 0 0 1;
                0 0 0 0 0 1;
                0 0 0 1 0 1;
                0 0 1 0 0 0;
                0 0 0 0 0 1;
                1 1 1 0 1 0]


###### PARAMETERS and DATA ###############

# The emissions from each generation source [Mtonne CO2]
EmissionRate = [0.25 0.75 4 0 0 0]

# The maximum amount of CO2 to be stored in every site [Mtonne CO2]
InjectionRate =  [0 0 0 3.5 1.5 0]

# Check to make sure supply equals demand
check = sum(EmissionRate) == sum(InjectionRate)
println("Check: supply equals demand: ", check)
println("---")



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
@variable(m, Ship[1:nSITES,1:nSITES] >= 0)

###### CONSTRAINTS #######

# Shipment of CO2 must balance
@constraint(m, [i=1:nSITES], sum(Ship[i,j] for j = 1:nSITES) - sum(Ship[j,i] for j = 1:nSITES)   ==  EmissionRate[i] - InjectionRate[i] )

# Cannot ship if a pipe does not exist
# Choose a "big M" value on RHS large enough to not affect shipments if pipe does exist
@constraint(m, [i=1:nSITES,j=1:nSITES], Ship[i,j] <= 10*PipeExists[i,j])


######### OBJECTIVE FUNCTION ################

# Minimize the total costs of Shipping CO2 [Mt-km/*$/Mt-km = $]
@objective(m, Min, sum(sum(Ship[i,j]*CostShipment[i,j] for i=1:nSITES) for j=1:nSITES)) 

# Solve the model
optimize!(m)




#### PRINTING RESULTS ####
ObjValue = objective_value(m)
DecisionValues = value.(Ship)


