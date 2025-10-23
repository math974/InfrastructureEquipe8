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

data "external" "check_global_address" {
  program = ["bash", "-lc", "gcloud compute addresses describe ${var.instance_name}-private-ip-range --project=${var.project_id} --global >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'"]
}

data "external" "check_sql_instance" {
  program = ["bash", "-lc", "gcloud sql instances describe ${var.instance_name} --project=${var.project_id} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'"]
}

data "external" "check_secret" {
  program = ["bash", "-lc", "gcloud secrets describe ${var.instance_name}-app-db-password --project=${var.project_id} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'"]
}

data "external" "check_service_networking_connection" {
  program = ["bash", "-lc", "gcloud services vpc-peerings list --network=projects/${var.project_id}/global/networks/${var.network_name} --project=${var.project_id} --format='value(service)' | grep -q '^servicenetworking.googleapis.com$' && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'"]
}

resource "google_compute_global_address" "private_ip_address" {
  count         = try(tobool(data.external.check_global_address.result.exists), false) ? 0 : 1
  name          = "${var.instance_name}-private-ip-range"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.private_ip_prefix_len
  network       = var.network_self_link
}

data "google_compute_global_address" "existing_private_ip" {
  count   = try(tobool(data.external.check_global_address.result.exists), false) ? 1 : 0
  name    = "${var.instance_name}-private-ip-range"
  project = var.project_id
}

data "google_sql_database_instance" "existing_instance" {
  count   = try(tobool(data.external.check_sql_instance.result.exists), false) ? 1 : 0
  name    = var.instance_name
  project = var.project_id
}

data "google_secret_manager_secret" "existing_secret" {
  count     = try(tobool(data.external.check_secret.result.exists), false) ? 1 : 0
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id
}

locals {
  global_address_exists = try(tobool(data.external.check_global_address.result.exists), false)
  sql_instance_exists   = try(tobool(data.external.check_sql_instance.result.exists), false)
  secret_exists         = try(tobool(data.external.check_secret.result.exists), false)
  connection_exists     = try(tobool(data.external.check_service_networking_connection.result.exists), false)

  reserved_peering_range_name = local.global_address_exists ? data.google_compute_global_address.existing_private_ip[0].name : google_compute_global_address.private_ip_address[0].name
  sql_instance_name           = local.sql_instance_exists ? data.google_sql_database_instance.existing_instance[0].name : google_sql_database_instance.mysql[0].name
  secret_resource_id          = local.secret_exists ? data.google_secret_manager_secret.existing_secret[0].id : google_secret_manager_secret.db_app_password[0].id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = local.connection_exists ? 0 : 1
  provider                = google
  network                 = "projects/${var.project_id}/global/networks/${var.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [local.reserved_peering_range_name]
  depends_on = [
    google_compute_global_address.private_ip_address,
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]
}

resource "google_sql_database_instance" "mysql" {
  count            = local.sql_instance_exists ? 0 : 1
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
  deletion_protection = false

  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "google_sql_database" "app_db" {
  name      = var.db_name
  instance  = local.sql_instance_name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"

  depends_on = [
    google_sql_database_instance.mysql
  ]

  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = local.sql_instance_name
  project  = var.project_id
  password = random_password.db_app.result

  depends_on = [
    google_sql_database_instance.mysql,
    google_sql_database.app_db
  ]
}

resource "google_secret_manager_secret" "db_app_password" {
  count     = local.secret_exists ? 0 : 1
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_app_password_version" {
  secret      = local.secret_resource_id
  secret_data = random_password.db_app.result
}
