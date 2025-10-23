output "cloudsql_private_network_self_link" {
  description = "VPC network self_link attached to the Cloud SQL private IP"
  value       = var.network_self_link
}

output "cloudsql_database_name" {
  description = "Application database name"
  value       = google_sql_database.app_db.name
}

output "cloudsql_app_user" {
  description = "Application database user"
  value       = google_sql_user.app_user.name
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)"
  value       = google_sql_database_instance.mysql.connection_name
}

output "cloudsql_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.mysql.ip_address[0].ip_address
}
