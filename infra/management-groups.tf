resource "azurerm_management_group" "platform" {
  display_name               = "Platform"
  name                       = "mg-platform"
  parent_management_group_id = data.azurerm_management_group.root.id
}

resource "azurerm_management_group" "personal" {
  display_name               = "Personal"
  name                       = "mg-personal"
  parent_management_group_id = data.azurerm_management_group.root.id
}

resource "azurerm_management_group" "customer" {
  display_name               = "Customer"
  name                       = "mg-customer"
  parent_management_group_id = data.azurerm_management_group.root.id
}

resource "azurerm_management_group_subscription_association" "platform" {
  for_each = toset(var.management_group_subscriptions.platform)

  management_group_id = azurerm_management_group.platform.id
  subscription_id     = "/subscriptions/${each.value}"
}

resource "azurerm_management_group_subscription_association" "personal" {
  for_each = toset(var.management_group_subscriptions.personal)

  management_group_id = azurerm_management_group.personal.id
  subscription_id     = "/subscriptions/${each.value}"
}

resource "azurerm_management_group_subscription_association" "customer" {
  for_each = toset(var.management_group_subscriptions.customer)

  management_group_id = azurerm_management_group.customer.id
  subscription_id     = "/subscriptions/${each.value}"
}
