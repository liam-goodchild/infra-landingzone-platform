resource "cloudflare_zone" "public" {
  for_each = local.cloudflare_dns_zones

  account = { id = var.cloudflare_account_id }
  name    = each.value.name
}

resource "cloudflare_zone_setting" "ssl" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "ssl"
  value      = "strict"
}

resource "cloudflare_zone_setting" "always_use_https" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "security_level" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "security_level"
  value      = "medium"
}

resource "cloudflare_zone_setting" "browser_check" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "browser_check"
  value      = "on"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  for_each = cloudflare_zone.public

  zone_id    = each.value.id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

resource "porkbun_nameservers" "cloudflare" {
  for_each    = cloudflare_zone.public
  domain      = each.key
  nameservers = [for ns in each.value.name_servers : trimsuffix(ns, ".")]
}
