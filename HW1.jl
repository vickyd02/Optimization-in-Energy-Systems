#Homework 1 Part 2 Questions 2 and 3 Energy 291

################################
######## Load packages #########
################################

# Use Pkg to install packages
import Pkg;

# Add the JuMP optimization package (allows you to write code to instantiate the model)
# Pkg.add("JuMP");

# # Add the GLPK linear programming solver package (GLPK solves the model created by JuMP code)
# Pkg.add("GLPK");

# #Add the additional packages for this question to effectively run

# Pkg.add("DataFrames");

# Pkg.add("XLSX");

# Pkg.add("Plots");
# Pkg.add("PlotlyBase");
# Pkg.add("PlotlyKaleido");

####################################
######### Initialize tools #########
####################################

# Initialize JuMP and GLPK
using JuMP
using GLPK
using DataFrames
using XLSX
using Plots
plotly()  # Use Plotly backend for interactive browser-based plots


###################################################
############ Define parameters and data ###########
###################################################

file_path = "/Users/vicky/Downloads/Energy 291 Optimization/HW_1_1_data_A.xlsx"
df = DataFrame(XLSX.readtable(file_path, "HW1_Table1"))

#interest rate
i_rate = 0.08
t = 30 # number of years of lifetime
f = ((i_rate * (1 + i_rate)^t) / ((1 + i_rate)^t - 1))
hours = 8760
num_projects = nrow(df)

#Calculate the actual values of upfront capital cost and. total profit per year 
UpfrontCapitalCost = zeros(num_projects)
TotalProfitPerYear = zeros(num_projects)

for i in 1:num_projects
    #need to now do the calculations
    area = df[i, "Available Land Area"]
    landcost = df[i, "Land Cost"]
    powerpotential = df[i, "Power Potential"]
    capacityfactor = df[i, "Capacity Factor"]
    powersalesprice = df[i, "Power Sales Price"]
    pvcapitalcost = df[i, "PV Capital Cost"]
    transmissioncost = df[i, "Trans. intercon. Cost"]
    operatingcost = df[i, "Operating Cost"]
    
    #capital costs per m^2
    upfrontcapcost = landcost + (pvcapitalcost + transmissioncost)*powerpotential
    UpfrontCapitalCost[i] = upfrontcapcost * area

    #Annualized yearly costs per m^2 (annualized cap cost + O&M costs)
    annualizedcapcost = upfrontcapcost * f + operatingcost * powerpotential

    #Revenues per m^2 
    revenue = powerpotential * capacityfactor * hours * powersalesprice/10^6 #convert to $/m^2

    #Net profit per m^2 for total area
    profit = revenue - annualizedcapcost
    TotalProfitPerYear[i] = profit * area

end

####################################
########## Declare model  ##########
####################################

# Define the model name and solver. In this case, model name is "m"
m = Model(GLPK.Optimizer)
#silencing solver temporarily to avoid printin all the text
set_silent(m)

####################################
######## Decision variables ########
####################################
@variable(m, 0<= x[1:num_projects]<=1) #x represents the fraction of land developed for each project and must be bounded between 0 and 1

######################################
######## Objective Functions #########
######################################

# Single objective for minimizing cost
#x represents the fraction of land developed for each project and must be bounded between 0 and 1
@objective(m, Max, sum(TotalProfitPerYear[i] * x[i] for i in 1:num_projects))

######################################
############# Constraints ############
###################################

# Define budgets first so we have a value for the constraint
budgets = [400_000_000, 500_000_000, 600_000_000, 700_000_000, 800_000_000]
budget_limit = first(budgets)  # Initialize with first budget value

# Constraint on the total upfront capital investment across all chosen projects being less than the budget limit
@constraint(m, budget_con, sum(UpfrontCapitalCost[i] * x[i] for i in 1:num_projects) <= budget_limit)

plot_array = Any[] #initialize an array to store the plots for each budget constraint

for B in budgets
    # Update the right-hand side of the budget constraint for the current budget limit
    set_normalized_rhs(budget_con, B)

    # Solve the model for the current budget limit
    optimize!(m)

    # Store the decision variable values for plotting
    local DecisionValues = value.(x)

    #Summary of the results
    println("\nBudget: \$$(Int(B/1_000_000))M | Max Profit: \$$(round(objective_value(m), digits=2))")
    
    # Print projects being invested in
    println("Projects invested in:")
    for i in 1:num_projects
        if DecisionValues[i] > 0.001  # Only show projects with meaningful investment
            println("  - Project $(df[i, "Project"]): $(round(DecisionValues[i]*100, digits=1))% of land (\$$(round(UpfrontCapitalCost[i] * DecisionValues[i]/1_000_000, digits=1))M)")
        end
    end
    
    # Create a bar chart of the decision variables for the current budget limit
    plot_fig = Plots.bar(df[:, "Project"], DecisionValues, 
        title = "Budget: \$$(Int(B/1_000_000))M",
        titlefont = 8,
        xlabel = "Project", 
        ylabel = "Fraction", 
        legend = false, 
        color = :blue,
        ylim = (0, 1.1),
        tickfont = 7,
        guidefont = 8
    )
    
    # Append the plot to the array of plots
    push!(plot_array, plot_fig)
