"""
Swarms.jl - Core Swarm Management for JuliaOS

This module provides functionalities to create, manage, and interact with swarms
of agents, leveraging various optimization algorithms.
"""
module Swarms

using Dates, Random, UUIDs, Logging, Base.Threads
using JSON3

# Assuming SwarmBase.jl is in the same directory
using .SwarmBase 
# Assuming Agents.jl and its submodules are accessible from the parent scope 
# (e.g., if JuliaOSFramework.jl includes both this and Agents)
# This might need adjustment based on actual module loading in JuliaOSFramework.jl
try
    # Attempt to use the main Agents module if available (e.g. loaded by a parent module)
    # This path might need to be `Main.Agents` or `JuliaOS.Agents` depending on how modules are structured and loaded.
    # For now, assuming direct relative access for simplicity if Swarms.jl is part of a larger JuliaOS module.
    # If Swarms is a completely independent module, it would `using Agents` after Agents is in LOAD_PATH.
    # Given that Swarms.jl is now in julia/src/swarm and Agents.jl is in julia/src/agents
    using ..agents.Agents 
    using ..agents.Config 
    using ..agents.AgentMetrics 
    @info "Swarms.jl: Successfully using main Agents module."
catch e
    @warn "Swarms.jl: Could not load main Agents module. Using internal stubs. Ensure Agents module is loaded correctly by the parent."
    # Minimal stubs if Agents module is not found (for basic compilation)
    module AgentsStub
        struct Agent end
        getAgent(id) = nothing
        module Swarm # Nested Swarm module within Agents for specific functions
            subscribe_swarm!(agent_id, topic) = @warn "Agents.Swarm unavailable (stub): Cannot subscribe $agent_id to $topic"
            publish_to_swarm(sender_id, topic, msg) = @warn "Agents.Swarm unavailable (stub): Cannot publish to $topic"
            unsubscribe_swarm!(agent_id, topic) = @warn "Agents.Swarm unavailable (stub): Cannot unsubscribe $agent_id from $topic"
        end
    end
    using .AgentsStub
    # Define dummy config/metrics if Agents.Config/AgentMetrics not available
    get_config(key, default) = default
    record_metric(args...; kwargs...) = nothing
end


export Swarm, SwarmConfig, SwarmStatus, createSwarm, getSwarm, listSwarms, startSwarm, stopSwarm,
       getSwarmStatus, addAgentToSwarm, removeAgentFromSwarm, getSharedState, updateSharedState!,
       electLeader, allocateTask, claimTask, completeTask, getSwarmMetrics,
       # Re-export types from SwarmBase that might be used by API or other modules
       AbstractSwarmAlgorithm, OptimizationProblem, SwarmSolution, OptimizationResult

@enum SwarmStatus begin
    SWARM_CREATED = 1
    SWARM_RUNNING = 2
    SWARM_STOPPED = 3
    SWARM_ERROR = 4
    SWARM_COMPLETED = 5 # Added for when algorithm finishes successfully
end

# Placeholder for specific algorithm types if not defined elsewhere or re-exported from SwarmBase/algorithms
# For now, we assume AbstractSwarmAlgorithm is the main type used in SwarmConfig.
# Concrete algorithm structs (like SwarmPSO, SwarmDE) would be defined in their respective files
# in the `algorithms` subdirectory and used when creating SwarmConfig.

"""
    SwarmConfig

Configuration for creating a new swarm.
"""
mutable struct SwarmConfig
    name::String
    algorithm_type::String # e.g., "PSO", "DE". Used to select the concrete algorithm.
    algorithm_params::Dict{String, Any} # Parameters for the chosen algorithm
    objective_description::String # Description or identifier for the objective function
    max_iterations::Int
    target_fitness::Union{Float64, Nothing} # Optional target fitness to stop early
    problem_definition::OptimizationProblem # Using OptimizationProblem from SwarmBase

    function SwarmConfig(name::String, algorithm_type::String, problem_def::OptimizationProblem;
                         algorithm_params::Dict{String,Any}=Dict{String,Any}(),
                         objective_desc::String="Default Objective",
                         max_iter::Int=100, target_fit=nothing)
        new(name, algorithm_type, algorithm_params, objective_desc, max_iter, target_fit, problem_def)
    end
end

