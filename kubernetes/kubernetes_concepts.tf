/**
 * CONCEPTS DE KUBERNETES
 *
 * 2.1 Cluster, Nodes & Control Plane
 *
 * Un Cluster est un ensemble de machines (nodes) gérées ensemble par Kubernetes.
 *
 * Les Nodes sont les machines de travail (VMs ou serveurs physiques) où s'exécutent les pods.
 *
 * Le Control Plane gère l'état du cluster. Composants principaux :
 *
 * API Server (kube-apiserver) : le point d'entrée central pour toutes les commandes et communications.
 *
 * Scheduler : assigne les pods aux nodes en fonction des ressources disponibles et des contraintes.
 *
 * Controller Managers : boucles de réconciliation (s'assurant que les déploiements, replicasets, jobs, etc. correspondent à l'état souhaité).
 *
 * etcd : un magasin de données clé-valeur distribué et cohérent qui contient l'état du cluster.
 */

# Ce fichier contient uniquement de la documentation sur les concepts Kubernetes.
# Il est référencé dans la configuration mais ne crée aucune ressource.

locals {
  kubernetes_concepts = {
    cluster      = "Un ensemble de machines (nodes) gérées ensemble par Kubernetes"
    nodes        = "Les machines de travail où s'exécutent les pods"
    control_plane = {
      api_server         = "Point d'entrée central pour toutes les commandes"
      scheduler          = "Assigne les pods aux nodes selon les ressources"
      controller_manager = "Boucles de réconciliation pour maintenir l'état souhaité"
      etcd               = "Magasin de données clé-valeur pour l'état du cluster"
    }
  }
}

output "kubernetes_concepts_doc" {
  value       = "Ce projet implémente une infrastructure Kubernetes"
  description = "Documentation conceptuelle sur Kubernetes"
}
