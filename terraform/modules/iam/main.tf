# Module IAM - Gestion des permissions et invitations

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  unique_team_member_emails = distinct(var.team_member_emails)
}

# Permissions pour les membres de l'équipe
resource "google_project_iam_member" "team_members" {
  for_each = var.auto_invite_missing_users ? {
    for email in local.unique_team_member_emails : email => email
  } : {}
  project = var.project_id
  role    = var.team_role
  member  = "user:${each.value}"
}

# Permissions pour l'instructeur
resource "google_project_iam_member" "instructor" {
  count   = var.enable_instructor_binding ? 1 : 0
  project = var.project_id
  role    = var.instructor_role
  member  = "user:${var.instructor_email}"
}

# Permissions de facturation pour l'instructeur
resource "google_billing_account_iam_member" "instructor_billing_viewer" {
  count              = var.enable_instructor_binding ? 1 : 0
  billing_account_id = var.billing_account_id
  role               = "roles/billing.user"
  member             = "user:${var.instructor_email}"
}

# Permissions IAM pour Kubernetes
resource "google_project_iam_member" "container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "user:${var.user_email}"
}

resource "google_project_iam_member" "compute_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "user:${var.user_email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "user:${var.user_email}"
}

# Service Account pour les nœuds GKE
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "gke-nodes-${var.environment}"
  display_name = "GKE Nodes ${upper(var.environment)}"
}

# Rôles nécessaires pour le SA des nœuds
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Accès aux secrets (Secret Manager) pour les pods via le SA des nœuds
resource "google_project_iam_member" "gke_nodes_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Accès Cloud SQL Client si vous utilisez le Cloud SQL Auth Proxy
resource "google_project_iam_member" "gke_nodes_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Permissions pour Artifact Registry
resource "google_project_iam_member" "gke_nodes_artifactregistry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Les permissions pour GitHub Actions sont gérées via Workload Identity Federation
# dans le module bootstrap-wif/

# Output email SA nœuds
output "gke_nodes_service_account_email" {
  description = "Email du service account utilisé par les nœuds GKE"
  value       = google_service_account.gke_nodes.email
}

# Les outputs pour GitHub Actions sont gérés dans bootstrap-wif/
