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

# "managementgroup" = tenant root group (TENANT_ID); "subscription" = subscription scope
declare -A ROLE_ASSIGNMENT_SCOPES=(
  ["platform"]="managementgroup"
  ["personal"]="subscription"
  ["customer"]="subscription"
)

SCOPES=("platform" "personal" "customer")

###############################################################################

for SCOPE in "${SCOPES[@]}"; do
  SUB_ID="${SUBSCRIPTION_IDS[$SCOPE]}"
  SUB_NAME="${SUBSCRIPTION_NAMES[$SCOPE]}"
  SP_NAME="spn-${SCOPE}"
  SC_NAME="sc-${SCOPE}"
  FC_NAME="fc-${SCOPE}"

  echo "=== ${SCOPE} ==="
  echo "Service principal:  ${SP_NAME}"
  echo "Service connection: ${SC_NAME}"
  echo "Subscription:       ${SUB_ID}"
  echo ""

  # App registration (idempotent — reuse if exists)
  echo "Creating app registration..."
  EXISTING_APP_ID=$(az ad app list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null)
  if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" != "None" ]]; then
    APP_ID="$EXISTING_APP_ID"
    echo "App already exists, reusing App ID: ${APP_ID}"
  else
    APP_ID=$(az ad app create \
      --display-name "$SP_NAME" \
      --query appId \
      --output tsv)
    echo "App ID: ${APP_ID}"
  fi

  # Service principal for the app (idempotent)
  echo "Creating service principal..."
  if ! az ad sp show --id "$APP_ID" --output none 2>/dev/null; then
    az ad sp create --id "$APP_ID" --output none
  else
    echo "Service principal already exists, skipping."
  fi

  # Role assignment — scope varies per identity:
  #   managementgroup → tenant root group (landing zone deployments require this)
  #   subscription    → subscription scope
  # Note: az role assignment create --scope is broken on some CLI builds; use REST directly
  SP_OBJ_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
  if [[ "${ROLE_ASSIGNMENT_SCOPES[$SCOPE]}" == "managementgroup" ]]; then
    ARM_SCOPE="providers/Microsoft.Management/managementGroups/${TENANT_ID}"
    echo "Assigning ${ROLE} on tenant root management group..."
  else
    ARM_SCOPE="subscriptions/${SUB_ID}"
    echo "Assigning ${ROLE} on subscription..."
  fi

  ROLE_DEF_ID=$(az rest \
    --method GET \
    --uri "https://management.azure.com/${ARM_SCOPE}/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&\$filter=roleName eq '${ROLE}'" \
    --query "value[0].id" -o tsv)

  # Check for existing assignment at the correct scope AND role — not just any assignment
  EXISTING_ASSIGNMENT=$(az rest \
    --method GET \
    --uri "https://management.azure.com/${ARM_SCOPE}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&\$filter=principalId eq '${SP_OBJ_ID}'" \
    --query "value[?properties.roleDefinitionId=='${ROLE_DEF_ID}'] | [0].id" -o tsv 2>/dev/null)
  if [[ -n "$EXISTING_ASSIGNMENT" && "$EXISTING_ASSIGNMENT" != "None" ]]; then
    echo "Role assignment already exists, skipping."
  else
    ASSIGNMENT_GUID=$(powershell -Command "[guid]::NewGuid().ToString()" 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    az rest \
      --method PUT \
      --uri "https://management.azure.com/${ARM_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${ASSIGNMENT_GUID}?api-version=2022-04-01" \
      --body "{
        \"properties\": {
          \"roleDefinitionId\": \"${ROLE_DEF_ID}\",
          \"principalId\": \"${SP_OBJ_ID}\",
          \"principalType\": \"ServicePrincipal\"
        }
      }" \
      --output none
  fi

  # Storage Blob Data Contributor on both tfstate storage accounts
  # Required for Terraform to read/write state files via azurerm backend
  TFSTATE_ROLE="Storage Blob Data Contributor"
  TFSTATE_SUB="cefc8742-e1dd-4b24-90a9-07e3d3c80d88"
  TFSTATE_STORAGE_ACCOUNTS=(
    "rg-tfs-platform-prd-uks-01/sttfsplatformprduks01"
    "rg-tfs-platform-dev-uks-01/sttfsplatformdevuks01"
  )

  for SA_ENTRY in "${TFSTATE_STORAGE_ACCOUNTS[@]}"; do
    SA_RG="${SA_ENTRY%%/*}"
    SA_NAME="${SA_ENTRY##*/}"
    SA_SCOPE="subscriptions/${TFSTATE_SUB}/resourceGroups/${SA_RG}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"

    echo "Assigning ${TFSTATE_ROLE} on ${SA_NAME}..."

    SA_ROLE_DEF_ID=$(az rest \
      --method GET \
      --uri "https://management.azure.com/${SA_SCOPE}/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&\$filter=roleName eq '${TFSTATE_ROLE}'" \
      --query "value[0].id" -o tsv)

    SA_EXISTING=$(az rest \
      --method GET \
      --uri "https://management.azure.com/${SA_SCOPE}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&\$filter=principalId eq '${SP_OBJ_ID}'" \
      --query "value[?properties.roleDefinitionId=='${SA_ROLE_DEF_ID}'] | [0].id" -o tsv 2>/dev/null)

    if [[ -n "$SA_EXISTING" && "$SA_EXISTING" != "None" ]]; then
      echo "Role assignment already exists on ${SA_NAME}, skipping."
    else
      SA_ASSIGNMENT_GUID=$(powershell -Command "[guid]::NewGuid().ToString()" 2>/dev/null || cat /proc/sys/kernel/random/uuid)
      az rest \
        --method PUT \
        --uri "https://management.azure.com/${SA_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${SA_ASSIGNMENT_GUID}?api-version=2022-04-01" \
        --body "{
          \"properties\": {
            \"roleDefinitionId\": \"${SA_ROLE_DEF_ID}\",
            \"principalId\": \"${SP_OBJ_ID}\",
            \"principalType\": \"ServicePrincipal\"
          }
        }" \
        --output none
    fi
  done

  # ADO service connection — WorkloadIdentityFederation scheme
  # Note: az rest fails on Windows due to cp1252 encoding; az devops extension handles auth correctly
  echo "Creating ADO service connection..."
  EXISTING_SC=$(az devops service-endpoint list \
    --org "https://dev.azure.com/${ADO_ORG_NAME}" \
    --project "${ADO_PROJECT}" \
    --query "[?name=='${SC_NAME}'] | [0]" \
    --output json 2>/dev/null)
  if [[ -n "$EXISTING_SC" && "$EXISTING_SC" != "null" ]]; then
    echo "Service connection already exists, reusing."
    SC_RESPONSE="$EXISTING_SC"
  else
    SC_CONFIG=$(mktemp /tmp/sc-XXXXXX.json)
    cat > "$SC_CONFIG" << SCEOF
{
  "name": "${SC_NAME}",
  "type": "AzureRM",
  "authorization": {
    "scheme": "WorkloadIdentityFederation",
    "parameters": {
      "serviceprincipalid": "${APP_ID}",
      "tenantid": "${TENANT_ID}"
    }
  },
  "data": {
    "subscriptionId": "${SUB_ID}",
    "subscriptionName": "${SUB_NAME}",
    "environment": "AzureCloud",
    "scopeLevel": "Subscription",
    "creationMode": "Manual"
  },
  "serviceEndpointProjectReferences": [
    {
      "projectReference": { "name": "${ADO_PROJECT}" },
      "name": "${SC_NAME}"
    }
  ]
}
SCEOF
    SC_RESPONSE=$(az devops service-endpoint create \
      --service-endpoint-configuration "$SC_CONFIG" \
      --org "https://dev.azure.com/${ADO_ORG_NAME}" \
      --project "${ADO_PROJECT}" \
      --output json)
    rm -f "$SC_CONFIG"
  fi

  SC_ID=$(echo "$SC_RESPONSE"   | powershell -Command "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; \$input | ConvertFrom-Json | Select-Object -ExpandProperty id")
  ISSUER=$(echo "$SC_RESPONSE"  | powershell -Command "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; \$input | ConvertFrom-Json | Select-Object -ExpandProperty authorization | Select-Object -ExpandProperty parameters | Select-Object -ExpandProperty workloadIdentityFederationIssuer")
  SUBJECT=$(echo "$SC_RESPONSE" | powershell -Command "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; \$input | ConvertFrom-Json | Select-Object -ExpandProperty authorization | Select-Object -ExpandProperty parameters | Select-Object -ExpandProperty workloadIdentityFederationSubject")

  echo "Service connection ID: ${SC_ID}"
  echo "Federated issuer:      ${ISSUER}"
  echo "Federated subject:     ${SUBJECT}"

  # Federated credential on the app registration (idempotent)
  echo "Adding federated credential..."
  EXISTING_CRED=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='${FC_NAME}'] | [0].id" -o tsv 2>/dev/null)
  if [[ -n "$EXISTING_CRED" && "$EXISTING_CRED" != "None" ]]; then
    echo "Federated credential already exists, skipping."
  else
    az ad app federated-credential create \
      --id "$APP_ID" \
      --parameters "{
        \"name\": \"${FC_NAME}\",
        \"issuer\": \"${ISSUER}\",
        \"subject\": \"${SUBJECT}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
      }" \
      --output none
  fi

  echo "Done."
  echo ""
done

echo "All service principals and service connections created successfully."
