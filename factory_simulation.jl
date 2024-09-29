using DataStructures
using Distributions
using StableRNGs
using Printf
using Dates

### EVENTS: structs
abstract type Event end

mutable struct Arrival <: Event ## arrival of mower
    id::Int64
    time::Float64
end

mutable struct Breakdown <: Event # breakdown of machine
    id::Int64
    time::Float64
end

mutable struct RepairCompletion <: Event # repair completion event
    time::Float64
end

mutable struct AssemblyCompletion <: Event # when mower is fully finished
    id::Int64
    time::Float64
end

### ENTITY: struct
mutable struct Lawnmower
    id::Int64
    arrival_time::Float64 # time when the lawnmower part arrives?
    start_blade_fitting::Float64 # time when the machine enters the blade fitting machine
    fitting_completion::Float64 # when lawnmower completes blade fitting?
end

## ENTITY: blank struct
Lawnmower(id, arrival_time) = Lawnmower(id, arrival_time, -1.0, -1.0) # set blade and completion time to -1 (clearly not set yet)

### STATE: struct
mutable struct SystemState
    current_time::Float64
    event_queue::PriorityQueue{Event} # keep track of future arrivals/services??
    order_queue::Queue{Lawnmower} # keep track of waiting orders
    n_entities::Int64 # number of mowers in da system
    n_events::Int64 # tracking num of events 
    machine_broken::Bool # if machine is broken/under repair
    n_interruptions::Int64 # counter for interruptions of mowers because of breakdowns
    total_repair_time::Float64 # to count total time lost to repairations
    current_lawnmower::Union{Nothing,LawnMower}  # tracks the mower in service
end

### STATE: blank struct
function State()
    init_time = 0.0
    init_event_queue = PriorityQueue{Event}()
    init_order_queue = Queue{Lawnmower}()
    init_n_entities = 0
    init_n_events = 0
    init_machine_broken = false
    init_n_interruptions = 0
    init_repair_time = 0.0
    init_current_lawnmower = nothing
    return SystemState(
        init_time,
        init_event_queue,
        init_order_queue,
        init_n_entities,
        init_n_events,
        init_machine_broken,
        init_n_interruptions,
        init_repair_time,
        init_current_lawnmower)
end

### MOVING LAWNMOWER TO BLADE MACHINE
function move_lawnmower_to_machine(system::SystemState, R::RandomNGs)
    lawnmower = dequeue!(system.order_queue) # remove mower from waiting list
    system.current_lawnmower = lawnmower  # store the mower being processed in the system
    system.machine_broken = false # change machine to not broken

    lawnmower.start_blade_fitting = system.current_time # start blade fitting
    lawnmower.fitting_completion = lawnmower.start_blade_fitting + R.construction_time() # generate total service time

    #assemblyCompletion event for when the blade fitting is done
    system.n_events += 1 # number of event increases 
    assembly_completion = AssemblyCompletion(system.n_events, lawnmower.fitting_completion) # create completion event
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
    future_arrival_time = system.time + R.interarrival_time() # generate arrival time 
    future_arrival = Arrival(system.n_events, future_arrival_time) # arrival event with id and time.
    enqueue!(system.event_queue, future_arrival, future_arrival_time) # add to event queue, using future arrivals time.

    # if machine is working and available
    if !system.machine_broken && system.current_lawnmower === nothing
        move_lawnmower_to_machine(system, R) # move into service
    end

    return new_lawnmower
end


### UPDATE DEPARTURE
function update!(system::SystemState, R::RandomNGs, event::AssemblyCompletion)
    system.current_time = event.time # advance system into the new departure
    lawnmower = system.current_lawnmower # select lawnmower as current one being made 
    lawnmower.fitting_completion = system.current_time # set lawnmower's completion to occur at the current time ()

    system.n_events += 1 # increase event count

    system.current_lawnmower = nothing # reset system into having no mower in machine

    # initiate the next event if there are more orders to be processed 
    if !isempty(system.order_queue)
        move_lawnmower_to_machine(system, R) # call move mower to machine function
    else
        system.machine_broken = false # keep machine status as false
    end 

    return lawnmower
end

### UPDATE BREAKDOWN
function update!(system::SystemState, R::RandomNGs, event::Breakdown)
    system.current_time = event.time # advance system time to this event
    system.machine_broken = true # change machine to broken 
    system.n_interruptions += 1 # increment interruption counter by 1 

    if system.current_lawnmower !== nothing # if machine was working on a mower at time of breakdown,
        lawnmower = system.current_lawnmower # select the mower being processed

        repair_duration = R.repair_time() # generate a repair time using RandomNGs
        lawnmower.fitting_completion += repair_duration # adding repair time to completion time
        
        #search for the assembly complete event that was created in event queue
        for (event, _) in system.event_queue
            if event isa AssemblyCompletion && event.id == lawnmower.id # if the id matches 
                dequeue!(system.event_queue, event)  # remove the event
                break
            end
        end

        #reenqueue an assembly complete event 
        enqueue!(system.event_queue, AssemblyCompletion(lawnmower.id, lawnmower.fitting_completion), lawnmower.fitting_completion)
    end

    # schedule repair completion event
    system.n_events += 1 # increase event count by 1 
    repair_completion_time = system.current_time + R.repair_time() # set system time when repair finishes
    repair_event = Repair(system.n_events, repair_completion_time) # create repair event 
    enqueue!(system.event_queue, repair_event, repair_completion_time) # add to event queue, using repair completion time

