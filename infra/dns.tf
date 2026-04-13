resource "azurerm_resource_group" "dns" {
  name     = "rg-dns-${local.name_suffix}"
  location = var.location
}

resource "azurerm_dns_zone" "public" {
  for_each = { for z in var.dns_zones : z.name => z }

  name                = each.value.name
  resource_group_name = azurerm_resource_group.dns.name
}

resource "porkbun_nameservers" "domain_ns" {
  for_each    = azurerm_dns_zone.public
  domain      = each.key
  nameservers = each.value.name_servers
}
