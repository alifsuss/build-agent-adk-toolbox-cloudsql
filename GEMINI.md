# Gemini ADK - Restaurant Agent

This project implements a conversational AI agent for a restaurant called "Foodie Finds". The agent can help users browse the menu, get details on specific dishes, and make reservations.

## Project Overview

The project consists of two main agents:

*   **Restaurant Agent (`root_agent`):** The primary agent that handles user interactions. It can search the menu, provide details about dishes, and recommend items based on user preferences.
*   **Reservation Agent (`reservation_remote_agent`):** A remote agent that is responsible for handling all aspects of table reservations, including creating, checking, and canceling bookings.

The Restaurant Agent uses a set of tools defined in `tools.yaml` to interact with a Cloud SQL for PostgreSQL database that stores the menu information. It also leverages a Gemini embedding model for semantic search capabilities.

## Key Components

*   **`restaurant_agent/`:** Contains the code for the main Restaurant Agent.
*   **`reservation_agent/`:** Contains the code for the Reservation Agent.
*   **`tools.yaml`:** Defines the tools used by the Restaurant Agent to query the database.
*   **`Dockerfile`:** Used to containerize and deploy the application.
*   **`scripts/`:** Contains various utility scripts for testing, deployment, and database setup.

## Running the Application

### Using Docker

The application can be run as a container using Docker.

1.  **Build the Docker image:**
    ```bash
    docker build -t restaurant-agent .
    ```

2.  **Run the Docker container:**
    ```bash
    docker run -p 8080:8080 -e GOOGLE_CLOUD_PROJECT=<your-gcp-project> -e ... <other-env-vars> restaurant-agent
    ```
    The agent will be accessible on port 8080.

### Local Testing

The `reservation_agent` can be tested locally using the `test_a2a_agent_local.py` script.

1.  **Install dependencies:**
    ```bash
    uv sync
    ```

2.  **Set up the required environment variables** in a `.env` file (see below).

3.  **Run the test script:**
    ```bash
    uv run python scripts/test_a2a_agent_local.py
    ```

## Environment Variables

The application requires the following environment variables to be set:

*   `GOOGLE_CLOUD_PROJECT`: Your Google Cloud project ID.
*   `GOOGLE_CLOUD_LOCATION`: The Google Cloud location for the embedding model (e.g., `us-central1`).
*   `REGION`: The region for the Cloud SQL instance.
*   `DB_INSTANCE`: The name of the Cloud SQL instance.
*   `DB_NAME`: The name of the database.
*   `DB_PASSWORD`: The password for the database user.
*   `TOOLBOX_URL`: The URL for the Toolbox service (defaults to `http://127.0.0.1:5000`).
*   `RESERVATION_AGENT_CARD_URL`: The URL for the Reservation Agent's card.

## Development Conventions

*   Dependencies are managed using `uv`. Use `uv sync` to install dependencies from `uv.lock`.
*   The application is served using the `adk web` command.
