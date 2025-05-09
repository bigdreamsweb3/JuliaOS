# backend-julia/src/api/MetricsHandlers.jl
module MetricsHandlers

using HTTP
using ..Utils # For standardized responses
import ..agents.AgentMetrics # Assuming AgentMetrics provides the core logic
import ..agents.Agents # To check agent existence

function get_all_metrics_handler(req::HTTP.Request)
    try
        # In a real implementation, AgentMetrics.get_all_system_metrics() would be called
        # For now, returning a placeholder
        all_metrics = Dict(
            "system_cpu_usage" => rand(),
            "system_memory_usage" => rand() * 100,
            "active_agents" => length(keys(Agents.AGENTS)), # Example, needs proper access
            "total_tasks_processed" => rand(100:1000)
        ) # Placeholder
        return Utils.json_response(all_metrics)
    catch e
        @error "Error in get_all_metrics_handler" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to retrieve all metrics", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function reset_all_metrics_handler(req::HTTP.Request)
    try
        # In a real implementation, AgentMetrics.reset_all_system_metrics!() would be called
        # Placeholder action
        @info "All system metrics reset (placeholder action)."
        return Utils.json_response(Dict("message" => "All system metrics reset successfully"), 200)
    catch e
        @error "Error in reset_all_metrics_handler" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to reset all metrics", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function get_agent_metrics_handler(req::HTTP.Request, agent_id::String)
    if isempty(agent_id)
        return Utils.error_response("Agent ID cannot be empty", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT, details=Dict("field"=>"agent_id"))
    end
    try
        # Check if agent exists first (optional, depends on AgentMetrics behavior)
        # agent = Agents.getAgent(agent_id) 
        # if isnothing(agent)
        #     return Utils.error_response("Agent not found", 404, error_code=Utils.ERROR_CODE_NOT_FOUND, details=Dict("agent_id"=>agent_id))
        # end

        # In a real implementation, AgentMetrics.get_metrics_for_agent(agent_id)
        agent_metrics = AgentMetrics.get_agent_metrics(agent_id) # Assuming this function exists and handles not found
        
        if isempty(agent_metrics) # Or some other indicator of "not found" from AgentMetrics
             # This check depends on what get_agent_metrics returns for a non-existent/untracked agent
            if isnothing(Agents.getAgent(agent_id)) # Confirm agent doesn't exist at all
                 return Utils.error_response("Agent not found, so no metrics available.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND, details=Dict("agent_id"=>agent_id))
            else # Agent exists, but no metrics (e.g. recently created or metrics disabled)
                 return Utils.json_response(Dict("message"=> "No metrics found for agent $agent_id, or metrics might be disabled.", "agent_id"=>agent_id, "metrics" => Dict()), 200)
            end
        end
        return Utils.json_response(agent_metrics)
    catch e
        @error "Error in get_agent_metrics_handler for agent $agent_id" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to retrieve metrics for agent $agent_id", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function reset_agent_metrics_handler(req::HTTP.Request, agent_id::String)
    if isempty(agent_id)
        return Utils.error_response("Agent ID cannot be empty", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT, details=Dict("field"=>"agent_id"))
    end
    try
        # Check if agent exists first
        agent = Agents.getAgent(agent_id) 
        if isnothing(agent)
            return Utils.error_response("Agent not found, cannot reset metrics.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND, details=Dict("agent_id"=>agent_id))
        end

        AgentMetrics.reset_metrics(agent_id) # Assuming this function exists
        @info "Metrics reset for agent $agent_id."
        return Utils.json_response(Dict("message" => "Metrics for agent $agent_id reset successfully"), 200)
    catch e
        @error "Error in reset_agent_metrics_handler for agent $agent_id" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to reset metrics for agent $agent_id", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

end
