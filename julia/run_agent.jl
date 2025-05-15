using Pkg
Pkg.activate(".")

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
    
    agent = JuliaOS.JuliaOSFramework.Agents.createAgent(cfg)
    @info "Agent $(agent.id) created successfully"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end