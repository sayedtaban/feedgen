#!/bin/bash
# Copyright 2025 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#       http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Pre-flight Check ---
# Check if jq is installed, as it's required for parsing JSON output.
if ! command -v jq &> /dev/null
then
    echo "ERROR: The 'jq' command is not found. 'jq' is required to parse command output."
    echo "Please install it to continue. For example:"
    echo "  - On Debian/Ubuntu: sudo apt-get install jq"
    echo "  - On macOS: brew install jq"
    exit 1
fi

# --- Configuration ---
# Define the config file path.
CONFIG_FILE=".install.conf"

# Load existing config from the file, if it exists.
if [ -f "$CONFIG_FILE" ]; then
    echo "INFO - Loading configuration from $CONFIG_FILE..."
    source "$CONFIG_FILE"
fi

echo "Please provide the following information (press Enter to accept defaults):"

read -p "Project ID (textual name) [${PROJECT}]: " INPUT_PROJECT
PROJECT=${INPUT_PROJECT:-$PROJECT}

read -p "Location (e.g. \"eu\") [${LOCATION}]: " INPUT_LOCATION
LOCATION=${INPUT_LOCATION:-$LOCATION}

read -p "Dataset name [${DATASET}]: " INPUT_DATASET
DATASET=${INPUT_DATASET:-$DATASET}

read -p "Connection name [${CONNECTION}]: " INPUT_CONNECTION
CONNECTION=${INPUT_CONNECTION:-$CONNECTION}

# Save value in the config file for the next run.
echo "PROJECT='$PROJECT'" > "$CONFIG_FILE"
echo "LOCATION='$LOCATION'" >> "$CONFIG_FILE"
echo "DATASET='$DATASET'" >> "$CONFIG_FILE"
echo "CONNECTION='$CONNECTION'" >> "$CONFIG_FILE"


if [ -z "$PROJECT" ] || [ -z "$DATASET" ] || [ -z "$CONNECTION" ] || [ -z "$LOCATION" ]; then
  echo "Error: All parameters are required."
  exit 1
fi

echo "INFO - Setting GCP project to '$PROJECT'..."
gcloud config set project $PROJECT

echo "INFO - Creating BigQuery dataset '$DATASET'..."
# Use --quiet to suppress the success message and 2>/dev/null to suppress errors if it already exists.
bq --location=$LOCATION mk --dataset $PROJECT:$DATASET > /dev/null 2>/dev/null || echo "WARN - Dataset '$DATASET' already exists. Continuing..."

echo "INFO - Creating BigQuery connection '$CONNECTION'..."
bq mk --connection --location=$LOCATION --project_id=$PROJECT --connection_type=CLOUD_RESOURCE $CONNECTION > /dev/null 2>/dev/null || echo "WARN - Connection '$CONNECTION' already exists. Continuing..."

echo "INFO - Enabling the Vertex AI API..."
gcloud services enable aiplatform.googleapis.com --project=$PROJECT

echo "INFO - Granting permissions to the BigQuery connection's service account..."

SERVICEACCOUNT=$(bq --project_id=$PROJECT show --connection --format=json "$LOCATION.$CONNECTION" | jq -r '.cloudResource.serviceAccountId')

if [ -z "$SERVICEACCOUNT" ] || [ "$SERVICEACCOUNT" == "null" ]; then
  echo "ERROR - Could not determine service account for connection '$CONNECTION'. Exiting."
  exit 1
fi
echo "INFO - Found service account: $SERVICEACCOUNT"

# Grant the Vertex AI User role to the connection's service account.
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:$SERVICEACCOUNT" \
  --role="roles/aiplatform.user"

# Add a delay to allow IAM permissions to propagate.
echo "INFO - Waiting 20 seconds for IAM permissions to propagate..."
sleep 20

echo "INFO - Creating the Gemini remote model in BigQuery..."
MODEL_SQL="CREATE OR REPLACE MODEL \`$DATASET\`.GeminiFlash
  REMOTE WITH CONNECTION \`$PROJECT.$LOCATION.$CONNECTION\`
  OPTIONS (endpoint = 'gemini-2.5-flash');"

echo "$MODEL_SQL" | bq query --use_legacy_sql=false

echo "INFO - Installing stored functions and procedures..."
if [ -f "generation.sql" ]; then
  sed "s/\[DATASET\]/$DATASET/" generation.sql | bq query --use_legacy_sql=false
else
    echo "WARN - 'generation.sql' not found. Skipping this step."
fi


echo "INFO - Installation complete."

