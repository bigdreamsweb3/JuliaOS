import asyncio
import uuid
import httpx

from a2a.client import A2AClient
from a2a.types import SendMessageRequest, MessageSendParams

AGENT_ID = "add2-agent"
BASE_URL = f"http://127.0.0.1:9100/{AGENT_ID}"

transport = httpx.AsyncHTTPTransport(
    local_address="0.0.0.0",
    retries=3
)

async def main():
    async with httpx.AsyncClient(transport=transport) as httpx_client:
        client = await A2AClient.get_client_from_agent_card_url(
            httpx_client, BASE_URL
        )
        text_msg = {
            "role": "user",
            "parts": [{"kind": "text", "text": "5"}],
            "messageId": uuid.uuid4().hex,
        }
        params = MessageSendParams(message=text_msg)
        request = SendMessageRequest(
            id=str(uuid.uuid4()),
            params=params
        )
        response = await client.send_message(request)
        print("Server replied →", response.root.result.parts[0].root.text)

if __name__ == "__main__":
    asyncio.run(main())
