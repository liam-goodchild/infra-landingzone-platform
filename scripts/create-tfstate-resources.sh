#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# create-tfstate-resources.sh
#
# Creates resource groups and storage accounts for Terraform remote state.
# These resources are intentionally not managed by Terraform (bootstrap).
#
# Naming schema: {type}-{workload}-{env}-{region}-{index}
###############################################################################

SUBSCRIPTION="cefc8742-e1dd-4b24-90a9-07e3d3c80d88"
WORKLOAD="terrastate"
LOCATION="uksouth"
LOCATION_SHORT="uks"
INSTANCE="01"
CONTAINER_NAME="tfstate"

ENVIRONMENTS=("prd" "dev")

for ENV in "${ENVIRONMENTS[@]}"; do
  RG_NAME="rg-${WORKLOAD}-${ENV}-${LOCATION_SHORT}-${INSTANCE}"
  ST_NAME="st${WORKLOAD}${ENV}${LOCATION_SHORT}${INSTANCE}"

  echo "=== ${ENV} ==="
  echo "Resource group:  ${RG_NAME}"
  echo "Storage account: ${ST_NAME}"
  echo ""

  # Resource group
  echo "Creating resource group ${RG_NAME}..."
  az group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --subscription "$SUBSCRIPTION" \
    --output none

  # Storage account
  echo "Creating storage account ${ST_NAME}..."
  az storage account create \
    --name "$ST_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --https-only true \
    --subscription "$SUBSCRIPTION" \
    --output none

  # Enable blob versioning and soft delete for state protection
  echo "Enabling blob versioning and soft delete..."
  az storage account blob-service-properties update \
    --account-name "$ST_NAME" \
    --resource-group "$RG_NAME" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --enable-container-delete-retention true \
    --container-delete-retention-days 30 \
    --subscription "$SUBSCRIPTION" \
    --output none

  # State container
  echo "Creating blob container ${CONTAINER_NAME}..."
  az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$ST_NAME" \
    --auth-mode login \
    --subscription "$SUBSCRIPTION" \
    --output none

  echo "Done."
  echo ""
done

echo "All resources created successfully."
echo ""
echo "Terraform backend configuration:"
echo ""
for ENV in "${ENVIRONMENTS[@]}"; do
  ST_NAME="st${WORKLOAD}${ENV}${LOCATION_SHORT}${INSTANCE}"
  RG_NAME="rg-${WORKLOAD}-${ENV}-${LOCATION_SHORT}-${INSTANCE}"
  cat <<EOF
  # ${ENV}
  backend "azurerm" {
    resource_group_name  = "${RG_NAME}"
    storage_account_name = "${ST_NAME}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "<stack>.tfstate"
  }

EOF
done