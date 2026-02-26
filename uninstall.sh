#!/usr/bin/env bash
set -euo pipefail

KUQE='\033[0;31m'
GJELBER='\033[0;32m'
PA='\033[0m'

shfaq() { printf "${GJELBER}[+]${PA} %s\n" "$*"; }
gabim() { printf "${KUQE}[x]${PA} %s\n" "$*"; exit 1; }

[[ "$(id -u)" -eq 0 ]] || gabim "Duhet te ekzekutohet si root."

if command -v systemctl &>/dev/null; then
    systemctl disable --now update-watchdog.timer 2>/dev/null || true
    systemctl disable --now update-watchdog.service 2>/dev/null || true
    rm -f /etc/systemd/system/update-watchdog.service
    rm -f /etc/systemd/system/update-watchdog.timer
    systemctl daemon-reload 2>/dev/null || true
    shfaq "Njesite systemd u hoqen."
fi

if crontab -l 2>/dev/null | grep -qF "update-watchdog"; then
    crontab -l 2>/dev/null | grep -vF "update-watchdog" | crontab -
    shfaq "Cron u hoq."
fi

rm -f /usr/local/bin/update-watchdog.sh
rm -f /var/run/update-watchdog.lock
shfaq "Skripti u fshi."

shfaq "Konfig dhe log u ruajten. Fshij manualisht nese nuk nevojiten."
echo ""
shfaq "abissnet update-watchdog u c'instalua."
