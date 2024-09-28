include("factory_simulation.jl")

# initialising params 
seed = 1 
T = 1000.0
mean_interarrival = 60 # unit is minutes
interarrival_time() = rand(rng, Exponential(mean_interarrival)) # gen ia times
service_time() = 45 #mins
mean_breakdown = 2880 #2 days in minute
breakdown_time() = rand(rng,Exponential(mean_breakdown))
mean_repair = 180 #mins
repair_time() = rand(rng, Exponential(mean_repair))
time_units = "minutes"

P = Parameters( seed, mean_interarrival, construction_time, mean_breakdown, mean_repair) # not sure about the service time/construction time 


# file directory and name to save to
dir = pwd()*"/factory_simulation_data" # directory name
mkpath(dir)                          # this creates the directory 
file_entities = dir*"/entities.csv"  # the name of the data file (informative) 
file_state = dir*"/state.csv"        # the name of the data file (informative) 
fid_entities = open(file_entities, "w") # open the file for writing
fid_state = open(file_state, "w")       # open the file for writing


write_metadata( fid_entities )
write_metadata( fid_state )
write_parameters( fid_entities, P )
write_parameters( fid_state, P )

# headers 
println(fid_entities, "# id, arrival_time, start_service_time, completion_time, interrupted")



# run! simulation


# close the files 