terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
  }
}

resource "random_password" "db_app" {
  length           = 20
  override_special = "!@#$%&*()-_=+"
  special          = true
}

resource "google_project_service" "servicenetworking_api" {
  project                    = var.project_id
  service                    = "servicenetworking.googleapis.com"
  disable_dependent_services = false
}

resource "google_project_service" "sqladmin_api" {
  project = var.project_id
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "secretmanager_api" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"
}

data "external" "check_service_networking_connection" {
  program = ["bash", "-lc", "gcloud services vpc-peerings list --network=projects/${var.project_id}/global/networks/${var.network_name} --project=${var.project_id} --filter='service:servicenetworking.googleapis.com' --format=json | jq -e 'length > 0' >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'"]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.instance_name}-private-ip-range"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.private_ip_prefix_len
  network       = var.network_self_link

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  connection_exists = try(tobool(data.external.check_service_networking_connection.result.exists), false)
}

# Créer la connexion Service Networking avec gestion des conflits
resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google
  network                 = "projects/${var.project_id}/global/networks/${var.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  update_on_creation_fail = true

  depends_on = [
    google_compute_global_address.private_ip_address,
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]
}


# Cloud SQL instance
resource "google_sql_database_instance" "mysql" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.db_version

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_compute_global_address.private_ip_address,
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_self_link
    }

    availability_type = "ZONAL"
  }

  deletion_protection = true

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      region,
      database_version,
      settings,
      deletion_protection
    ]
  }
}

resource "google_sql_database" "app_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.mysql.name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"

  depends_on = [
    google_sql_database_instance.mysql
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
  password = random_password.db_app.result

  depends_on = [
    google_sql_database_instance.mysql,
    google_sql_database.app_db
  ]
}

resource "google_secret_manager_secret" "db_app_password" {
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret_version" "db_app_password_version" {
  secret      = google_secret_manager_secret.db_app_password.id
  secret_data = random_password.db_app.result
}
