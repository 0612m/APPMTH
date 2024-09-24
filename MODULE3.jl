using CSV, DataFrames
df = CSV.read("simple_ex_entity.csv", DataFrame)
df[:,:waiting_times] = df[:,:departure_time] .- 
                       df[:,:service_time] .- 
                       df[:,:arrival_time]

                    
# ---------------------- packages
using DataStructures, StableRNGs, CSV, Distributions, DataFrames, DelimitedFiles 
seed = 17 # set the RNG and seed 
rng = StableRNG(seed)

# ---------------------- struct for customers

# this struct represents customers (cars) in the queue
# it is mutable so you can add the start_service field after it is initialised
mutable struct Customer
    id::Int64               # a unique id to be allocated upon arrival
    arrival_time::Float64   # the time of arrival (from start of simulation)
    start_service::Float64  # the time the valet serves them (from start of simulation)
    end_service::Float64    # the time the valet finished (from start of simulation)
end
# generate a newly arrived customer (where start_service and end_service are unknown)
Customer(id,arrival_time) = Customer(id,arrival_time,Inf,Inf)

# ----------------------- events
abstract type Event end 
struct Arrival <: Event # <: indicates arrival is a subtype of event 
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end
struct Departure <: Event
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end

# ---------------------- states of the system 
n_valets = 3 
# this struct will represent the state of the system
# it is mutable because we need to be able to change the state of the system
mutable struct SystemState # this is the SYSTEM track keeper
    time::Float64                               # the system time (simulation time)
    event_queue::PriorityQueue{Event,Float64}   # to keep track of future arravals/services
    waiting_room::Queue{Customer}               # to keep track of waiting customers
    in_service::PriorityQueue{Customer,Float64} # to keep track of customers in service
    n_entities::Int64                           # the number of entities to have been served
    n_events::Int64                             # tracks the number of events to have occur + queued
end

# ---------------------- helper functions
# these are small fns so u can use julias abbreviated style
mean_interarrival = 2                           # units here are minutes
interarrival_time() = 
    rand(rng,Exponential(mean_interarrival))    # to generate interarrival times
service_time() = 5                              # to 'generate' deterministic service times
servers_full(system) = length(system.in_service)>=n_valets # returns true if no valets avail.


# EVENT HANDLING FNS (using update! wrapper defined below)

# update!(system,arrival::Arrival)
# Update the system when in response to an event.
# Input: 
#    + system: a System struct to be updated
#    + e:      an event
# Output: 
#    + customer: the customer who arrived or departed or .. in response to the event
#
function update!( system::SystemState, e::Event )
    throw( DomainError("invalid event type" ) )
end

# MOVING CUSTOMER TO SERVER
function move_customer_to_server!( system::SystemState )
    # move the customer from the waiting room to being in service and update it
    customer = dequeue!(system.waiting_room) # remove customer from queue
    customer.start_service = system.time     # start service 'now'
    customer.end_service = customer.start_service + service_time()
    enqueue!(system.in_service, customer, customer.end_service) # put the customer in service
    # create a departure event for this customer
    system.n_events += 1
    departure_event = Departure( system.n_events, customer.end_service)
    enqueue!(system.event_queue, departure_event, customer.end_service)
end

# UPDATING AN ARRIVAL IN SYSTEM
function update!( system::SystemState, event::Arrival ) # the mention of event tells julia this is just for arrival events 
    system.time = event.time  # advance system time to the new arrival
    system.n_entities += 1    # new entity will enter the system
      
    # create an arriving customer and add it to the queue
    new_customer = Customer(system.n_entities, event.time )
    enqueue!(system.waiting_room, new_customer)
    
    # generate next arrival and add it to the event queue
    system.n_events += 1
    future_arrival = Arrival(system.n_events, system.time + interarrival_time())
    enqueue!(system.event_queue, future_arrival, future_arrival.time)
    # if a valet is available, the customer goes to service
    if !servers_full(system) # valet available
        move_customer_to_server!( system )
    end
    
    return new_customer
end

