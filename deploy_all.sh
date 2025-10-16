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
    [ -z "${base_prefix:-}" ] && base_prefix="state"

    # Avoid unnecessary re-init
    if [ ! -d .terraform ] || [ ! -f .terraform/terraform.tfstate ]; then
      log "Running terraform init (first time)"
      TF_WORKSPACE=default "${TF_BIN}" init -input=false -reconfigure \
        -backend-config="${backend_cfg}" \
        -backend-config="prefix=${base_prefix}/${module_suffix}"
    fi

    if ! "${TF_BIN}" workspace select "${env}" >/dev/null 2>&1; then
      log "Creating Terraform workspace: ${env}"
      "${TF_BIN}" workspace new "${env}" >/dev/null
    fi

    tfvars_path="${tfvars_dir}/${env}.tfvars"

    log "Planning environment '${env}' in ${dir}"
    if ! "${TF_BIN}" plan -input=false -detailed-exitcode -var-file="${tfvars_path}" >/tmp/plan_${env}.log 2>&1; then
      code=$?
      if [ $code -eq 2 ]; then
        log "Changes detected; applying Terraform for '${env}'"
        "${TF_BIN}" apply -input=false -auto-approve -var-file="${tfvars_path}"
      elif [ $code -eq 0 ]; then
        log "No changes for '${env}' (skipped)"
      else
        log "ERROR: terraform plan failed for '${env}' — see /tmp/plan_${env}.log"
        cat /tmp/plan_${env}.log >&2
        exit 1
      fi
    fi
  done
}

main() {
  require_bin "${TF_BIN}"
  export TF_IN_AUTOMATION=1

  log "Starting Terraform deployment"

  # Optional: parallel execution
  apply_envs_in_dir "${ROOT_DIR}/netwoks" "envs" &
  apply_envs_in_dir "${ROOT_DIR}/iam" "envs" &
  wait

  log "✅ All environments deployed successfully (fast mode)"
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
