include("factory_simulation.jl")

# initialising 
seed = 1 
T = 1000.0


# file directory and name to save to
dir = pwd()*                         # directory name
mkpath(dir)                          # this creates the directory 
file_entities = dir*"/entities.csv"  # the name of the data file (informative) 
file_state = dir*"/state.csv"        # the name of the data file (informative) 
fid_entities = open(file_entities, "w") # open the file for writing
fid_state = open(file_state, "w")       # open the file for writing

# headers 


# run! simulation


# close the files 