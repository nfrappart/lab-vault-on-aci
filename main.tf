
provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      version = "~> 2.39.0"
    }
  }
}

data "azurerm_client_config" "current_config" {}

locals {
  company = "ryzhom"
}

# Vault Resource Group
resource "azurerm_resource_group" "rg-vault-eu" {
  name     = "rg-vault-eu"
  location = "westeurope"
}