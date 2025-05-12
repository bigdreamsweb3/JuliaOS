# packages/templates/agents/custom_agent_template.jl
# Template for creating a custom agent in JuliaOS - Example: SimplePriceReporterAgent

"""
SimplePriceReporterAgentModule - An example agent that reports asset prices.

This agent periodically fetches the price of a configured asset pair using a specified
price feed provider and logs it. It also provides an ability to fetch the current
price on demand.
"""
module SimplePriceReporterAgentModule

# Import necessary components from JuliaOS and standard libraries.
# The exact `using` statements for JuliaOS modules depend on their final structure
# and how they are exposed to user-defined agent code.
using Dates
using Logging

# Conceptual imports from JuliaOS (actual paths/module names might vary)
# using JuliaOS.Agents # For Agent, AgentConfig, AgentStatus, AbstractAgentMemory, Schedule, etc.
# using JuliaOS.PriceFeed # For PriceFeed.get_latest_price, PriceFeed.PriceFeedConfig, PriceFeed.create_price_feed
# using JuliaOS.PriceFeed.PriceFeedBase # For PricePoint

# --- Define Agent Configuration ---
"""
Configuration for the SimplePriceReporterAgent.
"""
struct SimplePriceReporterAgentConfig
    asset_pair::String              # e.g., "BTC/USD"
    base_asset::String              # e.g., "BTC"
    quote_asset::String             # e.g., "USD"
    price_feed_provider::String     # e.g., "chainlink"
    price_feed_details::Dict{Symbol, Any} # Provider-specific config (e.g., chain_id, rpc_url for Chainlink)
    reporting_interval_seconds::Int # How often to report the price periodically
end

# --- Define Agent State ---
"""
Internal state for the SimplePriceReporterAgent.
This might be stored in the agent's memory.
"""
mutable struct SimplePriceReporterAgentState
    last_reported_price::Union{Float64, Nothing}
    last_report_time::Union{DateTime, Nothing}
    price_feed_instance::Any # Placeholder for a price feed client instance
    # Add other state variables if needed
end

# --- Agent Logic Implementation ---

"""
    initialize_simple_price_reporter_agent(agent_ref::Any, custom_config::SimplePriceReporterAgentConfig)

Initializes the SimplePriceReporterAgent.
`agent_ref` is the main Agent object from JuliaOS.Agents.
"""
function initialize_simple_price_reporter_agent(agent_ref::Any, custom_config::SimplePriceReporterAgentConfig)
    agent_id = getfield(agent_ref, :id) # Assuming agent_ref has an 'id' field
    agent_name = getfield(agent_ref, :name) # Assuming agent_ref has a 'name' field

    @info "Initializing SimplePriceReporterAgent ($(agent_id)): $(agent_name)" asset_pair=custom_config.asset_pair provider=custom_config.price_feed_provider

    # Initialize the price feed instance based on configuration.
    # This is a conceptual call; the actual PriceFeed API might differ.
    # pf_instance = try
    #     JuliaOS.PriceFeed.create_price_feed(
    #         custom_config.price_feed_provider,
    #         JuliaOS.PriceFeed.PriceFeedBase.PriceFeedConfig(;custom_config.price_feed_details...)
    #     )
    # catch e
    #     @error "Failed to initialize price feed for agent $(agent_id)" error=e
    #     nothing
    # end
    pf_instance = "SimulatedPriceFeedClient_$(custom_config.price_feed_provider)" # Placeholder

    initial_state = SimplePriceReporterAgentState(nothing, nothing, pf_instance)
    
    # Store the custom state. How this is done depends on JuliaOS.Agents design.
    # Option 1: Store in agent's generic parameters if it's a Dict
    # agent_ref.parameters["simple_price_reporter_state"] = initial_state
    # Option 2: Store in agent's memory
    # JuliaOS.Agents.setAgentMemory(agent_id, "simple_price_reporter_state", initial_state)
    # For this example, we'll assume the state is managed by the agent object itself or passed around.
    # A common pattern is for the agent's main struct to hold its specific state.
    # If not, the state would need to be retrieved from memory in other functions.
    
    # For simplicity in this template, we'll assume `agent_ref` can hold/access this state.
    # A more robust way is to use `setAgentMemory` and `getAgentMemory`.
    # Let's simulate storing it in a conceptual agent field:
    if !hasproperty(agent_ref, :custom_agent_specific_state)
         # This is highly conceptual, actual agent struct modification isn't done this way.
         # Typically, agent_ref.parameters or agent_ref.memory would be used.
        @warn "Agent object does not have :custom_agent_specific_state. State will be transient for this example."
    else
        setfield!(agent_ref, :custom_agent_specific_state, initial_state)
    end


    @info "SimplePriceReporterAgent ($(agent_id)) initialized."
