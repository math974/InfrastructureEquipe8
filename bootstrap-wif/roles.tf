# Configuration des rôles supplémentaires pour GitHub Actions
# Ce fichier peut être utilisé pour ajouter des rôles spécifiques si nécessaire

# Les rôles par défaut sont définis dans variables.tf
# Pour ajouter des rôles supplémentaires, vous pouvez :
# 1. Modifier la variable "roles" dans variables.tf
# 2. Ou créer des ressources google_project_iam_member supplémentaires ici

# Exemple d'ajout de rôles supplémentaires si nécessaire :
# resource "google_project_iam_member" "additional_roles" {
#   for_each = toset([
#     "roles/artifactregistry.admin",
#     "roles/artifactregistry.writer"
#   ])
#   project  = var.project_id
#   role     = each.key
#   member   = "serviceAccount:${google_service_account.sa.email}"
# }
