# ============================================================
# Redpoint RPI — Azure Module Outputs
# ============================================================

output "managed_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity. Used in Helm values for cloudIdentity.azure.managedIdentityClientId."
  value       = azurerm_user_assigned_identity.rpi.client_id
}

output "tenant_id" {
  description = "Azure AD Tenant ID from the managed identity. Used in Helm values for cloudIdentity.azure.tenantId."
  value       = azurerm_user_assigned_identity.rpi.tenant_id
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL Server."
  value       = azurerm_mssql_server.rpi.fully_qualified_domain_name
}

output "sql_admin_username" {
  description = "Administrator login for the Azure SQL Server (echoed for reference)."
  value       = azurerm_mssql_server.rpi.administrator_login
}

output "keyvault_uri" {
  description = "URI of the Azure Key Vault (empty string when Key Vault is disabled)."
  value       = var.enable_keyvault ? azurerm_key_vault.rpi[0].vault_uri : ""
}

output "helm_values_path" {
  description = "Absolute path to the generated Helm values override file."
  value       = local_file.helm_values.filename
}
