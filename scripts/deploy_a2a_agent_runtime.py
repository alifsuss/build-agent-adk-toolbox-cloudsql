# scripts/deploy_a2a_agent_runtime.py
import os
from pathlib import Path

import vertexai
from dotenv import load_dotenv
from google.genai import types
from vertexai.preview.reasoning_engines import A2aAgent

from reservation_agent.a2a_config import agent_card
from reservation_agent.executor import ReservationAgentExecutor

load_dotenv()

PROJECT_ID = os.environ["GOOGLE_CLOUD_PROJECT"]
REGION = os.environ["REGION"]
STAGING_BUCKET = os.environ.get("STAGING_BUCKET", f"{PROJECT_ID}-adk-a2a-agent-runtime")
BUCKET_URI = f"gs://{STAGING_BUCKET}"

a2a_agent = A2aAgent(
    agent_card=agent_card,
    agent_executor_builder=ReservationAgentExecutor,
)


def main():
    vertexai.init(project=PROJECT_ID, location=REGION, staging_bucket=BUCKET_URI)
    client = vertexai.Client(
        project=PROJECT_ID,
        location=REGION,
        http_options=types.HttpOptions(api_version="v1beta1"),
    )

    print("Deploying Reservation Agent to Agent Runtime...")
    print("This may take 3-5 minutes.")

    remote_agent = client.agent_engines.create(
        agent=a2a_agent,
        config={
            "display_name": agent_card.name,
            "description": agent_card.description,
            "requirements": [
                "google-cloud-aiplatform[agent_engines,adk]==1.149.0",
                "a2a-sdk==0.3.26",
                "google-adk==1.29.0",
                "cloudpickle",
                "pydantic"
            ],
            "extra_packages": [
                "./reservation_agent",
            ],
            "http_options": {
                "api_version": "v1beta1",
            },
            "staging_bucket": BUCKET_URI,
        },
    )

    resource_name = remote_agent.api_resource.name
    print(f"\nDeployment complete!")
    print(f"Resource name: {resource_name}")

    env_path = Path(".env")
    lines = env_path.read_text().splitlines() if env_path.exists() else []
    lines = [l for l in lines if not l.startswith("RESERVATION_AGENT_RESOURCE_NAME=")]
    lines.append(f"RESERVATION_AGENT_RESOURCE_NAME={resource_name}")
    env_path.write_text("\n".join(lines) + "\n")
    print("Written RESERVATION_AGENT_RESOURCE_NAME to .env")


if __name__ == "__main__":
    main()