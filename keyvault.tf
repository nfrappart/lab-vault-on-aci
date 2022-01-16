# Azure Keyvault for Hashicorp Vault Key
module "kv-vault-eu" {
  source = "github.com/nfrappart/azTerraKeyvault?ref=v1.0.6"
  Name = "kv-${local.company}"
  RgName = azurerm_resource_group.rg-vault-eu.name
  TenantID = data.azurerm_client_config.current_config.tenant_id
}

# Access to vault for managed identity
resource "azurerm_key_vault_access_policy" "vault-identity-kvpolicy" {
  key_vault_id = module.kv-vault-eu.Id
  tenant_id    = data.azurerm_client_config.current_config.tenant_id
  object_id    = azurerm_user_assigned_identity.vault-identity.principal_id

  key_permissions = [
    "get","list","create","delete","update","wrapKey","unwrapKey",
  ]

  secret_permissions = [
    "get",
  ]
}

# Create key for Vault
resource "azurerm_key_vault_key" "hashivault-key" {
  name         = "hashivault-key"
  key_vault_id = module.kv-vault-eu.Id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  depends_on = [
    module.kv-vault-eu,
  ]
}