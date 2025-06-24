from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.utils import new_agent_text_message
from typing_extensions import override
import juliaos

conn = juliaos.JuliaOSConnection("http://127.0.0.1:8052/api/v1")

class Add2Executor(AgentExecutor):
    @override
    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        jl_agent = juliaos.Agent.load(conn, "add2-agent")
        val = int(context.get_user_input())
        jl_agent.call_webhook({"value": val})
        result = jl_agent.get_logs()["logs"][-1]
        await event_queue.enqueue_event(new_agent_text_message(result))

    @override
    async def cancel(
        self,
        context: RequestContext,
        event_queue: EventQueue,
    ) -> None:
        raise Exception("cancel not supported")
