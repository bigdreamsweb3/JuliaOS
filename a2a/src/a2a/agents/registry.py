from typing import Dict, Type
from a2a.server.agent_execution import AgentExecutor

AGENT_REGISTRY: Dict[str, Type[AgentExecutor]] = {}

def register_agent(agent_id: str, executor_cls: Type[AgentExecutor]):
    AGENT_REGISTRY[agent_id] = executor_cls

def get_executor(agent_id: str) -> AgentExecutor:
    executor_cls = AGENT_REGISTRY.get(agent_id)
    if not executor_cls:
        raise ValueError(f"No executor registered for agent ID: {agent_id}")
    return executor_cls()