"""
    Swarm

Represents a swarm in the JuliaOS system.
"""
mutable struct Swarm
    id::String
    name::String
    status::SwarmStatus
    created_at::DateTime
    updated_at::DateTime
    config::SwarmConfig
    agents::Vector{String} # List of agent IDs participating in the swarm
    
    # Runtime state
    current_iteration::Int
    best_solution_found::Union{SwarmSolution, Nothing}
    algorithm_instance::Union{AbstractSwarmAlgorithm, Nothing} # Instance of the running algorithm
    swarm_task_handle::Union{Task, Nothing} # Handle to the background task running the algorithm
    
    shared_data::Dict{String, Any} # For inter-agent communication within the swarm or leader data
    task_queue::Vector{Dict{String,Any}} # Tasks for the swarm to distribute/process

    function Swarm(id, name, config)
        new(id, name, SWARM_CREATED, now(UTC), now(UTC), config, String[],
            0, nothing, nothing, nothing,
            Dict{String,Any}(), Vector{Dict{String,Any}}())
    end
end

# --- Global State & Persistence ---
const SWARMS_REGISTRY = Dict{String, Swarm}()
const SWARMS_LOCK = ReentrantLock() # For thread-safe access to SWARMS_REGISTRY

const DEFAULT_SWARM_STORE_PATH = joinpath(@__DIR__, "..", "..", "db", "swarms_state.json") # Consistent with agents_state.json location
const SWARM_STORE_PATH = Ref(get_config("storage.swarm_path", DEFAULT_SWARM_STORE_PATH))
const SWARM_AUTO_PERSIST = Ref(get_config("storage.auto_persist_swarms", true)) # Separate config for swarm auto-persist

function _ensure_storage_dir()
    try
        store_dir = dirname(SWARM_STORE_PATH[])
        ispath(store_dir) || mkpath(store_dir)
    catch e
        @error "Failed to ensure swarm storage directory exists: $(dirname(SWARM_STORE_PATH[]))" exception=(e, catch_backtrace())
    end
end

function _serialize_optimization_problem(prob::OptimizationProblem)
    # Note: objective_function cannot be directly serialized to JSON.
    # We store its name/identifier if possible, or a placeholder.
    # Deserialization will require re-associating this with an actual Julia function.
    return Dict(
        "dimensions" => prob.dimensions,
        "bounds" => prob.bounds,
        "objective_function_name" => string(prob.objective_function), # Placeholder
        "is_minimization" => prob.is_minimization
    )
end

function _deserialize_optimization_problem(data::Dict)::Union{OptimizationProblem, Nothing}
    try
        # IMPORTANT: The objective_function needs to be resolved from a string name
        # to an actual Julia function during deserialization. This is complex and
        # typically requires a registry of known objective functions or dynamic lookup.
    # For now, we'll use a placeholder function.
    # A real system needs a robust way to map objective_function_name to a callable function.
    # This could involve a registry or looking up functions in specific modules.
    obj_func_name = get(data, "objective_function_name", "default_sum_objective")
    resolved_obj_func = get_objective_function_by_name(obj_func_name)

    return OptimizationProblem(
        data["dimensions"],
        [tuple(b...) for b in data["bounds"]], # Convert array of arrays to array of tuples
        resolved_obj_func; 
        is_minimization=data["is_minimization"]
    )
    catch e
        @error "Error deserializing OptimizationProblem" data=data exception=e
        return nothing
    end
end


function _save_swarms_state()
    SWARM_AUTO_PERSIST[] || return
    _ensure_storage_dir()

    data_to_save = Dict{String, Any}()
    lock(SWARMS_LOCK) do
        for (id, swarm) in SWARMS_REGISTRY
            serialized_config = Dict(
                "name" => swarm.config.name,
                "algorithm_type" => swarm.config.algorithm_type,
                "algorithm_params" => swarm.config.algorithm_params,
                "objective_description" => swarm.config.objective_description,
                "max_iterations" => swarm.config.max_iterations,
                "target_fitness" => swarm.config.target_fitness,
                "problem_definition" => _serialize_optimization_problem(swarm.config.problem_definition)
            )
            # SwarmSolution also needs careful serialization if it contains non-standard types
            serialized_best_solution = isnothing(swarm.best_solution_found) ? nothing : Dict(
                "position" => swarm.best_solution_found.position,
                "fitness" => swarm.best_solution_found.fitness, # Assumes fitness is simple (Float or Vector{Float})
                "is_feasible" => swarm.best_solution_found.is_feasible,
                "metadata" => swarm.best_solution_found.metadata
            )

            data_to_save[id] = Dict(
                "id" => swarm.id,
                "name" => swarm.name,
                "status" => Int(swarm.status),
                "created_at" => string(swarm.created_at),
                "updated_at" => string(swarm.updated_at),
                "config" => serialized_config,
                "agents" => swarm.agents,
                "current_iteration" => swarm.current_iteration,
                "best_solution_found" => serialized_best_solution,
                "shared_data" => swarm.shared_data, # Assumes JSON-serializable
                "task_queue" => swarm.task_queue # Assumes JSON-serializable
                # algorithm_instance and swarm_task_handle are not persisted
            )
        end
    end

    temp_file_path = SWARM_STORE_PATH[] * ".tmp." * string(uuid4())
    try
        open(temp_file_path, "w") do io
            JSON3.write(io, data_to_save)
        end
        mv(temp_file_path, SWARM_STORE_PATH[]; force=true)
        @debug "Swarm state saved to $(SWARM_STORE_PATH[])"
    catch e
        @error "Failed to save swarm state" exception=(e, catch_backtrace())
        isfile(temp_file_path) && try rm(temp_file_path) catch rm_e @warn "Failed to remove temp swarm save file" exception=rm_e end
    end
