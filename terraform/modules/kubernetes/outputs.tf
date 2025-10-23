output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Nom du cluster GKE"
}

output "kubernetes_cluster_host" {
  value       = "https://${google_container_cluster.primary.endpoint}"
  description = "Point d'entrée de l'API Kubernetes"
}

output "kubernetes_location" {
  value       = google_container_cluster.primary.location
  description = "Région/zone du cluster GKE"
}

output "get_credentials_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  description = "Commande pour configurer kubectl avec ce cluster"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  description = "Certificat CA du cluster"
  sensitive   = true
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "Endpoint du cluster Kubernetes"
  sensitive   = true
}
