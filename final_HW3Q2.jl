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

#Define shipment variable
m = Model(GLPK.Optimizer)

##Decision Variable (amount of electricity shipped from region i to region j [MWh])
@variable(m, Ship[1:nregions, 1:nregions] >= 0);

#supply = demand balance constraint
@constraint(m, [s=1:nregions], G[s] + sum(Ship[j, s] for j=1:nregions) == D[s] + sum(Ship[s, j] for j=1:nregions))
#constraint where cannot self-transmit 
@constraint(m, [s=1:nregions], Ship[s, s] == 0)


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
show(flow_df)

#Total Cost of Lost Power ($332,900.05)

# Row │ Source_Region  CAL      CAR      CENT     FLA      MIDA     MIDW     NE       NW       NY       SE       SW       TEN      TEX     
#      │ String         Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64 
# ─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │ CAL                0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    2 │ CAR                0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    3 │ CENT           27346.0      0.0      0.0      0.0      0.0    778.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    4 │ FLA                0.0     41.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    5 │ MIDA               0.0   6239.7      0.0      0.0      0.0  28041.3  25719.0      0.0  59883.0      0.0      0.0      0.0      0.0
#    6 │ MIDW               0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    7 │ NE                 0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    8 │ NW             21657.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#    9 │ NY                 0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#   10 │ SE                 0.0  10666.3      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0  24334.7      0.0
#   11 │ SW             61137.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#   12 │ TEN                0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
#   13 │ TEX             3364.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0

