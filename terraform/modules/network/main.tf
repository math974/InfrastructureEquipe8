# Module Network - Configuration VPC et sous-réseaux

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# VPC
resource "google_compute_network" "main" {
  name                     = var.network_name
  project                  = var.project_id
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

# Sous-réseau principal
resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.ip_range
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.main.id

  # Support IPv4/IPv6 dual-stack
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"

  # Évite les tentatives de mise à jour des plages secondaires existantes (immutables côté GCP)
  lifecycle {
    ignore_changes = [secondary_ip_range]
  }

  # Ranges secondaires utilisées par GKE
  secondary_ip_range {
    range_name    = "services-range-2"
    ip_cidr_range = "10.10.0.0/20"
  }

  secondary_ip_range {
    range_name    = "pod-ranges-2"
    ip_cidr_range = "10.20.0.0/20"
  }
}
