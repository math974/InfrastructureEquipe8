output "iam_bindings_summary" {
  value = {
    project    = var.project_id
    team       = var.team_member_emails
    team_role  = var.team_role
    instructor = var.enable_instructor_binding ? var.instructor_email : null
  }
}
