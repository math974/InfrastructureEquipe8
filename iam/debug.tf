data "google_project_iam_policy" "current" {
  project = var.project_id
}

locals {
  instructor_principal = "user:${var.instructor_email}"
  instructor_roles      = [
    for b in data.google_project_iam_policy.current.bindings :
    b.role if contains(b.members, local.instructor_principal)
  ]
  team_principals = [
    for e in var.team_member_emails : "user:${e}"
  ]
}

output "instructor_present" {
  description = "True if instructor email is explicitly present in project IAM policy."
  value       = length(local.instructor_roles) > 0
}

output "instructor_roles_found" {
  description = "List of roles (if any) the instructor has at the project level."
  value       = local.instructor_roles
}

output "team_members_missing" {
  description = "Team member principals not found in project-level IAM policy for their target role (may still inherit elsewhere)."
  value = [
    for p in local.team_principals :
    p if !contains(flatten([
      for b in data.google_project_iam_policy.current.bindings :
      b.members
    ]), p)
  ]
}
