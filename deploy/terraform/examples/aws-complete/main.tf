# -----------------------------------------------------------------------------
# Example — Complete AWS deployment for Redpoint RPI
# -----------------------------------------------------------------------------
# Usage:
#   1. Copy this file into your own Terraform workspace.
#   2. Adjust variable values to match your environment.
#   3. Run `terraform init && terraform apply`.
#   4. Install the Helm chart using the generated values file:
#        helm upgrade --install rpi ./chart \
#          -n redpoint-rpi --create-namespace \
#          -f "$(terraform output -raw helm_values_path)"
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# Module invocation
# -----------------------------------------------------------------------------

module "rpi_aws" {
  source = "../../modules/aws"

  name_prefix          = "rpi-prod"
  region               = "us-east-1"
  vpc_id               = "vpc-0abc1234def567890"
  subnet_ids           = ["subnet-0aaa1111bbbb2222c", "subnet-0ddd3333eeee4444f"]
  kubernetes_namespace = "redpoint-rpi"
  rpi_image_tag        = "7.7.20260220.1524"
  ingress_domain       = "rpi.example.com"

  # RDS
  rds_instance_class = "db.m5.large"
  rds_admin_username = "rpiadmin"
  rds_admin_password = var.rds_admin_password   # pass via TF_VAR or .tfvars

  # EKS / IRSA
  eks_cluster_name      = "my-eks-cluster"
  eks_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  eks_oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"

  # Optional: enable Secrets Manager for SDK/CSI secrets mode
  enable_secrets_manager = false

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "rds_admin_password" {
  description = "Master password for the RDS instance. Pass via TF_VAR_rds_admin_password or a .tfvars file."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "irsa_role_arn" {
  description = "IRSA role ARN to verify ServiceAccount annotation."
  value       = module.rpi_aws.irsa_role_arn
}

output "rds_endpoint" {
  description = "RDS hostname for manual connectivity checks."
  value       = module.rpi_aws.rds_endpoint
}

output "helm_values_path" {
  description = "Path to the generated Helm values file."
  value       = module.rpi_aws.helm_values_path
}

output "secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN (empty if disabled)."
  value       = module.rpi_aws.secrets_manager_secret_arn
}
