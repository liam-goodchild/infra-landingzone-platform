resource "azurerm_consumption_budget_subscription" "all" {
  for_each        = local.all_subscription_ids
  name            = "${replace(lower(data.azurerm_subscription.all[each.key].display_name), " ", "-")}-budget"
  subscription_id = "/subscriptions/${each.value}"
  amount          = 2
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-04-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 10
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }
}

