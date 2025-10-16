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

resource "random_password" "db_app" {
  length           = 20
  override_special = "!@#$%&*()-_=+"
  special          = true
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.instance_name}-private-ip-range"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.private_ip_prefix_len
  network       = google_compute_network.main.self_link
}

resource "google_project_service" "servicenetworking_api" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
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

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google
  network                 = google_compute_network.main.name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  depends_on = [
    google_project_service.servicenetworking_api,
    google_project_service.sqladmin_api,
    google_project_service.secretmanager_api,
    google_project_service.compute_api,
  ]
}

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
      ipv4_enabled = false
      private_network = google_compute_network.main.self_link
    }
    availability_type = "ZONAL"
  }
  deletion_protection = false
}

# Application database inside the instance
resource "google_sql_database" "app_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.mysql.name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# Create the application user on the instance
resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.mysql.name
  project  = var.project_id
  password = random_password.db_app.result
}

# Optionally store the application user password in Secret Manager
resource "google_secret_manager_secret" "db_app_password" {
  secret_id = "${var.instance_name}-app-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_app_password_version" {
  secret      = google_secret_manager_secret.db_app_password.id
  secret_data = random_password.db_app.result
}

# Outputs
output "cloudsql_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.mysql.name
}

output "cloudsql_private_network_self_link" {
  description = "VPC network self_link attached to the Cloud SQL private IP"
  value       = google_compute_network.main.self_link
}

output "cloudsql_reserved_peering_range" {
  description = "Reserved peering range name used for Private Service Access"
  value       = google_compute_global_address.private_ip_address.name
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
  description = "Secret Manager resource name that holds the application DB password (secret version created)"
  value       = google_secret_manager_secret.db_app_password.name
}

# Combined .env content output for convenience — sensitive
# Produces a small .env file text containing the DB credentials and host.
# Marked sensitive so the secret value won't be shown in plain text in Terraform output.
output "db_env" {
  description = "Contents of a .env file with DB connection info (sensitive)"
  value       = <<EOF
DB_USER=${google_sql_user.app_user.name}
DB_NAME=${google_sql_database.app_db.name}
DB_HOST=${google_sql_database_instance.mysql.ip_address[0].ip_address}
DB_PORT=3306
DB_PASSWORD=${random_password.db_app.result}
EOF
  sensitive   = true
}
