resource "google_compute_network" "main" {
  name                     = var.network_name
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.ip_range
  region        = var.region
  network       = google_compute_network.main.id
  
  # Support IPv4/IPv6 dual-stack
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
  
  # Plages secondaires pour les pods et services Kubernetes
  # Cours 5, Section 3.5 - Networking
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }
}

output "network_id" {
  value       = google_compute_network.main.id
  description = "The ID of the created VPC network"
}
