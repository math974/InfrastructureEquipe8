variable "instance_name" {
  description = "Cloud SQL instance name (prefix)"
  type        = string
  default     = "tasks-mysql"
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "tasksdb"
}

variable "db_user" {
  description = "Database user for the application"
  type        = string
  default     = "tasks_app"
}

variable "db_tier" {
  description = "Machine type for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "db_version" {
  description = "Cloud SQL database version"
  type        = string
  default     = "MYSQL_8_0"
}

variable "private_ip_prefix_len" {
  description = "Prefix length for the reserved internal IP range used by Private Service Access"
  type        = number
  default     = 16
}

variable "import_global_address" {
  description = "If true, do not create the reserved global address; reference existing one via data source"
  type        = bool
  default     = false
}

variable "import_sql_instance" {
  description = "If true, do not create the Cloud SQL instance; reference existing one via data source"
  type        = bool
  default     = false
}

variable "import_secret" {
  description = "If true, do not create the Secret Manager secret; reference existing one via data source"
  type        = bool
  default     = false
}

resource "random_password" "db_app" {
  length           = 20
  override_special = "!@#$%&*()-_=+"
  special          = true
}

resource "google_compute_global_address" "private_ip_address" {
  count         = var.import_global_address ? 0 : 1
  name          = "${var.instance_name}-private-ip-range"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.private_ip_prefix_len
  network       = google_compute_network.main.self_link
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
  reserved_peering_range_name = var.import_global_address ? (length(data.google_compute_global_address.existing_private_ip) > 0 ? data.google_compute_global_address.existing_private_ip[0].name : null) : (length(google_compute_global_address.private_ip_address) > 0 ? google_compute_global_address.private_ip_address[0].name : null)
  sql_instance_name = var.import_sql_instance ? (length(data.google_sql_database_instance.existing_instance) > 0 ? data.google_sql_database_instance.existing_instance[0].name : var.instance_name) : var.instance_name
  secret_resource_id = var.import_secret ? (length(data.google_secret_manager_secret.existing_secret) > 0 ? data.google_secret_manager_secret.existing_secret[0].id : null) : (length(google_secret_manager_secret.db_app_password) > 0 ? google_secret_manager_secret.db_app_password[0].id : null)
}


resource "google_project_service" "servicenetworking_api" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
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

resource "google_compute_router" "nat_router" {
  name    = "${var.instance_name}-nat-router"
  project = var.project_id
  network = google_compute_network.main.self_link
  region  = var.region
}

resource "google_compute_router_nat" "default_nat" {
  name                               = "${var.instance_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    filter = "ALL"
    enable = false
  }
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.self_link
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

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.self_link
    }

    availability_type = "ZONAL"
  }

  deletion_protection = false
}

resource "google_sql_database" "app_db" {
  name      = var.db_name
  instance  = local.sql_instance_name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = local.sql_instance_name
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
  secret      = local.secret_resource_id
  secret_data = random_password.db_app.result
}

output "cloudsql_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = local.sql_instance_name
}

output "cloudsql_private_network_self_link" {
  description = "VPC network self_link attached to the Cloud SQL private IP"
  value       = google_compute_network.main.self_link
}

output "cloudsql_reserved_peering_range" {
  description = "Reserved peering range name used for Private Service Access"
  value       = local.reserved_peering_range_name
}

output "cloudsql_database_name" {
  description = "Application database name"
  value       = google_sql_database.app_db.name
}

output "cloudsql_app_user" {
  description = "Application database user"
  value       = google_sql_user.app_user.name
}

output "cloudsql_app_password_secret" {
  description = "Secret Manager resource identifier that holds the application DB password (imported or created)"
  value       = local.secret_resource_id
}
