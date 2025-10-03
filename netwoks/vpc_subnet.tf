resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.ip_range
  region        = var.region
  network       = google_compute_network.main.id
}

output "network_id" {
  value       = google_compute_network.main.id
  description = "The ID of the created VPC network"
}
