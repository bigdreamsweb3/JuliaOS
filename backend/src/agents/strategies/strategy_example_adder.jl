# Example implementation of a strategy. The STRATEGY_EXAMPLE_ADDER_SPECIFICATION struct encapsulates the implementation and is the part added to the registry in Strategy.jl.

using ..CommonTypes: StrategyConfig, AgentContext, StrategySpecification

Base.@kwdef struct StrategyExampleAdderConfig <: StrategyConfig
    times_to_add::Int
end

function strategy_example_adder_initialization(cfg::StrategyExampleAdderConfig, ctx::AgentContext)
    push!(ctx.logs, "Initializing StrategyExampleAdder with times_to_add: $(cfg.times_to_add)")

    if cfg.times_to_add <= 0
        push!(ctx.logs, "ERROR: times_to_add must be a positive integer.")
        return
    end

    adder_tool_index = findfirst(tool -> tool.metadata.name == "adder", ctx.tools)
    if adder_tool_index === nothing
        push!(ctx.logs, "ERROR: Adder tool not found in context tools.")
        return
    end
end

function strategy_example_adder(cfg::StrategyExampleAdderConfig, ctx::AgentContext, input::Any)
    if !isa(input, Dict) || !haskey(input, "value") || !isa(input["value"], Int)
        push!(ctx.logs, "ERROR: Input must be a Dict with an integer \"value\" field.")
        return
    end

    value = input["value"]

    adder_tool_index = findfirst(tool -> tool.metadata.name == "adder", ctx.tools)
    if adder_tool_index === nothing
        push!(ctx.logs, "ERROR: Adder tool not found in context tools.")
        return
    end
    adder_tool = ctx.tools[adder_tool_index]

    for _ in 1:cfg.times_to_add
        value = adder_tool.execute(adder_tool.config, value)
        push!(ctx.logs, "Adder tool result: $value")
    end
end

const STRATEGY_EXAMPLE_ADDER_SPECIFICATION = StrategySpecification(
    strategy_example_adder,
    strategy_example_adder_initialization,
    StrategyExampleAdderConfig
)