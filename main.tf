
provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {}
  }
}

data "azurerm_client_config" "current_config" {}

locals {
  company = "bulma${random_integer.id.result}"
  vault-name = "vault-bulma${random_integer.id.result}"
}

resource "random_integer" "id" {
  min     = 100
  max     = 999
}

# Vault Resource Group
resource "azurerm_resource_group" "rg-vault-eu" {
  name     = "rg-vault-eu"
  location = "westeurope"
}