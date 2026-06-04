# scripts/resolve_agent_card_url.py
import asyncio
import os
from pathlib import Path

import vertexai
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
    card = await agent.handle_authenticated_agent_card()
    card_url = f"{card.url}/v1/card"

    print(f"Agent: {card.name}")
    print(f"Card URL: {card_url}")

    # Write to restaurant_agent/.env
    # Write to both restaurant_agent/.env (for adk web) and root .env (for Cloud Run deploy)
    for env_path in [Path("restaurant_agent/.env"), Path(".env")]:
        lines = env_path.read_text().splitlines() if env_path.exists() else []
        lines = [l for l in lines if not l.startswith("RESERVATION_AGENT_CARD_URL=")]
        lines.append(f"RESERVATION_AGENT_CARD_URL={card_url}")
        env_path.write_text("\n".join(lines) + "\n")
        print(f"Written RESERVATION_AGENT_CARD_URL to {env_path}")


if __name__ == "__main__":
    asyncio.run(main())