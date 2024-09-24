using DataStructures
using Distributions
using StableRNGs
using Printf
using Dates

### seed and rng set
seed = 1 
rng = StableRNG(seed)

### entity data structure for each lawnmower?
mutable struct Lawnmower
    id::Int64
    arrival_time::Float64 # time when the lawnmower part arrives?
    start_blade_fitting::Float64 # time when the machine enters the blade fitting machine
    fitting_completion::Float64 # when lawnmower completes blade fitting?
end

## construct for mower
Lawnmower(id, arrival_time) = Customer(id, arrival_time, -1.0, -1.0) # set blade and completion time to -1 (clearly not set yet)

### EVENTS:
abstract type Event end

mutable struct Arrival <: Event ## arrival of mower
    id::Int64
    time::Float64
end

mutable struct Breakdown <: Event # breakdown of machine
    time::Float64
end

mutable struct RepairCompletion <: Event # repair completion event
    time::Float64
end

mutable struct AssemblyCompletion <: Event # when mower is fully finished
    id::Int64
    time::Float64
end

### state represents the entire system at any point in time 
mutable struct SystemState
    current_time::Float64
    event_queue::PriorityQueue{Event} # keep track of future arrivals/services
    order_queue::Queue{Lawnmower} # keep track of waiting orders
    n_entities::Int64 # number of mowers in da system
    n_events::Int64 # tracking num of events 
    machine_busy::Bool # if the machine is operating or idle
    machine_broken::Bool # if machine is broken/under repair
    n_interruptions::Int64 # counter for interruptions of mowers because of breakdowns
    total_repair_time::Float64 # to count total time lost to repairations
end

function SystemState() # blank constr. do i need to change the name for other stuff
    return SystemState(
        0.0,
        PriorityQueue{Event}(),
        Queue{Entity}(),
        0,
        0,
        false,
        false,
        0,
        0.0
    )
end

### HELPER FUNCTIONS:
mean_interarrival = 60 # unit is minutes
interarrival_time() = rand(rng, Exponential(mean_interarrival)) # gen ia times
service_time() = 45 #mins
mean_breakdown = 2880 #2 days in minute
breakdown_time() = rand(rng,Exponential(mean_breakdown))
mean_repair = 180 #mins
repair_time() = rand(rng, Exponential(mean_repair))


### MOVING LAWNMOWER TO BLADE MACHINE
function move_lawnmower_to_machine( system::SystemState )
    lawnmower = dequeue!(system.order_queue) #remove mower from waiting
    lawnmower.start_blade_fitting = system.current_time #start fitting
    lawnmower.fitting_completion = lawnmower.start_blade_fitting + service_time()
    system.machine_busy = true
    
    #assemblyCompletion event for when the blade fitting is done
    system.n_events += 1
    assembly_completion = AssemblyCompletion(system.n_events, lawnmower.fitting_completion)
    enqueue!(system.event_queue, assembly_completion, lawnmower.fitting_completion)
    
    # check if the machine will break down before the fitting is completed
    if rand(rng, Exponential(mean_breakdown)) < service_time()
        # schedule a breakdown time:
        breakdown_time = system.current_time + breakdown_time()
        enqueue!(system.event_queue, Breakdown(breakdown_time), breakdown_time)
    end
end


### UPDATE ARRIVAL of a lawnmower in system 
function update!(system::SystemState, event::Arrival)
    system.current_time = event.time # advancing system to the new arrival 
    system.n_entities += 1 # new ent enters system

    # create an arriving mower and add to blade queue
    new_lawnmower = Lawnmower(system.n_entities, event.time)
    enqueue!(system.order_queue, new_lawnmower)

    #generating next arrival and adding it to the event queue (priority)
    system.n_events += 1
    future_arrival = Arrival(system.n_events, system.time + interarrival_time())
    enqueue!(system.event_queue, future_arrival, future_arrival.time)

    #checking if the blade thing is full 
    # im thinking check if broken then if available check, then in that 
    # call the function to move the lawnmower "in" to blade machine 
    #or should i change it so that these things arent in system state but diff?
    #own state or mini fn?
    if !system.machine_broken && !system.machine_busy
        move_lawnmower_to_machine!(SystemState)
    end 

    return new_lawnmower
end


### UPDATE DEPARTURE of a lawnmower? 
function update!(system::SystemState, event::Departure)
    system.current_time = event.time # advance system into the new departure
    # departing_lawnmower = dequeue!(system.???)
end