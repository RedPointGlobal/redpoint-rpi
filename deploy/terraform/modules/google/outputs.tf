# ============================================================
# Redpoint RPI — Google Cloud Module Outputs
# ============================================================

output "service_account_email" {
  description = "Email of the GCP service account created for Workload Identity."
  value       = google_service_account.rpi.email
}

output "sql_instance_ip" {
  description = "Public IP address of the Cloud SQL for SQL Server instance."
  value       = google_sql_database_instance.rpi.public_ip_address
}

output "sql_admin_username" {
  description = "Admin username for the Cloud SQL instance."
  value       = "rpiadmin"
}

output "secret_manager_secret_id" {
  description = "Secret Manager secret ID (empty when enable_secret_manager is false)."
  value       = var.enable_secret_manager ? google_secret_manager_secret.rpi[0].secret_id : ""
}

output "helm_values_path" {
  description = "Absolute path to the rendered Helm values override file."
  value       = local_file.helm_values.filename
}
