# DAYZ — SERVEUR DÉDIÉ LINUX - Mise à jour - Gestion des mods 

[GB English version](README.md)

## Checklist d'installation — V1.4

*Installation • CLI / SSH • Mods • Mise à jour • systemd*

## 1 — Objectif du guide

**Contexte : explication — aucune commande**

Cette checklist décrit l'installation d'un serveur dédié DayZ sous Debian ou Ubuntu, administré en CLI ou par SSH, sans interface graphique, avec les outils standards de la distribution.

Le serveur DayZ est exécuté par l'utilisateur Linux dédié `dayz`, et non par `root`. Les privilèges système sont limités aux opérations nécessaires.

## 2 — Organisation générale

**Contexte : explication — aucune commande**

La configuration humaine est conservée dans `mods.conf`. Le script `update.sh` met à jour et prépare le serveur, puis génère `mod_list.conf`. Le script `start.sh` lit cette liste et lance DayZ. `systemd` orchestre l'ensemble et `journalctl` permet le diagnostic.


## 3 — Préparer le système

**Contexte : Utilisateur avec droits sudo**

Mettre à jour le système avant toute installation.

```bash
sudo apt update
sudo apt upgrade
```

## 4 — Installer les dépendances

**Contexte : Utilisateur avec droits sudo**

Installer la bibliothèque 32 bits nécessaire à SteamCMD.

```bash
sudo apt install lib32gcc-s1
```

## 5 — Télécharger et installer SteamCMD

**Contexte : Utilisateur avec droits sudo**

Préparer l'emplacement de SteamCMD dans l'arborescence du guide, puis extraire l'archive. L'utilisateur `dayz` deviendra propriétaire des fichiers après sa création.

```bash
sudo mkdir -p /home/dayz/servers/steamcmd

cd /tmp

curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
-o steamcmd_linux.tar.gz

sudo tar -xzf steamcmd_linux.tar.gz -C /home/dayz/servers/steamcmd

rm steamcmd_linux.tar.gz
```

Créez le répertoire partagé du Steam Workshop utilisé par toutes les instances éventuelles .

```bash
sudo mkdir -p /home/dayz/servers/workshop_shared
```

Ce répertoire stocke le contenu du Workshop et le partage entre les instances des serveurs. Il doit exister avant la première exécution de `update.sh`.
La propriété du répertoire sera atribuée à l' utilisateur dayz lors de l'étape suivante.

## 6 — Créer l'utilisateur du serveur et préparer sudoers

**Contexte : Utilisateur avec droits sudo**

Cette étape termine la préparation effectuée avec le compte administrateur. Après elle, on bascule une seule fois sur `dayz`.

```bash
sudo adduser --disabled-password --gecos "" dayz

getent passwd dayz

sudo chown -R dayz:dayz /home/dayz
```

Créer `/etc/sudoers.d/dayz` :

```text
dayz ALL=(root) NOPASSWD: /usr/bin/systemctl start dayz-server.service, /usr/bin/systemctl stop dayz-server.service, /usr/bin/systemctl restart dayz-server.service, /usr/bin/systemctl status dayz-server.service, /usr/bin/systemctl daemon-reload, /usr/bin/systemctl enable dayz-server.service, /usr/bin/systemctl disable dayz-server.service

dayz ALL=(root) NOPASSWD: /usr/bin/journalctl
```

Vérifier la syntaxe :

```bash
sudo visudo -cf /etc/sudoers.d/dayz
```

Pour plusieurs instances, ajouter explicitement les unités systemd correspondantes.

## 7 — Créer le service systemd

**Contexte : Utilisateur avec droits sudo**

Créer `/etc/systemd/system/dayz-server.service` : Le fichier est disponible dans [`systemd/dayz-server.service`](systemd/dayz-server.service)

