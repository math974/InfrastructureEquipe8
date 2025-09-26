#!/usr/bin/env bash

set -euo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# -----------------
# Paths and globals
# -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
ENVS_DIR="${PROJECT_DIR}/envs"

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

# -------------------------
# GCP project/service setup
# -------------------------
ensure_compute_api() {
  local project="$1"
  info "Ensuring Compute API is enabled for project ${project}"
  gcloud services enable compute.googleapis.com --project="${project}" >/dev/null
}

# -----------------
# VPC/Subnet helpers
# -----------------
network_exists() {
  local project="$1" network="$2"
  gcloud compute networks describe "${network}" --project="${project}" --format="value(selfLink)" >/dev/null 2>&1
}

create_network_custom() {
  local project="$1" network="$2"
  info "Creating custom-mode VPC '${network}' in project '${project}'"
  gcloud compute networks create "${network}" --project="${project}" --subnet-mode=custom >/dev/null
}

subnet_exists() {
  local project="$1" region="$2" subnet="$3"
  gcloud compute networks subnets describe "${subnet}" --project="${project}" --region="${region}" --format="value(selfLink)" >/dev/null 2>&1
}

get_subnet_cidr() {
  local project="$1" region="$2" subnet="$3"
  gcloud compute networks subnets describe "${subnet}" \
    --project="${project}" \
    --region="${region}" \
    --format="value(ipCidrRange)" 2>/dev/null | head -n1
}

create_subnet() {
  local project="$1" region="$2" network="$3" subnet="$4" cidr="$5"
  info "Creating subnet '${subnet}' in region '${region}' with range '${cidr}' on network '${network}' (project '${project}')"
  gcloud compute networks subnets create "${subnet}" \
    --project="${project}" \
    --region="${region}" \
    --network="${network}" \
    --range="${cidr}" >/dev/null
}

# -----------------
# Deployment runner
# -----------------
deploy_env() {
  local label="$1" tfvars="$2"

  info "==================== Deploying ${label} ===================="

  local project region network_name ip_range subnet_name
  project="$(tfvar_get "${tfvars}" "project_id" || true)"
  region="$(tfvar_get "${tfvars}" "region" || true)"
  network_name="$(tfvar_get "${tfvars}" "network_name" || true)"
  ip_range="$(tfvar_get "${tfvars}" "ip_range" || true)"

  [[ -n "${project}" ]] || die "project_id not found in ${tfvars}"
  [[ -n "${region}" ]] || die "region not found in ${tfvars}"
  [[ -n "${network_name}" ]] || die "network_name not found in ${tfvars}"
  [[ -n "${ip_range}" ]] || die "ip_range not found in ${tfvars}"

  subnet_name="${network_name}-subnet"

  ensure_compute_api "${project}"

  if network_exists "${project}" "${network_name}"; then
    info "VPC network '${network_name}' already exists in project '${project}'"
  else
    create_network_custom "${project}" "${network_name}"
    info "Created VPC network '${network_name}'"
  fi

  if subnet_exists "${project}" "${region}" "${subnet_name}"; then
    local existing_cidr
    existing_cidr="$(get_subnet_cidr "${project}" "${region}" "${subnet_name}")"
    if [[ "${existing_cidr}" != "${ip_range}" ]]; then
      warn "Subnet '${subnet_name}' already exists with CIDR '${existing_cidr}', which differs from desired '${ip_range}'. Skipping change (CIDR updates require manual migration)."
    else
      info "Subnet '${subnet_name}' already exists with matching CIDR '${existing_cidr}'"
    fi
  else
    create_subnet "${project}" "${region}" "${network_name}" "${subnet_name}" "${ip_range}"
    info "Created subnet '${subnet_name}' in region '${region}'"
  fi

  info "================ Completed ${label} deployment ============="
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

  deploy_env "dev" "${ENVS_DIR}/dev.tfvars"
  deploy_env "prod" "${ENVS_DIR}/prd.tfvars"

  info "All environments deployed successfully."
}

trap 'err "Script failed on line $LINENO"; exit 1' ERR
main "$@"
