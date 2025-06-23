from a2a.types import AgentCard, AgentSkill, AgentCapabilities

def make_agent_card(agent_id: str, port: int) -> AgentCard:
    skill_map = {
        "add2-agent": ("Add Two", "Adds +2 to input"),
    }

    name, desc = skill_map.get(agent_id, ("Unknown", "Unknown"))
    return AgentCard(
        name=f"{agent_id} agent",
        version="1.0",
        description=desc,
        url=f"http://127.0.0.1:{port}/{agent_id}/a2a",
        capabilities=AgentCapabilities(streaming=False),
        skills=[
            AgentSkill(
                id=agent_id,
                name=name,
                description=desc,
                tags=[]
            )
        ],
        defaultInputModes=["text/plain"],
        defaultOutputModes=["text/plain"],
    )
