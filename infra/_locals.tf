locals {
  resource_suffix      = "${var.workload}-${var.environment}-${var.location_short}-${var.instance}"
  resource_suffix_flat = "${var.workload}${var.environment}${var.location_short}${var.instance}"

  all_subscription_ids = toset(concat(
    var.management_group_subscriptions.platform,
    var.management_group_subscriptions.personal,
    var.management_group_subscriptions.customer
  ))

  cloudflare_dns_zones = { for z in var.dns_zones : z.name => z if z.cloudflare }

  tags = {
    managed-by = "terraform"
  }
}
