#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }

cleanup_old_configs() {
  log "🧹 Nettoyage des anciens fichiers de configuration obsolètes"

  # Fichiers de configuration backend obsolètes
  local old_configs=(
    "configs/dev.config"
    "configs/prd.config"
    "configs/kubernetes-dev.config"
    "configs/kubernetes-prd.config"
  )

  for config in "${old_configs[@]}"; do
    if [ -f "${ROOT_DIR}/${config}" ]; then
      log "🗑️  Suppression de ${config}"
      rm "${ROOT_DIR}/${config}"
    else
      log "ℹ️  ${config} n'existe pas (déjà supprimé)"
    fi
  done

  log "✅ Nettoyage terminé"
  log ""
  log "📋 Configuration actuelle :"
  log "  ✅ environments/dev/backend.config     (pour l'infra modulaire dev)"
  log "  ✅ environments/prd/backend.config     (pour l'infra modulaire prd)"
  log "  ✅ configs/bootstrap-wif-dev.config    (pour bootstrap-wif dev)"
  log "  ✅ configs/bootstrap-wif-prd.config    (pour bootstrap-wif prd)"
  log ""
  log "🎯 Utilisation :"
  log "  • Test local : ./test-local.sh dev"
  log "  • Déploiement : via GitHub Actions (pas d'apply local)"
}

main() {
  if [ $# -eq 0 ]; then
    cleanup_old_configs
  else
    case "$1" in
      "help"|"-h"|"--help")
        cat << EOF
Usage: $0 [help]

Script de nettoyage des anciens fichiers de configuration.

SUPPRIME:
  ❌ configs/dev.config
  ❌ configs/prd.config  
  ❌ configs/kubernetes-dev.config
  ❌ configs/kubernetes-prd.config

GARDE:
  ✅ environments/dev/backend.config
  ✅ environments/prd/backend.config
  ✅ configs/bootstrap-wif-dev.config
  ✅ configs/bootstrap-wif-prd.config

EXEMPLE:
  $0          # Nettoie les anciens configs
  $0 help     # Affiche cette aide
EOF
        ;;
      *)
        log "❌ Argument non reconnu: $1"
        log "Utilisez '$0 help' pour voir l'aide"
        exit 1
        ;;
    esac
  fi
}

trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
main "$@"
