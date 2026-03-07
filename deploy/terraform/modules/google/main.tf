# ============================================================
# Redpoint RPI — Google Cloud Infrastructure Module
# ============================================================
# Provision GCP resources for RPI. Requires google provider >= 5.0
#
# Resources created:
#   - GCP Service Account with Workload Identity binding
#   - Cloud SQL for SQL Server (Pulse + Pulse_Logging databases)
#   - (Optional) Secret Manager secret for SDK secrets mode
#
# The module renders a Helm values override file that can be
# passed directly to `helm install -f`.
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

# ----------------------------------------------------------
# Data sources
# ----------------------------------------------------------

data "google_project" "current" {
  project_id = var.project_id
}

# ----------------------------------------------------------
# Service Account — Workload Identity
# ----------------------------------------------------------

resource "google_service_account" "rpi" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-workload-sa"
  display_name = "${var.name_prefix} RPI Workload Identity SA"
  description  = "Service account bound to GKE pods via Workload Identity for RPI services."
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.rpi.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${var.name_prefix}-sa]",
  ]
}

# ----------------------------------------------------------
# Cloud SQL — SQL Server
# ----------------------------------------------------------

resource "google_sql_database_instance" "rpi" {
  project          = var.project_id
  name             = "${var.name_prefix}-sqlserver"
  database_version = "SQLSERVER_2019_STANDARD"
  region           = var.region

  deletion_protection = true

  settings {
    tier              = var.sql_tier
    availability_type = "REGIONAL"
    disk_autoresize   = true
    disk_size         = 20
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = true
      private_network = null # Set to a VPC self_link to use private IP
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = false
      start_time                     = "03:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    user_labels = var.labels
  }
}

resource "google_sql_database" "pulse" {
  project  = var.project_id
  name     = "Pulse"
  instance = google_sql_database_instance.rpi.name
}

resource "google_sql_database" "pulse_logging" {
  project  = var.project_id
  name     = "Pulse_Logging"
  instance = google_sql_database_instance.rpi.name
}

resource "google_sql_user" "admin" {
  project  = var.project_id
  name     = "rpiadmin"
  instance = google_sql_database_instance.rpi.name
  password = var.sql_admin_password
  type     = "BUILT_IN"
}

# ----------------------------------------------------------
# Secret Manager (conditional)
# ----------------------------------------------------------

resource "google_secret_manager_secret" "rpi" {
  count = var.enable_secret_manager ? 1 : 0

  project   = var.project_id
  secret_id = "${var.name_prefix}-secrets"

  labels = var.labels

  replication {
    auto {}
  }
}

# Grant the workload SA access to the secret
resource "google_secret_manager_secret_iam_member" "rpi_accessor" {
  count = var.enable_secret_manager ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.rpi[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.rpi.email}"
}
