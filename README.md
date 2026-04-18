# infra-landingzone-platform

Terraform root module for the Sky Haven Azure landing zone platform layer. Provisions the management group hierarchy, hub networking, public DNS zones with Porkbun nameserver delegation and per-subscription consumption budgets. Deployed via Azure DevOps with OIDC authentication and remote state stored in Azure Storage.
