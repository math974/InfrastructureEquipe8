# Outputs globaux de l'infrastructure

output "network_info" {
  description = "Informations sur le réseau"
  value = {
    network_name = module.network.network_name
    subnet_name  = module.network.subnet_name
    subnet_cidr  = module.network.subnet_cidr
  }
}

output "kubernetes_info" {
  description = "Informations sur le cluster Kubernetes"
  value = {
    cluster_name            = module.kubernetes.kubernetes_cluster_name
    cluster_host            = module.kubernetes.kubernetes_cluster_host
    location                = module.kubernetes.kubernetes_location
    get_credentials_command = module.kubernetes.get_credentials_command
  }
}

output "iam_info" {
  description = "Informations sur les permissions IAM"
  value = {
    service_accounts       = module.iam.service_accounts
    roles_assigned         = module.iam.roles_assigned
    kubernetes_permissions = module.iam.kubernetes_permissions
  }
}

# Output pour le déploiement de l'application
output "deployment_info" {
  description = "Informations pour le déploiement de l'application"
  value = {
    project_id   = var.project_id
    cluster_name = module.kubernetes.kubernetes_cluster_name
    region       = var.region
    environment  = var.environment
  }
}

# Les outputs pour GitHub Actions sont gérés dans bootstrap-wif/
