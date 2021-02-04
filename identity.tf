# Managed Identity for Keyvault
resource "azurerm_user_assigned_identity" "vault-identity" {
  resource_group_name = azurerm_resource_group.rg-vault-eu.name
  location            = azurerm_resource_group.rg-vault-eu.location
  name                = "hashicorp-vault-identity"
}