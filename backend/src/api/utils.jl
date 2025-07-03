using ..Agents: Agent, agent_state_to_string, trigger_type_to_string

function summarize(
    agent::Agent,
)::AgentSummary
    return AgentSummary(
        agent.id,
        agent.name,
        agent.description,
        agent_state_to_string(agent.state),
        trigger_type_to_string(agent.trigger.type)
    )
end