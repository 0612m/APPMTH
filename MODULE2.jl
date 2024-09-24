# using DataStructures


# pq = PriorityQueue{String, Int}()   # construct a new priority queue with keys of type K and priorities of type V (forward ordering by default)
# enqueue!(pq, "Angus", 1)            # insert the key k into pq with priority v
# enqueue!(pq, "Matt", 1)             # insert the key k into pq with priority v
# enqueue!(pq, "Lewis"=> 2)           # (same, using Pairs)
# peek(pq);                     # return the lowest priority key and value without removing it bruh the semicolon was stopping it 



    using StableRNGs       # load stableRNG package
    rng = StableRNG(5678)  # set seed and RNG
    P = [0.05, 0.1, 0.2, 0.3, 0.35] # probability of each triage class
    function generateTriage(P)
        r = 0.05
        if r < P[1]
            category = 1
        elseif r < P[1] 
            category = 2 
        # elseif r < P[1] + P[2] + P[3]
        #     category = 3
        # elseif r < P[1] + P[2] + P[3] + P[4]
        #     category = 4
        # else
        #     category = 5 
        end
        return category
        println(category)

    end

    
