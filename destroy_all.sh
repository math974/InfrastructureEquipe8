#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_BIN="${TF_BIN:-terraform}"

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  }
}

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }

destroy_envs_in_dir() {
  local dir="$1"
  local tfvars_dir="$2"

  (
    cd "${dir}"
    for env in prd dev; do
      log "Initializing backend for '${env}' in ${dir}"
      backend_cfg="${ROOT_DIR}/configs/${env}.config"
      module_suffix="$(basename "${dir}")"
      base_prefix="$(awk -F'=' '/^prefix/ { gsub(/[ "]/,"",$2); print $2 }' "${backend_cfg}" 2>/dev/null || true)"
      if [ -z "${base_prefix:-}" ]; then base_prefix="state"; fi
      log "Using backend config file=${backend_cfg} with prefix=${base_prefix}/${module_suffix}"
      if [ -f ".terraform/environment" ]; then
        echo "default" > .terraform/environment || true
      fi
      TF_WORKSPACE=default "${TF_BIN}" init -input=false -reconfigure \
        -backend-config="${backend_cfg}" \
        -backend-config="prefix=${base_prefix}/${module_suffix}"

      if "${TF_BIN}" workspace select "${env}" >/dev/null 2>&1; then
        tfvars_path="${tfvars_dir}/${env}.tfvars"

        # Skip slow Cloud SQL and Service Networking deletion
        log "Removing slow resources from state before destroy (Cloud SQL, service networking)"
        "${TF_BIN}" state rm -force google_sql_database_instance.mysql >/dev/null 2>&1 || true
        "${TF_BIN}" state rm -force google_service_networking_connection.private_vpc_connection >/dev/null 2>&1 || true
        "${TF_BIN}" state rm -force google_compute_global_address.private_ip_address >/dev/null 2>&1 || true

        # Now destroy remaining resources quickly
        log "Destroying environment '${env}' in ${dir} (fast mode)"
        "${TF_BIN}" destroy -input=false -auto-approve -var-file="${tfvars_path}"

        log "NOTE: Cloud SQL instances and private VPC connections were skipped."
        log "You can remove them manually later with:"
        log "  gcloud sql instances delete INSTANCE_NAME --project PROJECT_ID --quiet"
        log "  gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=YOUR_NETWORK"
      else
        log "Workspace '${env}' not found in ${dir}; skipping"
      fi
    done
  )
}

main() {
  require_bin "${TF_BIN}"
  export TF_IN_AUTOMATION=1

  destroy_envs_in_dir "${ROOT_DIR}/netwoks" "envs"

  log "All environments destroyed successfully (fast mode)."
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
