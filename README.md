# InfrastructureEquipe8

End-to-end Infrastructure as Code (IaC) on Google Cloud using Terraform. This project provisions:
- Networking (a VPC and a Subnet) per environment.
- Project IAM bindings for team members and an instructor per environment.
- Two environments managed with Terraform workspaces: `dev` and `prd`.
- Remote Terraform state stored in GCS buckets, configured per environment.

## Repository layout

- `netwoks/` — Terraform for networking
  - `main.tf` — Terraform and provider constraints + backend declaration
  - `basics_refresher.tf` — Google provider configuration
  - `vpc_subnet.tf` — VPC and Subnet resources
  - `variables.tf` — Variables for network module
  - `envs/` — Per-environment variables files (`dev.tfvars`, `prd.tfvars`)
- `iam/` — Terraform for IAM bindings
  - `main.tf` — Terraform and provider constraints + backend declaration
  - `provider.tf` — Google provider configuration
  - `variables.tf` — Variables for IAM module
  - `invite.tf` — IAM bindings for team members and instructor
  - `members.tf` — Outputs summary
  - `envs/` — Per-environment variables files (`dev.tfvars`, `prd.tfvars`)
- `configs/` — Backend config files for remote state
  - `dev.config`, `prd.config` — contain backend `bucket` and `prefix`
- `deploy_all.sh` — Deploys networking then IAM for both `dev` and `prd`
- `destroy_all.sh` — Destroys IAM then networking for both `prd` and `dev`
- `docs/` — Project documentation (md/pdf)

Note: the `netwoks` directory name is intentional; use it exactly as written in commands and paths.

## Prerequisites

- Terraform >= 1.5.0
- Google Cloud SDK (`gcloud`) and `gsutil`
- Access to Google Cloud project(s) with permissions to:
  - Create/modify VPC networking (Compute)
  - Manage IAM bindings on the project
  - Read/write to the GCS state bucket(s)
- Authentication:
  - Use Application Default Credentials (recommended): `gcloud auth application-default login`
  - Or set `GOOGLE_APPLICATION_CREDENTIALS` to a service account JSON with required permissions
- Enable required APIs in the target project(s):
  - `compute.googleapis.com`
  - `cloudresourcemanager.googleapis.com`
  - `iam.googleapis.com`
- Remote state buckets:
  - Ensure buckets defined in `configs/dev.config` and `configs/prd.config` exist and are unique globally.
  - Example create (adjust project/region/class as needed): `gsutil mb -p <project_id> -c STANDARD -l <region> gs://<bucket-name>`

## Environment configuration

- Networking (`netwoks/envs/*.tfvars`) — example values:
  - `project_id` — GCP project ID (e.g., `caramel-abacus-472612-h3`)
  - `region` — GCP region (e.g., `europe-west9`)
  - `network_name` — VPC name (e.g., `network-dev`, `network-prod`)
  - `ip_range` — Subnet CIDR (e.g., `10.0.0.0/20` for dev)

- IAM (`iam/envs/*.tfvars`) — example values:
  - `project_id` — GCP project ID (e.g., `caramel-abacus-472612-h3`)
  - `region` — GCP region (required by the provider, e.g., `europe-west9`)
  - `team_member_emails` — list of team emails
  - `team_role` — role for team (e.g., `roles/editor`)
  - `instructor_email` — instructor email
  - `instructor_role` — instructor role (e.g., `roles/viewer`)

Important: ensure `iam/envs/dev.tfvars` and `iam/envs/prd.tfvars` include a `region` value. The IAM provider reads `var.region`.

- Remote state backend configs (`configs/*.config`):
  - `bucket` — GCS bucket name (must exist)
  - `prefix` — base path for state; the scripts automatically append the module name (e.g., `vpc/netwoks` and `vpc/iam`)

## One-time setup checklist

1. Authenticate: `gcloud auth application-default login`
2. Create state buckets for dev/prd (or update `configs/*.config` to point to your buckets).
3. Confirm API enablement on the target project(s).
4. Verify/adjust values in:
   - `netwoks/envs/dev.tfvars` and `netwoks/envs/prd.tfvars`
   - `iam/envs/dev.tfvars` and `iam/envs/prd.tfvars` (ensure `region` exists)
   - `configs/dev.config` and `configs/prd.config`

## Deploy everything (end-to-end)

1. Make scripts executable (first time): `chmod +x deploy_all.sh destroy_all.sh`
2. Run: `./deploy_all.sh`

What happens:
- For each module (`netwoks`, then `iam`) and each environment (`dev`, then `prd`):
  - Initializes Terraform with the appropriate backend config and state prefix.
  - Selects or creates the workspace (`dev` or `prd`).
  - Applies using the corresponding `envs/*.tfvars`.

Resources created:
- `netwoks`: a custom-mode VPC and one Subnet per environment.
- `iam`: project-level IAM bindings for team members and optionally the instructor, plus an output summary.

## Destroy everything (clean up)

Run: `./destroy_all.sh`

What happens:
- Destroys IAM first (`prd` then `dev`), then networking (`prd` then `dev`), reusing the same backend configuration logic.

## Operating modules manually (optional)

If you want to run Terraform manually per module/environment:

- Networking (example: `dev`):
  - Change dir: `cd netwoks`
  - Init backend: `terraform init -reconfigure -backend-config=../configs/dev.config -backend-config=prefix=vpc/netwoks`
  - Workspace: `terraform workspace select dev || terraform workspace new dev`
  - Apply: `terraform apply -var-file=envs/dev.tfvars`

- IAM (example: `dev`):
  - Change dir: `cd iam`
  - Init backend: `terraform init -reconfigure -backend-config=../configs/dev.config -backend-config=prefix=vpc/iam`
  - Workspace: `terraform workspace select dev || terraform workspace new dev`
  - Apply: `terraform apply -var-file=envs/dev.tfvars`

Tip: You can pass transient overrides with environment variables like `TF_VAR_region=europe-west9`.

## Troubleshooting

- Missing region in IAM:
  - Error similar to "variable region is not set" — add `region = "<your-region>"` to `iam/envs/*.tfvars` or export `TF_VAR_region`.

- Backend bucket not found:
  - Error mentioning bucket does not exist — create the bucket or correct `configs/*.config` to point to an existing one.

- Permission or auth errors (403/401):
  - Ensure you have sufficient IAM roles on the target project(s).
  - Verify ADC (`gcloud auth application-default login`) or `GOOGLE_APPLICATION_CREDENTIALS` path.

- API not enabled:
  - Enable `compute.googleapis.com`, `cloudresourcemanager.googleapis.com`, and `iam.googleapis.com`.

- Bucket naming:
  - GCS bucket names are global; rename in `configs/*.config` if the provided names are taken.

## Notes

- The modules use Terraform workspaces (`dev`, `prd`) plus per-environment `*.tfvars`.
- Remote state prefix is derived from the `prefix` in `configs/*.config` and the module name; you can safely share buckets between modules with a unique prefix.
- IAM bindings are defined in `iam/invite.tf`. The `iam/members.tf` file emits a summary output.
- Provider versions:
  - Terraform `>= 1.5.0`
  - Google provider `>= 5.0`

## Quick reference

- Deploy all: `./deploy_all.sh`
- Destroy all: `./destroy_all.sh`
- Update only one env/module manually: run Terraform inside `netwoks/` or `iam/` with the appropriate workspace and `-var-file`.