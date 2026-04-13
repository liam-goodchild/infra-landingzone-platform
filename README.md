# infra-landingzone-platform

Terraform root module that provisions the platform layer of the Sky Haven Azure landing zone — management group hierarchy, hub networking, and public DNS.

## Usage

```bash
terraform init \
  -backend-config="resource_group_name=<tfstate-rg>" \
  -backend-config="storage_account_name=<tfstate-st>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=landingzone-platform.tfstate"

terraform plan  -var-file="vars/globals.tfvars" -var-file="vars/uks/prd.tfvars"
terraform apply -var-file="vars/globals.tfvars" -var-file="vars/uks/prd.tfvars"
```

## Structure

```
infra/
├── _terraform.tf      # Required providers and backend
├── _providers.tf      # Provider configuration
├── _variables.tf      # Input variable declarations
├── _locals.tf         # Naming locals (name_suffix, name_flat)
├── _data.tf           # Data sources
├── management-groups.tf  # Management group hierarchy and subscription associations
├── networking.tf         # Hub VNet, subnets, NSGs, route tables, network watcher
├── dns.tf                # Public DNS zones and Porkbun nameserver delegation
└── vars/
    ├── globals.tfvars        # Shared variables (project)
    └── uks/
        └── prd.tfvars        # UK South production values
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project` | Project short name | `sh` |
| `environment` | Environment token | `prd` |
| `location` | Azure region | `uksouth` |
| `instance` | Two-digit instance number | `01` |
| `virtual_network` | VNet address space and DNS servers | see tfvars |
| `subnets` | Subnet definitions with NSG and route table options | see tfvars |
| `dns_zones` | Public DNS zones to create | `[{ name = "skyhaven.ltd" }]` |
| `management_group_subscriptions` | Subscription IDs per management group | see tfvars |

### Naming Convention

Resources follow the pattern `{type}-{project}-{environment}-{region}-{instance}`, computed from `local.name_suffix`. Resources that prohibit hyphens (storage accounts, container registries) use `local.name_flat`.

### Providers

| Provider | Purpose |
|----------|---------|
| `hashicorp/azurerm` `>= 4.0, < 5.0` | Azure infrastructure |
| `kyswtn/porkbun` `>= 0.1.1` | DNS nameserver delegation at Porkbun registrar |

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
