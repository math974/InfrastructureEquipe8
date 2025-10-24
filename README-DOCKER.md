# Docker Compose - Environnement de Développement

Ce guide explique comment utiliser Docker Compose pour l'environnement de développement local.

## 🚀 Démarrage rapide

### 1. Configuration initiale

```bash
# Copier le fichier de configuration
cp env.local .env

# Modifier les valeurs selon vos besoins (optionnel)
nano .env
```

### 2. Démarrer les services

```bash
# Démarrer tous les services
docker-compose up -d

# Ou utiliser le script d'aide
./scripts/dev-setup.sh start
```

### 3. Vérifier les services

```bash
# Vérifier le statut
docker-compose ps

# Voir les logs
docker-compose logs -f
```

## 📋 Services disponibles

| Service | URL | Description |
|---------|-----|-------------|
| **Application FastAPI** | http://localhost:8000 | API principale |
| **Documentation API** | http://localhost:8000/docs | Swagger UI |
| **phpMyAdmin** | http://localhost:8080 | Interface MySQL |
| **MySQL** | localhost:3306 | Base de données |

## ⚙️ Configuration

### Variables d'environnement (.env)

```bash
# Base de données MySQL
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=tasksdb
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password

# Configuration de l'application
DB_HOST=mysql
DB_PORT=3306
DB_NAME=tasksdb
DB_USER=app_user
DB_PASSWORD=app_password

# Ports
APP_PORT=8000
MYSQL_PORT=3306
PHPMYADMIN_PORT=8080
```

## 🛠️ Commandes utiles

### Gestion des services

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Redémarrer
docker-compose restart

# Voir les logs
docker-compose logs -f [service]

# Statut des services
docker-compose ps
```

### Base de données

```bash
# Se connecter à MySQL
docker-compose exec mysql mysql -u app_user -p tasksdb

# Sauvegarder la base
docker-compose exec mysql mysqldump -u app_user -p tasksdb > backup.sql

# Restaurer la base
docker-compose exec -T mysql mysql -u app_user -p tasksdb < backup.sql
```

### Application

```bash
# Voir les logs de l'app
docker-compose logs -f app

# Redémarrer l'app
docker-compose restart app

# Exécuter des commandes dans l'app
docker-compose exec app bash
```

## 🧹 Nettoyage

```bash
# Arrêter et supprimer les conteneurs
docker-compose down

# Supprimer aussi les volumes (ATTENTION: perte de données)
docker-compose down -v

# Supprimer les images
docker-compose down --rmi all

# Nettoyage complet
./scripts/dev-setup.sh clean
```

## 🔧 Dépannage

### Problèmes courants

1. **Port déjà utilisé**
   ```bash
   # Changer le port dans .env
   APP_PORT=8001
   ```

2. **Base de données non accessible**
   ```bash
   # Vérifier que MySQL est prêt
   docker-compose logs mysql
   ```

3. **Application ne démarre pas**
   ```bash
   # Vérifier les logs
   docker-compose logs app
   
   # Reconstruire l'image
   docker-compose build app
   ```

### Logs utiles

```bash
# Tous les services
docker-compose logs -f

# Service spécifique
docker-compose logs -f app
docker-compose logs -f mysql

# Dernières 100 lignes
docker-compose logs --tail=100 app
```

## 📊 Monitoring

### Health checks

```bash
# Vérifier la santé des services
docker-compose ps

# Tester l'API
curl http://localhost:8000/health

# Tester MySQL
docker-compose exec mysql mysqladmin ping -h localhost
```

### Ressources

```bash
# Utilisation des ressources
docker stats

# Espace disque
docker system df
```

## 🔄 Développement

### Rebuild après modification

```bash
# Reconstruire l'application
docker-compose build app

# Redémarrer avec la nouvelle image
docker-compose up -d app
```

### Debug

```bash
# Mode interactif
docker-compose exec app bash

# Voir les variables d'environnement
docker-compose exec app env
```

## 📝 Notes importantes

- Le fichier `.env` est ignoré par Git pour la sécurité
- Les données MySQL sont persistantes dans le volume `mysql_data`
- L'application se connecte automatiquement à MySQL au démarrage
- phpMyAdmin est optionnel et peut être désactivé si non nécessaire
