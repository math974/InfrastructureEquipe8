# Bootstrap WIF (GitHub Actions to GCP)

This Terraform folder creates a Workload Identity Pool and a GitHub OIDC Provider, a Service Account, roles, and a conditional IAM binding (all branches except master).

## Variables
- project_id (required)
- github_owner (required)
- github_repo (required)
- pool_id (default: github-pool)
- provider_id (default: github)
- service_account_id (default: github-terraform)
- branch_excluded (default: master)
- roles (list of roles granted to the service account)

## Usage
1) Create `terraform.tfvars` in this directory:
```
project_id   = "YOUR_PROJECT_ID"
github_owner = "YOUR_ORG_OR_USER"
github_repo  = "YOUR_REPO"
```

2) Initialize and apply:
```
terraform init
terraform apply
```

3) Create GitHub Secrets (Settings -> Secrets and variables -> Actions):
- GCP_WORKLOAD_IDENTITY_PROVIDER = output `workload_identity_provider_name`
- GCP_SERVICE_ACCOUNT = output `service_account_email`

## Notes
- The IAM condition allows all branches `refs/heads/*` except `master` (change via `branch_excluded`).
- Adjust `roles` according to your Terraform modules' needs.
