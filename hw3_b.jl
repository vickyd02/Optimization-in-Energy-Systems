#Homework 3.3 Optimal storage of water in pumped hydro generation systems

#interested in pumped hydro storage from July to december
#grant lake has size of 1.1*10^8 m^3 
#reservoir cannot drop below its nautral size but can expand to 1.2 *10^8 m^3
#rated electrical capacity of dam turbines is 1 MW (2 500 kW turbines)
#rated size of the pumps is 1 MW of electrical input 
#there is no limit on the amount of water that can be drawn from the lower reservoir 
#turbines generate power using gravitational potential energy 
#P = effciency*mass flow rate*gravitational acceleration*height difference
#efficiency of turbines and pumps is 0.925, change in height is 25 
#

#to pump water up the hill, assume the same equation form applies but efficiency of the pump is 0.85
#cost of purchased electricity for storing water as well as a fixed weekly operating cost of 2000

#starting condition of the reservoir is the base level 
#use data on power prices and typical inflows per week in the attached excel sheet
#calculate the profit of an optimal schedule of power sales
#in addition to profits, report the m^3 of water you release each week as well as the water you pump back to the reservoir at each week


#read in the excel File
# import Pkg;
# Pkg.add("Plots")
# import Pkg
# Pkg.add("Clp")
using XLSX
using JuMP
using Clp
using Printf
data = XLSX.readxlsx("/Users/vicky/Downloads/Energy 291 Optimization/HW_3_3_data_A.xlsx")
sheet = data["Inputs"]

# Read Typical Inflows (Column B, Rows 6 to 57)
# Units are 10^6 m^3, so we multiply by 1e6 
raw_inflows = vec(sheet["B6:B57"])
Q_inflow = Float64.(raw_inflows) .* 1e6  

# Read Power Prices (Column B, Rows 67 to 118) [$/MWh]
raw_prices = vec(sheet["B67:B118"])
lambda_price = Float64.(raw_prices)

# ==============================================================================
# 2. PARAMETERS & CONSTANTS
# ==============================================================================
T = 52                     # Number of weeks
eta_t = 0.925              # Turbine efficiency
eta_p = 0.85               # Pump efficiency
g = 9.81                   # Gravity (m/s^2)
delta_h = 25               # Dam height (m)
rho = 1000.                # Water density (kg/m^3)
P_max = 1.0                # Max turbine/pump capacity (MW)
V_min = 1.1e8              # Minimum reservoir volume (m^3)
V_max = 1.2e8              # Maximum reservoir volume (m^3)
C_fix = 2000               # Fixed weekly cost ($)
T_s = 168  * 3600          # Seconds per week
T_hours = 168              # Hours per week
V_initial = 1.1e8          # Base level starting condition (m^3)

# ==============================================================================
# 3. INITIALIZE PROBLEM & VARIABLES
# ==============================================================================
model = Model(Clp.Optimizer)
set_silent(model)

@variable(model, pt_g[1:T])  # Turbine Power (MW)
@variable(model, pt_p[1:T])  # Pump Power (MW)
@variable(model, mt_g[1:T])  # Mass flow turbine (kg/s)
@variable(model, mt_p[1:T])  # Mass flow pump (kg/s)
@variable(model, vt[1:T])    # Reservoir Volume (m^3)

# ==============================================================================
# 4. OBJECTIVE FUNCTION
# ==============================================================================
@objective(model, Max, sum(
    (lambda_price[t] * pt_g[t] * T_hours) - 
    (lambda_price[t] * pt_p[t] * T_hours) - 
    C_fix 
    for t in 1:T
))

# ==============================================================================
# 5. CONSTRAINTS
# ==============================================================================

# 1. Turbine Capacity Limits
@constraint(model, Gen_LowerBound[t=1:T], pt_g[t] >= 0)
@constraint(model, Gen_UpperBound[t=1:T], pt_g[t] <= P_max)

# 2. Pump Capacity Limits
@constraint(model, Pump_LowerBound[t=1:T], pt_p[t] >= 0)
@constraint(model, Pump_UpperBound[t=1:T], pt_p[t] <= P_max)

# 3. Mass Flow Non-negativity Limits
@constraint(model, MassFlowGen_Positive[t=1:T], mt_g[t] >= 0)
@constraint(model, MassFlowPump_Positive[t=1:T], mt_p[t] >= 0)

# 4. Reservoir Volume Limits
# The lake cannot drop below its natural base level, nor can it exceed the dam limit.
@constraint(model, Vol_LowerBound[t=1:T], vt[t] >= V_min)
@constraint(model, Vol_UpperBound[t=1:T], vt[t] <= V_max)


# --- PHYSICAL SYSTEM CONSTRAINTS ---

# 5. Turbine Power Generation Physics 
@constraint(model, Gen_Physics[t=1:T], 
    pt_g[t] == eta_t * mt_g[t] * g * delta_h * 1e-6
)

# 6. Pump Power Consumption Physics
@constraint(model, Pump_Physics[t=1:T], 
    pt_p[t] == (mt_p[t] * g * delta_h / eta_p) * 1e-6
)

# 7. Reservoir Water Balance
@constraint(model, Continuity_W1, 
    vt[1] <= V_initial + Q_inflow[1] - (mt_g[1] / rho) * T_s + (mt_p[1] / rho) * T_s
)

@constraint(model, Continuity_Rest[t=2:T], 
    vt[t] <= vt[t-1] + Q_inflow[t] - (mt_g[t] / rho) * T_s + (mt_p[t] / rho) * T_s
)
# ==============================================================================
# 6. SOLVE MODEL & OUTPUT RESULTS
# ==============================================================================
optimize!(model)

println("="^75)
println("OPTIMIZATION RESULTS")
println("="^75)
println("Solver Status: ", termination_status(model))
@printf("Total Optimal Profit: \$%.2f\n\n", objective_value(model))

println("Week | Price (\$/MWh) | Water Released (m³) | Water Pumped (m³) | End Vol (m³)")
println("-"^75)

for t in 1:T
    price_val = lambda_price[t]
    
    # Calculate volumetric totals for the week (m^3)
    # Mass flow (kg/s) / density (kg/m^3) * seconds_per_week
    water_released = (value(mt_g[t]) / rho) * T_s
    water_pumped = (value(mt_p[t]) / rho) * T_s
    
    vol_val = value(vt[t])
    
    @printf("%4d | %13.2f | %19.0f | %17.0f | %12.0f\n", 
            t, price_val, water_released, water_pumped, vol_val)
end
println("="^75)

