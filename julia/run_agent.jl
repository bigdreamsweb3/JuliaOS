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

    #----------------------------------------------------------------------------------------------------------#
    println()
    println("#"^106)
    println()

    # create swarm
    objective_function = JuliaOS.JuliaOSFramework.Swarms.Swarms.get_objective_function_by_name("default_sum_objective")
    problem_def = JuliaOS.JuliaOSFramework.SwarmBase.OptimizationProblem(0, Vector{Tuple{Float64, Float64}}(), objective_function; is_minimization=true)
    config = JuliaOS.JuliaOSFramework.Swarms.SwarmConfig("TestSwarm", "PSO", problem_def; # Pass problem_def as positional argument
                                algorithm_params=Dict{String,Any}(),
                                objective_desc="Default Objective",
                                max_iter=100,
                                target_fit=nothing)
    swarm = JuliaOS.JuliaOSFramework.Swarms.createSwarm(config)
    @info "Sward $(swarm.id) created successfully"

    is_added = JuliaOS.JuliaOSFramework.Swarms.addAgentToSwarm(swarm.id, agent.id)
    @show is_added

    is_started = JuliaOS.JuliaOSFramework.Swarms.startSwarm(swarm.id)

    is_stopped = JuliaOS.JuliaOSFramework.Swarms.stopSwarm(swarm.id)
end

# Create and run a PlanAndExecute agent
function run_plan_execute_example()
    # First, we need to define some abilities to be used as tools
    # Here we're using the existing ping and llm_chat abilities, but you could create more specialized ones

    # Create a new agent to use with PlanAndExecute
    # Configure LLM parameters
    llm_config = Dict{String, Any}(
        "api_key" => ENV["OPENAI_API_KEY"],
        "api_base" => ENV["OPENAI_BASE_URL"],
        "model" => ENV["OPENAI_MODEL"],
        "temperature" => 0.7,
        "max_tokens" => 1024
    )

    plan_agent_cfg = JuliaOS.JuliaOSFramework.AgentCore.AgentConfig(
        "PlanExecuteAgent",
        JuliaOS.JuliaOSFramework.AgentCore.CUSTOM;
        abilities=["ping", "llm_chat"],
        parameters=Dict{String, Any}("demo" => true),
        llm_config=llm_config,  # Add LLM config
        memory_config=Dict{String, Any}(),
        queue_config=Dict{String, Any}(),
    )

    plan_agent = JuliaOS.JuliaOSFramework.Agents.createAgent(plan_agent_cfg)
    @info "PlanExecute Agent $(plan_agent.id) created successfully"

    # Start the agent
    JuliaOS.JuliaOSFramework.Agents.startAgent(plan_agent.id)
    @info "PlanExecute Agent $(plan_agent.id) started successfully"

    # Define tools for the PlanAndExecute agent
    tools = [
        Dict("name" => "Ping",
             "description" => "Simple ping tool to check if the system is responsive",
             "ability" => "ping"),
        Dict("name" => "LLMChat",
             "description" => "Ask the language model a question and get a response",
             "ability" => "llm_chat")
    ]

    # Create a PlanAndExecute agent
    @info "Creating PlanAndExecute agent"
    
    plan_execute_agent = JuliaOS.JuliaOSFramework.PlanAndExecute.create_plan_execute_agent(
        plan_agent.id,
        tools,
        llm_config  # Use the same LLM config
    )

    # Define a task for the agent to solve
    task = "First check if the system is responsive, then ask the language model what the capital of France is."

    # Run the PlanAndExecute agent
    @info "Running PlanAndExecute agent with task: $task"
    result = JuliaOS.JuliaOSFramework.PlanAndExecute.run_plan_execute_agent(plan_execute_agent, task)

    # Display the results
    @info "PlanAndExecute Execution Complete"
    @info "Success: $(result["success"])"
    @info "Steps Completed: $(result["steps_completed"]) / $(result["steps_count"])"
    @info "Execution Summary:\n$(result["execution_summary"])"
    @info "Final Answer: $(result["final_answer"])"

    # Stop the agent
    JuliaOS.JuliaOSFramework.Agents.stopAgent(plan_agent.id)
    @info "PlanExecute Agent $(plan_agent.id) stopped successfully"
end

# Create a streaming chat agent
function run_streaming_chat_example()
    # Configure LLM parameters
    llm_config = Dict{String, Any}(
        "provider" => "openai",
        "api_key" => ENV["OPENAI_API_KEY"],
        "api_base" => ENV["OPENAI_BASE_URL"],
        "model" => ENV["OPENAI_MODEL"],
        "temperature" => 0.7,
        "max_tokens" => 8092,
        "stream" => false  # Enable streaming output
    )

    # Create agent config
    chat_agent_cfg = JuliaOS.JuliaOSFramework.AgentCore.AgentConfig(
        "StreamingChatAgent",
        JuliaOS.JuliaOSFramework.AgentCore.CUSTOM;
        abilities=["llm_chat"],
        parameters=Dict{String, Any}("demo" => true),
        llm_config=llm_config,  # Add LLM config
        memory_config=Dict{String, Any}(),
        queue_config=Dict{String, Any}(),
    )

    # Create agent
    chat_agent = JuliaOS.JuliaOSFramework.Agents.createAgent(chat_agent_cfg)
    @info "Streaming Chat Agent $(chat_agent.id) created successfully"

    # Start agent
    JuliaOS.JuliaOSFramework.Agents.startAgent(chat_agent.id)
    @info "Streaming Chat Agent $(chat_agent.id) started successfully"

    # Execute chat task
    prompt = "Hello! Can you write a 1000-word essay for me? The topic is modernization!"
    @info "Start chat, input: $prompt"
    
    # Use streaming output
    result = JuliaOS.JuliaOSFramework.Agents.executeAgentTask(
        chat_agent.id, 
        Dict{String, Any}(
            "ability" => "llm_chat",
            "prompt" => prompt,
        )
    )
    
    # Handle streaming response
    @info "Start receiving streaming response..."
    if isa(result, Dict) && haskey(result, "answer")
        ch = result["answer"]
        for content in ch
            print(content)
            flush(stdout)
        end
        println()
    else
        @info "Received normal response"
        @show result
    end
    
    @info "Chat completed"

    # Stop agent
    JuliaOS.JuliaOSFramework.Agents.stopAgent(chat_agent.id)
    @info "Streaming Chat Agent $(chat_agent.id) stopped successfully"
end

# if abspath(PROGRAM_FILE) == @__FILE__
#     # main()
#     # run_plan_execute_example()
#     run_streaming_chat_example()
# end
run_streaming_chat_example()