# Cahier des Charges — Inception

**Version :** 1.0
**Date :** 01/07/2026
**Auteur(s) :** kebertra
**Statut :** Brouillon

---

## Sommaire

1. [Présentation du projet](#1-présentation-du-projet)
2. [Périmètre fonctionnel](#2-périmètre-fonctionnel)
3. [Exigences techniques](#3-exigences-techniques)
4. [Architecture et intégrations](#4-architecture-et-intégrations)
5. [Livrables et planning](#5-livrables-et-planning)
6. [Contraintes et hypothèses](#6-contraintes-et-hypothèses)
7. [Critères de recette](#7-critères-de-recette)
8. [Annexes](#8-annexes)

---

## 1. Présentation du projet

### 1.1 Contexte

Ce projet s'inscrit dans le cursus 42, module « System Administration ». L'objectif pédagogique est de mettre en pratique des compétences de conception et d'orchestration d'infrastructures conteneurisées avec Docker, en s'affranchissant des images pré-construites (DockerHub) pour forcer la compréhension fine de chaque service (serveur web, CMS, base de données).

> Contrairement à un cahier des charges d'entreprise classique, il n'y a pas de client externe : le « commanditaire » est ici le référentiel pédagogique 42 (sujet officiel), et la recette finale est assurée par une évaluation entre pairs (peer-evaluation) suivie d'une soutenance.

Le besoin métier est donc simulé : créer un site WordPress fonctionnel, sécurisé et persistant, exposé via un unique point d'entrée HTTPS, en respectant des contraintes strictes d'architecture (un service = un conteneur = une image construite maison).

### 1.2 Objectifs

- **Objectif 1 :** Construire une infrastructure Docker Compose de 3 services (NGINX, WordPress + php-fpm, MariaDB) entièrement conteneurisée, avec des Dockerfiles écrits soi-même (pas d'images toutes faites, hors Alpine/Debian).
- **Objectif 2 :** Garantir la persistance des données (base de données et fichiers WordPress) via des volumes Docker nommés stockés dans `/home/kebertra/data`.
- **Objectif 3 :** Sécuriser l'accès à l'infrastructure : un seul point d'entrée (NGINX, port 443, TLS 1.2/1.3), gestion des secrets hors dépôt Git, séparation stricte des responsabilités entre conteneurs.
- **Objectif 4 (bonus) :** Étendre l'infrastructure avec des services complémentaires réalistes (cache, transfert de fichiers, site vitrine, interface d'administration de base de données, supervision).
- **Objectif 5 (transverse) :** Documenter le projet pour qu'il soit compréhensible et réplicable par un tiers (README, documentation utilisateur, documentation développeur).

### 1.3 Vision

> « Permettre à un développeur ou un correcteur de déployer, en une seule commande (`make`), un site WordPress complet, résilient et sécurisé, sur un nom de domaine local dédié (`kebertra.42.fr`), sans jamais manipuler de mot de passe en clair. »

### 1.4 Parties prenantes

Le projet étant réalisé en solo dans un cadre pédagogique, le tableau ci-dessous remplace la notion classique de « client / équipe projet » par les rôles réellement impliqués dans le cycle de vie du projet.

| Rôle | Nom | Responsabilité |
|------|-----|----------------|
| Porteur du projet (dev unique) | kebertra | Conception, développement, tests, documentation, soutenance |
| Référentiel d'évaluation | Sujet officiel 42 « Inception » v5.3 | Définition des exigences obligatoires et des critères de recette |
| Évaluateurs | Pairs 42 (peer-evaluation) | Vérification du respect du sujet, questions de compréhension, modification live |
| Utilisateur final simulé | Visiteur / administrateur du site WordPress | Test fonctionnel du site déployé |

*Note : il n'y a pas de « commanditaire » au sens commercial ni de budget alloué — ces notions, non pertinentes dans ce contexte pédagogique, ont été retirées du présent document (cf. section 6).*

---

## 2. Périmètre fonctionnel

### 2.1 Fonctionnalités — Méthode MoSCoW

**Must have (indispensable — partie obligatoire du sujet)**
- [ ] VM VirtualBox dédiée au projet (Debian 13)
- [ ] `docker-compose.yml` + `Makefile` à la racine, dossier `srcs/` contenant toute la configuration
- [ ] Un Dockerfile par service, construit depuis Debian 12 (Bookworm) — aucune image finale tirée de DockerHub
- [ ] Conteneur NGINX : unique point d'entrée, port 443 uniquement, TLS 1.2/1.3 exclusivement
- [ ] Conteneur WordPress + php-fpm (sans NGINX à l'intérieur), configuré automatiquement (pas d'installation manuelle via navigateur)
- [ ] Conteneur MariaDB (sans NGINX à l'intérieur), avec 2 utilisateurs dont un administrateur au nom conforme (sans « admin »/« administrator »)
- [ ] 2 volumes Docker nommés (DB + fichiers WordPress), stockés dans `/home/kebertra/data`, sans bind mount
- [ ] Réseau Docker dédié (pas de `network: host`, pas de `--link`)
- [ ] Redémarrage automatique des conteneurs en cas de crash (`restart: on-failure` ou équivalent — hors boucle infinie/patch hacky)
- [ ] Domaine local `kebertra.42.fr` résolu vers l'IP de la VM
- [ ] Secrets exclus du code (`.env` + Docker secrets), aucun mot de passe en dur dans les Dockerfiles
- [ ] Pas de tag `latest` sur les images
- [ ] README.md, USER_DOC.md, DEV_DOC.md conformes aux exigences du sujet

**Should have (important — attendu pour une infrastructure de qualité, non explicitement noté mais implicite)**
- [ ] Healthchecks Docker Compose sur chaque service pour fiabiliser les dépendances de démarrage
- [ ] Logs structurés et accessibles pour le débogage
- [ ] `.dockerignore` par service pour limiter le contexte de build

**Could have (souhaitable — partie bonus, entièrement retenue selon décision projet)**
- [ ] Cache Redis pour WordPress
- [ ] Serveur FTP pointant vers le volume WordPress
- [ ] Site statique vitrine (hors PHP)
- [ ] Adminer (administration MariaDB via interface web)
- [ ] Service libre : supervision/monitoring (voir 2.4 pour l'arbitrage)

**Won't have (hors périmètre)**
- Haute disponibilité multi-nœuds / répartition de charge (hors périmètre pédagogique du sujet)
- Certificats TLS signés par une autorité publique (un certificat auto-signé suffit en environnement local)
- Déploiement en environnement de production réel / accessible publiquement

### 2.2 User Stories

| ID | Rôle | Action souhaitée | Bénéfice | Priorité |
|----|------|-----------------|----------|----------|
| US-01 | Développeur | Lancer `make` à la racine du projet | Construire et démarrer toute l'infrastructure en une commande | Must |
| US-02 | Visiteur | Accéder à `https://kebertra.42.fr` | Consulter le site WordPress via une connexion chiffrée | Must |
| US-03 | Administrateur | Se connecter à `/wp-admin` avec un compte non nommé « admin » | Administrer le contenu du site en toute sécurité | Must |
| US-04 | Correcteur | Redémarrer un conteneur manuellement (`docker kill`) | Vérifier qu'il redémarre automatiquement | Must |
| US-05 | Développeur | Modifier un article WordPress puis relancer la stack | Constater que les données ont persisté (volumes) | Must |
| US-06 | Développeur | Consulter `/home/kebertra/data` | Vérifier que les volumes nommés stockent bien les données à l'emplacement imposé | Must |
| US-07 | Administrateur | Gérer les fichiers du site via un client FTP | Uploader/modifier des médias sans passer par le conteneur | Could (bonus) |
| US-08 | Développeur | Consulter Adminer | Inspecter/modifier la base de données sans CLI | Could (bonus) |
| US-09 | Développeur | Consulter un tableau de bord de supervision | Visualiser l'état de santé des conteneurs et ressources VM | Could (bonus) |
| US-10 | Visiteur | Charger une page WordPress déjà visitée | Bénéficier d'un temps de réponse réduit grâce au cache Redis | Could (bonus) |

### 2.3 Cas d'usage principaux

**Cas d'usage 1 : Démarrage complet de l'infrastructure**

1. Le développeur exécute `make` à la racine du dépôt.
2. Le Makefile crée les répertoires de données sur l'hôte (si absents) et invoque `docker compose up --build -d` sur `srcs/docker-compose.yml`.
3. Docker Compose construit successivement les images `mariadb`, `wordpress`, `nginx` (et les images bonus), en lisant les variables du fichier `.env` et les secrets du dossier `secrets/`.
4. Chaque conteneur démarre dans l'ordre de ses dépendances (MariaDB → WordPress → NGINX), avec des scripts d'entrée (`entrypoint.sh`) qui configurent le service au premier lancement (création de la base, installation WP-CLI headless, génération du certificat TLS).
5. Le développeur peut accéder au site via `https://kebertra.42.fr`.

*Cas d'erreur :* si une variable obligatoire est absente du `.env`, le conteneur concerné doit échouer explicitement au démarrage avec un message clair, plutôt que de démarrer dans un état incohérent (cf. exigence « pas de patch hacky », section 3.3).

**Cas d'usage 2 : Résilience en cas de crash**

1. Le correcteur tue volontairement le conteneur WordPress (`docker kill wordpress`).
2. Docker, configuré avec une politique de redémarrage (`restart: unless-stopped` ou `on-failure`), relance automatiquement le conteneur.
3. Le service redevient accessible sans intervention manuelle, et les données (base + fichiers) restent intactes grâce aux volumes nommés.

**Cas d'usage 3 : Gestion des secrets**

1. Au build, aucun mot de passe n'est présent en dur dans un Dockerfile.
2. Les mots de passe de la base de données (utilisateur applicatif, root, admin WordPress) sont stockés dans des fichiers sous `secrets/` (ex. `db_password.txt`), montés en Docker secrets dans les conteneurs concernés.
3. Le fichier `.env` ne contient que des paramètres non sensibles (noms d'utilisateurs, nom de domaine, noms de bases) ainsi que les *chemins* vers les fichiers de secrets.
4. `.gitignore` exclut `secrets/` et `.env` du dépôt versionné ; seuls des fichiers `.env.example` / `secrets/*.txt.example` servent de gabarit documentaire.

---

## 3. Exigences techniques

### 3.1 Stack technologique

| Composant | Technologie | Justification |
|-----------|------------|---------------|
| Système hôte de la VM | **VirtualBox + Debian 13 (Trixie, stable actuelle)** | Debian est déjà la famille imposée pour les conteneurs ; utiliser la même distribution côté hôte réduit le changement de contexte (mêmes commandes `apt`, mêmes réflexes shell) et bénéficie d'un support à long terme. *Alternative envisageable : Ubuntu Server LTS, plus répandu en documentation grand public, mais qui n'apporte pas d'avantage technique ici.* |
| Images de base des conteneurs | **Debian 12 (Bookworm)** — avant-dernière version stable | Imposé explicitement par le sujet (« penultimate stable version of Alpine or Debian »). Choisi plutôt qu'Alpine pour la compatibilité native avec les paquets `.deb` de php-fpm, MariaDB et NGINX (moins de recompilation manuelle qu'avec `musl`/`apk` sous Alpine), au prix d'images un peu plus lourdes. |
| Serveur web | NGINX (compilé/installé depuis les dépôts Debian dans un Dockerfile dédié) | Imposé par le sujet ; reverse proxy léger et performant, nativement compatible TLS 1.2/1.3 |
| CMS / Backend applicatif | WordPress + php-fpm | Imposé par le sujet ; php-fpm permet de dissocier le traitement PHP du service web (conformément à la contrainte « sans nginx » dans ce conteneur) |
| Base de données | MariaDB | Imposé par le sujet ; fork MySQL open-source, pleinement compatible avec WordPress |
| Orchestration | Docker Compose | Imposé par le sujet |
| Automatisation du build | Makefile (wrapper autour de `docker compose`) | Imposé par le sujet ; standardise le point d'entrée (`make`, `make down`, `make fclean`, etc.) |
| Hébergement | VM locale (pas de cloud) | Le projet est un exercice pédagogique local, évalué en présentiel/à distance sur la machine du candidat |
| CI/CD | Non requis par le sujet | Hors périmètre : le sujet n'impose ni pipeline ni déploiement automatisé externe |

### 3.2 Performances

Le sujet 42 ne fixe pas de seuils de performance chiffrés (contrairement à un cahier des charges d'entreprise classique). Les valeurs ci-dessous sont donc des **objectifs de bon sens** que je me fixe pour garantir une infrastructure de qualité, et non des critères de recette imposés par 42.

| Critère | Valeur cible |
|---------|-------------|
| Temps de réponse moyen (page WordPress, cache froid) | < 800 ms en local |
| Disponibilité pendant la session de test/soutenance | 100 % (redémarrage automatique testé) |
| Charge simultanée supportée | Usage mono-utilisateur / évaluation (pas de test de charge exigé) |
| Temps de démarrage complet (`make` → site accessible) | < 2 min |

### 3.3 Sécurité

- [ ] Authentification : comptes WordPress (utilisateur standard + administrateur au nom conforme) — pas de SSO/OAuth requis par le sujet
- [ ] Chiffrement en transit : HTTPS obligatoire, **TLS 1.2 ou 1.3 exclusivement** (versions antérieures désactivées dans la configuration NGINX) — exigence explicite du sujet, seul point d'entrée réseau autorisé
- [ ] Conformité RGPD : non applicable (infrastructure locale, pédagogique, sans données personnelles réelles ni exposition publique)
- [ ] Gestion des secrets : `.env` pour la configuration non sensible + Docker secrets pour les mots de passe/identifiants — **aucun secret en dur dans le code ni commité sur Git**, sous peine d'échec du projet selon le sujet
- [ ] Isolation des processus : chaque conteneur exécute un unique processus de premier plan (PID 1) démarré proprement — interdiction explicite des patchs de type `tail -f`, `sleep infinity`, `while true`, `bash` comme entrypoint
- [ ] Isolation réseau : réseau Docker dédié, `network: host` et `--link` interdits
- [ ] Nom d'utilisateur administrateur WordPress ne devant pas contenir « admin »/« Admin »/« administrator »/« Administrator », afin de limiter les attaques par force brute basées sur des identifiants prévisibles

### 3.4 Compatibilité

| Type | Cible |
|------|-------|
| Navigateurs | Chrome, Firefox, Safari, Edge (versions récentes — test manuel, pas de matrice de compatibilité exigée) |
| Appareils | Desktop (usage principal ; le site WordPress reste responsive nativement) |
| OS hôte de la VM | Debian 13 (Trixie) |
| OS des conteneurs | Debian 12 (Bookworm) |
| Résolution minimale | Non contrainte par le sujet |

---

## 4. Architecture et intégrations

### 4.1 Schéma d'architecture

```
                              WWW
                               |
                             (443, TLS 1.2/1.3)
                               |
        ┌───────────────────────────────────────────┐
        │              Docker network                │
        │                                             │
        │   ┌────────┐   3306   ┌──────────────┐  9000  ┌────────┐
        │   │MariaDB │◄────────►│WordPress+PHP │◄──────►│ NGINX  │
        │   └───┬────┘          └──────┬───────┘        └────────┘
        │       │                      │
        └───────┼──────────────────────┼─────────────────────────┘
                 │                      │
              (volume)               (volume)
                 │                      │
          /home/kebertra/data/db   /home/kebertra/data/wp
```

*Conforme au schéma de référence fourni par le sujet (page 9) : NGINX est l'unique point d'entrée exposé (port 443), communique avec WordPress+PHP via le port interne 9000 (php-fpm/FastCGI), qui lui-même communique avec MariaDB via le port 3306. Aucun de ces ports internes n'est exposé à l'hôte, seul 443 l'est.*

### 4.2 Intégrations externes

Le périmètre obligatoire ne nécessite aucune intégration à un service tiers externe (pas de paiement, pas d'API SaaS). Les « intégrations » du projet sont en réalité inter-conteneurs, complétées par les services bonus ci-dessous.

| Service | Usage | Type d'intégration |
|---------|-------|-------------------|
| Redis (bonus) | Cache objets/pages WordPress | Plugin WordPress (ex. Redis Object Cache) + conteneur Redis dédié |
| FTP (bonus) | Accès aux fichiers WordPress hors conteneur | Conteneur FTP monté sur le volume `wordpress` |
| Adminer (bonus) | Administration visuelle de MariaDB | Conteneur web léger, connecté au réseau Docker interne |
| Site statique (bonus) | Vitrine / CV, hors PHP | Conteneur indépendant (ex. Nginx + HTML/CSS/JS, ou un framework statique au choix) |
| Monitoring (bonus, service libre) | Supervision de l'état des conteneurs et des ressources | Voir arbitrage ci-dessous (4.4) |

### 4.3 Modèle de données (ébauche)

- **Base `wordpress`** (MariaDB) : tables standards WordPress (`wp_users`, `wp_posts`, `wp_options`, etc.), générées automatiquement à l'installation.
- **Utilisateurs applicatifs MariaDB** :
  - Un compte `root` (mot de passe en secret, usage interne uniquement)
  - Un compte applicatif dédié à WordPress, droits limités à la base `wordpress`
- **Utilisateurs WordPress (niveau applicatif)** :
  - Un compte administrateur (nom conforme, ne contenant pas « admin »)
  - Un second compte (rôle standard, ex. auteur/éditeur), pour satisfaire l'exigence des « deux utilisateurs »
- Relations : `wp_users` 1–N `wp_posts`, `wp_users` 1–N `wp_usermeta`, etc. (modèle natif WordPress, non modifié)

### 4.4 Arbitrage — service de supervision (bonus « au choix »)

Le sujet impose de justifier ce choix en soutenance. Comparatif des options envisagées :

| Solution | Avantages | Inconvénients |
|---|---|---|
| **Zabbix** | Solution de supervision mature, alerting avancé, historisation fine des métriques | Architecture lourde (serveur + agent + base de données dédiée), configuration complexe pour un périmètre aussi restreint que 3-4 conteneurs |
| **Netdata** | Léger, un seul conteneur, tableau de bord temps réel prêt à l'emploi, faible configuration | Alerting moins riche que Zabbix, historisation par défaut plus limitée |
| **Uptime Kuma** | Très simple, orienté « statut de service » (up/down), interface agréable | Ne fait pas de métriques système fines (CPU/RAM par conteneur) |

**Choix retenu : Netdata.** Le sujet précise explicitement que *« le bonus est pensé pour rester simple »* ; Netdata offre le meilleur compromis entre valeur ajoutée (visibilité temps réel sur CPU/RAM/réseau de chaque conteneur) et simplicité de mise en œuvre (un seul conteneur supplémentaire, pas de base de données dédiée à maintenir). Zabbix reste une alternative crédible si tu souhaites approfondir l'aspect alerting — à trancher avant l'implémentation si tu changes d'avis.

---

## 5. Livrables et planning

### 5.1 Livrables

| Livrable | Description | Format | Date cible |
|----------|-------------|--------|-----------|
| Dépôt Git structuré | `Makefile`, `srcs/`, `secrets/` (non versionné en clair) | Git | — (pas de deadline fixée) |
| Infrastructure Docker Compose (Must) | NGINX + WordPress/php-fpm + MariaDB, volumes et réseau conformes | Conteneurs déployés | — |
| Services bonus | Redis, FTP, site statique, Adminer, Netdata | Conteneurs déployés | — |
| README.md | Présentation, description, instructions, ressources, choix techniques (VM vs Docker, secrets vs env vars, réseau Docker vs host, volumes vs bind mounts) | Markdown, en anglais | — |
| USER_DOC.md | Documentation utilisateur/administrateur | Markdown | — |
| DEV_DOC.md | Documentation développeur | Markdown | — |

> Section « Planning macro » du template volontairement supprimée : le projet n'a pas de deadline fixée et est mené en solo, sans contrainte de jalons imposés par un tiers. Le rythme de travail reste à la discrétion du porteur du projet.

---

## 6. Contraintes et hypothèses

### 6.1 Contraintes

| Type | Description |
|------|-------------|
| Ressources | Développeur unique (kebertra) |
| Technique | Doit tourner dans une VM (VirtualBox), pas d'exécution Docker directe sur l'hôte physique |
| Technique | Images construites uniquement depuis Debian 12 (Bookworm) — interdiction d'images finales DockerHub |
| Technique | Un seul point d'entrée réseau (NGINX, port 443, TLS 1.2/1.3) |
| Légale/scolaire | Respect strict du sujet officiel 42 « Inception » v5.3, sous peine d'invalidation du rendu |
| Sécurité | Aucun secret ne doit apparaître dans l'historique Git, sous peine d'échec direct du projet |

> Ligne « Budget » du template volontairement supprimée : projet pédagogique sans coût financier associé (infrastructure locale, aucune ressource cloud payante).

### 6.2 Hypothèses

- On suppose que la machine hôte dispose de ressources suffisantes pour exécuter VirtualBox + 7-8 conteneurs simultanés (Must + tous les bonus) sans dégradation notable.
- On suppose que le réseau local permet la résolution du domaine `kebertra.42.fr` vers l'IP de la VM (via `/etc/hosts` ou configuration DNS locale équivalente).
- On suppose que les dépôts de paquets Debian (Bookworm et Trixie) restent accessibles pendant toute la durée du développement pour la construction des images.
- On suppose qu'aucune mise à jour cassante des paquets NGINX/php-fpm/MariaDB packagés par Debian n'interviendra en cours de projet.

---

## 7. Critères de recette

### 7.1 Processus de validation

1. Auto-test complet : `make` depuis un état propre (`make fclean` puis `make`) doit reconstruire toute l'infrastructure sans intervention manuelle.
2. Vérification fonctionnelle : accès au site (`https://kebertra.42.fr`), à l'admin WordPress, persistance des données après redémarrage.
3. Vérification de résilience : arrêt forcé d'un conteneur → redémarrage automatique constaté.
4. Vérification de sécurité : absence de secrets dans Git (`git log -p` ou équivalent), configuration TLS vérifiée (`openssl s_client` ou navigateur).
5. Peer-evaluation 42 : un pair vérifie chaque point du sujet, peut demander une modification live du code pour valider la compréhension réelle du projet.
6. Évaluation de la partie bonus, **uniquement si la partie obligatoire est parfaitement validée** (règle explicite du sujet).

### 7.2 Critères d'acceptation

| Fonctionnalité | Critère de succès |
|---------------|------------------|
| Accès au site | `https://kebertra.42.fr` répond en TLS 1.2/1.3 uniquement, certificat valide localement |
| Authentification admin | Connexion `/wp-admin` réussie avec un identifiant ne contenant pas « admin » |
| Persistance des données | Les articles/médias créés survivent à un `docker compose down && up` |
| Volumes nommés | Données visibles dans `/home/kebertra/data` sur l'hôte, aucun bind mount utilisé |
| Résilience | Un conteneur tué redémarre automatiquement sans intervention |
| Secrets | Aucun mot de passe en clair détecté dans le dépôt Git ou les Dockerfiles |
| Bonus Redis | Cache actif et vérifiable (temps de réponse réduit sur requêtes répétées) |
| Bonus FTP | Connexion FTP fonctionnelle, fichiers visibles = fichiers du volume WordPress |
| Bonus Adminer | Connexion à la base `wordpress` réussie via interface web |
| Bonus site statique | Site accessible, ne contient aucun code PHP |
| Bonus Netdata | Tableau de bord affichant CPU/RAM/réseau de chaque conteneur en temps réel |

### 7.3 Tests attendus

- [ ] Test de build complet à froid (`make fclean && make`)
- [ ] Test de persistance des volumes après redémarrage complet
- [ ] Test de résilience (kill manuel de chaque conteneur Must)
- [ ] Test de sécurité TLS (versions autorisées uniquement)
- [ ] Test d'absence de secrets versionnés (`git grep` sur mots-clés sensibles avant commit)
- [ ] Test manuel de chaque service bonus

---

## 8. Annexes

### 8.1 Glossaire

| Terme | Définition |
|-------|-----------|
| CDC | Cahier des charges |
| MoSCoW | Must / Should / Could / Won't (méthode de priorisation) |
| php-fpm | FastCGI Process Manager — gestionnaire de processus PHP utilisé pour découpler PHP du serveur web |
| Docker secret | Mécanisme Docker permettant de monter une donnée sensible dans un conteneur sans l'exposer en variable d'environnement classique |
| Volume nommé | Espace de stockage géré par Docker, persistant indépendamment du cycle de vie du conteneur, par opposition à un bind mount qui pointe directement vers un chemin de l'hôte |
| PID 1 | Premier processus lancé dans un conteneur, responsable de la gestion des signaux système (arrêt propre, réception de SIGTERM, etc.) |
| Peer-evaluation | Évaluation du projet par un pair étudiant, incluant potentiellement une modification live du code pour vérifier la compréhension |

### 8.2 Documents de référence

- Sujet officiel 42 « Inception », version 5.3 (fourni)
- [Documentation officielle Docker](https://docs.docker.com/)
- [Documentation officielle Docker Compose](https://docs.docker.com/compose/)
- [Documentation Debian Bookworm](https://www.debian.org/releases/bookworm/)
- [Documentation WordPress (Codex/Developer Resources)](https://developer.wordpress.org/)
- [Documentation MariaDB](https://mariadb.com/kb/en/documentation/)
- [Documentation NGINX](https://nginx.org/en/docs/)

### 8.3 Historique des révisions

| Version | Date | Auteur | Modifications |
|---------|------|--------|--------------|
| 1.0 | 01/07/2026 | kebertra | Création initiale à partir du sujet Inception v5.3 et du template CDC |
