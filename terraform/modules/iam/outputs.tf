# Outputs du module IAM

output "iam_bindings_summary" {
  value = {
    project                   = var.project_id
    team                      = var.team_member_emails
    team_role                 = var.team_role
    instructor                = var.enable_instructor_binding ? var.instructor_email : null
    billing_account_id        = var.billing_account_id
    instructor_billing_viewer = var.enable_instructor_binding
  }
}

output "service_accounts" {
  description = "Liste des service accounts créés"
  value       = []
}

output "roles_assigned" {
  description = "Rôles assignés"
  value = {
    team_members    = var.team_member_emails
    instructor      = var.enable_instructor_binding ? var.instructor_email : null
    kubernetes_user = var.user_email
  }
}

output "kubernetes_permissions" {
  description = "Permissions Kubernetes accordées"
  value = {
    container_admin       = "roles/container.admin"
    compute_network_admin = "roles/compute.networkAdmin"
    service_account_user  = "roles/iam.serviceAccountUser"
    user                  = var.user_email
  }
}
