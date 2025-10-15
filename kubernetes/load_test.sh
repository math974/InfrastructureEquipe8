#!/bin/bash

# =============================================================================
# SCRIPT DE LOAD TESTING POUR LA DÉFENSE DU PROJET
# Fichier : load_test.sh
#
# Ce script génère de la charge sur votre application Task Manager pour
# démontrer le scaling horizontal (HPA + Cluster Autoscaler) selon les
# exigences du Cours 7.
#
# Utilisation :
#   chmod +x load_test.sh
#   ./load_test.sh <LOAD_BALANCER_IP>
#
# Exemple :
#   ./load_test.sh 34.155.123.45
# =============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOAD_BALANCER_IP=${1:-""}
CONCURRENT_REQUESTS=50
DURATION=300  # 5 minutes
REQUEST_RATE=10  # Requêtes par seconde

# Fonction d'affichage
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Vérification des prérequis
check_prerequisites() {
    print_header "Vérification des prérequis"
    
    # Vérifier kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl n'est pas installé"
        exit 1
    fi
    print_success "kubectl installé"
    
    # Vérifier l'accès au cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Impossible de se connecter au cluster Kubernetes"
        print_info "Exécutez : gcloud container clusters get-credentials <cluster-name> --region <region>"
        exit 1
    fi
    print_success "Accès au cluster Kubernetes OK"
    
    # Vérifier si l'IP du Load Balancer est fournie
    if [ -z "$LOAD_BALANCER_IP" ]; then
        print_warning "IP du Load Balancer non fournie"
        print_info "Récupération automatique de l'IP..."
        
        # Essayer de récupérer l'IP du service
        LOAD_BALANCER_IP=$(kubectl get svc task-manager-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -z "$LOAD_BALANCER_IP" ]; then
            print_error "Impossible de récupérer l'IP du Load Balancer"
            print_info "Utilisage : $0 <LOAD_BALANCER_IP>"
            print_info "Ou exécutez : kubectl get svc task-manager-service"
            exit 1
        fi
    fi
    
    print_success "Load Balancer IP : $LOAD_BALANCER_IP"
    echo ""
}

# Afficher l'état initial
show_initial_state() {
    print_header "État initial du cluster"
    
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -l app=task-manager
    echo ""
    
    echo -e "${YELLOW}HPA:${NC}"
    kubectl get hpa task-manager-hpa
    echo ""
    
    echo -e "${YELLOW}Nœuds:${NC}"
    kubectl get nodes
    echo ""
}

# Lancer les observateurs en arrière-plan
start_watchers() {
    print_header "Lancement des observateurs"
    
    # Créer un répertoire pour les logs
    LOG_DIR="./load_test_logs_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
    
    print_info "Les logs seront enregistrés dans : $LOG_DIR"
    
    # Observer les pods
    kubectl get pods -l app=task-manager -w > "$LOG_DIR/pods.log" 2>&1 &
    PODS_PID=$!
    print_success "Observateur de pods démarré (PID: $PODS_PID)"
    
    # Observer le HPA
    kubectl get hpa task-manager-hpa -w > "$LOG_DIR/hpa.log" 2>&1 &
    HPA_PID=$!
    print_success "Observateur HPA démarré (PID: $HPA_PID)"
    
    # Observer les nœuds
    kubectl get nodes -w > "$LOG_DIR/nodes.log" 2>&1 &
    NODES_PID=$!
    print_success "Observateur de nœuds démarré (PID: $NODES_PID)"
    
    echo ""
}