end

### UDPDATE REPAIR 
function update!(system::SystemState, R::RandomNGs, event::RepairCompletion)
    system.current_time = event.time # advance system time to this event
    system.machine_broken = false # changing machine status to opertaional

    if system.current_lawnmower !== nothing # if there was a current lawnmower
        lawnmower = system.current_lawnmower # select the mower that was being processed 
        system.n_events += 1 # increment event count by 1 
        finish_event_time = lawnmower.fitting_completion # set finish time to this mowers finish time
        finish_event = Finish(system.n_events, finish_event_time) # create a finish event
        enqueue!(system.event_queue, finish_event, finish_event_time) # enqueue the event
    end

    if system.current_lawnmower === nothing && !isempty(system.order_queue) # if there was no mower being processed and order list isn't empty
        move_lawnmower_to_machine(system, R) # call move to machine function 
    end
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
    rng::StableRNG.LehmerRNG
    interarrival_time::Function
    construction_time::Function
    interbreakdown_time::Function
    repair_time::Function
end

### RANDOMNGS: function
function RandomNGs(P::Parameters)
    rng = StableRNG(P.seed)
    interarrival_time() = rand(rng, Exponential(P.mean_interarrival))
    construction_time() = P.mean_construction_time
    interbreakdown_time() = rand(rng, Exponential(P.mean_interbreakdown_time))
    repair_time() = rand(rng, Exponential(P.mean_repair_time))
    return RandomNGs( rng, interarrival_time, construction_time, interbreakdown_time, repair_time )

end

### INITIALISE FN 
function initialise(P::Parameters)
    R = RandomNGs(P)
    system = State()

    t0 = 0.0
    system.n_events += 1  # 
    enqueue!(system.event_queue, Arrival(system.n_events, t0), t0)  #

    t1 = 150.0
    system.n_events += 1  # 
    enqueue!(system.event_queue, Breakdown(system.n_events, t1), t1) #

    return (system, R)
end

### HELPER FNS TO WRITE DATA

# STATE writing fn (actually record state data)
function write_state(event_file::IO, system::SystemState, event::Event)
    type_of_event = typeof(event) # creating variable for event type
    in_service = (system.current_lawnmower !== nothing) ? 1 : 0 # variable for in service status (if in service, set as 1)
    machine_status = !system.machine_broken ? 0 : 1 # if machine is not broken, display 0 or else 1 (not broken)
    
    @printf(event_file, # print function with parameters of the file,
            "%12.3f, %6d, %11s, %4d, %4d, %4d, %4d", # space and characters allowed settings
            system.current_time, # time of event columm
            event.id, # event id column
            type_of_event, # event type column
            length(system.event_queue), # length of events occuring
            length(system.order_queue), # length of order list (waiting for machine)
            in_service, # in machine has a mower in process column
            machine_status # if machine is broken or not column 
            )

    @printf(event_file, "\n")
end 

# ENTITIES writing fn (actually records entity data)
function write_entity(entity_file::IO, system::SystemState, lawnmower::LawnMower, event::Event)
    @printf(entity_file, 
            "%6d, %12.14f, %12.14f, %12.14f, %4d∇",
            event.id,
            lawnmower.arrival_time,
            lawnmower.start_blade_fitting,
            lawnmower.fitting_completion,
            system.n_interruptions)

    @printf(entity_file,"\n") 
end

### RUN FUNCTION
# The function should run the main simulation loop for time T. It should remove
# an event from the event list, call the appropriate function(s) to update the state
# and write any required output. This should be the function that writes any
# output when the code is performing correctly, but you may create some utility
# functions for writing data that are called by run! to make the run! function more
# readable.
# The run! function should return the system state when the simulation finishes

function run!(system::SystemState, R::RandomNGs, T::Float64, fid_state::IO, fid_entities::IO)
    # main simulation loop
    while system.current_time < T # run loop until time is reached 
        (event, event_time) = dequeue_pair!(system.event_queue) # grab the next event from event queue
        system.current_time = event_time # advance system time to new arrival
        # system.n_events += 1 # increase event counter?

        # write out event and state data before event 
        write_state(fid_state, system, event)
        
                # process the event based on event type
                if event isa Arrival
                    update!(state, R, event)
                elseif event isa Departure
                    update!(state, R, event)
                    # assume you are logging the lawnmower that has just completed processing
                    lawnmower = state.current_lawnmower  # Get the current lawnmower being processed
                    write_entity(fid_entities, state, lawnmower, event)  # Write lawnmower data to entity file
                elseif event isa Breakdown
                    update!(state, R, event)
                elseif event isa Repair
                    update!(state, R, event)
                else
                    error("Unknown event type")
                end
        
                # Write the updated state to the state file after processing the event
                write_state(fid_state, state, event)
            end
            
            return system  # Return the final state of the system
        end