end

function _load_swarms_state()
    _ensure_storage_dir()
    isfile(SWARM_STORE_PATH[]) || ( @info "No swarm state file found at $(SWARM_STORE_PATH[])."; return )
    
    raw_data = nothing
    try
        raw_data = JSON3.read(read(SWARM_STORE_PATH[], String))
    catch e
        @error "Error reading/parsing swarm state file $(SWARM_STORE_PATH[])." exception=e
        return
    end

    loaded_count = 0
    lock(SWARMS_LOCK) do
        empty!(SWARMS_REGISTRY)
        for (id_str, swarm_data) in raw_data
            try
                cfg_data = swarm_data["config"]
                problem_def_data = cfg_data["problem_definition"]
                
                deserialized_problem_def = _deserialize_optimization_problem(problem_def_data)
                if isnothing(deserialized_problem_def)
                    @warn "Skipping swarm $id_str due to problem deserialization error."
                    continue
                end

                config = SwarmConfig(
                    cfg_data["name"],
                    cfg_data["algorithm_type"],
                    deserialized_problem_def; # Use deserialized problem
                    algorithm_params=cfg_data["algorithm_params"],
                    objective_desc=cfg_data["objective_description"],
                    max_iter=cfg_data["max_iterations"],
                    target_fit=cfg_data["target_fitness"]
                )
                
                swarm = Swarm(
                    swarm_data["id"],
                    swarm_data["name"],
                    config
                )
                swarm.status = SwarmStatus(swarm_data["status"])
                swarm.created_at = DateTime(swarm_data["created_at"])
                swarm.updated_at = DateTime(swarm_data["updated_at"])
                swarm.agents = get(swarm_data, "agents", String[])
                swarm.current_iteration = get(swarm_data, "current_iteration", 0)
                
                bs_data = get(swarm_data, "best_solution_found", nothing)
                if !isnothing(bs_data)
                    swarm.best_solution_found = SwarmSolution(
                        convert(Vector{Float64}, bs_data["position"]), # Ensure type
                        bs_data["fitness"], # Allow Union{Float64, Vector{Float64}}
                        bs_data["is_feasible"],
                        bs_data["metadata"]
                    )
                end
                swarm.shared_data = get(swarm_data, "shared_data", Dict{String,Any}())
                swarm.task_queue = get(swarm_data, "task_queue", Vector{Dict{String,Any}}())
                
                SWARMS_REGISTRY[id_str] = swarm
                loaded_count += 1
            catch e
                @error "Error loading swarm $id_str from state." exception=(e, catch_backtrace())
            end
        end
    end
    @info "Loaded $loaded_count swarms from $(SWARM_STORE_PATH[])."
end


# --- Objective Function Registry (Simple Example) ---
# In a real application, this might be more extensive, configurable, or use metaprogramming.
const OBJECTIVE_FUNCTION_REGISTRY = Dict{String, Function}()

function register_objective_function!(name::String, func::Function)
    OBJECTIVE_FUNCTION_REGISTRY[name] = func
    @info "Registered objective function: $name"
end

function get_objective_function_by_name(name::String)::Function
    if haskey(OBJECTIVE_FUNCTION_REGISTRY, name)
        return OBJECTIVE_FUNCTION_REGISTRY[name]
    else
        @warn "Objective function '$name' not found in registry. Falling back to default sum objective."
        return (pos_vec::Vector{Float64}) -> sum(pos_vec) # Default placeholder
    end
