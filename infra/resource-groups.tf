resource "azurerm_resource_group" "networking" {
  name     = "rg-netw-${local.resource_suffix}"
  location = var.location
  tags     = local.tags
}
