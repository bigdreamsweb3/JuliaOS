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
    println()

    # start agent
    is_started = JuliaOS.JuliaOSFramework.Agents.startAgent(agent.id)
    @info "Agent $(agent.id) started successfully"
    println()

    # pause agent
    is_paused = JuliaOS.JuliaOSFramework.Agents.pauseAgent(agent.id)
    @info "Agent $(agent.id) paused successfully"
    println()

    # get agent status
    status = JuliaOS.JuliaOSFramework.Agents.getAgentStatus(agent.id)
    @show status
    println()

    # resume agent
    is_resumed = JuliaOS.JuliaOSFramework.Agents.resumeAgent(agent.id)
    @info "Agent $(agent.id) resumed successfully"
    println()

    # execute ping task
    result = JuliaOS.JuliaOSFramework.Agents.executeAgentTask(agent.id, Dict{String, Any}("ability" => "ping"))
    @show result
    println()

    # execute llm chat task
    result = JuliaOS.JuliaOSFramework.Agents.executeAgentTask(agent.id, Dict{String, Any}("ability" => "llm_chat", "prompt" => "how are you?"))
    @show result
    println()

    # stop agent
    is_stopped = JuliaOS.JuliaOSFramework.Agents.stopAgent(agent.id)
    @info "Agent $(agent.id) stopped successfully"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end