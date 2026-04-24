# Example from ENERGY 191/291 lab reader
# Example 4: Power purchasing with time with multiple time steps and storage

# Adam R. Brandt
# Department of Energy Resources Engineering
# Stanford University
# File version 4
# Updated March 30 2021


####################################
######### Initialize tools #########
####################################

import Pkg;
Pkg.add("Plots")


# Initialize JuMP to allow mathematical programming models
using JuMP

# Initialize solver
using GLPK


###############################
######### Define Sets #########
###############################

# Set of purchased power types
POWER = ["NGCC", "NGCC-CCS", "PC", "PC-CCS", "Wind"]
NumPower = length(POWER) # Number of power types, useful for indexing

# Set of time steps
TimeStart = 1
TimeEnd = 14
TIME = collect(TimeStart:1:TimeEnd) # Collect time steps into a vector
NumTime = length(TIME) # Number of time steps, useful for indexing


###################################################
############ Define parameters and data ###########
###################################################

# Availability of each power type in each time element [MWh per time step]
AvailPower = [30, 50, 250, 40, 60]

# Costs of each power type. Indexed p for power in columns, t for time in rows.
CostPower = [37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;
							37 54 46 73 50;
							25 25 20 20 15;]

# GHGs of each power type [kg CO2/MWh]
GHGsPower = [431, 113, 839, 181, 16]

# Max allowable GHGs [kg CO2/MWh]
MaxGHG = 400

# Total power requirements [MWh per time step]
RequiredPower = [120 120 150 130 130 130 120 100 150 120 150 140 100 90]

# Cost to store power [$/MWh]
StorageCosts = 15

# Amount of power in storage at model start [MWh]
InitialStorage = 0

# Maximum amount of power in stroage at any time step [MWh]
StorageLimit = 120

####################################
########## Declare model  ##########
####################################

# Define the model name and solver. In this case, model name is "m"
m = Model(GLPK.Optimizer)

####################################
######## Decision variables ########
####################################
@variable(m, Buy[1:NumTime,1:NumPower] >= 0)

@variable(m, StoreIn[1:NumTime] >= 0)

@variable(m, StoreOut[1:NumTime] >= 0)

@variable(m, InStorage[1:NumTime+1] >= 0)

@variable(m, DailyBuy[1:NumTime] >= 0)

######################################
######## Objective Functions #########
######################################

# Single objective for minimizing cost
@objective(m, Min, sum(sum(CostPower[t,p]*Buy[t,p] for t=1:NumTime) for p = 1:NumPower) + sum(StoreIn[t]*StorageCosts for t=1:NumTime))


######################################
############# Constraints ############
######################################

# Storage initialization constraint
@constraint(m, InStorage[1] == InitialStorage)

# Storage conservation of energy constraint
for t = 1:NumTime
	@constraint(m, InStorage[t+1] == InStorage[t] + StoreIn[t] - StoreOut[t])
end

# Store-in constraint
for t = 1:NumTime
	@constraint(m, StoreIn[t] <= sum(Buy[t,p] for p=1:NumPower))
end

# Storage size constraint
for t = 1:NumTime
	@constraint(m, InStorage[t] <= StorageLimit)
end

# GHG constraint
for t = 1:NumTime
	@constraint(m, sum(GHGsPower[p]*Buy[t,p] for p=1:NumPower) <= MaxGHG*RequiredPower[t])
end

# Sufficiency constraint
for t = 1:NumTime
	@constraint(m, sum(Buy[t,p] for p=1:NumPower) - StoreIn[t] + StoreOut[t] >= RequiredPower[t])
end

# Available power constraints
for p = 1:NumPower
	for t = 1:NumTime
		@constraint(m, Buy[t,p] <= AvailPower[p])
	end
end


# Record the daily buy
for t = 1:NumTime
	@constraint(m, DailyBuy[t] == sum(Buy[t,p] for p=1:NumPower))
end


######################################
########### Print and solve ##########
######################################
print(m);

optimize!(m)


ObjValue = objective_value(m);
OptimalDailyBuy = value.(DailyBuy);
OptimalInStorage = value.(InStorage);


######################################
############ Plot results ############
######################################

#Plotting script using plots package

using Plots
gr()
# Bar charts of purchases and volume in storage
bar(OptimalDailyBuy, xaxis = ("Purchases by day", (0, 15), 1:1:14),yaxis = ("MWh purchased", (0,250), 0:50:250))
bar(OptimalInStorage, xaxis = ("Storage amount day", (0, 15), 1:1:14),yaxis = ("MWh in storage", (0,250), 0:50:250))