end

# Example objective functions (could be in a separate file/module)
function sphere_objective(pos::Vector{Float64})::Float64
    return sum(x^2 for x in pos)
end

function rastrigin_objective(pos::Vector{Float64})::Float64
    A = 10.0
    n = length(pos)
    return A * n + sum(x^2 - A * cos(2 * π * x) for x in pos)
end

# Register some default objectives during module initialization
function _register_default_objectives()
    register_objective_function!("sphere", sphere_objective)
    register_objective_function!("rastrigin", rastrigin_objective)
    register_objective_function!("default_sum_objective", (pos_vec::Vector{Float64}) -> sum(pos_vec))
end
# --- End Objective Function Registry ---


# --- Core Swarm Management Functions ---

function createSwarm(config::SwarmConfig)::Swarm
    swarm_id = "swarm-" * string(uuid4())
    swarm = Swarm(swarm_id, config.name, config)
    
    lock(SWARMS_LOCK) do
        SWARMS_REGISTRY[swarm_id] = swarm
    end
    @info "Created swarm '$(config.name)' (ID: $swarm_id) with algorithm $(config.algorithm_type)."
    _save_swarms_state()
    return swarm
end

function getSwarm(id::String)::Union{Swarm, Nothing}
    lock(SWARMS_LOCK) do
        return get(SWARMS_REGISTRY, id, nothing)
    end
end

function listSwarms(; filter_status::Union{SwarmStatus, Nothing}=nothing)::Vector{Swarm}
    lock(SWARMS_LOCK) do
        swarms_list = collect(values(SWARMS_REGISTRY))
        if !isnothing(filter_status)
            filter!(s -> s.status == filter_status, swarms_list)
        end
        return swarms_list
    end
end

function addAgentToSwarm(swarm_id::String, agent_id::String)::Bool
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && (@warn "Swarm $swarm_id not found."; return false)
    
    # Ensure agent exists (using the imported Agents module)
    agent_instance = nothing
    try
        agent_instance = Agents.getAgent(agent_id)
    catch e
        @warn "Error checking agent $agent_id: $e. Could not add to swarm $swarm_id."
        return false
    end
    isnothing(agent_instance) && (@warn "Agent $agent_id not found. Cannot add to swarm $swarm_id."; return false)

    lock(SWARMS_LOCK) do # Lock for modifying the swarm's agent list
        if !(agent_id in swarm.agents)
            push!(swarm.agents, agent_id)
            swarm.updated_at = now(UTC)
            @info "Agent $agent_id added to swarm $swarm_id."
            # TODO: Subscribe agent to swarm-specific topics using Agents.Swarm.subscribe_swarm!
            _save_swarms_state()
            return true
        else
            @info "Agent $agent_id already in swarm $swarm_id."
            return true # Idempotent
        end
    end
    # This part of the code might not be reachable due to the lock structure,
    # but as a fallback or if the lock logic changes:
    # @warn "Failed to acquire lock or other issue in addAgentToSwarm for swarm $swarm_id."
    return false 
end

function removeAgentFromSwarm(swarm_id::String, agent_id::String)::Bool
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && (@warn "Swarm $swarm_id not found."; return false)

    lock(SWARMS_LOCK) do
        if agent_id in swarm.agents
            filter!(id -> id != agent_id, swarm.agents)
            swarm.updated_at = now(UTC)
            @info "Agent $agent_id removed from swarm $swarm_id."
            # TODO: Unsubscribe agent from swarm topics using Agents.Swarm.unsubscribe_swarm!
            _save_swarms_state()
            return true
        else
            @warn "Agent $agent_id not found in swarm $swarm_id."
            return false
        end
    end
    # @warn "Failed to acquire lock or other issue in removeAgentFromSwarm for swarm $swarm_id."
    return false
end

