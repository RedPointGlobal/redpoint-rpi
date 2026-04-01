# ============================================================
# Example: Complete Azure RPI deployment
# ============================================================
# This example provisions all Azure infrastructure required
# for a Redpoint RPI deployment and generates a Helm values
# file that can be passed to `helm install`.
#
# Usage:
#   terraform init
#   terraform plan -var-file="terraform.tfvars"
#   terraform apply -var-file="terraform.tfvars"
#
# After apply, install the Helm chart:
#   helm install redpoint-rpi ../../chart \
#     -n redpoint-rpi --create-namespace \
#     -f <generated-values-path>
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# ----------------------------------------------------------
# RPI Azure Module
# ----------------------------------------------------------
module "rpi" {
  source = "../../modules/azure"

  name_prefix         = "myrpi"
  location            = "eastus"
  resource_group_name = "rg-rpi-production"
  kubernetes_namespace = "redpoint-rpi"

  # AKS OIDC issuer — retrieve from your AKS cluster:
  #   az aks show -n <cluster> -g <rg> --query oidcIssuerProfile.issuerUrl -o tsv
  aks_oidc_issuer_url = var.aks_oidc_issuer_url

  # SQL Server credentials
  sql_admin_username = "rpiadmin"
  sql_admin_password = var.sql_admin_password

  # Ingress base domain — service subdomains are prepended automatically
  ingress_domain = "rpi.example.com"

  # Set to true to create a Key Vault and use SDK-based secrets management
  enable_keyvault = false

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Application = "redpoint-rpi"
  }
}

# ----------------------------------------------------------
# Variables for this example
# ----------------------------------------------------------
variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server administrator password."
  type        = string
  sensitive   = true
}

# ----------------------------------------------------------
# Outputs — useful for subsequent Helm install
# ----------------------------------------------------------
output "managed_identity_client_id" {
  description = "Client ID for the RPI workload identity."
  value       = module.rpi.managed_identity_client_id
}

output "tenant_id" {
  description = "Azure AD tenant ID."
  value       = module.rpi.tenant_id
}

output "sql_server_fqdn" {
  description = "FQDN of the provisioned SQL Server."
  value       = module.rpi.sql_server_fqdn
}

output "keyvault_uri" {
  description = "Key Vault URI (empty when disabled)."
  value       = module.rpi.keyvault_uri
}

output "helm_values_path" {
  description = "Path to the generated Helm values file. Use with: helm install -f <path>"
  value       = module.rpi.helm_values_path
}
