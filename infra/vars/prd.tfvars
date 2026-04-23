#########################################
# Management Group Subscription Associations
#########################################
management_group_subscriptions = {
  platform = ["cefc8742-e1dd-4b24-90a9-07e3d3c80d88"]
  personal = ["48a8b708-dc42-468f-97bc-fd949c073eb8"]
  customer = ["1c26c084-763b-4d2d-86aa-af36b444b6bb"]
}

#########################################
# Subscription Budgets
#########################################

budget_contact_emails = ["liamgoodchild12@hotmail.co.uk"]

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
    name       = "skyhaven.ltd"
    cloudflare = true
  }
]
