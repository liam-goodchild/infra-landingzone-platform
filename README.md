# infra-landingzone-platform

Terraform root module that provisions the platform layer of the Sky Haven Azure landing zone — management group hierarchy, hub networking, public DNS, Key Vault, and per-subscription consumption budgets.

## Usage

```bash
terraform init \
  -backend-config="resource_group_name=rg-tfs-platform-prd-uks-01" \
  -backend-config="storage_account_name=sttfsplatformprduks01" \
  -backend-config="container_name=infra-landingzone-platform" \
  -backend-config="key=terraform.tfstate"

terraform plan  -var-file=vars/prd.tfvars
terraform apply -var-file=vars/prd.tfvars
```

## Structure

```
infra/
├── _terraform.tf         # Required providers and backend
├── _providers.tf         # Provider configuration
├── _variables.tf         # Input variable declarations
├── _locals.tf            # Naming locals (resource_suffix, resource_suffix_flat)
├── _data.tf              # Data sources
├── management-groups.tf  # Management group hierarchy and subscription associations
├── networking.tf         # Hub VNet, subnets, NSGs, route tables, network watcher
├── dns.tf                # Public DNS zones and Porkbun nameserver delegation
├── key-vault.tf          # Key Vault with RBAC authorization
├── budgets.tf            # Per-subscription consumption budgets
└── vars/
    ├── globals.tfvars    # Shared variables (reserved)
    └── prd.tfvars        # Production values
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `workload` | Workload or platform layer name | `platform` |
| `environment` | Environment token | `prd` |
| `location` | Azure region | `uksouth` |
| `instance` | Two-digit instance number | `01` |
| `virtual_network` | VNet address space and DNS servers | see tfvars |
| `subnets` | Subnet definitions with NSG and route table options | see tfvars |
| `dns_zones` | Public DNS zones to create | `[{ name = "skyhaven.ltd" }]` |
| `management_group_subscriptions` | Subscription IDs per management group | see tfvars |
| `budget_contact_emails` | Email addresses for budget alerts | see tfvars |

### Naming Convention

Resources follow the pattern `{type}-{workload}-{env}-{region}-{index}`, computed from `local.resource_suffix`. Resources that prohibit hyphens (e.g. storage accounts) use `local.resource_suffix_flat`.

### Providers

| Provider | Purpose |
|----------|---------|
| `hashicorp/azurerm` `~> 4.68` | Azure infrastructure |
| `kyswtn/porkbun` `~> 0.1.3` | DNS nameserver delegation at Porkbun registrar |

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
