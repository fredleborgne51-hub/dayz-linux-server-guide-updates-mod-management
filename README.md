# DAYZ — LINUX DEDICATED SERVER - Updates - Mod Management

[FR French version](README_FR.md)

## Installation Checklist — V1.4

*Installation • CLI / SSH • Mods • Updates • systemd*

## 1 — Guide objective

**Context: explanation — no commands**

This checklist describes the installation of a dedicated DayZ server on Debian or Ubuntu, administered through the CLI or SSH, without a graphical interface, using the distribution's standard tools.

The DayZ server runs under the dedicated Linux user `dayz`, not `root`. System privileges are limited to the operations that require them.

## 2 — General organization

**Context: explanation — no commands**

The human-maintained configuration is stored in `mods.conf`. The `update.sh` script updates and prepares the server, then generates `mod_list.conf`. The `start.sh` script reads this list and starts DayZ. `systemd` orchestrates the whole process and `journalctl` provides diagnostics.


## 3 — Prepare the system

**Context: User with sudo privileges**

Update the system before starting the installation.

```bash
sudo apt update
sudo apt upgrade
```

## 4 — Install dependencies

**Context: User with sudo privileges**

Install the 32-bit library required by SteamCMD.

```bash
sudo apt install lib32gcc-s1
```

## 5 — Download and install SteamCMD

**Context: User with sudo privileges**

Prepare the SteamCMD location in the guide's directory structure, then extract the archive. The `dayz` user will become the owner of the files after it is created.

```bash
sudo mkdir -p /home/dayz/servers/steamcmd

cd /tmp

curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
-o steamcmd_linux.tar.gz

sudo tar -xzf steamcmd_linux.tar.gz -C /home/dayz/servers/steamcmd
rm steamcmd_linux.tar.gz
```
Create the shared Steam Workshop directory used by all servers instances.

```bash
sudo mkdir -p ~/servers/workshop_shared
```

This directory stores the downloaded Workshop content shared between server instances. It must exist before running `update.sh` for the first time.
Ownership will be assigned to user dayz in the next step.
 
## 6 — Create the server user and prepare sudoers

**Context: User with sudo privileges**

This step completes the preparation performed with the administrator account. After it, switch to `dayz` once and stay with that account.

```bash
sudo adduser --disabled-password --gecos "" dayz

getent passwd dayz

sudo chown -R dayz:dayz /home/dayz
```

Create `/etc/sudoers.d/dayz`:

```text
dayz ALL=(root) NOPASSWD: /usr/bin/systemctl start dayz-server.service, /usr/bin/systemctl stop dayz-server.service, /usr/bin/systemctl restart dayz-server.service, /usr/bin/systemctl status dayz-server.service, /usr/bin/systemctl daemon-reload, /usr/bin/systemctl enable dayz-server.service, /usr/bin/systemctl disable dayz-server.service

dayz ALL=(root) NOPASSWD: /usr/bin/journalctl
```

Check the syntax:

```bash
sudo visudo -cf /etc/sudoers.d/dayz
```

For multiple instances, explicitly add the corresponding systemd units.

## 7 — Create the systemd service

**Context: User with sudo privileges**

Create `/etc/systemd/system/dayz-server.service`: The complete file is available in [`systemd/dayz-server.service`](systemd/dayz-server.service)

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

`ExecStartPre` performs the preparation before starting the server. `Restart=on-abnormal` restarts the service after an abnormal termination, but not after a simple exit code such as 78: this prevents an infinite restart loop.

## 8 — Permanently switch to the `dayz` account

**Context: User with sudo privileges → then user `dayz`**

From this point onward, remain in the `dayz` session for the entire installation and routine administration. Operations requiring privileges use the authorized `sudo` commands.

```bash
sudo -iu dayz
whoami
```

## 9 — First SteamCMD login

**Context: User `dayz`**

On the first login, SteamCMD will prompt for the Steam account password. A Steam Guard code may also be requested if Steam Guard is enabled.
Launch SteamCMD, log in with the account intended for the server, then exit.

```bash
~/servers/steamcmd/steamcmd.sh
```

### What does `~` mean?

The `~` character represents the home directory of the current user. In the `dayz` session, `~` corresponds to `/home/dayz`. Therefore, `~/servers/dayz-server` is shorthand for `/home/dayz/servers/dayz-server`. Its value therefore depends on the current user.

## 10 — Install DayZ

**Context: User `dayz`**

The server AppID is `223350`. Install or update DayZ with SteamCMD, then verify that `DayZServer` is present.

