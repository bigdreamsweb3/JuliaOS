module Tools

export TOOL_REGISTRY

include("tool_example_adder.jl")
include("tool_example_telegram.jl")
include("tool_example_plan_and_execute.jl")

using ..CommonTypes: ToolSpecification

const TOOL_REGISTRY = Dict{String, ToolSpecification}()

function register_tool(tool_name::String, tool_spec::ToolSpecification)
    if haskey(TOOL_REGISTRY, tool_name)
        error("Tool with name '$tool_name' is already registered.")
    end
    TOOL_REGISTRY[tool_name] = tool_spec
end

# All tools to be used by agents must be registered here:

register_tool("adder", TOOL_EXAMPLE_ADDER_SPECIFICATION)
register_tool("detect_swearing", TOOL_DETECT_SWEAR_SPECIFICATION)
register_tool("ban_user", TOOL_BAN_USER_SPECIFICATION)
register_tool("ping", TOOL_PING_SPECIFICATION)
register_tool("llm_chat", TOOL_LLM_CHAT_SPECIFICATION)

end