```ini
[Unit]
Description=DayZ Dedicated Server
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/home/dayz/servers/dayz-server
User=dayz
Group=dayz
ExecStartPre=/home/dayz/servers/dayz-server/update.sh
ExecStart=/home/dayz/servers/dayz-server/start.sh
TimeoutStopSec=90
KillMode=control-group
LimitNOFILE=100000
Restart=on-abnormal
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

`ExecStartPre` exécute la préparation avant le lancement. `Restart=on-abnormal` permet de relancer le service après une terminaison anormale, mais pas après un simple code de sortie tel que 78 : cela évite une boucle de redémarrage infinie.

## 8 — Passer définitivement sur le compte `dayz`

**Contexte : Utilisateur avec droits sudo → puis utilisateur dayz**

À partir de cette étape, rester dans la session `dayz` pour toute l'installation et l'administration courante. Les opérations nécessitant des privilèges passent par les commandes `sudo` autorisées.

```bash
sudo -iu dayz
whoami
```

## 9 — Première connexion à SteamCMD

**Contexte : Utilisateur dayz**

Lors de la première connexion, SteamCMD demande le mot de passe du compte Steam. Un code Steam Guard peut également être demandé si la protection est activée.
Lancer SteamCMD, se connecter avec le compte prévu pour le serveur, puis quitter.

```bash
~/servers/steamcmd/steamcmd.sh
```

### Que signifie `~` ?

Le caractère `~` représente le répertoire personnel de l'utilisateur courant. Dans la session `dayz`, `~` correspond à `/home/dayz`. Ainsi `~/servers/dayz-server` est l'abréviation de `/home/dayz/servers/dayz-server`. Sa valeur dépend donc de l'utilisateur courant.

## 10 — Installer DayZ

**Contexte : Utilisateur dayz**

L'AppID du serveur est `223350`. Installer ou mettre à jour DayZ avec SteamCMD, puis vérifier la présence de `DayZServer`.

```bash
~/servers/steamcmd/steamcmd.sh \
+force_install_dir ~/servers/dayz-server/ \
+login VOTRE_COMPTE_STEAM \
+app_update 223350 \
+quit
```

## 11 — Mods Workshop

**Contexte : Utilisateur dayz**

Les mods sont téléchargés dans :

```text
/home/dayz/servers/workshop_shared/steamapps/workshop/content/221100/<WorkshopID>
```

Des liens symboliques les exposent ensuite dans le serveur sous leur nom `@...`.

Le répertoire Workshop mutualisé est préparé en dehors de `update.sh`, dans les étapes d'installation du serveur.

## 12 — Créer `mods.conf`

**Contexte : Utilisateur dayz**

Créer `~/servers/dayz-server/mods.conf` avec le format suivant :

```text
# SteamWorkshopID | @Nom_du_mod

1559212036 | @CF
1828439124 | @VPPAT
```

Les lignes commençant par `#` (commentaire) et les lignes vides sont ignorées. Pour désactiver un mod, commenter sa ligne.

## 13 — Créer `update.sh` 0.3.0

**Contexte : Utilisateur dayz**

Copier le script `update.sh` validé dans `~/servers/dayz-server/update.sh`. Il valide `mods.conf`, met à jour DayZ et les mods Workshop, prépare les liens et les clés `.bikey`, puis génère `mod_list.conf`.

Le fichier complet est disponible dans [`scripts/FR/update.sh`](scripts/FR/update.sh). Modifiez la variable STEAM_USER par votre identifiant Steam .


Puis rendre le script exécutable :

```bash
chmod +x ~/servers/dayz-server/update.sh
```

Le script utilise une session SteamCMD unique pour l'ensemble des mods et retourne 78 lorsqu'une erreur critique empêche de garantir un état cohérent.

## 14 — Comprendre `mod_list.conf`

**Contexte : Utilisateur dayz**

Ce fichier est généré par `update.sh` et ne doit normalement pas être modifié manuellement. Un fichier absent est une erreur ; un fichier vide signifie un démarrage vanilla.

Exemple :

```text
@CF;@VPPAT;@Code_Lock
```

## 15 — Créer `start.sh` 0.2.0

**Contexte : Utilisateur dayz**

Copier le script `start.sh` validé dans le répertoire du serveur. Il lit exclusivement `mod_list.conf` et lance DayZ. Le port utilisé dans cette installation de base est `2301` ; il peut être adapté pour une autre instance.

Le fichier complet est disponible dans [`scripts/FR/start.sh`](scripts/FR/start.sh).


Puis rendre le script exécutable :

```bash
chmod +x ~/servers/dayz-server/start.sh
```

## 16 — Recharger systemd

**Contexte : Utilisateur avec droits sudo**

Relire les unités après leur création ou modification.

```bash
sudo systemctl daemon-reload
```

## 17 — Activer le démarrage automatique

