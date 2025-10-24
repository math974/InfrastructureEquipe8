-- Script d'initialisation de la base de données
-- Ce script est exécuté automatiquement lors du premier démarrage de MySQL

-- Créer la base de données si elle n'existe pas
CREATE DATABASE IF NOT EXISTS tasksdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Utiliser la base de données
USE tasksdb;

-- Afficher un message de confirmation
SELECT 'Base de données tasksdb créée avec succès!' as message;