# Placeholder for algorithm instantiation - this would be more complex
function _instantiate_algorithm(swarm::Swarm)
    algo_type_str = swarm.config.algorithm_type
    params = swarm.config.algorithm_params
    problem = swarm.config.problem_definition # This is an OptimizationProblem

    # This function needs to dynamically load and instantiate the correct algorithm
    # based on `algo_type_str`. This typically involves a registry or `if/elseif` chain.
    # For now, it's a placeholder. Actual algorithms would be in `julia/src/swarm/algorithms/`.
    
    # Example structure (assuming algorithms are in separate modules):
    # if algo_type_str == "PSO"
    #     try
    #         # using .Algorithms.PSO # Or however PSOAlgorithm is exposed
    #         # return PSO.PSOAlgorithm(problem, params...) 
    #         @warn "PSO algorithm instantiation is a placeholder."
    #         # A mock algorithm that conforms to AbstractSwarmAlgorithm for testing loop
    #         struct MockPSO <: AbstractSwarmAlgorithm end
    #         function SwarmBase.initialize!(alg::MockPSO, problem::OptimizationProblem, agents::Vector{String}) @info "MockPSO initialized" end
    #         function SwarmBase.step!(alg::MockPSO, problem::OptimizationProblem, agents::Vector{String}, current_iter::Int, shared_data::Dict) 
    #             @info "MockPSO step $current_iter"
    #             # Simulate work and agent interaction
    #             # This is where agents would be tasked with evaluations.
    #             # For now, just return a mock solution.
    #             mock_pos = rand(problem.dimensions) .* (problem.bounds[1][2] - problem.bounds[1][1]) .+ problem.bounds[1][1]
    #             mock_fitness = problem.objective_function(mock_pos)
    #             return SwarmSolution(mock_pos, mock_fitness)
    #         end
    #         function SwarmBase.should_terminate(alg::MockPSO, problem::OptimizationProblem, current_iter::Int, max_iter::Int, best_solution::Union{SwarmSolution,Nothing}, target_fitness::Union{Float64,Nothing}) 
    #             return current_iter >= max_iter 
    #         end
    #         return MockPSO()
    #     catch load_err
    #         @error "Failed to load/instantiate PSO algorithm" error=load_err
    #         return nothing
    #     end
    # elseif algo_type_str == "DE"
    #     # ... similar for DE ...
    # else
    #     @error "Unknown algorithm type: $algo_type_str for swarm $(swarm.id)"
    #     return nothing
    # end
    
    # This function needs to dynamically load and instantiate the correct algorithm
    # based on `algo_type_str`. This typically involves a registry or `if/elseif` chain.
    
    # Ensure the algorithms subdirectory and specific algorithm files are included.
    # This is a common pattern in Julia for organizing code.
    # The `include` path is relative to Swarms.jl (in julia/src/swarm/)
    try
        if algo_type_str == "PSO"
            include("algorithms/PSO.jl") # Make PSOAlgorithmImpl available
            # Parameters for PSOAlgorithm constructor can be extracted from swarm.config.algorithm_params
            pso_params = get(swarm.config.algorithm_params, "pso_specific_params", Dict()) # Example
            return PSOAlgorithmImpl.PSOAlgorithm(;
                num_particles=get(pso_params, "num_particles", 30),
                inertia=get(pso_params, "inertia", 0.7),
                c1=get(pso_params, "c1", 1.5),
                c2=get(pso_params, "c2", 1.5)
            )
        elseif algo_type_str == "DE"
            include("algorithms/DE.jl") # Make DEAlgorithmImpl available
            de_params = get(swarm.config.algorithm_params, "de_specific_params", Dict())
            return DEAlgorithmImpl.DEAlgorithm(;
                pop_size=get(de_params, "population_size", 50),
                cr=get(de_params, "crossover_rate", 0.9),
                f_factor=get(de_params, "mutation_factor", 0.8)
            )
        elseif algo_type_str == "GA"
            include("algorithms/GA.jl") # Make GAAlgorithmImpl available
            ga_params = get(swarm.config.algorithm_params, "ga_specific_params", Dict())
            return GAAlgorithmImpl.GAAlgorithm(;
                pop_size=get(ga_params, "population_size", 50),
                mut_rate=get(ga_params, "mutation_rate", 0.01),
                cross_rate=get(ga_params, "crossover_rate", 0.7)
            )
        # Add other algorithms here
        else
            @error "Unknown algorithm type: $algo_type_str for swarm $(swarm.id). Falling back to GenericMockAlgorithm."
            # Fallback to GenericMockAlgorithm if specific one not found or error during include
        end
    catch e
        @error "Error including/instantiating algorithm '$algo_type_str'" error=e
        # Fallback
    end

    # Generic Mock Algorithm as a fallback or for testing if specific includes fail
    @warn "Algorithm instantiation for '$(algo_type_str)' is using GenericMockAlgorithm due to error or unknown type. Swarm will not perform real optimization."
    struct GenericMockAlgorithm <: AbstractSwarmAlgorithm end
    function SwarmBase.initialize!(alg::GenericMockAlgorithm, problem::OptimizationProblem, agents::Vector{String}, config_params::Dict) 
        @info "GenericMockAlgorithm: Initialized for problem with $(problem.dimensions) dimensions."
    end
    function SwarmBase.step!(alg::GenericMockAlgorithm, problem::OptimizationProblem, agents::Vector{String}, current_iter::Int, shared_data::Dict, config_params::Dict)::Union{SwarmSolution, Nothing}
        @info "GenericMockAlgorithm: Step $current_iter."
        pos = rand(problem.dimensions)
        fitness = problem.objective_function(pos) - current_iter # Mock improvement
        return SwarmSolution(pos, fitness)
    end
    function SwarmBase.should_terminate(alg::GenericMockAlgorithm, current_iter::Int, max_iter::Int, best_solution::Union{SwarmSolution,Nothing}, target_fitness::Union{Float64,Nothing}, problem::OptimizationProblem)::Bool
        if !isnothing(best_solution) && !isnothing(target_fitness)
            if problem.is_minimization && best_solution.fitness <= target_fitness return true end
            if !problem.is_minimization && best_solution.fitness >= target_fitness return true end
        end
        return current_iter >= max_iter
    end
    return GenericMockAlgorithm()