```bash
~/servers/steamcmd/steamcmd.sh \
+force_install_dir ~/servers/dayz-server/ \
+login YOUR_STEAM_ACCOUNT \
+app_update 223350 \
+quit
```

## 11 — Workshop mods

**Context: User `dayz`**

Mods are downloaded to:

```text
/home/dayz/servers/workshop_shared/steamapps/workshop/content/221100/<WorkshopID>
```

Symbolic links then expose them in the server under their `@...` names.

The shared Workshop directory is prepared outside `update.sh`, during the server installation steps.

## 12 — Create `mods.conf`

**Context: User `dayz`**

Create `~/servers/dayz-server/mods.conf` with the following format:

```text
# SteamWorkshopID | @Mod_name

1559212036 | @CF
1828439124 | @VPPAT
```

Lines beginning with `#` (comments) and blank lines are ignored. To disable a mod, comment out its line.

## 13 — Create `update.sh` 0.3.0

**Context: User `dayz`**

Copy the validated `update.sh` script to `~/servers/dayz-server/update.sh`. It validates `mods.conf`, updates DayZ and the Workshop mods, prepares the links and `.bikey` keys, then generates `mod_list.conf`.

The complete file is available in [`scripts/EN/update.sh`](scripts/EN/update.sh). Change the STEAM_USER variable to your Steam account name.


Then make the script executable:

```bash
chmod +x ~/servers/dayz-server/update.sh
```

The script uses a single SteamCMD session for all mods and returns 78 when a critical error prevents a consistent state from being guaranteed.

## 14 — Understanding `mod_list.conf`

**Context: User `dayz`**

This file is generated by `update.sh` and should normally not be edited manually. A missing file is an error; an empty file means a vanilla startup.

Example:

```text
@CF;@VPPAT;@Code_Lock
```

## 15 — Create `start.sh` 0.2.0

**Context: User `dayz`**

Copy the validated `start.sh` script into the server directory. It reads only `mod_list.conf` and starts DayZ. The port used in this base installation is `2301`; it can be adapted for another instance.

The complete file is available in [`scripts/EN/start.sh`](scripts/EN/start.sh).


Then make the script executable:

```bash
chmod +x ~/servers/dayz-server/start.sh
```

## 16 — Reload systemd

**Context: User with sudo privileges**

Reload the units after creating or modifying them.

```bash
sudo systemctl daemon-reload
```

## 17 — Enable automatic startup

**Context: User `dayz`**

Enable the service at system startup.

```bash
sudo systemctl enable dayz-server.service
```

## 18 — First startup

**Context: User `dayz`**

The update and preparation steps are executed automatically before startup.

```bash
sudo systemctl start dayz-server.service
```

## 19 — Check the service

**Context: User `dayz`**

The expected result contains `Active: active (running)` when DayZ is running.

```bash
sudo systemctl status dayz-server.service
```

## 20 — Optional: View the logs

**Context: User `dayz`**

Follow the service messages and distinguish a preparation error from a DayZ error.

```bash
sudo journalctl -u dayz-server.service -f
```

## 21 — Optional: Test exit code 78

**Context: User `dayz`**

Temporarily add an invalid line to `mods.conf`, then run `update.sh`. The script should return 78. Restore the valid configuration afterwards.

```text
abc | @CF
```

```bash
~/servers/dayz-server/update.sh
echo $?
sudo systemctl restart dayz-server.service
```

The service should enter the `failed` state without an automatic restart loop.

## 22 — Modify or disable a mod

**Context: User `dayz`**

Modify `mods.conf`, add or comment out a line, then restart the service. Already downloaded Workshop files and old links are not automatically removed.

```bash
nano ~/servers/dayz-server/mods.conf
sudo systemctl restart dayz-server.service
```

## 23 — Scheduled restarts

**Context: User with sudo privileges**

`messages.xml` can be used for player messages and a controlled shutdown. Periodic restarts are a separate mechanism and allow the server and mods to be kept up to date.

To schedule them, use root's crontab:

```bash
sudo crontab -e
```

```cron
0 */4 * * * /usr/bin/systemctl restart dayz-server.service
```

The task runs at 00:00, 04:00, 08:00, 12:00, 16:00 and 20:00.

The restart chain is:

```text
cron → systemctl → update.sh → start.sh → DayZServer
```

## 24 — Routine maintenance

**Context: User `dayz`**

