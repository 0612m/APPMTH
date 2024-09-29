include("factory_simulation.jl")

# initialising parameters
seed = 1 
T = 1000.0 
mean_interarrival = 60 # unit is minutes
mean_construction_time = 45 #mins
mean_breakdown = 2880 #2 days in minute
mean_repair = 180 #mins
time_units = "minutes"

#set parameter using struct 
P = Parameters( seed, mean_interarrival, mean_construction_time, mean_breakdown, mean_repair) 

# file directory and name to save to
dir = pwd()*"/factory_simulation_data" # directory name
mkpath(dir)                          # this creates the directory 
file_entities = dir*"/entities.csv"  # the name of the data file (informative) 
file_state = dir*"/state.csv"        # the name of the data file (informative) 
fid_entities = open(file_entities, "w") # open the file for writing
fid_state = open(file_state, "w")       # open the file for writing

# printing metadata of the simulation in the files
write_metadata( fid_entities )
write_metadata( fid_state )
# printing paramater details in the files
write_parameters( fid_entities, P )
write_parameters( fid_state, P )

# headers (these functions write up the headers for the columns)
println(fid_entities, "id, arrival_time, start_service_time, completion_time, interrupted") # entity file column names
println(fid_state,"time, event_id, event_type, length_event_list, length_queue, in_service, machine_status") # state file column names

# run! simulation
(system, R) = initialise(P) # initialise the system with parameters inputted
run!(system, R, T, fid_state, fid_entities) # run the simulation

# close the files 
close(fid_entities) 
close(fid_state)