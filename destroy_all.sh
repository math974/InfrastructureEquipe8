#!/usr/bin/env bash

set -euo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# -----------------
# Paths and globals
# -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
ENVS_DIR="${PROJECT_DIR}/envs"
IAM_DIR="${PROJECT_DIR}/iam"
IAM_ENVS_DIR="${IAM_DIR}/envs"

# -------------
# Logging utils
# -------------
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s %s\n' "$(ts)" "$*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err()  { log "ERROR $*" >&2; }
die()  { err "$*"; exit 1; }

# -------------
# Prerequisites
# -------------
require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Required command not found: $1 (please install it and ensure it's on PATH)"
  fi
}

ensure_prereqs() {
  require_bin gcloud
  [[ -f "${ENVS_DIR}/dev.tfvars" ]] || die "Missing ${ENVS_DIR}/dev.tfvars"
  [[ -f "${ENVS_DIR}/prd.tfvars" ]] || die "Missing ${ENVS_DIR}/prd.tfvars"
  [[ -f "${IAM_ENVS_DIR}/dev.tfvars" ]] || die "Missing ${IAM_ENVS_DIR}/dev.tfvars"
  [[ -f "${IAM_ENVS_DIR}/prd.tfvars" ]] || die "Missing ${IAM_ENVS_DIR}/prd.tfvars"
}

# -------------
# Authentication
# -------------
active_gcloud_account() {
  gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n1
}

run_gcloud_interactive() {
  CLOUDSDK_CORE_DISABLE_PROMPTS=0 "$@"
}

ensure_gcloud_user_login() {
  local acct
  acct="$(active_gcloud_account || true)"
  if [[ -z "${acct:-}" ]]; then
    info "No active gcloud user account. Launching gcloud auth login (interactive)..."
    run_gcloud_interactive gcloud auth login
    acct="$(active_gcloud_account || true)"
    [[ -n "${acct:-}" ]] || die "gcloud auth login did not complete successfully"
    info "Logged in as: ${acct}"
  else
    info "Using active gcloud account: ${acct}"
  fi
}

# ------------------------
# File parsing convenience
# ------------------------
tfvar_get() {
  local file="$1" key="$2"
  sed -n -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$file" | tail -n1
}

tfvar_get_list() {
  local file="$1" key="$2"
  local line
  line="$(sed -n -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\\[(.*)\\][[:space:]]*$/\\1/p" "$file" | tail -n1)"
  line="${line//\"/}"
  line="${line// /}"
  IFS=',' read -r -a arr <<< "$line"
  printf '%s\n' "${arr[@]}"
}


tfvar_first() {
  local file="$1"; shift
  local k v
  for k in "$@"; do
    v="$(tfvar_get "$file" "$k" || true)"
    if [[ -n "$v" ]]; then
      printf '%s' "$v"
      return 0
    fi
  done
  return 1
}

# -------------------------
# GCP project/service setup
# -------------------------
ensure_compute_api() {
  local project="$1"
  info "Ensuring Compute API is enabled for project ${project}"
  gcloud services enable compute.googleapis.com --project="${project}" --quiet >/dev/null
}
ensure_iam_apis() {
  local project="$1"
  info "Ensuring Resource Manager and IAM APIs are enabled for project ${project}"
  gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com --project="${project}" --quiet >/dev/null
}

# -----------------
# VPC/Subnet helpers
# -----------------
network_exists() {
  local project="$1" network="$2"
  gcloud compute networks describe "${network}" --project="${project}" --format="value(selfLink)" >/dev/null 2>&1
}

subnet_exists() {
  local project="$1" region="$2" subnet="$3"
  gcloud compute networks subnets describe "${subnet}" --project="${project}" --region="${region}" --format="value(selfLink)" >/dev/null 2>&1
}

delete_subnet_if_exists() {
  local project="$1" region="$2" subnet="$3"
  if subnet_exists "${project}" "${region}" "${subnet}"; then
    info "Deleting subnet '${subnet}' in region '${region}' (project '${project}')"
    if ! gcloud compute networks subnets delete "${subnet}" --project="${project}" --region="${region}" --quiet; then
      warn "Failed to delete subnet '${subnet}'. It may still have dependent resources."
      return 1
    fi
    info "Deleted subnet '${subnet}'"
  else
    info "Subnet '${subnet}' not found in region '${region}' (project '${project}'); skipping"
  fi
}

