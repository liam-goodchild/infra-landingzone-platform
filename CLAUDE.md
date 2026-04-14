# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Terraform root module for the Sky Haven Azure landing zone platform layer. Provisions management group hierarchy, hub networking (VNet, subnets, NSGs, route tables, network watcher), public DNS with Porkbun nameserver delegation, and per-subscription consumption budgets.

## Commands

### Local plan

Prerequisites: `az login`, `PORKBUN_API_KEY` and `PORKBUN_SECRET_API_KEY` exported.

```bash
./scripts/terraform-plan-local.sh
```

### Manual init + plan/apply

All Terraform commands run from `infra/`:

```bash
cd infra

terraform init \
  -backend-config="resource_group_name=rg-terrastate-prd-uks-01" \
  -backend-config="storage_account_name=stterrastateprduks01" \
  -backend-config="container_name=infra-landingzone-platform" \
  -backend-config="key=terraform.tfstate"

terraform plan  -var-file=vars/prd.tfvars
terraform apply -var-file=vars/prd.tfvars
```

### Bootstrap scripts (one-time, not Terraform-managed)

- `scripts/bootstrap-tfstate-backend.sh` — creates state storage accounts per environment
- `scripts/bootstrap-deployment-identities.sh` — creates OIDC service principals and ADO service connections

### Linting

CI uses Super-Linter via ADO pipeline templates from `liam-goodchild/pipeline-engineering-templates`. Checkov config at `.azuredevops/linters/.checkov.yaml` (skips `CKV_TF_1`).

### Documentation

terraform-docs auto-generates into `README.md` via `.terraform-docs.yml`. CI commits docs updates on PR branches.

## Architecture

### Naming convention

`{type}-{env}-uks-{instance}` via `local.resource_suffix`. No project prefix in resource names — the suffix is built from `var.environment`, hardcoded region short `uks`, and `var.instance`.

### Providers

- `hashicorp/azurerm ~> 4.68` — all Azure resources
- `kyswtn/porkbun ~> 0.1.3` — delegates NS records at Porkbun registrar to Azure DNS nameservers

Porkbun provider authenticates via `PORKBUN_API_KEY` and `PORKBUN_SECRET_API_KEY` env vars.

### State backend

Azure Storage with azurerm backend. Container name matches repo name (`infra-landingzone-platform`). Single state file covers all resources.

### Tfvars layout

Flat structure under `infra/vars/`:
- `globals.tfvars` — empty (reserved for cross-env shared values)
- `prd.tfvars` — production values (subscriptions, networking, DNS, budgets)

CI pipelines reference `vars/globals.tfvars` + `vars/uks/$(environmentCode).tfvars` (path differs between CI and current working tree — CI uses a region subfolder).

### CI/CD (Azure DevOps)

- `.azuredevops/ci-terraform.yaml` — PR pipeline: lint → terraform-docs → plan. Triggers on PRs to `main`.
- `.azuredevops/dev-terraform.yaml` — manual pipeline: plan/apply/destroy with environment selector. No auto-trigger.

Both pipelines use shared templates from `liam-goodchild/pipeline-engineering-templates` (GitHub) and service connection `sc-platform`. Porkbun secrets come from ADO variable group `porkbun-secrets`.

### Resource domains

| File | What it manages |
|------|----------------|
| `management-groups.tf` | Three MGs (Platform, Personal, Customer) under tenant root + subscription associations |
| `networking.tf` | Hub VNet, subnets (data-driven from `var.subnets`), NSGs, route tables, network watcher |
| `dns.tf` | Azure public DNS zones + Porkbun NS delegation |
| `budgets.tf` | £2/mo consumption budget per subscription with email alerts |

### Deployment identity model

Platform SP (`spn-platform`) has Owner on tenant root management group — required for MG and cross-subscription operations. Personal and customer SPs have Owner scoped to their respective subscriptions.