end

function _swarm_algorithm_loop(swarm::Swarm)
    @info "Algorithm loop started for swarm $(swarm.name) (ID: $(swarm.id)) using $(swarm.config.algorithm_type)."
    
    swarm.algorithm_instance = _instantiate_algorithm(swarm)
    if isnothing(swarm.algorithm_instance)
        swarm.status = SWARM_ERROR
        swarm.updated_at = now(UTC)
        @error "Failed to initialize algorithm for swarm $(swarm.id). Swarm set to ERROR."
        _save_swarms_state()
        return
    end

    try
        # Initialize the algorithm instance (e.g., create initial population)
        SwarmBase.initialize!(swarm.algorithm_instance, swarm.config.problem_definition, swarm.agents, swarm.config.algorithm_params)
        @info "Swarm $(swarm.id): Algorithm initialized."

        max_iter = swarm.config.max_iterations
        
        for iter in 1:max_iter
            if swarm.status != SWARM_RUNNING # Check if stopped externally
                @info "Swarm $(swarm.id) loop stopping as status is $(swarm.status)."
                break
            end
            swarm.current_iteration = iter
            @debug "Swarm $(swarm.id) iteration $iter/$(max_iter)"

            # --- Perform one step of the algorithm ---
            # This step would typically involve:
            # 1. Algorithm generating new candidate solutions (e.g., new particle positions).
            # 2. Tasking agents to evaluate these solutions (call objective_function).
            #    - For each agent in `swarm.agents` or a subset:
            #      - `task_payload = Dict("type" => "evaluate_fitness", "position_to_evaluate" => candidate_pos, "swarm_id" => swarm.id, "iteration" => iter)`
            #      - `Agents.Swarm.publish_to_swarm(swarm.id, "agent_tasks", task_payload)` (or direct to agent)
            # 3. Collecting fitness results from agents (e.g., via a shared data structure or message passing).
            #    - This part is complex and needs a mechanism for agents to report back.
            #    - `results = _collect_agent_evaluations(swarm, expected_results_count)`
            # 4. Algorithm updating its internal state (e.g., particle velocities, best positions) based on results.
            # 5. Algorithm potentially updating `swarm.best_solution_found`.
            
            # --- Perform one step of the algorithm ---
            # The SwarmBase.step! function for a given algorithm might:
            #   a) Directly compute everything if no agents are needed/used.
            #   b) Generate a set of tasks (e.g., candidate solutions to evaluate).
            #      In this case, the loop here would distribute them, collect results,
            #      and then potentially call another method on the algorithm instance
            #      to update its state with the new fitness values.
            # For this conceptual loop, we assume `step!` handles its internal logic
            # and might use `shared_data` or direct agent calls if it's designed to be distributed.
            # If `step!` itself needs to be broken into "generate_tasks" and "process_results",
            # this loop would be more complex.

            # Conceptual: If step! returns tasks to be evaluated by agents:
            # tasks_to_evaluate = SwarmBase.generate_evaluation_tasks(swarm.algorithm_instance, ...)
            # if !isempty(tasks_to_evaluate) && !isempty(swarm.agents)
            #    _distribute_and_collect_fitnesses(swarm, tasks_to_evaluate) # This would update shared_data or algorithm state
            # end
            # new_best_solution_this_iter = SwarmBase.update_algorithm_state_and_get_best(swarm.algorithm_instance, ...)
            
            # Simplified: Assume step! does its work and returns the current best from its perspective
            current_iteration_best_solution = SwarmBase.step!(
                swarm.algorithm_instance, 
                swarm.config.problem_definition, 
                swarm.agents, # Agents available for the algorithm to use
                iter, 
                swarm.shared_data, # For inter-agent/algorithm communication
                swarm.config.algorithm_params
            )

            if !isnothing(current_iteration_best_solution)
                is_new_global_best = false
                if isnothing(swarm.best_solution_found)
                    is_new_global_best = true
                elseif swarm.config.problem_definition.is_minimization && current_iteration_best_solution.fitness < swarm.best_solution_found.fitness
                    is_new_global_best = true
                elseif !swarm.config.problem_definition.is_minimization && current_iteration_best_solution.fitness > swarm.best_solution_found.fitness
                    is_new_global_best = true
                end

                if is_new_global_best
                    swarm.best_solution_found = current_iteration_best_solution
                    @info "Swarm $(swarm.id) new global best solution at iter $iter: Fitness = $(swarm.best_solution_found.fitness), Position: $(swarm.best_solution_found.position)"
                    _save_swarms_state() # Persist on new best
                end
            end
            
            # Check termination criteria (delegated to algorithm instance, using the current global best)
            if SwarmBase.should_terminate(swarm.algorithm_instance, iter, max_iter, swarm.best_solution_found, swarm.config.target_fitness, swarm.config.problem_definition)
                @info "Swarm $(swarm.id) termination condition met at iteration $iter."
                swarm.status = SWARM_COMPLETED
                break 
            end
            
            # Simulate work / allow for agent communication
            # In a real system, this might be event-driven or have more sophisticated timing.
            sleep(get(swarm.config.algorithm_params, "iteration_delay_seconds", 0.1)) 
        end # end iteration loop

        if swarm.status == SWARM_RUNNING # If loop finished due to max_iterations without other termination
            swarm.status = SWARM_COMPLETED
            @info "Swarm $(swarm.id) completed max iterations ($max_iter)."
        end

    catch e
        if isa(e, InterruptException)
            @info "Swarm $(swarm.id) algorithm loop interrupted."
            swarm.status = SWARM_STOPPED
        else
            @error "Error in swarm $(swarm.id) algorithm loop!" exception=(e, catch_backtrace())
            swarm.status = SWARM_ERROR
        end
    finally
        swarm.updated_at = now(UTC)
        swarm.swarm_task_handle = nothing # Clear task handle
        @info "Swarm $(swarm.id) algorithm loop finished. Final status: $(swarm.status)."
        _save_swarms_state() # Persist final state
    end
