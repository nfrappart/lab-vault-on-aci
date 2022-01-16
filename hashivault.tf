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


###########################
# Create self signed cert #
###########################

resource "tls_private_key" "vault-tls-key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_self_signed_cert" "vault-tls-cert" {
  key_algorithm   = tls_private_key.vault-tls-key.algorithm
  private_key_pem = tls_private_key.vault-tls-key.private_key_pem

  validity_period_hours = 87600
  
  allowed_uses = [
      "key_encipherment",
      "digital_signature",
      "server_auth",
  ]

  dns_names = ["vault-${local.company}.${azurerm_resource_group.rg-vault-eu.location}.azurecontainer.io"]

  subject {
      common_name  = "vault-${local.company}.${azurerm_resource_group.rg-vault-eu.location}.azurecontainer.io"
      organization = "Capsule Corps."
  }
}

resource "local_file" "vault-key" {
    content     = tls_private_key.vault-tls-key.private_key_pem
    filename = "${path.module}/vault.key"
} 

resource "local_file" "vault-cert" {
    content     = tls_self_signed_cert.vault-tls-cert.cert_pem
    filename = "${path.module}/vault.crt"
} 

############################
# Upload vault config file #
############################

variable "filelist" {
  default = [
    "vault.key",
    "vault.crt",
    "config.hcl",
  ]
}

resource "null_resource" "uploadvaultconfig" {
  for_each = toset(var.filelist)
  provisioner "local-exec" {
    command = "az storage file upload --account-key '${azurerm_storage_account.vaultbackend.primary_access_key}' --account-name '${azurerm_storage_account.vaultbackend.name}' --share-name '${azurerm_storage_share.vaultbackend-share["config"].name}' --source ${each.value}" #config.hcl"
    #interpreter = ["Bash", "-Command"]
  }
  depends_on = [
    azurerm_storage_share.vaultbackend-share,
    local_file.vault-key,
    local_file.vault-cert,
  ]
}


################################
# Container Instance for Vault #
################################

resource "azurerm_container_group" "vault-aci" {
  name                = local.vault-name
  location            = azurerm_resource_group.rg-vault-eu.location
  resource_group_name = azurerm_resource_group.rg-vault-eu.name
  ip_address_type     = "public"
  dns_name_label      = local.vault-name
  os_type             = "Linux"

  identity  {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.vault-identity.id,
    ]
  }

  container {
    name   = local.vault-name
    image  = "vault:1.9.2"#"vault:1.6.2"
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
      "AZURE_TENANT_ID" = data.azurerm_client_config.current_config.tenant_id,
      "VAULT_AZUREKEYVAULT_VAULT_NAME" = module.kv-vault-eu.Name,
      "VAULT_AZUREKEYVAULT_KEY_NAME" = azurerm_key_vault_key.hashivault-key.name,
      "VAULT_SKIP_VERIFY" = true,
    }
  }
  depends_on = [
    azurerm_storage_share.vaultbackend-share,
    null_resource.uploadvaultconfig,
    azurerm_key_vault_key.hashivault-key,
  ]
  
}

output "To-Configure-Vault-Address" {
    value = "export VAULT_ADDR=https://${local.vault-name}.${azurerm_resource_group.rg-vault-eu.location}.azurecontainer.io:8200"
}

output "To-Ignore-SelfSigned-Certs" {
  value = "export VAULT_SKIP_VERIFY=true"
}

output "To-Initialize-Vault" {
  value = "vault operator init -recovery-shares=3 -recovery-threshold=2"
}

