# ============================================================
# Redpoint RPI — Azure Terraform Module Variables
# ============================================================

variable "name_prefix" {
  description = "Prefix applied to all resource names for uniqueness and identification."
  type        = string
  default     = "rpi"
}

variable "location" {
  description = "Azure region where resources will be provisioned (e.g., eastus, westeurope)."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of an existing Azure Resource Group to deploy into."
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where RPI workloads are deployed. Used for federated identity credential binding."
  type        = string
  default     = "redpoint-rpi"
}

variable "rpi_image_tag" {
  description = "RPI container image tag. Format: <major.minor>.<year><MMDD>.<HHMM>"
  type        = string
  default     = "7.7.20260220.1524"
}

variable "ingress_domain" {
  description = "Base domain for ingress hostnames (e.g., rpi.example.com). Service subdomains are prepended automatically."
  type        = string
}

variable "sql_admin_username" {
  description = "Administrator login for the Azure SQL Server."
  type        = string
  default     = "rpiadmin"
}

variable "sql_admin_password" {
  description = "Administrator password for the Azure SQL Server. Must meet Azure complexity requirements."
  type        = string
  sensitive   = true
}

variable "enable_keyvault" {
  description = "Whether to create an Azure Key Vault for SDK or CSI-based secrets management."
  type        = bool
  default     = false
}

variable "managed_identity_name" {
  description = "Name of the User-Assigned Managed Identity for AKS workload identity federation."
  type        = string
  default     = "rpi-workload-identity"
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster. Required for federated identity credential binding."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Azure resources created by this module."
  type        = map(string)
  default     = {}
}
