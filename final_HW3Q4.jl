#Homework 2.3 

using XLSX, DataFrames
using JuMP, GLPK

file_path = "/Users/vicky/Downloads/Energy 291 Optimization/HW_2_3_data_A.xlsx"
sheet = "Sheet1"
#Is the current transportation system sufficient for shifting electricity in bulk quanti-
# ties between regions?
# 2. How might you model the electricity system to understand how close to optimal it
# is operating?
# 3. Could we minimize the lost power due to transmission compared to the current
# real-world trading patterns?

#13 regions, carbon intensity of power production and consumption by region
#chief cost is lost power, loss factor: 3% power is lost per 1000 km distance traveled 

# Region Names
regions = XLSX.readdata(file_path, sheet, "A22:A34")[:] 
regions = string.(regions)
nregions = length(regions)

# Demand (D_i)
D_raw = XLSX.readdata(file_path, sheet, "B22:B34")[:]
D = convert.(Float64, D_raw)

# Generation (G_i)
gen_matrix_raw = XLSX.readdata(file_path, sheet, "C22:K34")
gen_matrix = convert.(Float64, gen_matrix_raw)
G = [sum(gen_matrix[i, :]) for i in 1:13]

# 1D. Distances (d_ij)
# Scroll down your Excel file to find the Distance matrix.
# Assume it is a 13x13 grid of numbers (e.g., from cell B80 to N92). 
dist_raw = XLSX.readdata(file_path, sheet, "B40:N52")
distances = convert.(Float64, dist_raw)
D_km = distances .* 1.60934

# Calculate the Loss Matrix (L_ij)
# L = 0.03 * (d / 1000)
L = 0.03 .* (D_km ./ 1000.0)
Lostpower_value = 50

#Existence of a line matrix
E_raw = XLSX.readdata(file_path, sheet, "C59:O71")
E = convert.(Float64, E_raw)

#Define shipment variable
m = Model(GLPK.Optimizer)

##Decision Variable (amount of electricity shipped from region i to region j [MWh])
@variable(m, Ship[1:nregions, 1:nregions] >= 0);

#supply = demand balance constraint
@constraint(m, [s=1:nregions], G[s] + sum(Ship[j, s] for j=1:nregions) == D[s] + sum(Ship[s, j] for j=1:nregions))
#constraint where cannot self-transmit 
@constraint(m, [s=1:nregions], Ship[s, s] == 0)
#constraint that confirms the existence or non-existence of power lines between regions.
#If a power line between regions is not existing, ensure that no power can flow between those regions. 
@constraint(m, [i=1:nregions, j=1:nregions], Ship[i, j] <= sum(D) * E[i, j]) # Assuming a very large number for the upper bound when a line exists

# Minimize the total loss costs of Shipping electricity [MWh * $/MWh = $] 
@objective(m, Min, sum(L[i, j]*Lostpower_value*Ship[i, j] for i=1:nregions, j=1:nregions)) 

# Solve the model
optimize!(m)


ObjValue = objective_value(m)
DecisionValues = value.(Ship)

println("--------------------------------------------------")
println("Total Shipping Cost (Lost Power): \$", round(ObjValue, digits=2))
println("--------------------------------------------------")

# Convert the 2D matrix of results into a DataFrame for easy reading
flow_df = DataFrame(DecisionValues, :auto)
rename!(flow_df, Symbol.(regions))
insertcols!(flow_df, 1, :Source_Region => regions)

println("\nOptimal Power Flows Between Regions [MWh]:")
show(flow_df, allrows=true, allcols=true)

#Total cost of lost power: $344,692.87
# Row │ Source_Region  CAL      CAR       CENT     FLA      MIDA     MIDW      NE       NW       NY       SE       SW       TEN      TEX     
#      │ String         Float64  Float64   Float64  Float64  Float64  Float64   Float64  Float64  Float64  Float64  Float64  Float64  Float64 
# ─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │ CAL                0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    2 │ CAR                0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    3 │ CENT               0.0      0.0       0.0      0.0      0.0    778.32      0.0      0.0      0.0      0.0  30709.7      0.0      0.0
#    4 │ FLA                0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0     41.0      0.0      0.0      0.0
#    5 │ MIDA               0.0   6240.02      0.0      0.0      0.0  28041.0       0.0      0.0  85602.0      0.0      0.0      0.0      0.0
#    6 │ MIDW               0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    7 │ NE                 0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    8 │ NW             21657.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    9 │ NY                 0.0      0.0       0.0      0.0      0.0      0.0   25719.0      0.0      0.0      0.0      0.0      0.0      0.0
#   10 │ SE                 0.0  10707.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0  24335.0      0.0
#   11 │ SW             91846.7      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#   12 │ TEN                0.0      0.0       0.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0
#   13 │ TEX                0.0      0.0    3364.0      0.0      0.0      0.0       0.0      0.0      0.0      0.0      0.0      0.0      0.0

#This number is significantly higher than the previous total cost of lost power (about $11,792.82 higher).
# This makes our optimal solution more expensive than before. 
#This is because we have added a new constraint that limits the flow of electricity between regions based on the existence of power lines.
#This should line up more with the observed data from Table 1, as we are now considering the real-world limitations of the electricity transmission system.
#Adding the line-existence constraint restricted the feasible region of solutions
#If you add a restricting constraint to LO, your objective function can only get worse or stay the same, not improve.
#The model is now adhereing to the real-world physical constraints of the power grid. 
#The objective cosst is higher here, but also the matrix is more empty. This is a result of the fact that power flows are concentrated only where the transmission lines truly exist.
#This definitely better aligns with the data because the model now follows the real transmission system. The pattern of trade routes is more realistic.


# Extract Observed Trades (Table 5) 
# UPDATE COORDINATES IF NEEDED! (Likely C78:O90 based on standard spacing)
obs_raw = XLSX.readdata(file_path, sheet, "C78:O90")
Observed = convert.(Float64, obs_raw)

# Calculate cost: Sum of ($50 * Loss * Observed Flow)
Observed_Cost = sum(Lostpower_value * L[i, j] * Observed[i, j] for i=1:nregions, j=1:nregions)

println("Observed Real-World Cost: \$", round(Observed_Cost, digits=2))
println("Difference: \$", round(Observed_Cost - ObjValue, digits=2))