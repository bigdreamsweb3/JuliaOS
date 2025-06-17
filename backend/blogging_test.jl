using Pkg
Pkg.activate(".")

using JuliaOSBackend.Agents
using JuliaOSBackend.Agents.CommonTypes: AgentBlueprint, ToolBlueprint, StrategyBlueprint, TriggerConfig, WebhookTriggerParams

function main()
    @info "Supported tools:"
    for (name, spec) in Agents.Tools.TOOL_REGISTRY
        @info " - $name: $spec"
    end
    @info "Supported strategies:"
    for (name, spec) in Agents.Strategies.STRATEGY_REGISTRY
        @info " - $name: $spec"
    end

    tool_blueprints = [
        ToolBlueprint("write_blog", Dict()),
    ]
    strategy_config = Dict()

    blog_writer_blueprint = AgentBlueprint(
        tool_blueprints,
        StrategyBlueprint("blogger", strategy_config),
        TriggerConfig(Agents.CommonTypes.WEBHOOK_TRIGGER, WebhookTriggerParams())
    )
    
    blog_writer_agent = Agents.create_agent("blog_writer_agent", blog_writer_blueprint)
    @info "Created blogger agent: $blog_writer_agent"

    @info "Existing agents:"
    for (name, agent) in Agents.AGENTS
        @info " - $name: $agent"
    end

    Agents.set_agent_state(blog_writer_agent, Agents.CommonTypes.RUNNING_STATE)
    @info "plan_execute_agent is now RUNNING"

    task = Dict{String, Any}(
        "title" => "My favourite Julia features",
        "tone" => "informal",
        "length" => "long",
        "output_format" => "plain"
    )

    @info "Running Blogger agent with task: $task"
    Agents.run(blog_writer_agent, task)

    @info "Agent logs after sample runs:"
    for log in blog_writer_agent.context.logs
        @info " - $log"
    end

    @info "Existing agents at the end:"
    for (name, agent) in Agents.AGENTS
        @info " - $name: $agent"
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end