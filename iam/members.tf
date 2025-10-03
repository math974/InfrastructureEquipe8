resource "google_project_iam_member" "team" {
  for_each = toset(var.team_member_emails)
  project  = var.project_id
  role     = var.team_role
  member   = "user:${each.key}"
}

resource "google_project_iam_member" "instructor" {
  count   = var.enable_instructor_binding ? 1 : 0
  project = var.project_id
  role    = var.instructor_role
  member  = "user:${var.instructor_email}"
}

output "iam_bindings_summary" {
  value = {
    project    = var.project_id
    team       = var.team_member_emails
    team_role  = var.team_role
    instructor = var.enable_instructor_binding ? var.instructor_email : null
  }
}