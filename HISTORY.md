# Historique des versions

Ce fichier résume les évolutions fonctionnelles des scripts publiés dans ce dépôt.
Le détail des modifications reste disponible dans l'historique des commits GitHub.

## 0.4.0 — update.sh

- Mutualisation du contenu Workshop entre les instances DayZ.
- Gestion distincte des mods classiques et des mods exclusivement serveur.
- Lecture des configurations `mods.conf` et `servermods.conf`.
- Vérification des doublons de Workshop ID entre les deux catégories.
- Téléchargement de l'ensemble des mods dans une seule session SteamCMD.
- Création et réconciliation des liens symboliques vers le Workshop partagé.
- Copie des clés `.bikey` avec détection des conflits de nom et de contenu.
- Génération séparée de `mod_list.conf` et `servermod_list.conf`.
- Utilisation du code de sortie `78` (`EX_CONFIG`) en cas d'erreur empêchant de garantir un état cohérent.

## 0.3.0 — start.sh

- Lecture des listes générées par `update.sh` :
  - `mod_list.conf` pour les mods classiques.
  - `servermod_list.conf` pour les mods exclusivement serveur.
- Refus du démarrage si l'une des deux listes est absente.
- Démarrage en mode VANILLA lorsque les deux listes sont présentes et vides.
- Construction des paramètres DayZ uniquement pour les catégories de mods configurées.
- Prise en charge distincte des paramètres `-mod` et `-servermod`.

Les versions française et anglaise de chaque script sont disponibles dans les dossiers `FR/` et `EN/`.
