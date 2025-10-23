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

apply_envs_in_dir() {
  local dir="$1"
  local tfvars_dir="$2"

  cd "${dir}"

  for env in dev prd; do
    log "Initializing backend for '${env}' in ${dir}"
    backend_cfg="${ROOT_DIR}/configs/${env}.config"
    module_suffix="$(basename "${dir}")"
    base_prefix="$(awk -F'=' '/^prefix/ { gsub(/[ "]/,"",$2); print $2 }' "${backend_cfg}" 2>/dev/null || true)"
    if [ -z "${base_prefix:-}" ]; then base_prefix="state"; fi
    log "Using backend config file=${backend_cfg} with prefix=${base_prefix}/${module_suffix}"
    if [ -f ".terraform/environment" ]; then
      echo "default" > .terraform/environment || true
    fi
    TF_WORKSPACE=default "${TF_BIN}" init -input=false -reconfigure -backend-config="${backend_cfg}" -backend-config="prefix=${base_prefix}/${module_suffix}"

    if ! "${TF_BIN}" workspace select "${env}" >/dev/null 2>&1; then
      log "Creating Terraform workspace: ${env}"
      "${TF_BIN}" workspace new "${env}" >/dev/null
    fi
    tfvars_path="${tfvars_dir}/${env}.tfvars"

    log "Applying environment '${env}' in ${dir}"
    "${TF_BIN}" apply -input=false -auto-approve -var-file="${tfvars_path}"
  done
}

main() {
  require_bin "${TF_BIN}"

  export TF_IN_AUTOMATION=1

  apply_envs_in_dir "${ROOT_DIR}/netwoks" "envs"

  apply_envs_in_dir "${ROOT_DIR}/iam" "envs"

  apply_envs_in_dir "${ROOT_DIR}/kubernetes" "envs"

  log "All environments deployed successfully for netwoks, iam, and kubernetes."
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"