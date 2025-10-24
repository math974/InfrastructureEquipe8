#!/bin/bash

# Script de configuration pour l'environnement de développement
set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    log "Prérequis OK"
}

# Créer le fichier .env s'il n'existe pas
setup_env() {
    if [ ! -f ".env" ]; then
        log "Création du fichier .env..."
        cp env.local .env
        warn "Fichier .env créé. Vous pouvez le modifier selon vos besoins."
    else
        log "Fichier .env existe déjà"
    fi
}

# Construire et démarrer les services
start_services() {
    log "Construction et démarrage des services..."
    
    # Construire l'image de l'application
    log "Construction de l'image de l'application..."
    docker-compose build app
    
    # Démarrer les services
    log "Démarrage des services..."
    docker-compose up -d
    
    log "Services démarrés avec succès"
}

# Vérifier le statut des services
check_services() {
    log "Vérification du statut des services..."
    
    # Attendre que MySQL soit prêt
    log "Attente que MySQL soit prêt..."
    timeout 60 bash -c 'until docker-compose exec mysql mysqladmin ping -h localhost --silent; do sleep 2; done'
    
    # Vérifier l'application
    log "Vérification de l'application..."
    sleep 10
    if curl -f http://localhost:8000/health >/dev/null 2>&1; then
        log "Application accessible sur http://localhost:8000"
    else
        warn "Application pas encore prête, vérifiez les logs avec: docker-compose logs app"
    fi
    
    # Afficher les informations
    info "=== SERVICES DISPONIBLES ==="
    info "Application FastAPI: http://localhost:8000"
    info "Documentation API: http://localhost:8000/docs"
    info "phpMyAdmin: http://localhost:8080"
    info "MySQL: localhost:3306"
    echo ""
    info "=== COMMANDES UTILES ==="
    info "Voir les logs: docker-compose logs -f"
    info "Arrêter: docker-compose down"
    info "Redémarrer: docker-compose restart"
    info "Base de données: docker-compose exec mysql mysql -u app_user -p tasksdb"
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Démarrer tous les services (défaut)"
    echo "  stop      Arrêter tous les services"
    echo "  restart   Redémarrer tous les services"
    echo "  logs      Afficher les logs"
    echo "  status    Afficher le statut des services"
    echo "  clean     Nettoyer les volumes et images"
    echo "  help      Afficher cette aide"
}

# Gestion des commandes
case "${1:-start}" in
    start)
        check_prerequisites
        setup_env
        start_services
        check_services
        ;;
    stop)
        log "Arrêt des services..."
        docker-compose down
        ;;
    restart)
        log "Redémarrage des services..."
        docker-compose restart
        ;;
    logs)
        docker-compose logs -f
        ;;
    status)
        docker-compose ps
        ;;
    clean)
        warn "Nettoyage des volumes et images..."
        docker-compose down -v --rmi all
        ;;
    help)
        show_help
        ;;
    *)
        error "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac
