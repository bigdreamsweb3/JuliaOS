from .executors import Add2Executor
from .registry import register_agent

def register_all_agents():
    register_agent("add2-agent", Add2Executor)
