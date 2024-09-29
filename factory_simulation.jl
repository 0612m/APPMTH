using DataStructures, Distributions, StableRNGs, Printf, Dates

### EVENTS: structs
abstract type Event end

mutable struct Arrival <: Event # arrival of a mower
    id::Int64
    time::Float64
end

mutable struct Breakdown <: Event # breakdown of machine
    id::Int64
    time::Float64
end

mutable struct RepairCompletion <: Event # repair completion of machine
    id::Int64
    time::Float64
end

mutable struct Departure <: Event # departure of mower from machine
    id::Int64
    time::Float64
end

### ENTITY: struct
mutable struct Lawnmower
    id::Int64 # each lawnmower has own ID
    arrival_time::Float64 # time when the lawnmower order arrived in system
    start_blade_fitting::Float64 # time when the machine enters the blade fitting machine
    fitting_completion::Float64 # time when lawnmower completes blade fitting
end

## ENTITY: blank struct
Lawnmower(id, arrival_time) = Lawnmower(id, arrival_time, -1.0, -1.0) # set blade fitting start time and completion time to -1

### STATE: struct
mutable struct SystemState
    current_time::Float64 # current time in system clock
    event_queue::PriorityQueue{Event,Float64} # keep track of all future arrivals/events
    order_queue::Queue{Lawnmower} # keep track of waiting orders for blade machine
    n_entities::Int64 # number of mowers in the system
    n_events::Int64 # tracking number of events 
    machine_broken::Bool # if machine is broken/under repair
    n_interruptions::Int64 # counter for interruptions of mowers because of breakdowns
    total_repair_time::Float64 # to count total time lost to repairations
    current_lawnmower::Union{Nothing,Lawnmower}  # tracks the mower in service
end

### STATE: blank struct
function State()
    return SystemState(
        0.0,                                  # init_time
        PriorityQueue{Event,Float64}(),      # init_event_queue
        Queue{Lawnmower}(),                   # init_order_queue
        0,                                    # init_n_entities
        0,                                    # init_n_events
        false,                                # init_machine_broken
        0,                                    # init_n_interruptions
        0.0,                                  # init_repair_time
        nothing                               # init_current_lawnmower
    )
end

### PARAMETER: struct
struct Parameters
    seed::Int
    mean_interarrival::Float64
    mean_construction_time::Float64
    mean_interbreakdown_time::Float64
    mean_repair_time::Float64
end

### RANDOMNGS: struct
struct RandomNGs
    rng::StableRNGs.LehmerRNG
    interarrival_time::Function
    construction_time::Function
    interbreakdown_time::Function
    repair_time::Function
end

### RANDOMNGS: function
function RandomNGs(P::Parameters) # creating random number generators with specific parameters as input
    rng = StableRNG(P.seed)
    interarrival_time() = rand(rng, Exponential(P.mean_interarrival))
    construction_time() = P.mean_construction_time
    interbreakdown_time() = rand(rng, Exponential(P.mean_interbreakdown_time))
    repair_time() = rand(rng, Exponential(P.mean_repair_time))

    return RandomNGs(rng, interarrival_time, construction_time, interbreakdown_time, repair_time) # return
end

### MOVING LAWNMOWER TO BLADE MACHINE
function move_lawnmower_to_machine(system::SystemState, R::RandomNGs)
    lawnmower = dequeue!(system.order_queue) # remove mower from waiting list
    system.current_lawnmower = lawnmower  # store the mower being processed in the system
    system.machine_broken = false # change machine to not broken

    lawnmower.start_blade_fitting = system.current_time # start blade fitting
    lawnmower.fitting_completion = lawnmower.start_blade_fitting + R.construction_time() # generate total service time

    #Departure event for when the blade fitting is done
    system.n_events += 1 # number of event increases 
    assembly_completion = Departure(system.n_events, lawnmower.fitting_completion) # create completion event
    enqueue!(system.event_queue, assembly_completion, lawnmower.fitting_completion) # enqueue the event 
end


### UPDATE ARRIVAL 
function update!(system::SystemState, R::RandomNGs, event::Arrival)
    system.current_time = event.time # advancing system to the new arrival 
    system.n_entities += 1 # new entity enters system

    # create mower object and adding to blade queue
    new_lawnmower = Lawnmower(system.n_entities, event.time)
    enqueue!(system.order_queue, new_lawnmower)

    # generating next arrival and adding it to the event queue (priority)
    system.n_events += 1 # number of events increases 
    future_arrival_time = system.current_time + R.interarrival_time() # generate arrival time 
    future_arrival = Arrival(system.n_events, future_arrival_time) # arrival event with id and time.
    enqueue!(system.event_queue, future_arrival, future_arrival_time) # add to event queue, using future arrivals time.

    # if machine is working and available
    if !system.machine_broken && system.current_lawnmower === nothing
        move_lawnmower_to_machine(system, R) # move into service
    end

    return new_lawnmower
end


### UPDATE ASSEMBLY COMPLETION / DEPARTURE
function update!(system::SystemState, R::RandomNGs, event::Departure)
    if system.machine_broken
        return
    end
    system.current_time = event.time # advance system into the new departure

    if system.current_lawnmower !== nothing
        lawnmower = system.current_lawnmower # select lawnmower as current one being made 
        lawnmower.fitting_completion = system.current_time # set lawnmower's completion to occur at the current time ()

        write_entity(fid_entities, system, lawnmower, event)

        system.n_events += 1 # increase event count
        system.current_lawnmower = nothing # reset system into having no mower in machine

        # initiate the next event if there are more orders to be processed 
        if !isempty(system.order_queue)
            move_lawnmower_to_machine(system, R) # call move mower to machine function
        end
    end
end

