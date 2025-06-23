import uvicorn
from starlette.applications import Starlette
from starlette.routing import Mount

from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore

from agents import register_all_agents
from agents.registry import get_executor
from agents.card import make_agent_card

AGENT_IDS = ["add2-agent"]
PORT = 9100

register_all_agents()

routes = []
for agent_id in AGENT_IDS:
    handler = DefaultRequestHandler(
        agent_executor=get_executor(agent_id),
        task_store=InMemoryTaskStore()
    )
    a2a_subapp = A2AStarletteApplication(
        agent_card=make_agent_card(agent_id, port=PORT),
        http_handler=handler
    ).build(rpc_url=f"/a2a")

    routes.append(Mount(f"/{agent_id}", app=a2a_subapp))

multi_agent_app = Starlette(routes=routes)


if __name__ == "__main__":
    uvicorn.run(multi_agent_app, host="127.0.0.1", port=PORT)
