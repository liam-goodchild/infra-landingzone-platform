#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# create-oidc-service-principals.sh
#
# Creates service principals and Azure DevOps service connections with OIDC
# (Workload Identity Federation) for Terraform deployments.
# One SP and service connection per subscription scope.
#
# Prerequisites: az CLI, jq, az devops extension, authenticated session
#   az login
#   az extension add --name azure-devops
#
# Naming schema: spn-{scope}, sc-{scope}
###############################################################################

TENANT_ID="bcfa57b3-7ca9-479a-bd62-2d2894d69ee4"
ADO_ORG_NAME="SkyHavenLtd"
ADO_PROJECT="Azure Platform"
ROLE="Owner"                      # Owner required for Terraform to manage role assignments

declare -A SUBSCRIPTION_IDS=(
  ["platform"]="cefc8742-e1dd-4b24-90a9-07e3d3c80d88"
  ["personal"]="48a8b708-dc42-468f-97bc-fd949c073eb8"
  ["customer"]="1c26c084-763b-4d2d-86aa-af36b444b6bb"
)

declare -A SUBSCRIPTION_NAMES=(
  ["platform"]="Platform Subscription"
  ["personal"]="Personal Subscription"
  ["customer"]="Customer Subscription"
)

SCOPES=("platform" "personal" "customer")

###############################################################################

for SCOPE in "${SCOPES[@]}"; do
  SUB_ID="${SUBSCRIPTION_IDS[$SCOPE]}"
  SUB_NAME="${SUBSCRIPTION_NAMES[$SCOPE]}"
  SP_NAME="spn-${SCOPE}"
  SC_NAME="sc-${SCOPE}"

  echo "=== ${SCOPE} ==="
  echo "Service principal:  ${SP_NAME}"
  echo "Service connection: ${SC_NAME}"
  echo "Subscription:       ${SUB_ID}"
  echo ""

  # App registration
  echo "Creating app registration..."
  APP_ID=$(az ad app create \
    --display-name "$SP_NAME" \
    --query appId \
    --output tsv)
  echo "App ID: ${APP_ID}"

  # Service principal for the app
  echo "Creating service principal..."
  az ad sp create --id "$APP_ID" --output none

  # Role assignment on the target subscription
  echo "Assigning ${ROLE} on subscription..."
  az role assignment create \
    --assignee "$APP_ID" \
    --role "$ROLE" \
    --scope "/subscriptions/${SUB_ID}" \
    --output none

  # ADO service connection — WorkloadIdentityFederation scheme
  echo "Creating ADO service connection..."
  SC_RESPONSE=$(az rest \
    --method POST \
    --uri "https://dev.azure.com/${ADO_ORG_NAME}/${ADO_PROJECT}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" \
    --resource "499b84ac-1321-427f-aa17-267ca6975798" \
    --headers "Content-Type=application/json" \
    --body "{
      \"name\": \"${SC_NAME}\",
      \"type\": \"AzureRM\",
      \"authorization\": {
        \"scheme\": \"WorkloadIdentityFederation\",
        \"parameters\": {
          \"serviceprincipalid\": \"${APP_ID}\",
          \"tenantid\": \"${TENANT_ID}\"
        }
      },
      \"data\": {
        \"subscriptionId\": \"${SUB_ID}\",
        \"subscriptionName\": \"${SUB_NAME}\",
        \"environment\": \"AzureCloud\",
        \"scopeLevel\": \"Subscription\",
        \"creationMode\": \"Manual\"
      },
      \"serviceEndpointProjectReferences\": [
        {
          \"projectReference\": { \"name\": \"${ADO_PROJECT}\" },
          \"name\": \"${SC_NAME}\"
        }
      ]
    }")

  SC_ID=$(echo "$SC_RESPONSE"     | jq -r '.id')
  ISSUER=$(echo "$SC_RESPONSE"    | jq -r '.authorization.parameters.workloadIdentityFederationIssuer')
  SUBJECT=$(echo "$SC_RESPONSE"   | jq -r '.authorization.parameters.workloadIdentityFederationSubject')

  echo "Service connection ID: ${SC_ID}"
  echo "Federated issuer:      ${ISSUER}"
  echo "Federated subject:     ${SUBJECT}"

  # Federated credential on the app registration
  echo "Adding federated credential..."
  az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{
      \"name\": \"${SC_NAME}\",
      \"issuer\": \"${ISSUER}\",
      \"subject\": \"${SUBJECT}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none

  echo "Done."
  echo ""
done

echo "All service principals and service connections created successfully."
