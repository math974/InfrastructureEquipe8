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
      TF_WORKSPACE=default "${TF_BIN}" init -input=false -reconfigure -backend-config="${backend_cfg}" -backend-config="prefix=${base_prefix}/${module_suffix}"

      if "${TF_BIN}" workspace select "${env}" >/dev/null 2>&1; then
        tfvars_path="${tfvars_dir}/${env}.tfvars"
        if [ "${module_suffix}" = "netwoks" ]; then
          project_id="$(awk -F'=' '/^[[:space:]]*project_id[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2}' "${tfvars_path}" 2>/dev/null || true)"
          region="$(awk -F'=' '/^[[:space:]]*region[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2}' "${tfvars_path}" 2>/dev/null || true)"
          network_name="$(awk -F'=' '/^[[:space:]]*network_name[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2}' "${tfvars_path}" 2>/dev/null || true)"
          log "Import check (netwoks): env=${env} project_id='${project_id:-}' region='${region:-}' network_name='${network_name:-}' tfvars='${tfvars_path}'"
          if [ -n "${project_id:-}" ] && [ -n "${network_name:-}" ]; then
            net_id="projects/${project_id}/global/networks/${network_name}"
            sub_id=""
            if [ -n "${region:-}" ]; then
              sub_id="projects/${project_id}/regions/${region}/subnetworks/${network_name}-subnet"
            fi
            if ! "${TF_BIN}" state list | grep -q '^google_compute_network\.main$'; then
              log "State missing google_compute_network.main; attempting import ${net_id}"
              "${TF_BIN}" import -var-file="${tfvars_path}" google_compute_network.main "${net_id}" || log "Network import skipped/failed"
            fi
            if [ -n "${sub_id}" ] && ! "${TF_BIN}" state list | grep -q '^google_compute_subnetwork\.main$'; then
              log "State missing google_compute_subnetwork.main; attempting import ${sub_id}"
              "${TF_BIN}" import -var-file="${tfvars_path}" google_compute_subnetwork.main "${sub_id}" || log "Subnet import skipped/failed"
            fi
          fi
        fi
        log "Destroying environment '${env}' in ${dir}"
        "${TF_BIN}" destroy -input=false -auto-approve -var-file="${tfvars_path}"
        if [ "${module_suffix}" = "iam" ]; then
          project_id_cleanup="$(awk -F'=' '/^[[:space:]]*project_id[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2}' "${tfvars_path}" 2>/dev/null || true)"
          current_acct="$(gcloud config get-value account 2>/dev/null | tr -d '[:space:]')"
          if [ -n "${project_id_cleanup:-}" ] && [ -n "${current_acct:-}" ]; then
            for role in roles/editor roles/viewer; do
              members="$(gcloud projects get-iam-policy "${project_id_cleanup}" --flatten="bindings[].members" --filter="bindings.role=${role}" --format="value(bindings.members)" 2>/dev/null || true)"
              if [ -n "${members:-}" ]; then
                for m in ${members}; do
                  if [[ "${m}" == user:* && "${m}" != "user:${current_acct}" ]]; then
                    log "Removing ${role} for member ${m} on project ${project_id_cleanup}"
                    gcloud projects remove-iam-policy-binding "${project_id_cleanup}" --member="${m}" --role="${role}" --quiet >/dev/null 2>&1 || true
                  fi
                done
              fi
            done
          else
            log "Skipping IAM prune: missing project_id or current gcloud account"
          fi
        fi
      else
        log "Workspace '${env}' not found in ${dir}; skipping"
      fi
    done
  )
}

main() {
  require_bin "${TF_BIN}"
  require_bin "gcloud"
  export TF_IN_AUTOMATION=1

  destroy_envs_in_dir "${ROOT_DIR}/iam" "envs"

  destroy_envs_in_dir "${ROOT_DIR}/netwoks" "envs"

  log "All environments destroyed successfully for iam and netwoks."
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
