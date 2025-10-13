# Bootstrap WIF (GitHub Actions to GCP)

This Terraform folder creates separate Workload Identity Pools, GitHub OIDC Providers, and Service Accounts for dev and prod environments.

## Variables
- project_id (required)
- environment (required: "dev" or "prd")
- github_owner (required)
- github_repo (required)
- allowed_branches (list of allowed branches for this environment)
- pool_id (default: github-pool)
- provider_id (default: github)
- service_account_id (default: github-terraform)
- roles (list of roles granted to the service account)

## Usage

### For Development Environment:
1) Update `envs/dev.tfvars`:
```
project_id   = "caramel-abacus-472612-h3"
environment  = "dev"
github_owner = "math974"
github_repo  = "InfrastructureEquipe8"
allowed_branches = ["develop", "feature/*"]
```

2) Deploy dev environment:
```
terraform init -backend-config=../configs/bootstrap-wif-dev.config
terraform apply -var-file=envs/dev.tfvars
```

### For Production Environment:
1) Update `envs/prd.tfvars`:
```
project_id   = "epitech-vpc-demo-69"
environment  = "prd"
github_owner = "math974"
github_repo  = "InfrastructureEquipe8"
allowed_branches = ["main"]
```

2) Deploy prod environment:
```
terraform init -backend-config=../configs/bootstrap-wif-prd.config
terraform apply -var-file=envs/prd.tfvars
```

### Create GitHub Secrets:
For each environment, create secrets in GitHub (Settings -> Secrets and variables -> Actions):

**Develop environment:**
- GCP_WORKLOAD_IDENTITY_PROVIDER = output `workload_identity_provider_name` (dev)
- GCP_SERVICE_ACCOUNT = output `service_account_email` (dev)

**Production environment:**
- GCP_WORKLOAD_IDENTITY_PROVIDER = output `workload_identity_provider_name` (prd)
- GCP_SERVICE_ACCOUNT = output `service_account_email` (prd)

## Notes
- Each environment creates separate resources with `-dev` or `-prd` suffixes
- Branch restrictions are enforced via `allowed_branches` variable
- Adjust `roles` according to your Terraform modules' needs
