##############################################################################
# This configuration is for a single vault Node with storage account backend #
##############################################################################


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

############################
# Upload vault config file #
############################

resource "null_resource" "uploadvaultconfig" {
  provisioner "local-exec" {
    command = "az storage file upload --account-key '${azurerm_storage_account.vaultbackend.primary_access_key}' --account-name '${azurerm_storage_account.vaultbackend.name}' --share-name '${azurerm_storage_share.vaultbackend-share["config"].name}' --source config.hcl"
    #interpreter = ["Bash", "-Command"]
  }
  depends_on = [
    azurerm_storage_share.vaultbackend-share,
  ]
}
################################
# Container Instance for Vault #
################################

resource "azurerm_container_group" "vault-ryzhom" {
  name                = "vault-ryzhom"
  location            = azurerm_resource_group.rg-vault-eu.location
  resource_group_name = azurerm_resource_group.rg-vault-eu.name
  ip_address_type     = "public"
  dns_name_label      = "vault-ryzhom"
  os_type             = "Linux"

  identity  {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.vault-identity.id,
    ]
  }

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
    environment_variables = {
      #"VAULT_LOCAL_CONFIG" = "{\"backend\": {\"file\": {\"path\": \"/vault/file\"}}, \"default_lease_ttl\": \"168h\", \"max_lease_ttl\": \"720h\"}",
      "AZURE_TENANT_ID" = data.azurerm_client_config.current_config.tenant_id,
      "VAULT_AZUREKEYVAULT_VAULT_NAME" = module.kv-vault-eu.Name,
      "VAULT_AZUREKEYVAULT_KEY_NAME" = azurerm_key_vault_key.hashivault-key.name,
    }
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