# Générer la charge
generate_load() {
    print_header "Génération de charge"
    
    print_warning "Génération de $CONCURRENT_REQUESTS requêtes concurrentes pendant $DURATION secondes"
    print_info "URL cible : http://$LOAD_BALANCER_IP"
    print_info "Appuyez sur Ctrl+C pour arrêter"
    echo ""
    
    # Utiliser Apache Bench si disponible
    if command -v ab &> /dev/null; then
        print_info "Utilisation d'Apache Bench (ab)"
        ab -n $((DURATION * REQUEST_RATE)) -c $CONCURRENT_REQUESTS -t $DURATION "http://$LOAD_BALANCER_IP/" 2>&1 | tee "$LOG_DIR/load_test.log"
    # Sinon utiliser curl en boucle
    else
        print_info "Apache Bench non disponible, utilisation de curl"
        print_warning "Pour de meilleurs résultats, installez Apache Bench : apt-get install apache2-utils"
        
        END_TIME=$(($(date +%s) + DURATION))
        REQUEST_COUNT=0
        
        while [ $(date +%s) -lt $END_TIME ]; do
            for i in $(seq 1 $CONCURRENT_REQUESTS); do
                curl -s -o /dev/null -w "%{http_code}\n" "http://$LOAD_BALANCER_IP/" >> "$LOG_DIR/load_test.log" 2>&1 &
            done
            REQUEST_COUNT=$((REQUEST_COUNT + CONCURRENT_REQUESTS))
            echo -ne "\rRequêtes envoyées : $REQUEST_COUNT"
            sleep 1
        done
        echo ""
    fi
    
    print_success "Génération de charge terminée"
    echo ""
}

# Afficher l'état final
show_final_state() {
    print_header "État final du cluster"
    
    print_info "Attente de 10 secondes pour la stabilisation..."
    sleep 10
    
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -l app=task-manager
    echo ""
    
    echo -e "${YELLOW}HPA:${NC}"
    kubectl get hpa task-manager-hpa
    echo ""
    
    echo -e "${YELLOW}Nœuds:${NC}"
    kubectl get nodes
    echo ""
}

# Nettoyer les processus en arrière-plan
cleanup() {
    print_header "Nettoyage"
    
    if [ ! -z "$PODS_PID" ]; then
        kill $PODS_PID 2>/dev/null || true
        print_success "Observateur de pods arrêté"
    fi
    
    if [ ! -z "$HPA_PID" ]; then
        kill $HPA_PID 2>/dev/null || true
        print_success "Observateur HPA arrêté"
    fi
    
    if [ ! -z "$NODES_PID" ]; then
        kill $NODES_PID 2>/dev/null || true
        print_success "Observateur de nœuds arrêté"
    fi
    
    # Tuer tous les processus curl en arrière-plan
    pkill -P $$ curl 2>/dev/null || true
}

# Afficher le rapport
show_report() {
    print_header "Rapport de Load Testing"
    
    echo -e "${YELLOW}Fichiers de log générés :${NC}"
    ls -lh "$LOG_DIR"
    echo ""
    
    echo -e "${YELLOW}Nombre de pods avant/après :${NC}"
    INITIAL_PODS=$(head -n 2 "$LOG_DIR/pods.log" | tail -n 1 | wc -l)
    FINAL_PODS=$(tail -n 1 "$LOG_DIR/pods.log" | wc -l)
    echo "Initial: ~$INITIAL_PODS | Final: ~$FINAL_PODS"
    echo ""
    
    print_success "Test de load terminé avec succès !"
    print_info "Pour votre défense, montrez :"
    echo "  1. L'augmentation du nombre de pods (HPA)"
    echo "  2. L'ajout de nouveaux nœuds (Cluster Autoscaler)"
    echo "  3. Les logs dans $LOG_DIR"
    echo "  4. Les métriques CPU/mémoire avec : kubectl top pods"
    echo ""
}

# Gestionnaire de signaux pour nettoyer proprement
trap cleanup EXIT INT TERM

# Programme principal
main() {
    clear
    print_header "LOAD TESTING - KUBERNETES CLUSTER"
    echo ""
    
    check_prerequisites
    show_initial_state
    start_watchers
    
    sleep 3  # Laisser les watchers se stabiliser
    
    generate_load
    show_final_state
    show_report
}

# Exécuter le programme principal
main


