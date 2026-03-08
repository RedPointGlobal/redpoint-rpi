# ============================================================
# Redpoint RPI — Render Helm Values Override File
# ============================================================

locals {
  secrets_provider = var.enable_secret_manager ? "sdk" : "kubernetes"

  helm_values_content = templatefile("${path.module}/helm-values.tftpl", {
    rpi_image_tag         = var.rpi_image_tag
    sql_instance_ip       = google_sql_database_instance.rpi.public_ip_address
    sql_admin_password    = var.sql_admin_password
    service_account_email = google_service_account.rpi.email
    project_id            = var.project_id
    name_prefix           = var.name_prefix
    secrets_provider      = local.secrets_provider
    ingress_domain        = var.ingress_domain
  })
}

resource "local_file" "helm_values" {
  filename        = "${path.module}/generated-values.yaml"
  content         = local.helm_values_content
  file_permission = "0640"
}
