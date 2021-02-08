listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address  = "0.0.0.0:8201"
  tls_cert_file = "/vault/config/vault.crt"
  tls_key_file = "/vault/config/vault.key"
  #tls_disable = "true"
}

storage "file" {
  path = "/vault/file"
}
seal "azurekeyvault" {
}

ui = true

disable_mlock = true