end

"""
    get_agent_specific_state(agent_ref::Any)::Union{SimplePriceReporterAgentState, Nothing}
Helper to retrieve agent-specific state.
In a real system, this would use `JuliaOS.Agents.getAgentMemory`.
"""
function get_agent_specific_state(agent_ref::Any)
    # Conceptual: return getfield(agent_ref, :custom_agent_specific_state)
    # Using memory: return JuliaOS.Agents.getAgentMemory(getfield(agent_ref, :id), "simple_price_reporter_state")
    if hasproperty(agent_ref, :custom_agent_specific_state) && !isnothing(getfield(agent_ref, :custom_agent_specific_state))
        return getfield(agent_ref, :custom_agent_specific_state)
    end
    # Fallback for simulation if state isn't properly attached
    return SimplePriceReporterAgentState(nothing, nothing, "SimulatedPriceFeedClient_fallback")
end

"""
    update_agent_specific_state(agent_ref::Any, state::SimplePriceReporterAgentState)
Helper to update agent-specific state.
In a real system, this would use `JuliaOS.Agents.setAgentMemory`.
"""
function update_agent_specific_state(agent_ref::Any, state::SimplePriceReporterAgentState)
    # Conceptual: setfield!(agent_ref, :custom_agent_specific_state, state)
    # Using memory: JuliaOS.Agents.setAgentMemory(getfield(agent_ref, :id), "simple_price_reporter_state", state)
    if hasproperty(agent_ref, :custom_agent_specific_state)
         setfield!(agent_ref, :custom_agent_specific_state, state)
    end
end


"""
    report_price_periodically(agent_ref::Any)

Periodically fetches and logs the price of the configured asset.
This function would be registered as a scheduled "skill".
"""
function report_price_periodically(agent_ref::Any)
    agent_id = getfield(agent_ref, :id)
    agent_config = getfield(agent_ref, :config) # Assuming AgentConfig is stored in agent_ref.config
    # The custom_config (SimplePriceReporterAgentConfig) would typically be part of agent_config.parameters
    
    # Retrieve the specific config for this agent type
    # This assumes custom_config is stored in agent_ref.parameters["simple_price_reporter_config"]
    # custom_config = agent_config.parameters["simple_price_reporter_config"]::SimplePriceReporterAgentConfig
    
    # For template simplicity, let's assume custom_config is directly accessible or passed if this skill is called
    # For this example, let's simulate getting it from agent_ref if it were structured that way
    custom_config_params = get(getfield(agent_ref, :parameters, Dict()), "simple_price_reporter_config_params", Dict())
    
    # If custom_config_params is empty, use some defaults for simulation
    asset_pair_to_report = get(custom_config_params, "asset_pair", "BTC/USD")
    base_asset_to_report = get(custom_config_params, "base_asset", "BTC")
    quote_asset_to_report = get(custom_config_params, "quote_asset", "USD")
    
    state = get_agent_specific_state(agent_ref)
    if isnothing(state) || isnothing(state.price_feed_instance)
        @error "SimplePriceReporterAgent ($(agent_id)): State or price feed not initialized. Cannot report price."
        return
    end

    @info "SimplePriceReporterAgent ($(agent_id)): Fetching price for $(asset_pair_to_report) using $(state.price_feed_instance)..."
    
    current_price = try
        # Conceptual call to JuliaOS PriceFeed service
        # price_point = JuliaOS.PriceFeed.get_latest_price(state.price_feed_instance, custom_config.base_asset, custom_config.quote_asset)
        # price_point.price
        rand(20000.0:0.01:70000.0) # Simulated price for BTC/USD
    catch e
        @error "SimplePriceReporterAgent ($(agent_id)): Error fetching price for $(asset_pair_to_report)." error=e
        nothing
    end

    if !isnothing(current_price)
        state.last_reported_price = current_price
        state.last_report_time = now()
        update_agent_specific_state(agent_ref, state)
        @info "SimplePriceReporterAgent ($(agent_id)): Current price of $(asset_pair_to_report) is $(current_price). Reported at $(state.last_report_time)."
        # JuliaOS.Agents.AgentMetrics.record_metric(agent_id, "price_reported", current_price, tags=Dict("asset_pair"=>asset_pair_to_report))
    else
        @warn "SimplePriceReporterAgent ($(agent_id)): Could not retrieve price for $(asset_pair_to_report)."
    end
