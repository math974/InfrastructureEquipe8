variable "project_id" {
  type        = string
  description = "Cloud project ID"
}

variable "region" {
  type        = string
  description = "Region for resources"
}

variable "network_name" {
  type        = string
  description = "Name of the VPC network"
}

variable "ip_range" {
  type        = string
  description = "IP range for the VPC network"
}
