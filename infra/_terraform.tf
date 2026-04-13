terraform {
  required_version = ">= 1.0, < 2.0"

  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
    porkbun = {
      source  = "kyswtn/porkbun"
      version = ">= 0.1.1"
    }
  }
}
