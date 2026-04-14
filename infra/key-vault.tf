resource "azurerm_resource_group" "key_vault" {
  name     = "rg-kv-${local.resource_suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_key_vault" "main" {
  name                          = "kv-${local.resource_suffix}"
  resource_group_name           = azurerm_resource_group.key_vault.name
  location                      = azurerm_resource_group.key_vault.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_role_assignment" "key_vault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
