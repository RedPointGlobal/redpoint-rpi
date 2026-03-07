# -----------------------------------------------------------------------------
# Render and write the Helm values override file
# -----------------------------------------------------------------------------

locals {
  secrets_provider = var.enable_secrets_manager ? "sdk" : "kubernetes"

  helm_values_content = templatefile("${path.module}/helm-values.tftpl", {
    rpi_image_tag    = var.rpi_image_tag
    rds_endpoint     = split(":", aws_db_instance.rpi.endpoint)[0]
    rds_admin_username = var.rds_admin_username
    rds_admin_password = var.rds_admin_password
    irsa_role_arn    = aws_iam_role.irsa.arn
    region           = var.region
    secrets_provider = local.secrets_provider
    ingress_domain   = var.ingress_domain
  })
}

resource "local_file" "helm_values" {
  content  = local.helm_values_content
  filename = "${path.root}/generated-helm-values.yaml"

  file_permission      = "0640"
  directory_permission = "0750"
}
