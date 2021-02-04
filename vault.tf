#############################################################################
# Ths configuration is for a single vault Node with storage account backend #
#############################################################################

data "azurerm_client_config" "current_config" {}


# Vault Resource Group
resource "azurerm_resource_group" "rg-vault-eu" {
  name     = "rg-vault-eu"
  location = "westeurope"
}
/*
# Managed Identity for Keyvault
resource "azurerm_user_assigned_identity" "vault-identity" {
  resource_group_name = azurerm_resource_group.rg-vault-eu.name
  location            = azurerm_resource_group.rg-vault-eu.location
  name                = "hashicorp-vault-identity"
}

# Azure Keyvault for Hashicorp Vault Key
module "kv-vault-eu" {
  source = "github.com/nfrappart/azTerraKeyvault?ref=v1.0.2"
  KeyVaultName = "kv-hashivault-${local.company}-eu"
  #KeyVaultLocation = "westeurope" #Optional. Default value is "westeurope"
  KeyVaultRgName = azurerm_resource_group.rg-vault-eu.name
  #KeyVaultSkuName = "standard" #Optional. Default value is "standard"
  KeyVaultTenantID = data.azurerm_client_config.current_config.tenant_id
  #KeyVaultEnabledforDeployment = "true" #Optional. Default is set to "true"
  #KeyVaultEnabledforDiskEncrypt = "true" #Optional. Default is set to "true"
  #KeyVaultEnabledforTempDeploy = "true" #Optional. Default is set to "true"
  ProvisioningDateTag = timestamp() #This Tag is configured to NOT be updated unless resource is destroyed
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
*/

#####################################
# Storage Account for Vault backend #
#####################################

variable "share-list" {
  default = [
    "file",
    "logs",
    "config",
  ]
}

resource "azurerm_storage_account" "vaultbackend" {
  name                     = "hashivault${local.company}"
  resource_group_name      = azurerm_resource_group.rg-vault-eu.name
  location                 = azurerm_resource_group.rg-vault-eu.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "vaultbackend-share" {
  for_each = toset(var.share-list)
  name                 = each.value
  storage_account_name = azurerm_storage_account.vaultbackend.name
  quota                = "50"
}
/*


resource "azurerm_storage_share_directory" "vaultbackend-share-dir" {
  for_each = toset(var.folderlist)
  name                 = each.value#"config"
  share_name           = azurerm_storage_share.vaultbackend-share.name
  storage_account_name = azurerm_storage_account.vaultbackend.name
}
*/

# Upload vault config 
resource "null_resource" "uploadvaultconfig" {
  provisioner "local-exec" {
    command = "az storage file upload --account-key '${azurerm_storage_account.vaultbackend.primary_access_key}' --account-name '${azurerm_storage_account.vaultbackend.name}' --share-name '${azurerm_storage_share.vaultbackend-share["config"].name}' --source config.hcl"
    #interpreter = ["Bash", "-Command"]
  }
  depends_on = [
    azurerm_storage_share.vaultbackend-share,
  ]
}

# Container Instance for Vault
resource "azurerm_container_group" "vault-ryzhom" {
  name                = "vault-ryzhom"
  location            = azurerm_resource_group.rg-vault-eu.location
  resource_group_name = azurerm_resource_group.rg-vault-eu.name
  ip_address_type     = "public"
  dns_name_label      = "vault-ryzhom"
  os_type             = "Linux"

  container {
    name   = "vault-ryzhom"
    image  = "vault:1.6.2"
    cpu    = "1"
    memory = "2"

    dynamic "volume" {
      for_each = toset(var.share-list)
      content {
        name = volume.value
        read_only = "false"
        share_name           = azurerm_storage_share.vaultbackend-share[volume.key].name
        storage_account_name = azurerm_storage_account.vaultbackend.name
        storage_account_key  = azurerm_storage_account.vaultbackend.primary_access_key
        mount_path           = "/vault/${volume.value}"
      }
    }
    ports {
      port     = "8200"
      protocol = "TCP"
    }
    
    commands = [
      "vault", "server", "-config=/vault/config/config.hcl" 
    ]
    /*
    environment_variables = {
      "VAULT_LOCAL_CONFIG" = "{\"backend\": {\"file\": {\"path\": \"/vault/file\"}}, \"default_lease_ttl\": \"168h\", \"max_lease_ttl\": \"720h\"}"
    }*/
  }
  depends_on = [
    azurerm_storage_share.vaultbackend-share,
    null_resource.uploadvaultconfig,
  ]
  
}

output "environment_variables" {
    value = <<EOF
export VAULT_ADDR="http://vault-ryzhom.${azurerm_resource_group.rg-vault-eu.location}.azurecontainer.io:8200"
export VAULT_SKIP_VERIFY=true
EOF
}

