# lab-vault-on-aci
Terraform code to deploy Hashicorp Vault in an Azure Container Instance - for testing purposes
This project was made possible thanks to Ned Bellavence who made somthing similar. The intent here was to do everthing out of terraform, whereas Ned elegantly generate azcli commands with terraform outputs.

This project will deploy the folowing resources:
- azure keyvault
- azure storage account (with 3 file shares)
- azure Container Instance (with hachicorp vault image from dockerhub)

Vault will deploy with: 
- self signed certificate
- keyvault auto unseal

Terraform will generate the following outputs, to copy-paste in your terminal so you can interact with your vault instance:
- To-Configure-Vault-Address = "export VAULT_ADDR=https://<your_intance_name>.westeurope.azurecontainer.io:8200"
- To-Ignore-SelfSigned-Certs = "export VAULT_SKIP_VERIFY=true"
- To-Initialize-Vault = "vault operator init -recovery-shares=1 -recovery-threshold=1"

If you plan to test for a long period, the Container Instance is setup with persistent volumes in the storage account. If you want to avoid paying for compute resources, you can destroy the Container Group only with the command:

```bash
terraform destroy -target=azurerm_container_group.vault-aci
```