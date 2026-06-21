
# Balena Cloud Apps
[![balena-cloud-apps](https://circleci.com/gh/b23prodtm/balena-cloud-apps.svg?style=shield)](https://app.circleci.com/pipelines/github/b23prodtm/balena-cloud-apps)

**Description**
Outil open-source en NodeJS pour faciliter le paramétrage et le déploiement de projets sur **Balena Cloud** (Raspberry Pi, Intel NUC, etc.). Ce module permet de packager des conteneurs pour des applications comme [balena-sound](https://github.com/balenalabs/balena-sound) ou [wifi-repeater](https://github.com/balenalabs-incubator/wifi-repeater).

---

## 📥 Installation

### Prérequis
- **[Balena-CLI](https://github.com/balena-io/balena-cli)** doit être installé sur la machine hôte.

### Installation du module
Dans votre projet, exécutez :
```bash
#!/usr/bin/env bash
cd application
printf "%s\n" "nodeLinker: node-modules" | tee -a .yarnrc.yml
yarn add balena-cloud-apps
```

---

## ⚙️ Configuration du projet

### 1. Variables de template
Les fichiers `Dockerfile.template` utilisent des variables au format `%%templates_var%%`, remplacées par les valeurs définies dans les fichiers `<arch>.env` (ex: `armhf.env`, `aarch64.env`, `x86_64.env`).

### 2. Initialisation des fichiers
Exécutez la commande suivante pour générer `package.json`, `common.env` et `<arch>.env` :
```bash
post_install
```
> ⚠️ **Note** : Cette commande analyse les sous-dossiers pour détecter les fichiers Docker et réinitialise les fichiers de configuration.

### 3. Configuration de l’environnement commun
Éditez le fichier **`common.env`** pour définir :
- Les chemins des projets Balena (`BALENA_PROJECTS`).
- Les flags spécifiques (`BALENA_PROJECTS_FLAGS`).

**Exemple :**
```env
# Chemins des projets Docker Compose
BALENA_PROJECTS=( MY/PATH MY/RELATIVE/PATH )
BALENA_PROJECTS_FLAGS=( BALENA_MACHINE_NAME MY_VARIABLE )
```

### 4. Définir les architectures
Créez un fichier par architecture (ex: `x86_64.env`) :
```env
BALENA_ARCH=x86_64
BALENA_MACHINE_NAME=intel-nuc
IMG_TAG=latest
PRIMARY_HUB=docker-hub-repo/container-service-image
```

---

## 🔨 Construction et déploiement

### 1. Authentification
Connectez-vous à Docker ou Balena :
```bash
docker login  # ou
balena login
```

### 2. Construction des dépendances
Utilisez la commande suivante pour construire les images Docker :
```bash
balena_deploy test/build/ 5
```
> ⚠️ **Choix de l’architecture** : Sélectionnez `ARM32`, `ARM64` ou `X86-64` (1, 2 ou 3).
> Les images sont poussées vers votre dépôt Docker (`$DOCKER_USER/<image>`).

### 3. Déploiement
- **Vers Balena Cloud** :
  ```bash
  balena_deploy .
  ```
- **En local** :
  ```bash
  docker_build . . <DOCKER_USER>/<IMAGE>:<TAG> <BALENA_ARCH>
  ```
- **Avec des arguments** :
  ```bash
  balena_deploy . x86_64 --nobuild --exit
  balena_deploy . armhf --balena
  ```

---

## 🔄 Mise à jour du projet après modifications

1. **Testez les modifications** :
   ```bash
   yarn test
   ```
   > Exécutez les tests locaux ou en CI pour valider les changements.

2. **Incrémentez la version** :
   ```bash
   npm version patch  # ou minor/major
   git push --tags && git push
   ```
   > ⚠️ **Bonnes pratiques** :
   > - Validez toutes les modifications dans une PR.
   > - Utilisez `npm version` pour gérer les versions (ex: `1.0.1`).

3. **Déploiement automatique** :
   > Après fusion dans `master`, GitHub détecte le nouveau tag et déclenche le déploiement via `.circleci/config.yml`.

---
## 📜 Fonctions CLI
Toutes les commandes sont enregistrées dans `package.json` et disponibles dans le `PATH` après installation.
