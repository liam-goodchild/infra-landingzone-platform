#########################################
# Generic
#########################################
environment = "prd"
location    = "uksouth"
instance    = "01"

#########################################
# Management Group Subscription Associations
#########################################
management_group_subscriptions = {
  platform = ["<platform-subscription-id>"]
  personal = ["<personal-subscription-id>"]
  customer = []
}

#########################################
# Networking
#########################################
virtual_network = {
  address_space = "10.1.0.0/22"
  dns_servers   = []
}

subnets = [
  {
    name                           = "default"
    address_prefixes               = ["10.1.0.0/26"]
    network_security_group_enabled = false
    create_route_table             = false
  }
]

#########################################
# DNS
#########################################
dns_zones = [
  {
    name = "skyhaven.ltd"
  }
]