### UPDATE BREAKDOWN
function update!(system::SystemState, R::RandomNGs, event::Breakdown)

    system.current_time = event.time # advance system time to this event
    system.machine_broken = true # change machine to broken 

    if system.current_lawnmower !== nothing # if machine was working on a mower at time of breakdown,
        lawnmower = system.current_lawnmower # select the mower being processed
        system.n_interruptions += 1 # increment interruption counter by 1 

        #search for the assembly complete event that was created in event queue (cannot depart as scheduled as breakdown)
        for (event, _) in system.event_queue
            if event isa Departure && event.time == lawnmower.fitting_completion # if event is a departure and time matches
                dequeue!(system.event_queue, event)  # remove the departure event
                break
            end
        end

        repair_duration = R.repair_time() # generate a repair time using RandomNGs
        lawnmower.fitting_completion += repair_duration # adding repair time to completion time 

    end

    # schedule repair completion event
    system.n_events += 1 # increase event count by 1 
    repair_completion_time = system.current_time + R.repair_time() # set system time when repair finishes
    repair_event = RepairCompletion(system.n_events, repair_completion_time) # create repair event 
    enqueue!(system.event_queue, repair_event, repair_completion_time) # add to event queue, using repair completion time

end

### UDPDATE REPAIR 
function update!(system::SystemState, R::RandomNGs, event::RepairCompletion)
    system.current_time = event.time # advance system time to this event
    system.machine_broken = false # changing machine status to operational

    if system.current_lawnmower !== nothing # if there was a current lawnmower
        lawnmower = system.current_lawnmower # select the mower that was being processed 
        system.n_events += 1 # increment event count by 1 

        finish_event_time = lawnmower.fitting_completion # set finish time to this mowers finish time
        finish_event = Departure(system.n_events, finish_event_time) # create a finish event
        enqueue!(system.event_queue, finish_event, finish_event_time) # enqueue the event
    end

    if system.current_lawnmower === nothing && !isempty(system.order_queue) # if there was no mower being processed and order list isn't empty
        move_lawnmower_to_machine(system, R) # call move to machine function 
    end
end


### INITIALISE FN 
function initialise(P::Parameters)
    R = RandomNGs(P) # defining random generator for specific parameter
    system = State() # init state 

    t0 = 0.0 # define t0 as 0.0 time
    system.n_events += 1  # increase event counter by 1
    enqueue!(system.event_queue, Arrival(system.n_events, t0), t0)  # queue the first event at t0 time

    t1 = 150.0 # t1 at 150 time
    system.n_events += 1  # increase event counter by 1 
    enqueue!(system.event_queue, Breakdown(system.n_events, t1), t1) # queue a breakdown event at t1 time

    return (system, R) # return system and random generators with specific parameter created
end

### HELPER FNS TO WRITE DATA

# STATE writing fn (actually record state data)
function write_state(event_file::IO, system::SystemState, event::Event)
    type_of_event = typeof(event) # creating variable for event type
    in_service = (system.current_lawnmower !== nothing) ? 1 : 0 # variable for in service status (if in service, set as 1)
    machine_status = system.machine_broken ? 1 : 0 # if machine is not broken, display 0 or else 1 (not broken)

    @printf(event_file, # print function with parameters of the file,
        "%.3f, %d, %s, %d, %d, %d, %d", # space and characters allowed settings
        system.current_time, # time of event columm
        event.id, # event id column
        type_of_event, # event type column
        length(system.event_queue), # number of events occuring column
        length(system.order_queue), # length of order list (waiting for machine) column
        in_service, # in machine has a mower in process column
        machine_status # if machine is broken or not column 
    )

    @printf(event_file, "\n") # new line
end

# ENTITIES writing fn (actually records entity data)
function write_entity(entity_file::IO, system::SystemState, lawnmower::Lawnmower, event::Event)
    @printf(entity_file,
        "%d, %12.14f, %12.14f, %12.14f, %d", # spacing for data
        lawnmower.id, # id column
        lawnmower.arrival_time, # arrival into system column
        lawnmower.start_blade_fitting, # time when entity starts blade fitting column 
        lawnmower.fitting_completion, # time when fitting is completed (departure) column
        system.n_interruptions) # interrutions counter in column

    @printf(entity_file, "\n") # new line 
end

# PARAMETER writing fn
function write_parameters(output::IO, P::Parameters) # function to writeout parameters
    T = typeof(P)
    for name in fieldnames(T)
        println(output, "# parameter: $name = $(getfield(P,name))")
    end
end

# different signature
write_parameters(P::Parameters) = write_parameters(stdout, P) # writes metadata with parameter as input

# METADATA writing fn
function write_metadata(output::IO) # function to writeout extra metadata
    (path, prog) = splitdir(@__FILE__)
    println(output, "# file created by code in $(prog)")
    t = now()
    println(output, "# file created on $(Dates.format(t, "yyyy-mm-dd at HH:MM:SS"))")
end

### RUN! function
function run!(system::SystemState, R::RandomNGs, T::Float64, fid_state::IO, fid_entities::IO)
    # main simulation loop
    while system.current_time < T && !isempty(system.event_queue) # run loop until time is reached 
        (event, event_time) = dequeue_pair!(system.event_queue) # grab the next event from event queue
        system.current_time = event_time # advance system time to new arrival

        write_state(fid_state, system, event) # write out event and state data before event

        # process the event based on event type
        if event isa Arrival # if event is an arrival of mower
            update!(system, R, event)
        elseif event isa Departure # if departure event
            update!(system, R, event)
        elseif event isa Breakdown # if breakdown event
            update!(system, R, event)
        elseif event isa RepairCompletion # if repair completion event
            update!(system, R, event)
        end

    end
    return system # return the final state of the system
end