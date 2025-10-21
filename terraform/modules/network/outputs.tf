# Outputs du module Network

output "network_name" {
  description = "Nom du réseau VPC"
  value       = google_compute_network.main.name
}

output "network_id" {
  description = "ID du réseau VPC"
  value       = google_compute_network.main.id
}

output "subnet_name" {
  description = "Nom du sous-réseau"
  value       = google_compute_subnetwork.main.name
}

output "subnet_id" {
  description = "ID du sous-réseau"
  value       = google_compute_subnetwork.main.id
}

output "services_range_name" {
  description = "Nom de la plage secondaire pour les services"
  value       = "services-range"
}

output "pod_ranges_name" {
  description = "Nom de la plage secondaire pour les pods"
  value       = "pod-ranges"
}

output "subnet_cidr" {
  description = "CIDR du sous-réseau"
  value       = google_compute_subnetwork.main.ip_cidr_range
}
