# -----------------------------------------------------------------------------
# Variables — Redpoint RPI AWS Module
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "rpi"
}

variable "region" {
  description = "AWS region for resource provisioning."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the existing VPC where resources will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs used for the RDS subnet group."
  type        = list(string)
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where the RPI Helm release will be installed."
  type        = string
  default     = "redpoint-rpi"
}

variable "rpi_image_tag" {
  description = "RPI container image tag (chart appVersion)."
  type        = string
  default     = "7.7.20260220.1524"
}

variable "ingress_domain" {
  description = "Domain name used for the ingress resource (e.g. rpi.example.com)."
  type        = string
}

variable "rds_instance_class" {
  description = "RDS instance class for the SQL Server Express database."
  type        = string
  default     = "db.m5.large"
}

variable "rds_admin_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "rpiadmin"
}

variable "rds_admin_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster (used for resource tagging and IRSA trust)."
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (for IRSA trust policy)."
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "URL of the EKS OIDC provider without the https:// prefix."
  type        = string
}

variable "enable_secrets_manager" {
  description = "When true, create an AWS Secrets Manager secret for SDK/CSI secrets mode."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to all resources."
  type        = map(string)
  default     = {}
}
