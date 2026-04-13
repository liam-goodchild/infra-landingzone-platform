locals {
  locations = {
    uksouth = "uks"
    ukwest  = "ukw"
  }
  location_short = local.locations[var.location]

  name_suffix = "${var.environment}-${local.location_short}-${var.instance}"
  name_flat   = "${var.environment}${local.location_short}${var.instance}"
}