end

"""
    get_current_price_ability(agent_ref::Any, task_payload::Dict)

An "ability" that fetches and returns the current price on demand.
"""
function get_current_price_ability(agent_ref::Any, task_payload::Dict)
    agent_id = getfield(agent_ref, :id)
    # custom_config = getfield(agent_ref, :config).parameters["simple_price_reporter_config"]::SimplePriceReporterAgentConfig
    custom_config_params = get(getfield(agent_ref, :parameters, Dict()), "simple_price_reporter_config_params", Dict())
    asset_pair_to_report = get(custom_config_params, "asset_pair", "BTC/USD")
    base_asset_to_report = get(custom_config_params, "base_asset", "BTC")
    quote_asset_to_report = get(custom_config_params, "quote_asset", "USD")

    state = get_agent_specific_state(agent_ref)
    if isnothing(state) || isnothing(state.price_feed_instance)
        @error "SimplePriceReporterAgent ($(agent_id)): State or price feed not initialized. Cannot get price."
        return Dict("status"=>"error", "message"=>"Agent not properly initialized.")
    end

    @info "SimplePriceReporterAgent ($(agent_id)): Servicing on-demand price request for $(asset_pair_to_report)."
    
    current_price = try
        # price_point = JuliaOS.PriceFeed.get_latest_price(state.price_feed_instance, custom_config.base_asset, custom_config.quote_asset)
        # price_point.price
        rand(20000.0:0.01:70000.0) # Simulated price
    catch e
        @error "SimplePriceReporterAgent ($(agent_id)): Error fetching on-demand price for $(asset_pair_to_report)." error=e
        return Dict("status"=>"error", "message"=>"Error fetching price: $(sprint(showerror, e))", "asset_pair"=>asset_pair_to_report)
    end

    if !isnothing(current_price)
        # Optionally update state if this on-demand check should also count as a "report"
        # state.last_reported_price = current_price
        # state.last_report_time = now()
        # update_agent_specific_state(agent_ref, state)
        return Dict("status"=>"success", "asset_pair"=>asset_pair_to_report, "price"=>current_price, "timestamp"=>now())
    else
        return Dict("status"=>"error", "message"=>"Could not retrieve price.", "asset_pair"=>asset_pair_to_report)
    end
end

# --- Registration (Conceptual) ---
# This section shows how the agent's functions might be registered with JuliaOS.
# The actual registration API provided by `JuliaOS.Agents` may differ.

# function register_simple_price_reporter_agent_type()
#     # 1. Define how to initialize an agent of this type.
#     #    This might involve associating the `SimplePriceReporterAgentConfig` with an agent type name
#     #    and linking the `initialize_simple_price_reporter_agent` function.
#     #    JuliaOS.Agents.register_agent_initializer("SimplePriceReporter", initialize_simple_price_reporter_agent, SimplePriceReporterAgentConfig)
#
#     # 2. Register the periodic reporting function as a "skill".
#     #    The schedule would be derived from `SimplePriceReporterAgentConfig.reporting_interval_seconds`.
#     #    This registration might happen when an agent instance is created and configured.
#     #    Example: If an agent instance `my_reporter_agent` has its config, its skill would be:
#     #    reporting_interval = my_reporter_agent.config.parameters["simple_price_reporter_config"].reporting_interval_seconds
#     JuliaOS.Agents.register_skill(
#         "SimplePriceReporter.ReportPricePeriodically", # Unique skill name
#         report_price_periodically
#         # The schedule (e.g., `Schedule(:periodic, reporting_interval)`) would be set
#         # when an agent instance of this type is configured and started.
#     )
#
#     # 3. Register the on-demand price fetching as an "ability".
#     JuliaOS.Agents.register_ability(
#         "SimplePriceReporter.GetCurrentPrice", # Unique ability name
#         get_current_price_ability
#     )
#
#     @info "SimplePriceReporterAgent type, skills, and abilities conceptually registered."
# end

# This registration would typically be called once during application setup if JuliaOS
# doesn't auto-discover modules in the templates directory.
# register_simple_price_reporter_agent_type()

@info "SimplePriceReporterAgentModule template loaded. Define and register your agent logic."

end # module SimplePriceReporterAgentModule