```bash
sudo systemctl start dayz-server.service
sudo systemctl stop dayz-server.service
sudo systemctl restart dayz-server.service
sudo systemctl status dayz-server.service
sudo journalctl -u dayz-server.service -f
sudo systemctl enable dayz-server.service
sudo systemctl disable dayz-server.service
```

## 25 — Tips and tricks

### Beware of `+validate`

When updating a modded DayZ server, avoid the `+validate` option with SteamCMD. Validation can rewrite or replace locally modified files, including XML, JSON and other configuration files used by the server or its mods.

### Use logs with `grep` and the pipe `|`

The `.ADM` files generated by DayZ contain, among other things, player connection events. Before creating an alias, they can be filtered directly:

```bash
grep -hE 'Player ".*" \(id=.*\) is connected' ~/servers/dayz-server/profiles/*.ADM
```

### Connection history with aliases

To avoid handling `.ADM` files directly, an alias can be added to `~/.bashrc`. It extracts the date in DD/MM/YYYY format, the actual connection time, the player's name and their DayZ identifier.

Repeated connections are retained: each `is connected` event constitutes a history entry. The date is taken from the `.ADM` filename; the time contained in the filename is ignored.

Add the following alias to `~/.bashrc`:

```bash
alias players_chernarus='for f in /home/dayz/servers/dayz-server/profiles/*.ADM; do d=$(basename "$f" .ADM | sed -E "s#DayZServer_([0-9]{4})-([0-9]{2})-([0-9]{2})_.*#\3/\2/\1#"); grep -hE '\''Player ".*" \(id=.*\) is connected'\'' "$f" | sed -E "s#^([0-9:]+) \| Player \"(.*)\" \(id=([^ ]+) pos=.*#${d} | \1 | \2 | \3#"; done | sort -t"/" -k3,3n -k2,2n -k1,1n'
```

After adding or modifying the alias, reload the shell configuration:

```bash
source ~/.bashrc
```

You can add other aliases by adjusting the path for other DayZ instances.

The `|` character (pipe) passes the output of one command to the next and allows several filters to be combined. `grep -E` enables extended regular expressions. In a regular expression, `|` means "OR" and therefore allows several patterns to be searched with a single command.

For example, search all connections from a month:

```bash
players_chernarus | grep '/08/2026'
```

Search several days:

```bash
players_chernarus | grep -E '17/09/2026|18/09/2026|19/09/2026'
```

Search for a player across several days:

```bash
players_chernarus | grep -E '17/09/2026|18/09/2026|19/09/2026' | grep -i 'John Doe'
```

Search for several players:

```bash
players_chernarus | grep -Ei 'John Doe|Chuck Norris|Tom Mason'
```

Count connections matching a filter:

```bash
players_chernarus | grep '/08/2026' | wc -l
```

### Multiple DayZ instances

Each DayZ instance must use a different `-port`. The second observed UDP port at `port + 2` must also be taken into account to avoid conflicts between instances.

**Example:**

```text
Chernarus : -port=2301 → secondary UDP 2303
Livonia   : -port=2304 → secondary UDP 2306
Sakhal    : -port=2307 → secondary UDP 2309
```

These values are example port choices, not values imposed by DayZ.

The secondary port must be considered occupied when choosing ports for the different instances. It does not necessarily need to be exposed/routed separately according to the observed operation, but it must not conflict with another instance.

## 26 — Final directory structure

**Context: explanation**

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

## 27 — Final validation

**Context: User with sudo privileges**

- [ ] user `dayz` created
- [ ] SteamCMD installed
- [ ] DayZ installed
- [ ] `mods.conf` created
- [ ] `update.sh` 0.3.0 installed and executable
- [ ] `start.sh` 0.2.0 installed and executable
- [ ] sudoers configured and verified
- [ ] systemd service created
- [ ] `daemon-reload` performed
- [ ] service enabled
- [ ] first startup successful
- [ ] `status` and `journalctl` checked
- [ ] `mod_list.conf` generated
- [ ] modded configuration tested
- [ ] optional: vanilla configuration tested
- [ ] optional: invalid Workshop ID tested
- [ ] optional: exit code 78 verified
- [ ] optional: absence of a restart loop verified

## 28 — Key principle

**Context: summary**

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

systemd = service management
journalctl = diagnostics
```
## Related project

See DSXT [DayZ Server xml Tool ](https://github.com/fredleborgne51-hub/dayz-server-xml-tool) for quick and efficient management of custom DayZ mission XML blocks.

## License

DSXT is distributed under the MIT License. See [LICENSE](LICENSE) for details.
