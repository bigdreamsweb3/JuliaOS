using Pkg
Pkg.activate(".")

using DotEnv
DotEnv.load!()

using JuliaOS

function main()
    cfg = JuliaOS.JuliaOSFramework.AgentCore.AgentConfig(
        "TestAgent",
        JuliaOS.JuliaOSFramework.AgentCore.CUSTOM;
        abilities=["ping"],
        parameters=Dict{String, Any}("demo" => true),
        llm_config=Dict{String, Any}(),
        memory_config=Dict{String, Any}(),
        queue_config=Dict{String, Any}(), 
    )
    
    # create agent
    agent = JuliaOS.JuliaOSFramework.Agents.createAgent(cfg)
    @info "Agent $(agent.id) created successfully"

    # start agent
    has_started = JuliaOS.JuliaOSFramework.Agents.startAgent(agent.id)
    @info "Agent $(agent.id) started successfully"

    # execute ping task
    result = JuliaOS.JuliaOSFramework.Agents.executeAgentTask(agent.id, Dict{String, Any}("ability" => "ping"))
    @show result

    # execute llm chat task
    result = JuliaOS.JuliaOSFramework.Agents.executeAgentTask(agent.id, Dict{String, Any}("ability" => "llm_chat", "prompt" => "how are you?"))
    @show result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end