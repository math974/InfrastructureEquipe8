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

test_environment() {
  local env="$1"
  local env_dir="${ROOT_DIR}/environments/${env}"
  local backend_config="${env_dir}/backend.config"

  if [ ! -d "${env_dir}" ]; then
    log "❌ Environnement ${env} non trouvé dans ${env_dir}"
    return 1
  fi

  log "🧪 Test de l'environnement: ${env}"

  cd "${ROOT_DIR}/terraform"

  # 1. Format check
  log "📝 Vérification du format Terraform..."
  if ! "${TF_BIN}" fmt -check -recursive; then
    log "❌ Format Terraform incorrect. Exécutez 'terraform fmt -recursive' pour corriger."
    return 1
  fi
  log "✅ Format Terraform correct"

  # 2. Initialisation
  log "🔧 Initialisation Terraform pour ${env}..."
  "${TF_BIN}" init -backend-config="${backend_config}" -input=false

  # 3. Validation
  log "✅ Validation de la configuration Terraform..."
  if ! "${TF_BIN}" validate; then
    log "❌ Validation Terraform échouée"
    return 1
  fi
  log "✅ Configuration Terraform valide"

  # 4. Plan
  log "📋 Génération du plan d'exécution pour ${env}..."
  if ! "${TF_BIN}" plan -var-file="${env_dir}/terraform.tfvars" -input=false -detailed-exitcode; then
    local exit_code=$?
    if [ $exit_code -eq 1 ]; then
      log "❌ Erreur lors de la génération du plan"
      return 1
    elif [ $exit_code -eq 2 ]; then
      log "⚠️  Plan généré avec des changements détectés"
    fi
  else
    log "✅ Plan généré - Aucun changement détecté"
  fi

  log "✅ Test de ${env} terminé avec succès"
  return 0
}

show_help() {
  cat << EOF
Usage: $0 [dev|prd|all|help]

Script de test local pour l'infrastructure Terraform modulaire.

COMMANDES:
  dev     Test l'environnement de développement
  prd     Test l'environnement de production  
  all     Test tous les environnements
  help    Affiche cette aide

TESTS EFFECTUÉS:
  ✅ Format check (terraform fmt -check)
  ✅ Validation (terraform validate)
  ✅ Plan (terraform plan)
  ❌ Pas d'apply (déploiement via GitHub Actions)

EXEMPLES:
  $0 dev          # Test dev uniquement
  $0 prd          # Test prd uniquement
  $0 all          # Test dev puis prd
  $0 help         # Affiche cette aide

CONFIGURATION REQUISE:
  - Buckets de state configurés dans environments/*/backend.config
  - Variables configurées dans environments/*/terraform.tfvars
EOF
}

main() {
  require_bin "${TF_BIN}"

  export TF_IN_AUTOMATION=1

  if [ $# -eq 0 ]; then
    log "❌ Aucun argument fourni"
    show_help
    exit 1
  fi

  case "$1" in
    "dev")
      test_environment "dev"
      ;;
    "prd")
      test_environment "prd"
      ;;
    "all")
      log "🚀 Test de tous les environnements"
      test_environment "dev" && test_environment "prd"
      ;;
    "help"|"-h"|"--help")
      show_help
      ;;
    *)
      log "❌ Argument non reconnu: $1"
      show_help
      exit 1
      ;;
  esac
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