# UPDATING SERVERS ON DEPARTURES 
function update!( system::SystemState, event::Departure)
    system.time = event.time   # advance system time to the new departure time
    departing_customer = dequeue!(system.in_service)  # remove customer
    
    if !isempty(system.waiting_room) # if someone is waiting, move them to service
        move_customer_to_server!( system )
    end
    return departing_customer
end

# ---------------------- testing the fns 

# initialise the system. In this case, the system starts with 1 arrival
t0 = 0.0 
init_event_queue = PriorityQueue{Event,Float64}()
enqueue!(init_event_queue,Arrival(0,t0),t0) # event_queue, init with arrival @ t=0
system = SystemState(
    0.0,                                # time
    init_event_queue,                   # event_queue
    Queue{Customer}(),                  # waiting_room
    PriorityQueue{Customer,Float64}(),  # in_service queue
    0,                                  # n_entities
    0                                   # n_events
)
# main event loop 
while system.time < 6
    # grab the next event from the event queue
    event = dequeue!( system.event_queue )
    # process the event
    customer = update!( system, event )
    # temporary outputs
    display(system.event_queue)
end

# ---------------------- writing data out

# file directory and name; * concatenates strings.
dir = pwd()*"/data/"*
    "/n_valets"*string(n_valets)*
    "/mean_interarrival"*string(mean_interarrival)*
    "/seed"*string(seed)             # directory name
mkpath(dir)                          # this creates the directory dir 
file_entities = dir*"/entities.csv"  # the name of the data file (informative) 
file_state = dir*"/state.csv"        # the name of the data file (informative) 
fid_entities = open(file_entities, "w") # open the file for writing
fid_state = open(file_state, "w")       # open the file for writing

# Before the start of the simulation, you want to initialise the CSV files with metadata and column headings as follows.

println(fid_entities, "# seed = $seed")
println(fid_entities, "# n_valets = $n_valets")
println(fid_entities, "# service_time = $(service_time())")
println(fid_entities, "entity_ID,arrival_time,service_time,departure_time")
println(fid_state, "# seed = $seed")
println(fid_state, "# n_valets = $n_valets")
println(fid_state,"# service_time = $(service_time())")
println(fid_state,"time,event,n_customers")

# fns that write out stuff 

function write_entity( fid::IO, customer::Customer, event::Arrival )
end
function write_entity( fid::IO, customer::Customer, event::Departure )
    println(fid, "$(customer.id),$(customer.arrival_time),$(customer.start_service),$(customer.end_service)")
end
function write_state( fid::IO, state::SystemState, event::Arrival )
    n_system = length( state.in_service ) + length( state.waiting_room )
    println(fid, "$(state.time),$(typeof(event)),$(n_system)")
end
function write_state( fid::IO, state::SystemState, event::Departure )
end


# ---------------------- SIMULATION 
# initialise the system. In this case, the system starts with 1 arrival
t0 = 0.0 
init_event_queue = PriorityQueue{Event,Float64}()
enqueue!(init_event_queue,Arrival(0,t0),t0) # event_queue, init with arrival @ t=0
system = SystemState(
    0.0,                                # time
    init_event_queue,                   # event_queue
    Queue{Customer}(),                  # waiting_room
    PriorityQueue{Customer,Float64}(),  # in_service queue
    0,                                  # n_entities
    0                                   # n_events
)
# main event loop 
while system.time < 1_000
    # grab the next event from the event queue
    event = dequeue!(system.event_queue)
    
    # update the system based on the next event, and spawn new events. 
    # return arrived/departed customer.
    customer = update!(system, event)
    
    # write out data
    write_entity(fid_entities, customer, event)
    write_state(fid_state, system, event )
    # note that we are writing out the state AFTER each ARRIVAL 
end
# remember to close the files
close( fid_entities )
close( fid_state )

data_entities = CSV.read(file_entities, DataFrame; comment="#") # ignore the metadata 
first(data_entities, 10) # head the data (entities)

data_state = CSV.read(file_state, DataFrame; comment="#") # ignore the metadata 
first(data_state, 10) # head the data (state)


# can analyse data
mean(data_entities[:,:service_time] - data_entities[:,:arrival_time])
