# ============================================================
# Render the Helm values template and write to disk.
# ============================================================

locals {
  # Determine secrets provider based on Key Vault enablement.
  # When Key Vault is enabled, default to SDK-based secrets;
  # otherwise, fall back to Kubernetes-native secrets.
  secrets_provider = var.enable_keyvault ? "sdk" : "kubernetes"

  helm_values_content = templatefile("${path.module}/helm-values.tftpl", {
    rpi_image_tag              = var.rpi_image_tag
    sql_server_fqdn            = azurerm_mssql_server.rpi.fully_qualified_domain_name
    sql_admin_username         = var.sql_admin_username
    sql_admin_password         = var.sql_admin_password
    pulse_database_name        = azurerm_mssql_database.pulse.name
    pulse_logging_database_name = azurerm_mssql_database.pulse_logging.name
    managed_identity_client_id = azurerm_user_assigned_identity.rpi.client_id
    tenant_id                  = azurerm_user_assigned_identity.rpi.tenant_id
    secrets_provider           = local.secrets_provider
    keyvault_uri               = var.enable_keyvault ? azurerm_key_vault.rpi[0].vault_uri : ""
    ingress_domain             = var.ingress_domain
  })
}

resource "local_file" "helm_values" {
  content  = local.helm_values_content
  filename = "${path.module}/generated-values.yaml"

  file_permission      = "0640"
  directory_permission = "0750"
}

# ============================================================
# Optional: Deploy the Helm chart directly from Terraform.
# Uncomment the block below and configure the kubernetes
# provider to use this approach.
# ============================================================

# resource "helm_release" "rpi" {
#   name       = "redpoint-rpi"
#   namespace  = var.kubernetes_namespace
#   chart      = "${path.module}/../../../../chart"
#
#   create_namespace = true
#   wait             = true
#   timeout          = 900
#
#   values = [
#     local.helm_values_content,
#   ]
#
#   # Pin the release to a specific chart version if publishing to a registry
#   # version = "7.7.0"
#
#   depends_on = [
#     azurerm_mssql_database.pulse,
#     azurerm_mssql_database.pulse_logging,
#     azurerm_federated_identity_credential.rpi,
#   ]
# }