end


function startSwarm(id::String)::Bool
    swarm = getSwarm(id)
    isnothing(swarm) && (@warn "Swarm $id not found."; return false)

    if swarm.status == SWARM_RUNNING && !isnothing(swarm.swarm_task_handle) && !istaskdone(swarm.swarm_task_handle)
        @warn "Swarm $id is already running."
        return true
    end
    if swarm.status == SWARM_ERROR
        @warn "Swarm $id is in ERROR state. Please reset or recreate."
        return false
    end
    if isempty(swarm.agents) && swarm.config.algorithm_type != "SingleAgentDebug" # Allow some algos to run without agents for testing
        @warn "Swarm $id has no agents. Algorithm cannot start unless it's designed for solo execution."
        # return false # Uncomment if agents are strictly required for most algorithms
    end

    swarm.status = SWARM_RUNNING
    swarm.updated_at = now(UTC)
    swarm.current_iteration = 0 # Reset iteration count

    swarm.swarm_task_handle = @task _swarm_algorithm_loop(swarm)
    schedule(swarm.swarm_task_handle)
    
    @info "Swarm $id started with algorithm $(swarm.config.algorithm_type)."
    _save_swarms_state()
    return true
end

function stopSwarm(id::String)::Bool
    swarm = getSwarm(id)
    isnothing(swarm) && (@warn "Swarm $id not found."; return false)

    if swarm.status != SWARM_RUNNING
        @warn "Swarm $id is not currently running. Current status: $(swarm.status)."
        # If it's created or stopped, this is fine. If error, user should handle.
        return swarm.status != SWARM_ERROR # Return true if already stopped/created, false if error
    end

    swarm.status = SWARM_STOPPED
    swarm.updated_at = now(UTC)
    @info "Signaled swarm $id to stop."

    # The _swarm_algorithm_loop checks swarm.status and should exit.
    # For more immediate interruption, one could schedule an InterruptException
    # if swarm.swarm_task_handle !== nothing && !istaskdone(swarm.swarm_task_handle)
    #     schedule(swarm.swarm_task_handle, InterruptException(), error=true)
    # end
    _save_swarms_state() # Save state after signaling stop
    return true
