module Strategies

export STRATEGY_REGISTRY

include("strategy_example_adder.jl")
include("strategy_plan_and_execute.jl")
include("telegram/strategy_moderator.jl")
include("telegram/strategy_support.jl")
include("strategy_ai_news_scraping.jl")

using ..CommonTypes: StrategySpecification

const STRATEGY_REGISTRY = Dict{String, StrategySpecification}()

function register_strategy(strategy_name::String, strategy_spec::StrategySpecification)
    if haskey(STRATEGY_REGISTRY, strategy_name)
        error("Strategy with name '$strategy_name' is already registered.")
    end
    STRATEGY_REGISTRY[strategy_name] = strategy_spec
end

# All strategies to be used by agents must be registered here:

register_strategy("adder", STRATEGY_EXAMPLE_ADDER_SPECIFICATION)
register_strategy("plan_execute", STRATEGY_PLAN_AND_EXECUTE_SPECIFICATION)
register_strategy("telegram_moderator", STRATEGY_TELEGRAM_MODERATOR_SPECIFICATION)
register_strategy("support", STRATEGY_SUPPORT_SPECIFICATION)
register_strategy("ai_news_scraping", STRATEGY_AI_NEWS_SCRAPING_SPECIFICATION)

end