**Contexte : Utilisateur dayz**

Activer le service au démarrage du système.

```bash
sudo systemctl enable dayz-server.service
```

## 18 — Premier démarrage

**Contexte : Utilisateur dayz**

La mise à jour et la préparation sont exécutées automatiquement avant le lancement.

```bash
sudo systemctl start dayz-server.service
```

## 19 — Vérifier le service

**Contexte : Utilisateur dayz**

Le résultat attendu contient `Active: active (running)` lorsque DayZ fonctionne.

```bash
sudo systemctl status dayz-server.service
```

## 20 — Optionnel : Consulter les journaux

**Contexte : Utilisateur dayz**

Suivre les messages du service et distinguer une erreur de préparation d'une erreur DayZ.

```bash
sudo journalctl -u dayz-server.service -f
```

## 21 — Optionnel : Tester le code 78

**Contexte : Utilisateur dayz**

Ajouter temporairement une ligne invalide dans `mods.conf`, puis lancer `update.sh`. Le script doit retourner 78. Restaurer ensuite la configuration valide.

```text
abc | @CF
```

```bash
~/servers/dayz-server/update.sh
echo $?
sudo systemctl restart dayz-server.service
```

Le service doit passer à l'état `failed`, sans boucle de redémarrage automatique.

## 22 — Modifier ou désactiver un mod

**Contexte : Utilisateur dayz**

Modifier `mods.conf`, ajouter ou commenter une ligne, puis redémarrer le service. Les fichiers Workshop déjà téléchargés et les anciens liens ne sont pas automatiquement supprimés.

```bash
nano ~/servers/dayz-server/mods.conf
sudo systemctl restart dayz-server.service
```

## 23 — Redémarrages planifiés

**Contexte : Utilisateur avec droits sudo**

`messages.xml` peut servir aux messages joueurs et à un arrêt contrôlé. Les redémarrages périodiques sont un mécanisme distinct et permettent de maintenir à jour le serveur et les mods.

Pour les planifier, utiliser la crontab de root :

```bash
sudo crontab -e
```

```cron
0 */4 * * * /usr/bin/systemctl restart dayz-server.service
```

La tâche s'exécute à 00:00, 04:00, 08:00, 12:00, 16:00 et 20:00.

Le redémarrage suit la chaîne :

```text
cron → systemctl → update.sh → start.sh → DayZServer
```

## 24 — Maintenance courante

**Contexte : Utilisateur dayz**

```bash
sudo systemctl start dayz-server.service
sudo systemctl stop dayz-server.service
sudo systemctl restart dayz-server.service
sudo systemctl status dayz-server.service
sudo journalctl -u dayz-server.service -f
sudo systemctl enable dayz-server.service
sudo systemctl disable dayz-server.service
```

## 25 — Trucs et astuces

### Attention à `+validate`

Lors de la mise à jour d'un serveur DayZ moddé, éviter l'option `+validate` avec SteamCMD. Une validation peut réécrire ou remplacer des fichiers modifiés localement, notamment des fichiers XML, JSON et autres fichiers de configuration utilisés par le serveur ou ses mods.

### Exploiter les logs avec `grep` et le pipe `|`

Les fichiers `.ADM` générés par DayZ contiennent notamment les événements de connexion des joueurs. Avant de créer un alias, on peut les filtrer directement :

```bash
grep -hE 'Player ".*" \(id=.*\) is connected' ~/servers/dayz-server/profiles/*.ADM
```

### Historique des connexions avec des alias

Pour éviter de manipuler directement les fichiers `.ADM`, un alias peut être ajoutés dans `~/.bashrc`. Il extrait la date au format JJ/MM/AAAA, l'heure réelle de la connexion, le nom du joueur et son identifiant DayZ.

Les connexions répétées sont conservées : chaque événement `is connected` constitue une entrée de l'historique. La date est récupérée depuis le nom du fichier `.ADM` ; l'heure présente dans le nom du fichier est ignorée.

Ajouter l'alias suivant dans `~/.bashrc` :

```bash
alias joueurs_chernarus='for f in /home/dayz/servers/dayz-server/profiles/*.ADM; do d=$(basename "$f" .ADM | sed -E "s#DayZServer_([0-9]{4})-([0-9]{2})-([0-9]{2})_.*#\3/\2/\1#"); grep -hE '\''Player ".*" \(id=.*\) is connected'\'' "$f" | sed -E "s#^([0-9:]+) \| Player \"(.*)\" \(id=([^ ]+) pos=.*#${d} | \1 | \2 | \3#"; done | sort -t"/" -k3,3n -k2,2n -k1,1n'
```