end

function getSwarmStatus(id::String)::Union{Dict, Nothing}
    swarm = getSwarm(id)
    isnothing(swarm) && return nothing
    
    return Dict(
        "id" => swarm.id,
        "name" => swarm.name,
        "status" => string(swarm.status),
        "algorithm_type" => swarm.config.algorithm_type,
        "agent_count" => length(swarm.agents),
        "current_iteration" => swarm.current_iteration,
        "best_solution_fitness" => isnothing(swarm.best_solution_found) ? nothing : swarm.best_solution_found.fitness,
        "created_at" => string(swarm.created_at),
        "updated_at" => string(swarm.updated_at)
    )
end

# --- Placeholder functions for other swarm functionalities ---
# These would be expanded with actual logic.

function getSharedState(swarm_id::String, key::String, default=nothing)
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && return default
    return get(swarm.shared_data, key, default)
end

function updateSharedState!(swarm_id::String, key::String, value)
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && return false
    swarm.shared_data[key] = value
    swarm.updated_at = now(UTC)
    # TODO: Persist and potentially broadcast this change to swarm members
    return true
end

function electLeader(swarm_id::String; criteria_func=nothing)
    # Placeholder: Elects the first agent as leader
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && return nothing
    if isempty(swarm.agents)
        @warn "No agents in swarm $swarm_id to elect a leader."
        return nothing
    end
    leader_id = first(swarm.agents) # Simplistic leader election
    updateSharedState!(swarm_id, "leader_id", leader_id)
    @info "Agent $leader_id elected as leader for swarm $swarm_id."
    return leader_id
end

function allocateTask(swarm_id::String, task_details::Dict)
    swarm = getSwarm(swarm_id)
    isnothing(swarm) && return nothing
    task_id = "task-" * string(uuid4())
    task_details["id"] = task_id
    task_details["status"] = "pending"
    task_details["allocated_at"] = now(UTC)
    push!(swarm.task_queue, task_details)
    swarm.updated_at = now(UTC)
    @info "Task $task_id allocated to swarm $swarm_id."
    # TODO: Notify agents or leader about new task
    return task_id
end

function claimTask(swarm_id::String, task_id::String, agent_id::String)
    # Placeholder
    @info "Agent $agent_id claimed task $task_id in swarm $swarm_id (placeholder)."
    return true
end

function completeTask(swarm_id::String, task_id::String, agent_id::String, result::Any)
    # Placeholder
    @info "Agent $agent_id completed task $task_id in swarm $swarm_id with result (placeholder)."
    return true
end

function getSwarmMetrics(swarm_id::String)
    # Placeholder
    status = getSwarmStatus(swarm_id)
    isnothing(status) && return Dict("error" => "Swarm not found")
    # Add more metrics from AgentMetrics or specific algorithm performance
    return Dict(
        "status_summary" => status,
        "queue_length" => length(getSwarm(swarm_id).task_queue)
    )
end


# --- Module Initialization ---
function __init__()
    # Update config-dependent constants like SWARM_STORE_PATH
    # This assumes get_config is available and Config module is loaded.
    # If Swarms.jl is loaded before Agents.Config, this might use defaults.
    # It's better if the main application startup sequence ensures Config is loaded first.
    try
        SWARM_STORE_PATH[] = get_config("storage.swarm_path", DEFAULT_SWARM_STORE_PATH)
        SWARM_AUTO_PERSIST[] = get_config("storage.auto_persist_swarms", true)
        _ensure_storage_dir() # Ensure directory exists based on potentially updated path
    catch e
        @warn "Swarms __init__: Could not update config-dependent constants. Using defaults. Error: $e"
    end
    
    _register_default_objectives() # Register example objective functions
    _load_swarms_state() # Load persisted swarms
    @info "Swarms module initialized. $(length(SWARMS_REGISTRY)) swarms loaded. $(length(OBJECTIVE_FUNCTION_REGISTRY)) objective functions registered."
    # Note: Periodic persistence task for swarms is not implemented here,
    # unlike agents. Swarms are saved on critical state changes.
end

end # module Swarms