end

#Display all plots together with adjusted layout to prevent overlapping
final_plot = Plots.plot(plot_array..., 
    layout=(2, 3), 
    size=(1400, 900),
    plot_titlefont=8,
    titlefontsize=8,
    bottom_margin = 15 * Plots.mm,
    top_margin = 15 * Plots.mm,
    left_margin = 10 * Plots.mm,
    right_margin = 10 * Plots.mm
)

# Save and open interactive plot in browser (like plt.show() in Python)
Plots.savefig(final_plot, "budget_analysis.html")
println("\nInteractive plot saved to: budget_analysis.html")
println("Opening in default browser...")
run(`open budget_analysis.html`)

#--------------------------------------------------------------------------------------
# Homework 1 Part 2 Question 4 Energy 291

################################
######## Load packages #########
################################

using JuMP
using GLPK
using DataFrames
using XLSX
import PyPlot

###################################################
############ Define parameters and data ###########
###################################################

file_path = "/Users/vicky/Downloads/Energy 291 Optimization/HW_1_1_data_A.xlsx"
df = DataFrame(XLSX.readtable(file_path, "HW1_Table1"))

# Interest rate and time
i_rate = 0.08
t = 30 
f = ((i_rate * (1 + i_rate)^t) / ((1 + i_rate)^t - 1))
hours = 8760
num_projects = nrow(df)

# Arrays for constraints and objective
TotalCapacity_W = zeros(num_projects)
TotalProfitPerYear = zeros(num_projects)

for i in 1:num_projects
    area = df[i, "Available Land Area"]
    landcost = df[i, "Land Cost"]
    powerpotential = df[i, "Power Potential"]
    capacityfactor = df[i, "Capacity Factor"]
    powersalesprice = df[i, "Power Sales Price"]
    pvcapitalcost = df[i, "PV Capital Cost"]
    transmissioncost = df[i, "Trans. intercon. Cost"]
    operatingcost = df[i, "Operating Cost"]
    
    # Total Capacity in Watts for this project (Power Potential * Area)
    TotalCapacity_W[i] = powerpotential * area
    
    # Financials
    upfrontcapcost = landcost + (pvcapitalcost + transmissioncost) * powerpotential
    annualizedcapcost = upfrontcapcost * f + operatingcost * powerpotential
    revenue = powerpotential * capacityfactor * hours * powersalesprice / 10^6 
    
    profit = revenue - annualizedcapcost
    TotalProfitPerYear[i] = profit * area
end

####################################
########## Declare model  ##########
####################################

m = Model(GLPK.Optimizer)
set_silent(m)

# Decision variables
@variable(m, 0 <= x[1:num_projects] <= 1) 

# Objective Function: Maximize Profit
@objective(m, Max, sum(TotalProfitPerYear[i] * x[i] for i in 1:num_projects))

######################################
############# Constraints ############
######################################

# Total Capacity <= 200 MW
@constraint(m, capacity_con, sum(TotalCapacity_W[i] * x[i] for i in 1:num_projects) <= 200_000_000)

######################################
########### Print and solve ##########
######################################

optimize!(m)

DecisionValues = value.(x)

println("--- 200 MW CAPACITY CONSTRAINT RESULTS ---")
println("Maximized Yearly Profit (\$): ", round(objective_value(m), digits=2))
println("\nFraction of Land Developed per Project:")

for i in 1:num_projects
    if DecisionValues[i] > 0.0001
        println("Project ", df[i, "Project"], ": ", round(DecisionValues[i], digits=4))
    end
end

######################################
############# Plotting ###############
######################################

fig, ax = PyPlot.subplots(figsize=(10, 6))

ax.bar(df[:, "Project"], DecisionValues, color="darkorange", edgecolor="black")
ax.set_title("Fraction of Land Utilized per Project (200 MW Limit)")
ax.set_xlabel("Project")
ax.set_ylabel("Fraction Developed")
ax.set_ylim(0, 1.1)
ax.grid(axis="y", linestyle="--", alpha=0.7)

PyPlot.tight_layout()
PyPlot.savefig("Q4_capacity_constraint.png", dpi=150, bbox_inches="tight")
println("\nPlot saved to: Q4_capacity_constraint.png")