resource "azurerm_role_assignment" "personal_sp_dns_zone_contributor" {
  scope                = azurerm_resource_group.dns.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = var.personal_sp_object_id
}
