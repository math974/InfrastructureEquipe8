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

resource "google_compute_global_address" "private_ip_address" {
  count         = var.import_global_address ? 0 : 1
  name          = "${var.instance_name}-private-ip-range"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.private_ip_prefix_len
  network       = var.network_self_link
}

data "google_compute_global_address" "existing_private_ip" {
  count   = var.import_global_address ? 1 : 0
  name    = "${var.instance_name}-private-ip-range"
  project = var.project_id
}

data "google_sql_database_instance" "existing_instance" {
  count   = var.import_sql_instance ? 1 : 0
  name    = var.instance_name
  project = var.project_id
}

data "google_secret_manager_secret" "existing_secret" {
  count     = var.import_secret ? 1 : 0
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id
}

locals {
  reserved_peering_range_name = var.import_global_address ? data.google_compute_global_address.existing_private_ip[0].name : google_compute_global_address.private_ip_address[0].name
  sql_instance_name           = var.import_sql_instance ? data.google_sql_database_instance.existing_instance[0].name : google_sql_database_instance.mysql[0].name
  secret_resource_id          = var.import_secret ? data.google_secret_manager_secret.existing_secret[0].id : google_secret_manager_secret.db_app_password[0].id
}

## NAT déplacé vers le module réseau

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.import_service_networking_connection ? 0 : 1
  provider                = google
  network                 = "projects/${var.project_id}/global/networks/${var.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [local.reserved_peering_range_name]
  depends_on = [
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]
}

resource "google_sql_database_instance" "mysql" {
  count            = var.import_sql_instance ? 0 : 1
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.db_version

  depends_on = concat(
    var.import_service_networking_connection ? [] : [google_service_networking_connection.private_vpc_connection],
    [
      google_compute_global_address.private_ip_address,
      google_project_service.servicenetworking_api,
      google_project_service.sqladmin_api,
      google_project_service.secretmanager_api,
      google_project_service.compute_api,
    ]
  )

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
  }
}

resource "google_sql_database" "app_db" {
  name      = var.db_name
  instance  = var.import_sql_instance ? local.sql_instance_name : google_sql_database_instance.mysql[0].name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = var.import_sql_instance ? local.sql_instance_name : google_sql_database_instance.mysql[0].name
  project  = var.project_id
  password = random_password.db_app.result
}

resource "google_secret_manager_secret" "db_app_password" {
  count     = var.import_secret ? 0 : 1
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_app_password_version" {
  secret      = var.import_secret ? local.secret_resource_id : google_secret_manager_secret.db_app_password[0].id
  secret_data = random_password.db_app.result
}


