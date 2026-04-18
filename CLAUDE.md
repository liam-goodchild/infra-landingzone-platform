# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Terraform root module for the Sky Haven Azure landing zone platform layer. Provisions management group hierarchy, hub networking (VNet, subnets, NSGs, route tables, network watcher), public DNS with Porkbun nameserver delegation, and per-subscription consumption budgets.

## Commands

### Local plan

Prerequisites: `az login`, `PORKBUN_API_KEY` and `PORKBUN_SECRET_API_KEY` exported.

```bash
cd infra

terraform init \
  -backend-config="resource_group_name=rg-tfs-platform-prd-uks-01" \
  -backend-config="storage_account_name=sttfsplatformprduks01" \
  -backend-config="container_name=infra-landingzone-platform" \
  -backend-config="key=terraform.tfstate"

terraform plan  -var-file=vars/globals.tfvars -var-file=vars/prd.tfvars
terraform apply -var-file=vars/globals.tfvars -var-file=vars/prd.tfvars
```

### Bootstrap scripts (one-time, not Terraform-managed)

- `scripts/bootstrap-tfstate-backend.sh` — creates resource groups and storage accounts for Terraform remote state
- `scripts/bootstrap-deployment-identities.sh` — creates OIDC service principals and role assignments

### Linting

CI uses Super-Linter. Configs under `.github/workflows/linters/`: Checkov (`.checkov.yaml`), TFLint (`.tflint.hcl`), Prettier (`.prettierrc.json`).

## Architecture

### Naming convention

`{type}-{workload}-{env}-{region}-{index}` via `local.resource_suffix` (e.g. `vnet-platform-prd-uks-01`). Built from `var.workload`, `var.environment`, `var.location_short`, and `var.instance`. Flat variant `local.resource_suffix_flat` used for resources that disallow hyphens (e.g. storage accounts).

### Providers

- `hashicorp/azurerm ~> 4.68.0` — all Azure resources
- `kyswtn/porkbun ~> 0.1.3` — delegates NS records at Porkbun registrar to Azure DNS nameservers

Porkbun provider authenticates via `PORKBUN_API_KEY` and `PORKBUN_SECRET_API_KEY` env vars. In CI these come from the `prd` GitHub environment secrets.

### State backend

Azure Storage with azurerm backend. Resource group `rg-tfs-platform-prd-uks-01`, storage account `sttfsplatformprduks01`. Container name matches repo name (`infra-landingzone-platform`). Single state file covers all resources.

### Tfvars layout

Flat structure under `infra/vars/`:

- `globals.tfvars` — empty (reserved for cross-env shared values)
- `prd.tfvars` — production values (subscriptions, networking, DNS, budgets)

### CI/CD (GitHub Actions)

- `.github/workflows/linting.yml` — PR pipeline targeting `main`: Super-Linter only.
- `.github/workflows/terraform.yml` — plan/apply/destroy for `prd`. Auto-triggers on push to `major/**`, `minor/**`, `patch/**` branches (defaults to plan); manual dispatch allows selecting action. Uses `prd` GitHub environment for OIDC secrets.
- `.github/actions/ensure-tfstate-container/` — composite action: creates tfstate storage container if missing before init.
- `.github/actions/break-tfstate-lease/` — composite action: breaks blob lease on failed runs (always runs).

### Resource domains

| File                   | What it manages                                                                         |
| ---------------------- | --------------------------------------------------------------------------------------- |
| `management-groups.tf` | Three MGs (Platform, Personal, Customer) under tenant root + subscription associations  |
| `networking.tf`        | Hub VNet, subnets (data-driven from `var.subnets`), NSGs, route tables, network watcher |
| `dns.tf`               | Azure public DNS zones + Porkbun NS delegation                                          |
| `budgets.tf`           | £2/mo consumption budget per subscription with email alerts                             |

### Deployment identity model

Platform SP (`spn-platform`) has Owner on tenant root management group — required for MG and cross-subscription operations. Personal and customer SPs have Owner scoped to their respective subscriptions.
