#!/usr/bin/env bash
set -euo pipefail

# Script de migration vers l'architecture modulaire
# Ce script aide à migrer de l'architecture séparée vers l'architecture modulaire

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }

log "🚀 Migration vers l'architecture modulaire Terraform"

# 1. Créer la structure des environnements
log "📁 Création de la structure des environnements..."
mkdir -p "${ROOT_DIR}/environments/dev"
mkdir -p "${ROOT_DIR}/environments/prd"

# 2. Copier les fichiers de configuration existants
log "📋 Copie des configurations existantes..."

# Configuration dev
if [ -f "${ROOT_DIR}/netwoks/envs/dev.tfvars" ]; then
    cp "${ROOT_DIR}/netwoks/envs/dev.tfvars" "${ROOT_DIR}/environments/dev/terraform.tfvars"
    log "✅ Configuration dev copiée"
fi

# Configuration prd
if [ -f "${ROOT_DIR}/netwoks/envs/prd.tfvars" ]; then
    cp "${ROOT_DIR}/netwoks/envs/prd.tfvars" "${ROOT_DIR}/environments/prd/terraform.tfvars"
    log "✅ Configuration prd copiée"
fi

# 3. Créer les fichiers de configuration backend
log "🔧 Création des configurations backend..."

cat > "${ROOT_DIR}/environments/dev/backend.config" << EOF
bucket = "your-terraform-state-bucket"
prefix = "state/dev"
EOF

cat > "${ROOT_DIR}/environments/prd/backend.config" << EOF
bucket = "your-terraform-state-bucket"
prefix = "state/prd"
EOF

# 4. Créer un nouveau script de déploiement
log "📝 Création du nouveau script de déploiement..."

cat > "${ROOT_DIR}/deploy-modular.sh" << 'EOF'
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
EOF

chmod +x "${ROOT_DIR}/deploy-modular.sh"

# 5. Créer un guide de migration
log "📖 Création du guide de migration..."

cat > "${ROOT_DIR}/MIGRATION_GUIDE.md" << 'EOF'
# Guide de Migration vers l'Architecture Modulaire

## 🎯 Avantages de la nouvelle architecture

### ✅ **Avantages de l'approche modulaire :**

1. **Gestion des dépendances** : Terraform gère automatiquement les dépendances entre modules
2. **Réutilisabilité** : Les modules peuvent être réutilisés dans différents environnements
3. **Isolation** : Chaque module a ses propres variables et outputs
4. **Maintenance** : Plus facile de maintenir et tester individuellement
5. **State management** : Un seul state file par environnement
6. **DRY (Don't Repeat Yourself)** : Évite la duplication de code

### ❌ **Inconvénients de l'approche séparée :**

1. **Gestion manuelle des dépendances** : Doit gérer l'ordre de déploiement manuellement
2. **Duplication de code** : Configuration répétée entre environnements
3. **State files multiples** : Plus difficile à gérer
4. **Complexité de déploiement** : Scripts plus complexes

## 🚀 Migration

### Étape 1 : Préparer la migration
```bash
# Exécuter le script de migration
./migrate-to-modules.sh
```

### Étape 2 : Configurer les variables
Éditer les fichiers dans `environments/` :
- `environments/dev/terraform.tfvars`
- `environments/prd/terraform.tfvars`

### Étape 3 : Migrer le state
```bash
# Pour chaque module existant, importer le state
cd terraform
terraform init -backend-config=environments/dev/backend.config

# Importer les ressources existantes (exemple pour le réseau)
terraform import module.network.google_compute_network.main projects/YOUR_PROJECT/global/networks/vpc-dev
terraform import module.network.google_compute_subnetwork.main projects/YOUR_PROJECT/regions/europe-west9/subnetworks/subnet-dev
```

### Étape 4 : Déployer avec la nouvelle architecture
```bash
# Déploiement dev
./deploy-modular.sh dev

# Déploiement prd
./deploy-modular.sh prd

# Déploiement complet
./deploy-modular.sh all
```

## 📁 Nouvelle structure

```
InfrastructureEquipe8/
├── terraform/                    # Configuration principale
│   ├── main.tf                  # Appel des modules
│   ├── variables.tf             # Variables globales
│   ├── outputs.tf               # Outputs globaux
│   └── modules/                 # Modules réutilisables
│       ├── network/             # Module réseau
│       ├── iam/                 # Module IAM
│       ├── kubernetes/          # Module Kubernetes
│       └── bootstrap-wif/       # Module WIF
├── environments/                 # Configuration par environnement
│   ├── dev/
│   │   ├── terraform.tfvars     # Variables dev
│   │   └── backend.config       # Backend dev
│   └── prd/
│       ├── terraform.tfvars     # Variables prd
│       └── backend.config       # Backend prd
├── deploy-modular.sh            # Script de déploiement modulaire
└── kubernetes/simple-app/       # Application (inchangé)
```

## 🔄 Comparaison des approches

| Aspect | Approche séparée | Approche modulaire |
|--------|------------------|-------------------|
| **Dépendances** | Gestion manuelle | Automatique |
| **Réutilisabilité** | Faible | Élevée |
| **Maintenance** | Complexe | Simple |
| **State files** | Multiples | Un par environnement |
| **Tests** | Difficile | Facile |
| **Documentation** | Dispersée | Centralisée |

## 🎯 Recommandation

**Utilisez l'approche modulaire** pour :
- Projets de production
- Équipes multiples
- Environnements multiples
- Maintenance à long terme

**Gardez l'approche séparée** pour :
- Prototypage rapide
- Projets très simples
- Équipes très petites
EOF

log "✅ Migration terminée !"
log ""
log "📋 Prochaines étapes :"
log "1. Configurer les variables dans environments/dev/terraform.tfvars et environments/prd/terraform.tfvars"
log "2. Configurer les buckets de state dans environments/*/backend.config"
log "3. Migrer les states existants (voir MIGRATION_GUIDE.md)"
log "4. Tester avec: ./deploy-modular.sh dev"
log ""
log "📖 Consultez MIGRATION_GUIDE.md pour plus de détails"
