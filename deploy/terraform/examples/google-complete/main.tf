# ============================================================
# Example: Complete RPI Deployment on Google Cloud
# ============================================================
# Usage:
#   1. Copy this file to your own working directory.
#   2. Create a terraform.tfvars with your values.
#   3. Run: terraform init && terraform apply
#   4. Install the chart:
#        helm install rpi ./chart -f <helm_values_path output>
# ============================================================

terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ----------------------------------------------------------
# Variables
# ----------------------------------------------------------

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "ingress_domain" {
  description = "Base DNS domain for RPI ingress (e.g. rpi.example.com)."
  type        = string
}

variable "sql_admin_password" {
  description = "Password for the Cloud SQL admin user."
  type        = string
  sensitive   = true
}

variable "gke_service_account_email" {
  description = "Email of the GKE node service account for Workload Identity binding."
  type        = string
}

# ----------------------------------------------------------
# RPI Google Cloud Module
# ----------------------------------------------------------

module "rpi_google" {
  source = "../../modules/google"

  name_prefix               = "rpi"
  project_id                = var.project_id
  region                    = var.region
  kubernetes_namespace      = "redpoint-rpi"
  ingress_domain            = var.ingress_domain
  sql_admin_password        = var.sql_admin_password
  gke_service_account_email = var.gke_service_account_email
  enable_secret_manager     = true

  labels = {
    environment = "production"
    managed_by  = "terraform"
    application = "redpoint-rpi"
  }
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------

output "service_account_email" {
  description = "GCP service account email for Workload Identity."
  value       = module.rpi_google.service_account_email
}

output "sql_instance_ip" {
  description = "Cloud SQL public IP."
  value       = module.rpi_google.sql_instance_ip
}

output "helm_values_path" {
  description = "Path to the generated Helm values file. Use with: helm install rpi ./chart -f <this path>"
  value       = module.rpi_google.helm_values_path
}

output "secret_manager_secret_id" {
  description = "Secret Manager secret ID for SDK secrets mode."
  value       = module.rpi_google.secret_manager_secret_id
}
