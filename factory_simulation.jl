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
    ##############might add completion event?
end

## ENTITY: blank struct
Lawnmower(id, arrival_time) = Lawnmower(id, arrival_time, -1.0, -1.0) # set blade and completion time to -1 (clearly not set yet)

### STATE: struct
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

### STATE: blank struct
function State() 
    init_time = 0.0
    init_event_queue = PriorityQueue{Event}()
    init_order_queue = Queue{Lawnmower}()
    init_n_entities = 0
    init_n_events = 0
    init_machine_busy = false
    init_machine_broken = false
    init_n_interruptions = 0
    init_repair_time = 0.0
    return SystemState(
        init_time,
        init_event_queue,
        init_order_queue,
        init_n_entities,
        init_n_events,
        init_machine_busy,
        init_machine_broken,
        init_n_interruptions,
        init_repair_time)
end



### HELPER FUNCTIONS:
# mean_interarrival = 60 # unit is minutes
# interarrival_time() = rand(rng, Exponential(mean_interarrival)) # gen ia times
# service_time() = 45 #mins
# mean_breakdown = 2880 #2 days in minute
# breakdown_time() = rand(rng,Exponential(mean_breakdown))
# mean_repair = 180 #mins
# repair_time() = rand(rng, Exponential(mean_repair))


### MOVING LAWNMOWER TO BLADE MACHINE
function move_lawnmower_to_machine( system::SystemState, R::RandomNGs )
    lawnmower = dequeue!(system.order_queue) #remove mower from waiting list
    system.machine_busy = true # change machine to busy
    lawnmower.start_blade_fitting = system.current_time #start fitting
    lawnmower.fitting_completion = lawnmower.start_blade_fitting + R.construction_time() # total service time
    
    
    #assemblyCompletion event for when the blade fitting is done
    system.n_events += 1 # number of event increases 
    assembly_completion = AssemblyCompletion(system.n_events, lawnmower.fitting_completion) # create completion event
    enqueue!(system.event_queue, assembly_completion, lawnmower.fitting_completion) #shld i include this?
    
    
    # check if the machine will break down before the fitting is completed
    if rand(rng, Exponential(mean_breakdown)) < service_time()
        # schedule a breakdown time:
        breakdown_time = system.current_time + breakdown_time()
        enqueue!(system.event_queue, Breakdown(breakdown_time), breakdown_time)
    end
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
    future_arrival = Arrival(system.n_events, system.time + R.interarrival_time()) # arrival event with id and time.
    enqueue!(system.event_queue, future_arrival, future_arrival.time) # add to event queue, using future arrivals time.

    # if machine is working and available
    if !system.machine_broken && !system.machine_busy
        move_lawnmower_to_machine!(SystemState) # move into service
    end 

    return new_lawnmower
end


### UPDATE DEPARTURE
function update!(system::SystemState, event::Departure)
    system.current_time = event.time # advance system into the new departure
    
    #mark as assembly complete, machine is not busy

    ############################### finish departure event type
end

### UPDATE BREAKDOWN
function update!(system::SystemState, rng::RandomNGs, event::Breakdown)
    system.current_time = event.time
    system.machine_broken = true
    system.n_interruptions += 1

    if system.machine_busy
        lawnmower = dequeue!(system.order_queue)
        
        # Calculate repair time
        repair_duration = repair_time()

        # Extend fitting completion time and update priority in the event queue directly
        lawnmower.fitting_completion += repair_duration
        system.event_queue[lawnmower.completion_event] = lawnmower.fitting_completion
    end

    # Schedule repair completion
    repair_completion_time = system.current_time + repair_duration
    enqueue!(system.event_queue, RepairCompletion(system.n_events + 1, repair_completion_time))
end

### PARAMETER: struct
struct Parameters
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
function RandomNGs( P::Parameters )
    rng = StableRNG(P.seed)
    interarrival_time() = rand(rng, Exponential(P.mean_interarrival))
    construction_time() = P.mean_construction_time
    interbreakdown_time() = rand(rng, Exponential(P.mean_interbreakdown_time))
    repair_time() = rand(rng, Exponential(P.mean_repair_time))
end 

### INITIALISE FN 
function initialise(P::Parameters) 
    R = RandomNGs(P)
    system = State()

    t0 = 0.0
    system.n_events += 1
    enqueue!(system.event_queue, Arrival(0,t0),t0)

    t1 = 150.0
    system.n_events += 1 
    enqueue!(system.event_queue, Breakdown(system.n_events,t1),t1)
    
    return (system,R)
end 

########################## finish the initialising 

### RUN FUNCTION