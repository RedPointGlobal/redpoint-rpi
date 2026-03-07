# -----------------------------------------------------------------------------
# Outputs — Redpoint RPI AWS Module
# -----------------------------------------------------------------------------

output "irsa_role_arn" {
  description = "ARN of the IRSA IAM role for the RPI Kubernetes ServiceAccount."
  value       = aws_iam_role.irsa.arn
}

output "rds_endpoint" {
  description = "RDS instance hostname (port stripped)."
  value       = split(":", aws_db_instance.rpi.endpoint)[0]
}

output "rds_admin_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.rpi.username
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret (empty when secrets manager is disabled)."
  value       = var.enable_secrets_manager ? aws_secretsmanager_secret.rpi[0].arn : ""
}

output "helm_values_path" {
  description = "Absolute path to the rendered Helm values file."
  value       = local_file.helm_values.filename
}
