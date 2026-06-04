#!/usr/bin/env bash
# ./telegram-integration/deploy.sh

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Color codes for neat terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;37m' # No Color
# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo -e "${GREEN}✔ Loading environment variables from .env...${NC}"
    export $(grep -v '^#' .env | xargs)
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Google Cloud Run Deployment: Telegram Bot        ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Check for gcloud CLI
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: 'gcloud' CLI is not installed.${NC}"
    echo "Please install the Google Cloud SDK and try again."
    echo "See: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# 2. Check active gcloud account/auth
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
if [ -z "$ACTIVE_ACCOUNT" ]; then
    echo -e "${RED}Error: No active Google Cloud account found.${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

# 3. Detect / Prompt for GCP Project
DEFAULT_PROJECT=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}
if [ -n "${DEFAULT_PROJECT}" ]; then
    echo -e "${GREEN}✔ Using GCP Project: $DEFAULT_PROJECT${NC}"
    GCP_PROJECT="$DEFAULT_PROJECT"
else
    echo -n "Enter GCP Project ID: "
    read -r GCP_PROJECT
fi

if [ -z "$GCP_PROJECT" ]; then
    echo -e "${RED}Error: GCP Project ID is required.${NC}"
    exit 1
fi

# Set active project
gcloud config set project "$GCP_PROJECT" &> /dev/null

# 4. Configure Service Parameters
DEFAULT_SERVICE=${SERVICE_NAME:-"telegram-integration"}
if [ -n "${SERVICE_NAME:-}" ]; then
    echo -e "${GREEN}✔ Using Cloud Run Service Name: $SERVICE_NAME${NC}"
else
    echo -n "Enter Cloud Run Service Name [Default: $DEFAULT_SERVICE]: "
    read -r SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE}
fi

DEFAULT_REGION=${REGION:-"us-central1"}
if [ -n "${REGION:-}" ]; then
    echo -e "${GREEN}✔ Using Cloud Run Region: $REGION${NC}"
else
    echo -n "Enter Cloud Run Region [Default: $DEFAULT_REGION]: "
    read -r REGION
    REGION=${REGION:-$DEFAULT_REGION}
fi

DEFAULT_ADK_APP=${ADK_APP_NAME:-"restaurant_agent"}
if [ -n "${ADK_APP_NAME:-}" ]; then
    echo -e "${GREEN}✔ Using ADK App Name: $ADK_APP_NAME${NC}"
    ADK_APP="$ADK_APP_NAME"
else
    echo -n "Enter ADK App Name [Default: $DEFAULT_ADK_APP]: "
    read -r ADK_APP
    ADK_APP=${ADK_APP:-$DEFAULT_ADK_APP}
fi

# 5. Retrieve/Prompt for Telegram Bot Token
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo -e "${GREEN}✔ Found TELEGRAM_BOT_TOKEN in environment.${NC}"
    BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
else
    echo -e "${YELLOW}TELEGRAM_BOT_TOKEN is not set in your environment.${NC}"
    echo -n "Enter your Telegram Bot Token (input will be hidden): "
    read -s -r BOT_TOKEN
    echo ""
fi

if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}Error: Telegram Bot Token is required.${NC}"
    exit 1
fi

# 6. Retrieve/Prompt for ADK Server URL
DEFAULT_ADK_URL="http://localhost:8000"
if [ -n "${ADK_SERVER_URL:-}" ]; then
    echo -e "${GREEN}✔ Found ADK_SERVER_URL in environment: $ADK_SERVER_URL${NC}"
    ADK_URL="$ADK_SERVER_URL"
else
    echo -n "Enter your ADK Server URL [Default: $DEFAULT_ADK_URL]: "
    read -r ADK_URL
    ADK_URL=${ADK_URL:-$DEFAULT_ADK_URL}
fi

# Enable required GCP services
echo -e "\n${YELLOW}Checking and enabling required GCP services...${NC}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project "$GCP_PROJECT"

# Determine source directory dynamically
SOURCE_DIR="."
if [ -d "telegram-integration" ]; then
    SOURCE_DIR="telegram-integration"
    echo -e "${GREEN}✔ Found source directory: telegram-integration${NC}"
elif [ -f "Dockerfile" ]; then
    SOURCE_DIR="."
    echo -e "${GREEN}✔ Dockerfile found in current directory. Using current directory as source.${NC}"
else
    echo -e "${RED}Error: Could not find source directory 'telegram-integration' or Dockerfile in current directory.${NC}"
    exit 1
fi

# 7. First-pass Deployment with placeholder SERVICE_URL
# This boots the container in Webhook mode (so health check binds to port)
# but uses a high-reliability placeholder URL (google.com) to pass DNS verification checks.
echo -e "\n${YELLOW}Deploying to Cloud Run (Step 1/2: Initial Deploy)...${NC}"
gcloud run deploy "$SERVICE_NAME" \
  --source "$SOURCE_DIR" \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-env-vars "IS_DEPLOYING=true,TELEGRAM_BOT_TOKEN=$BOT_TOKEN,ADK_SERVER_URL=$ADK_URL,ADK_APP_NAME=$ADK_APP,SERVICE_URL=https://google.com" \
  --project "$GCP_PROJECT"

# 8. Retrieve the actual service URL
echo -e "\n${YELLOW}Retrieving service URL...${NC}"
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project "$GCP_PROJECT" --format 'value(status.url)')
echo -e "${GREEN}✔ Service URL is: $SERVICE_URL${NC}"

# 9. Update service environment variables with the real SERVICE_URL
# This triggers a rolling update and registers the correct webhook with Telegram automatically!
echo -e "\n${YELLOW}Updating configuration with final Webhook URL (Step 2/2)...${NC}"
gcloud run services update "$SERVICE_NAME" \
  --region "$REGION" \
  --set-env-vars "TELEGRAM_BOT_TOKEN=$BOT_TOKEN,ADK_SERVER_URL=$ADK_URL,ADK_APP_NAME=$ADK_APP,SERVICE_URL=$SERVICE_URL" \
  --project "$GCP_PROJECT"

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}   Deployment Completed Successfully! 🎉            ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Service Name:   ${BLUE}$SERVICE_NAME${NC}"
echo -e "Region:         ${BLUE}$REGION${NC}"
echo -e "Active URL:     ${BLUE}$SERVICE_URL${NC}"
echo -e "Webhook Path:   ${BLUE}$SERVICE_URL/<bot-token>${NC}"
echo -e "ADK Backend:    ${BLUE}$ADK_URL${NC}"
echo -e "ADK App Name:   ${BLUE}$ADK_APP${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "Your Telegram Bot has been configured to use webhooks."
echo "Any message sent to your bot will now trigger this Cloud Run instance."don