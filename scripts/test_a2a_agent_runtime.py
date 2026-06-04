# scripts/test_a2a_agent_runtime.py
import asyncio
import os
import time

import vertexai
from a2a.types import TaskState
from dotenv import load_dotenv
from google.genai import types

load_dotenv()

PROJECT_ID = os.environ["GOOGLE_CLOUD_PROJECT"]
REGION = os.environ["REGION"]
RESOURCE_NAME = os.environ["RESERVATION_AGENT_RESOURCE_NAME"]


async def main():
    vertexai.init(project=PROJECT_ID, location=REGION)
    client = vertexai.Client(
        project=PROJECT_ID, location=REGION,
        http_options=types.HttpOptions(api_version="v1beta1"),
    )

    agent = client.agent_engines.get(name=RESOURCE_NAME)

    # 1. Get agent card
    print("=" * 50)
    print("1. Retrieving agent card...")
    print("=" * 50)
    card = await agent.handle_authenticated_agent_card()
    print(f"Agent: {card.name}")
    print(f"URL: {card.url}")
    print(f"Skills: {[s.name for s in card.skills]}")

    # 2. Send a reservation request
    print("\n" + "=" * 50)
    print("2. Sending reservation request...")
    print("=" * 50)
    message_data = {
        "messageId": "msg-remote-001",
        "role": "user",
        "parts": [{"kind": "text", "text": "Book a table for 3 on Sunday at noon. Name: Carol, Phone: 555-0303"}],
    }
    response = await agent.on_message_send(**message_data)

    task_object = None
    for chunk in response:
        if isinstance(chunk, tuple) and len(chunk) > 0 and hasattr(chunk[0], "id"):
            task_object = chunk[0]
            break

    task_id = task_object.id
    print(f"Task ID: {task_id}")
    print(f"Status: {task_object.status.state}")

    # 3. Poll for result
    print("\n" + "=" * 50)
    print("3. Waiting for result...")
    print("=" * 50)
    result = None
    for _ in range(30):
        try:
            result = await agent.on_get_task(id=task_id)
            if result.status.state in [TaskState.completed, TaskState.failed]:
                break
        except Exception:
            pass
        time.sleep(1)

    print(f"Final status: {result.status.state}")
    if result.artifacts:
        for artifact in result.artifacts:
            if artifact.parts and hasattr(artifact.parts[0], "root") and hasattr(artifact.parts[0].root, "text"):
                print(f"Answer: {artifact.parts[0].root.text}")

    print("\n" + "=" * 50)
    print("Remote agent test passed!")
    print("=" * 50)


if __name__ == "__main__":
    asyncio.run(main())