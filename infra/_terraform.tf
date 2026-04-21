terraform {
  required_version = "~> 1.14.8"

  backend "azurerm" {}

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.68.0"
    }
    porkbun = {
      source  = "kyswtn/porkbun"
      version = "~> 0.1.3"
    }
  }
}
