#!/bin/sh
set -eu

KUQE='\033[0;31m'
GJELBER='\033[0;32m'
VERDHE='\033[1;33m'
PA='\033[0m'

shfaq()  { printf "${GJELBER}[+]${PA} %s\n" "$*"; }
kujdes() { printf "${VERDHE}[!]${PA} %s\n" "$*"; }
gabim()  { printf "${KUQE}[x]${PA} %s\n" "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] || gabim "Duhet te ekzekutohet si root."

DOSJA_SKRIPTIT="$(cd "$(dirname "$0")" && pwd)"

zbulo_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-}" in
            almalinux|alma)  echo "almalinux" ;;
            alpine)          echo "alpine" ;;
            arch|archarm)    echo "arch" ;;
            centos)          echo "centos" ;;
            debian)          echo "debian" ;;
            fedora)          echo "fedora" ;;
            rocky)           echo "rocky" ;;
            ubuntu)          echo "ubuntu" ;;
            *)               echo "${ID:-unknown}" ;;
        esac
    elif [ "$(uname)" = "FreeBSD" ]; then
        echo "freebsd"
    elif [ "$(uname)" = "OpenBSD" ]; then
        echo "openbsd"
    else
        echo "unknown"
    fi
}

DISTRO="$(zbulo_distro)"
shfaq "Distro: $DISTRO"

instalo_varesi() {
    shfaq "Instalim i varesive per $DISTRO"

    case "$DISTRO" in
        almalinux|rocky)
            dnf install -y bash curl yum-utils 2>/dev/null || true
            ;;
        fedora)
            dnf install -y bash curl dnf-utils 2>/dev/null || true
            ;;
        centos)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y bash curl yum-utils 2>/dev/null || true
            else
                yum install -y bash curl yum-utils 2>/dev/null || true
            fi
            ;;
        debian|ubuntu)
            apt-get update -qq 2>/dev/null || true
            apt-get install -y bash curl needrestart 2>/dev/null || true
            ;;
        alpine)
            apk add --no-cache bash curl 2>/dev/null || true
            ;;
        arch)
            pacman -Sy --noconfirm --needed bash curl pacman-contrib 2>/dev/null || true
            ;;
        freebsd)
            pkg install -y bash curl 2>/dev/null || true
            ;;
        openbsd)
            pkg_add bash curl 2>/dev/null || true
            ;;
    esac
}

kontrollo_bash() {
    if command -v bash >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

instalo_varesi

if ! kontrollo_bash; then
    gabim "bash nuk u instalua. Instalo manualisht dhe provo perseri."
fi

if ! command -v curl >/dev/null 2>&1; then
    kujdes "curl nuk u instalua. Njoftimet Telegram nuk do te punojne."
fi

shfaq "Instalim update-watchdog.sh -> /usr/local/bin/"
install -m 0755 "$DOSJA_SKRIPTIT/update-watchdog.sh" /usr/local/bin/update-watchdog.sh

if [ -f /etc/update-watchdog.conf ]; then
    kujdes "/etc/update-watchdog.conf ekziston. Nuk mbishkruhet."
    kujdes "Konfiguracioni i ri u ruajt ne /etc/update-watchdog.conf.new"
    install -m 0600 "$DOSJA_SKRIPTIT/update-watchdog.conf.example" /etc/update-watchdog.conf.new
else
    shfaq "Instalim konfig -> /etc/update-watchdog.conf"
    install -m 0600 "$DOSJA_SKRIPTIT/update-watchdog.conf.example" /etc/update-watchdog.conf
fi

touch /var/log/update-watchdog.log
chmod 0640 /var/log/update-watchdog.log

if [ -d /etc/logrotate.d ]; then
    install -m 0644 "$DOSJA_SKRIPTIT/update-watchdog.logrotate" /etc/logrotate.d/update-watchdog
    shfaq "Logrotate u instalua."
fi

perdor_systemd=false
if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    perdor_systemd=true
fi

if [ "$perdor_systemd" = "true" ]; then
    shfaq "U zbulua systemd. Instalim i timer."
    install -m 0644 "$DOSJA_SKRIPTIT/update-watchdog.service" /etc/systemd/system/
    install -m 0644 "$DOSJA_SKRIPTIT/update-watchdog.timer"   /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now update-watchdog.timer
    shfaq "Timer u aktivizua."
    systemctl list-timers update-watchdog.timer --no-pager
else
    shfaq "Systemd nuk u gjet. Instalim cron."
    RRESHTI_CRON="0 3 1,4,7,10,13,16,19,22,25,28 * * /usr/local/bin/update-watchdog.sh >> /var/log/update-watchdog.log 2>&1"

    if crontab -l 2>/dev/null | grep -qF "update-watchdog"; then
        kujdes "Cron ekziston. Nuk dublikohet."
    else
        (crontab -l 2>/dev/null; echo "$RRESHTI_CRON # update-watchdog") | crontab -
        shfaq "Cron u instalua."
    fi
fi

echo ""
echo "============================================="
echo "  abissnet update-watchdog u instalua"
echo "============================================="
echo ""
echo "  Testo me prove:"
echo "    sudo PROVE=true /usr/local/bin/update-watchdog.sh"
echo ""
echo "  Shiko log:"
echo "    tail -f /var/log/update-watchdog.log"
echo ""
if [ "$perdor_systemd" = "true" ]; then
    echo "  Ekzekutim manual:"
    echo "    sudo systemctl start update-watchdog.service"
    echo ""
    echo "  Statusi i timer:"
    echo "    systemctl list-timers update-watchdog.timer"
    echo ""
fi
