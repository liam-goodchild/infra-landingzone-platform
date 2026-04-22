data "azurerm_client_config" "current" {}

data "azuread_service_principal" "personal" {
  display_name = "spn-personal"
}

data "azurerm_management_group" "root" {
  name = data.azurerm_client_config.current.tenant_id
}

data "azurerm_subscription" "all" {
  for_each        = local.all_subscription_ids
  subscription_id = each.value
}
