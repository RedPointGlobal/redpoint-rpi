# ============================================================
# Redpoint RPI — Google Cloud Terraform Module Variables
# ============================================================

variable "name_prefix" {
  description = "Prefix applied to all resource names for namespacing."
  type        = string
  default     = "rpi"
}

variable "project_id" {
  description = "GCP project ID where resources will be provisioned."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources (Cloud SQL, etc.)."
  type        = string
  default     = "us-central1"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where the RPI Helm release is installed."
  type        = string
  default     = "redpoint-rpi"
}

variable "rpi_image_tag" {
  description = "RPI container image tag (chart appVersion)."
  type        = string
  default     = "7.7.20260220.1524"
}

variable "ingress_domain" {
  description = "Base DNS domain used for ingress host rules (e.g. rpi.example.com)."
  type        = string
}

variable "sql_tier" {
  description = "Cloud SQL machine type / tier for the SQL Server instance."
  type        = string
  default     = "db-custom-2-7680"
}

variable "sql_admin_password" {
  description = "Password for the Cloud SQL admin user (rpiadmin)."
  type        = string
  sensitive   = true
}

variable "gke_service_account_email" {
  description = "Email of the existing GKE node service account used for Workload Identity binding."
  type        = string
}

variable "enable_secret_manager" {
  description = "When true, provision a Google Secret Manager secret for SDK-based secrets management."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to all GCP resources that support them."
  type        = map(string)
  default     = {}
}