delete_network_if_exists() {
  local project="$1" network="$2"
  if network_exists "${project}" "${network}"; then
    info "Deleting VPC network '${network}' (project '${project}')"
    if ! gcloud compute networks delete "${network}" --project="${project}" --quiet; then
      warn "Failed to delete VPC network '${network}'. Ensure all subnets and dependent resources are removed."
      return 1
    fi
    info "Deleted VPC network '${network}'"
  else
    info "VPC network '${network}' not found (project '${project}'); skipping"
  fi
}

# -----------------
# IAM removal
# -----------------
destroy_iam_env() {
  local label="$1" tfvars="$2"

  info "==================== Removing IAM ${label} ===================="

  local project team_role instructor_role instructor_email enable_instructor_binding
  project="$(tfvar_get "${tfvars}" "project_id" || true)"
  [[ -n "${project}" ]] || die "project_id not found in ${tfvars}"

  team_role="$(tfvar_get "${tfvars}" "team_role" || true)"
  [[ -n "${team_role}" ]] || team_role="roles/editor"

  instructor_role="$(tfvar_get "${tfvars}" "instructor_role" || true)"
  [[ -n "${instructor_role}" ]] || instructor_role="roles/viewer"

  instructor_email="$(tfvar_get "${tfvars}" "instructor_email" || true)"
  enable_instructor_binding="$(tfvar_get "${tfvars}" "enable_instructor_binding" || true)"
  [[ -n "${enable_instructor_binding}" ]] || enable_instructor_binding="true"

  ensure_iam_apis "${project}"

  while IFS= read -r email; do
    [[ -n "${email}" ]] || continue
    info "Removing IAM binding if present: ${email} <- ${team_role} on project ${project}"
    if gcloud projects remove-iam-policy-binding "${project}" \
      --member="user:${email}" \
      --role="${team_role}" \
      --quiet >/dev/null; then
      info "Removed binding for ${email} (${team_role})"
    else
      warn "Binding not found or could not remove for ${email} (${team_role})"
    fi
  done < <(tfvar_get_list "${tfvars}" "team_member_emails")

  if [[ "${enable_instructor_binding}" == "true" && -n "${instructor_email}" ]]; then
    info "Removing IAM binding if present: instructor ${instructor_email} <- ${instructor_role} on project ${project}"
    if gcloud projects remove-iam-policy-binding "${project}" \
      --member="user:${instructor_email}" \
      --role="${instructor_role}" \
      --quiet >/dev/null; then
      info "Removed binding for instructor ${instructor_email} (${instructor_role})"
    else
      warn "Binding not found or could not remove for instructor ${instructor_email} (${instructor_role})"
    fi
  fi

  info "================ Completed IAM ${label} removal ============="
}

# -----------------
# Destruction runner
# -----------------
destroy_env() {
  local label="$1" tfvars="$2"

  info "==================== Destroying ${label} ===================="

  local project region vpc_name subnet_name
  project="$(tfvar_get "${tfvars}" "project_id" || true)"
  region="$(tfvar_get "${tfvars}" "region" || true)"
  vpc_name="$(tfvar_first "${tfvars}" vpc_name network_name || true)"

  [[ -n "${project}" ]]  || die "project_id not found in ${tfvars}"
  [[ -n "${region}" ]]   || die "region not found in ${tfvars}"
  [[ -n "${vpc_name}" ]] || die "vpc_name (or network_name) not found in ${tfvars}"

  subnet_name="${vpc_name}-subnet"

  ensure_compute_api "${project}"

  delete_subnet_if_exists "${project}" "${region}" "${subnet_name}" || true
  delete_network_if_exists "${project}" "${vpc_name}" || true

  info "================ Completed ${label} destruction ============"
}

# ----
# Main
# ----
main() {
  ensure_prereqs
  ensure_gcloud_user_login
  cd "${PROJECT_DIR}"

  info "gcloud version:"
  gcloud --version | head -n1 | sed 's/^/  /'

  destroy_env "dev" "${ENVS_DIR}/dev.tfvars"
  destroy_env "prod" "${ENVS_DIR}/prd.tfvars"

  destroy_iam_env "dev" "${IAM_ENVS_DIR}/dev.tfvars"
  destroy_iam_env "prod" "${IAM_ENVS_DIR}/prd.tfvars"

  info "All environments destroyed and IAM bindings removed (or already absent)."
}

trap 'err "Script failed on line $LINENO"; exit 1' ERR
main "$@"