Après avoir ajouté ou modifié l'alias, recharger la configuration du shell :

```bash
source ~/.bashrc
```

Vous pouvez ajouter d'autres alias en ajustant le chemin pour d'autres instances de DayZ.

Le caractère `|` (pipe) transmet la sortie d'une commande à la suivante et permet de combiner plusieurs filtres. `grep -E` permet d'utiliser les expressions régulières étendues. Dans une expression régulière, `|` signifie « OU » et permet donc de rechercher plusieurs motifs avec une seule commande.

Par exemple, rechercher toutes les connexions d'un mois :

```bash
joueurs_chernarus | grep '/08/2026'
```

Rechercher plusieurs jours :

```bash
joueurs_chernarus | grep -E '17/09/2026|18/09/2026|19/09/2026'
```

Rechercher un joueur sur plusieurs jours :

```bash
joueurs_chernarus | grep -E '17/09/2026|18/09/2026|19/09/2026' | grep -i 'John Doe'
```

Rechercher plusieurs joueurs :

```bash
joueurs_chernarus | grep -Ei 'John Doe|Chuck Norris|Tom Mason'
```

Compter les connexions correspondant à un filtre :

```bash
joueurs_chernarus | grep '/08/2026' | wc -l
```

### Plusieurs instances DayZ

Chaque instance DayZ doit utiliser un port `-port` différent. Il faut également tenir compte du second port UDP observé à `port + 2`, afin d'éviter les conflits entre instances.

**Exemple :**

```text
Chernarus : -port=2301 → UDP secondaire 2303
Livonia   : -port=2304 → UDP secondaire 2306
Sakhal    : -port=2307 → UDP secondaire 2309
```

Ces valeurs sont des exemples de choix de ports, pas des valeurs imposées par DayZ.

Le port secondaire doit être considéré comme occupé lors du choix des ports des différentes instances. Il n'est pas nécessairement à exposer/routé séparément dans le fonctionnement constaté, mais il ne doit pas entrer en conflit avec une autre instance.

## 26 — Arborescence finale

**Contexte : explication**

```text
/home/dayz/
└── servers/
    ├── steamcmd/steamcmd.sh
    ├── workshop_shared/steamapps/workshop/content/221100/
    └── dayz-server/
        ├── DayZServer
        ├── serverDZ.cfg
        ├── mods.conf
        ├── mod_list.conf
        ├── update.sh
        ├── start.sh
        ├── keys/
        └── mpmissions/dayzOffline.chernarusplus/
```

## 27 — Validation finale

**Contexte : Utilisateur avec droits sudo**

- [ ] utilisateur `dayz` créé
- [ ] SteamCMD installé
- [ ] DayZ installé
- [ ] `mods.conf` créé
- [ ] `update.sh` 0.3.0 installé et exécutable
- [ ] `start.sh` 0.2.0 installé et exécutable
- [ ] sudoers configuré et vérifié
- [ ] service systemd créé
- [ ] `daemon-reload` effectué
- [ ] service activé
- [ ] premier démarrage réussi
- [ ] `status` et `journalctl` vérifiés
- [ ] `mod_list.conf` généré
- [ ] configuration modded testée
- [ ] optionnel : configuration vanilla testée
- [ ] optionnel : Workshop ID invalide testé
- [ ] optionnel : retour 78 vérifié
- [ ] optionnel : absence de boucle de redémarrage vérifiée

## 28 — Principe à retenir

**Contexte : synthèse**

```text
mods.conf
    ↓
update.sh
    ↓
mod_list.conf
    ↓
start.sh
    ↓
DayZServer

systemd = gestion du service
journalctl = diagnostic
```
## Related project

Consultez DSXT [DayZ Server xml Tool ](https://github.com/fredleborgne51-hub/dayz-server-xml-tool/blob/main/README_FR.md) pour gérer rapidement et efficacement les blocs XML personnalisés des missions DayZ.

## License

Ce guide est distribué sous license MIT . Consultez le fichier [LICENSE](LICENSE) pour plus de détails.
