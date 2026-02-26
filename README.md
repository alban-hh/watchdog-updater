# abissnet update-watchdog

Package update watchdog for AlmaLinux, Alpine, Arch, CentOS, Debian, Fedora, Rocky, Ubuntu, FreeBSD, OpenBSD.

Checks for updates every 3 days, notifies via Telegram, waits 30 min, then applies them. Kernel and critical system packages are never touched.

## Setup

```
ssh root@server
git clone https://github.com/alban-hh/watchdog-updater.git
cd watchdog-updater
sh install.sh
nano /etc/update-watchdog.conf
```

Set `TOKEN_TELEGRAM` and `ID_BISEDE` in the config.

## Test

```
PROVE=true /usr/local/bin/update-watchdog.sh
```

## Logs

```
tail -f /var/log/update-watchdog.log
```

## Remove

```
sh uninstall.sh
```
