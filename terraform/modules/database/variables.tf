variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
}

variable "network_self_link" {
  description = "Self link du réseau VPC"
  type        = string
}

variable "network_name" {
  description = "Nom du réseau VPC (simple)"
  type        = string
}

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
  description = "Prefix length for Private Service Access reserved range"
  type        = number
  default     = 16
}

variable "import_global_address" {
  description = "If true, reference existing reserved global address"
  type        = bool
  default     = false
}

variable "import_sql_instance" {
  description = "If true, reference existing Cloud SQL instance"
  type        = bool
  default     = false
}

variable "import_secret" {
  description = "If true, reference existing Secret Manager secret"
  type        = bool
  default     = false
}


