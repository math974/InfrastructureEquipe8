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

deploy_environment() {
  local env="$1"
  local env_dir="${ROOT_DIR}/environments/${env}"
  local backend_config="${env_dir}/backend.config"

  if [ ! -d "${env_dir}" ]; then
    log "❌ Environnement ${env} non trouvé dans ${env_dir}"
    exit 1
  fi

  log "🚀 Déploiement de l'environnement: ${env}"

  cd "${ROOT_DIR}/terraform"

  # Initialiser Terraform
  log "🔧 Initialisation Terraform pour ${env}..."
  "${TF_BIN}" init -backend-config="${backend_config}"

  # Sélectionner l'espace de travail
  if ! "${TF_BIN}" workspace select "${env}" >/dev/null 2>&1; then
    log "📝 Création de l'espace de travail: ${env}"
    "${TF_BIN}" workspace new "${env}" >/dev/null
  fi

  # Plan et Apply
  log "📋 Plan d'exécution pour ${env}..."
  "${TF_BIN}" plan -var-file="${env_dir}/terraform.tfvars"

  log "🚀 Application des changements pour ${env}..."
  "${TF_BIN}" apply -auto-approve -var-file="${env_dir}/terraform.tfvars"

  log "✅ Déploiement de ${env} terminé"
}

main() {
  require_bin "${TF_BIN}"

  export TF_IN_AUTOMATION=1

  if [ $# -eq 0 ]; then
    log "Usage: $0 [dev|prd|all]"
    exit 1
  fi

  case "$1" in
    "dev"|"prd")
      deploy_environment "$1"
      ;;
    "all")
      deploy_environment "dev"
      deploy_environment "prd"
      ;;
    *)
      log "❌ Environnement non supporté: $1"
      log "Environnements supportés: dev, prd, all"
      exit 1
      ;;
  esac
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
