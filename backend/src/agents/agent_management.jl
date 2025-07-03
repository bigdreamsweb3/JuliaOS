using .CommonTypes: Agent, AgentBlueprint, AgentContext, AgentState, InstantiatedTool, InstantiatedStrategy, CommonTypes

const AGENTS = Dict{String, Agent}()

function create_agent(
    id::String,
    name::String,
    description::String,
    blueprint::AgentBlueprint,
)::Agent
    # Check if the agent with the given ID already exists
    if haskey(AGENTS, id)
        error("Agent with ID '$id' already exists.")
    end

    # Instantiate tools from the blueprint
    tools = Vector{InstantiatedTool}()
    for tool_blueprint in blueprint.tools
        tool = instantiate_tool(tool_blueprint)
        push!(tools, tool)
    end

    # Create the agent context
    context = AgentContext(
        tools,
        Vector{String}()
    )

    # Create the instantiated strategy
    strategy = instantiate_strategy(blueprint.strategy)

    # Create the agent
    agent = Agent(
        id,
        name,
        description,
        context,
        strategy,
        blueprint.trigger,
        CommonTypes.CREATED_STATE
    )

    AGENTS[id] = agent

    initialize(agent)

    return agent
end

function delete_agent(
    id::String,
)::Nothing
    # Check if the agent with the given ID exists
    if !haskey(AGENTS, id)
        error("Agent with ID '$id' does not exist.")
    end

    # TODO: we currently have no mechanism of checking if the agent strategy is currently executing.

    # Remove the agent from the registry
    delete!(AGENTS, id)

    return nothing
end

function set_agent_state(
    agent::Agent,
    new_state::AgentState,
)
    # All transitions are allowed, except transitions to CREATED and transitions from STOPPED:
    if (agent.state == CommonTypes.STOPPED_STATE)
        error("Agent with ID '$(agent.id)' is already STOPPED.")
    elseif (new_state == CommonTypes.CREATED_STATE)
        error("Agents cannot be explicitly set to CREATED state.")
    end

    agent.state = new_state

    return nothing
end

function run(
    agent::Agent,
    input::Any=nothing,
)
    if agent.state != CommonTypes.RUNNING_STATE
        error("Agent with ID '$(agent.id)' is not in RUNNING state.")
    end

    @info "Executing strategy of agent $(agent.id)"
    strat = agent.strategy
    if strat.input_type === nothing
        return strat.run(strat.config, agent.context, input)
    else
        if isa(input, AbstractDict)
            input_any = Dict{String, Any}(input)
            input_obj = deserialize_object(strat.input_type, input_any)
        else
            error("run() for $(agent.id) expects JSON object matching $(strat.input_type)")
        end
        return strat.run(strat.config, agent.context, input_obj)
    end
end

function initialize(
    agent::Agent,
)
    if agent.state != CommonTypes.CREATED_STATE
        error("Agent with ID '$(agent.id)' is not in CREATED state.")
    end

    @info "Initializing strategy of agent $(agent.id)"
    if agent.strategy.initialize !== nothing
        return agent.strategy.initialize(agent.strategy.config, agent.context)
    else
        return nothing
    end
end