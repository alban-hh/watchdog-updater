#!/usr/bin/env bash
# abissnet update-watchdog
# AlmaLinux, Alpine, Arch, CentOS, Debian, Fedora, Rocky, Ubuntu, FreeBSD, OpenBSD

set -euo pipefail

SKEDARI_KONFIG="/etc/update-watchdog.conf"
[[ -f "$SKEDARI_KONFIG" ]] && . "$SKEDARI_KONFIG"

TOKEN_TELEGRAM="${TOKEN_TELEGRAM:-}"
ID_BISEDE="${ID_BISEDE:-}"
VONESA_SEKONDA="${VONESA_SEKONDA:-1800}"
SKEDARI_LOG="${SKEDARI_LOG:-/var/log/update-watchdog.log}"
SKEDARI_BLLOKIMIT="${SKEDARI_BLLOKIMIT:-/var/run/update-watchdog.lock}"
EMRI_SERVERIT="${EMRI_SERVERIT:-$(hostname -f 2>/dev/null || hostname)}"
PROVE="${PROVE:-false}"
HAPESIRA_MIN_MB="${HAPESIRA_MIN_MB:-500}"

PAKETAT_E_NDALUARA=(
    "^kernel"
    "^linux-image"
    "^linux-headers"
    "^linux-firmware"
    "^linux-lts"
    "^linux-zen"
    "^linux-hardened"
    "^grub"
    "^shim"
    "^systemd$"
    "^glibc"
    "^libc6"
    "^musl"
    "^openrc"
    "^init"
    "^base-system"
    "^freebsd-update"
    "^src"
    "^bsd\."
)

PERDITESIMET_GATI=""
NUMRI_PERDITESIMEVE=0

regjistro() {
    local koha
    koha="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "$koha" "$*" | tee -a "$SKEDARI_LOG"
}

ndalo() {
    regjistro "FATAL: $*"
    dergo_telegram "[GABIM] update-watchdog | Host: ${EMRI_SERVERIT} | $*" || true
    pastrimi
    exit 1
}

pastrimi() {
    rmdir "$SKEDARI_BLLOKIMIT" 2>/dev/null || true
}
trap pastrimi EXIT INT TERM

merr_bllokimin() {
    if mkdir "$SKEDARI_BLLOKIMIT" 2>/dev/null; then
        return 0
    fi
    local skedari_pid="${SKEDARI_BLLOKIMIT}/pid"
    if [[ -f "$skedari_pid" ]]; then
        local pid
        pid="$(cat "$skedari_pid" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            regjistro "Instanca tjeter (PID $pid) eshte duke punuar. Dalje."
            trap - EXIT
            exit 0
        fi
    fi
    regjistro "Bllokimi i vjeter. Fshirje."
    rm -rf "$SKEDARI_BLLOKIMIT"
    mkdir "$SKEDARI_BLLOKIMIT"
    echo $$ > "${SKEDARI_BLLOKIMIT}/pid"
}

kontrollo_rrjetin() {
    local objektivi
    for objektivi in "1.1.1.1" "8.8.8.8" "9.9.9.9"; do
        if ping -c 1 -W 3 "$objektivi" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

kontrollo_hapesiren() {
    local hapesira_mb
    if command -v df &>/dev/null; then
        hapesira_mb="$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')"
        if [[ -n "$hapesira_mb" ]] && [[ "$hapesira_mb" -lt "$HAPESIRA_MIN_MB" ]]; then
            return 1
        fi
    fi
    return 0
}

pastro_markdown() {
    sed 's/[_*`\[]/\\&/g'
}

dergo_telegram() {
    local mesazhi="$1"
    if [[ -z "$TOKEN_TELEGRAM" || -z "$ID_BISEDE" ]]; then
        regjistro "Telegram nuk eshte konfiguruar."
        return 1
    fi

    local url="https://api.telegram.org/bot${TOKEN_TELEGRAM}/sendMessage"
    local gjatesia_max=4000
    local pjesa
    local deshtoi=false
    while [[ ${#mesazhi} -gt 0 ]]; do
        pjesa="${mesazhi:0:$gjatesia_max}"
        mesazhi="${mesazhi:$gjatesia_max}"
        if ! curl -sf --max-time 30 -X POST "$url" \
            -d chat_id="$ID_BISEDE" \
            -d parse_mode="Markdown" \
            -d text="$pjesa" >/dev/null 2>&1; then
            if ! curl -sf --max-time 30 -X POST "$url" \
                -d chat_id="$ID_BISEDE" \
                -d text="$pjesa" >/dev/null 2>&1; then
                deshtoi=true
            fi
        fi
    done
    if [[ "$deshtoi" == "true" ]]; then
        regjistro "KUJDES: Dergimi ne Telegram deshtoi."
        return 1
    fi
    return 0
}

zbulo_distro() {
    if [[ -f /etc/os-release ]]; then
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
            flatcar)         echo "flatcar" ;;
            coreos)          echo "coreos" ;;
            *)               echo "${ID:-e_panjohur}" ;;
        esac
    elif [[ "$(uname)" == "FreeBSD" ]]; then
        echo "freebsd"
    elif [[ "$(uname)" == "OpenBSD" ]]; then
        echo "openbsd"
    else
        echo "e_panjohur"
    fi
}

filtro_te_ndaluarat() {
    local hyrja="$1"
    local shabllon
    local te_bashkuara=""
    for shabllon in "${PAKETAT_E_NDALUARA[@]}"; do
        if [[ -n "$te_bashkuara" ]]; then
            te_bashkuara="${te_bashkuara}|${shabllon}"
        else
            te_bashkuara="$shabllon"
        fi
    done
    echo "$hyrja" | grep -vE "$te_bashkuara" || true
}

kontrollo_dnf() {
    regjistro "Rifreskim i cache dnf"
    dnf makecache -q 2>>"$SKEDARI_LOG" || return 1

    local te_paperpunuara
    te_paperpunuara="$(dnf check-update --quiet 2>/dev/null | \
           awk 'NF>=3 && $2 ~ /\./ {print $1}' || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_dnf() {
    local perjashtuar="--exclude=kernel* --exclude=linux-firmware* --exclude=grub* --exclude=shim* --exclude=systemd --exclude=glibc*"
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] dnf update -y $perjashtuar"
    else
        dnf update -y $perjashtuar 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_yum() {
    regjistro "Rifreskim i cache yum"
    yum makecache -q 2>>"$SKEDARI_LOG" || return 1

    local te_paperpunuara
    te_paperpunuara="$(yum check-update --quiet 2>/dev/null | \
           awk 'NF>=3 && $2 ~ /\./ {print $1}' || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_yum() {
    local perjashtuar="--exclude=kernel* --exclude=linux-firmware* --exclude=grub* --exclude=shim* --exclude=systemd --exclude=glibc*"
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] yum update -y $perjashtuar"
    else
        yum update -y $perjashtuar 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_apt() {
    regjistro "Rifreskim i cache apt"
    apt-get update -qq 2>>"$SKEDARI_LOG" || return 1

    local te_paperpunuara
    te_paperpunuara="$(apt list --upgradable 2>/dev/null | \
           tail -n +2 | cut -d'/' -f1 || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_apt() {
    local paketat_mbajtur=("linux-image-" "linux-headers-" "linux-firmware" "grub-" "shim-signed" "systemd" "libc6")
    for shabllon_pak in "${paketat_mbajtur[@]}"; do
        dpkg --get-selections | awk '{print $1}' | grep -F "$shabllon_pak" | \
            xargs -r apt-mark hold 2>/dev/null || true
    done

    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] apt-get upgrade -y"
    else
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
            -o Dpkg::Options::="--force-confold" 2>>"$SKEDARI_LOG"
    fi

    for shabllon_pak in "${paketat_mbajtur[@]}"; do
        dpkg --get-selections | awk '{print $1}' | grep -F "$shabllon_pak" | \
            xargs -r apt-mark unhold 2>/dev/null || true
    done
}

kontrollo_apk() {
    regjistro "Rifreskim i cache apk"
    apk update -q 2>>"$SKEDARI_LOG" || return 1

    local te_paperpunuara
    te_paperpunuara="$(apk version -l '<' 2>/dev/null | awk '{print $1}' | \
           sed 's/-[0-9].*//' || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_apk() {
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] apk upgrade"
    else
        apk upgrade --no-cache --available 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_pacman() {
    regjistro "Kontrollo perditesime pacman"
    if command -v checkupdates &>/dev/null; then
        local te_paperpunuara
        te_paperpunuara="$(checkupdates 2>/dev/null | awk '{print $1}' || true)"
    else
        regjistro "checkupdates nuk u gjet, perdoret pacman -Qu"
        pacman -Sy --noconfirm 2>>"$SKEDARI_LOG" || return 1
        local te_paperpunuara
        te_paperpunuara="$(pacman -Qu 2>/dev/null | awk '{print $1}' || true)"
    fi
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_pacman() {
    local lista_perjashtuar="linux,linux-lts,linux-zen,linux-hardened,linux-headers,linux-firmware,grub,systemd,glibc"
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] pacman -Syu --noconfirm --ignore $lista_perjashtuar"
    else
        pacman -Syu --noconfirm --ignore "$lista_perjashtuar" 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_freebsd() {
    regjistro "Rifreskim i katalogut pkg"
    pkg update -q 2>>"$SKEDARI_LOG" || return 1

    local te_paperpunuara
    te_paperpunuara="$(pkg version -vRL= 2>/dev/null | awk '{print $1}' | \
           sed 's/-[0-9].*//' || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_freebsd() {
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] pkg upgrade -y"
    else
        pkg upgrade -y 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_openbsd() {
    regjistro "Kontrollo per perditesime OpenBSD"

    local te_paperpunuara
    te_paperpunuara="$(pkg_add -u -s 2>&1 | grep 'to be updated' | \
           awk '{print $1}' | sed 's/-[0-9].*//' || true)"
    PERDITESIMET_GATI="$(filtro_te_ndaluarat "$te_paperpunuara")"
    NUMRI_PERDITESIMEVE="$(echo "$PERDITESIMET_GATI" | grep -c . || true)"
}

zbato_openbsd() {
    if [[ "$PROVE" == "true" ]]; then
        regjistro "[PROVE] pkg_add -u"
    else
        pkg_add -u 2>>"$SKEDARI_LOG"
    fi
}

kontrollo_flatcar() {
    regjistro "Flatcar/CoreOS: perditesimet menaxhohen nga imazhi i OS"
    PERDITESIMET_GATI=""
    NUMRI_PERDITESIMEVE=0
}

zbato_flatcar() {
    regjistro "Asnje perditesim paketash per Flatcar/CoreOS"
}

rinise_sherbimet() {
    regjistro "Kontrollo per sherbime qe kerkojne rinisje"
    local sherbimet_rinisur=""

    if command -v needs-restarting &>/dev/null; then
        local lista
        lista="$(needs-restarting -s 2>/dev/null || true)"
        if [[ -n "$lista" ]]; then
            regjistro "Sherbime qe kerkojne rinisje (needs-restarting): $lista"
            while IFS= read -r sherbimi; do
                [[ -z "$sherbimi" ]] && continue
                [[ "$sherbimi" == *"sshd"* ]] && continue
                regjistro "Rinisje: $sherbimi"
                if [[ "$PROVE" != "true" ]]; then
                    systemctl restart "$sherbimi" 2>>"$SKEDARI_LOG" || regjistro "KUJDES: Deshtoi rinisja e $sherbimi"
                fi
                sherbimet_rinisur="${sherbimet_rinisur} ${sherbimi}"
            done <<< "$lista"
        fi
    elif command -v needrestart &>/dev/null; then
        if [[ "$PROVE" != "true" ]]; then
            needrestart -r a -l 2>>"$SKEDARI_LOG" || true
        fi
        sherbimet_rinisur="(needrestart automatic)"
    elif command -v systemctl &>/dev/null; then
        local te_njohurat=("nginx" "apache2" "httpd" "php-fpm" "php8.1-fpm" "php8.2-fpm" "php8.3-fpm" "mariadb" "mysql" "mysqld" "postgresql" "redis" "redis-server" "memcached" "postfix" "dovecot" "named" "bind9" "haproxy" "varnish" "fail2ban")
        for sherbimi in "${te_njohurat[@]}"; do
            if systemctl is-active --quiet "$sherbimi" 2>/dev/null; then
                local skedari_sherbimit
                skedari_sherbimit="$(systemctl show -p FragmentPath "$sherbimi" 2>/dev/null | cut -d= -f2)"
                regjistro "Rinisje: $sherbimi"
                if [[ "$PROVE" != "true" ]]; then
                    systemctl restart "$sherbimi" 2>>"$SKEDARI_LOG" || regjistro "KUJDES: Deshtoi rinisja e $sherbimi"
                fi
                sherbimet_rinisur="${sherbimet_rinisur} ${sherbimi}"
            fi
        done
    elif [[ "$(uname)" == "FreeBSD" ]]; then
        local te_njohurat=("nginx" "apache24" "mysql-server" "postgresql" "redis" "memcached" "postfix" "dovecot" "named" "haproxy")
        for sherbimi in "${te_njohurat[@]}"; do
            if service "$sherbimi" status >/dev/null 2>&1; then
                regjistro "Rinisje: $sherbimi"
                if [[ "$PROVE" != "true" ]]; then
                    service "$sherbimi" restart 2>>"$SKEDARI_LOG" || regjistro "KUJDES: Deshtoi rinisja e $sherbimi"
                fi
                sherbimet_rinisur="${sherbimet_rinisur} ${sherbimi}"
            fi
        done
    elif [[ "$(uname)" == "OpenBSD" ]]; then
        local te_njohurat=("nginx" "apache2" "mysqld" "postgresql" "redis" "memcached" "smtpd" "dovecot" "named" "haproxy")
        for sherbimi in "${te_njohurat[@]}"; do
            if rcctl check "$sherbimi" >/dev/null 2>&1; then
                regjistro "Rinisje: $sherbimi"
                if [[ "$PROVE" != "true" ]]; then
                    rcctl restart "$sherbimi" 2>>"$SKEDARI_LOG" || regjistro "KUJDES: Deshtoi rinisja e $sherbimi"
                fi
                sherbimet_rinisur="${sherbimet_rinisur} ${sherbimi}"
            fi
        done
    fi

    if [[ -n "$sherbimet_rinisur" ]]; then
        regjistro "Sherbimet e rinisura:${sherbimet_rinisur}"
    else
        regjistro "Asnje sherbim nuk kerkonte rinisje."
    fi

    echo "$sherbimet_rinisur"
}

kryesore() {
    merr_bllokimin
    echo $$ > "${SKEDARI_BLLOKIMIT}/pid"
    regjistro "===== abissnet update-watchdog filloi ====="

    if ! kontrollo_rrjetin; then
        ndalo "Rrjeti nuk eshte i disponueshem. Nuk mund te kontrollohen perditesimet."
    fi

    if ! kontrollo_hapesiren; then
        ndalo "Hapesira ne disk eshte nen ${HAPESIRA_MIN_MB}MB. Perditesimet nuk zbatohen."
    fi

    local distro
    distro="$(zbulo_distro)"
    regjistro "Distro: $distro"

    case "$distro" in
        almalinux|fedora|rocky)
            kontrollo_dnf;    zbato_perditesimet() { zbato_dnf; } ;;
        centos)
            if command -v dnf &>/dev/null; then
                kontrollo_dnf;    zbato_perditesimet() { zbato_dnf; }
            else
                kontrollo_yum;    zbato_perditesimet() { zbato_yum; }
            fi ;;
        debian|ubuntu)
            kontrollo_apt;    zbato_perditesimet() { zbato_apt; } ;;
        alpine)
            kontrollo_apk;    zbato_perditesimet() { zbato_apk; } ;;
        arch)
            kontrollo_pacman; zbato_perditesimet() { zbato_pacman; } ;;
        freebsd)
            kontrollo_freebsd; zbato_perditesimet() { zbato_freebsd; } ;;
        openbsd)
            kontrollo_openbsd; zbato_perditesimet() { zbato_openbsd; } ;;
        flatcar|coreos)
            kontrollo_flatcar; zbato_perditesimet() { zbato_flatcar; } ;;
        *)
            ndalo "Distro e pambeshtetut: $distro" ;;
    esac

    if [[ "$NUMRI_PERDITESIMEVE" -eq 0 ]]; then
        regjistro "Asnje perditesim."
        dergo_telegram "abissnet update-watchdog | Host: ${EMRI_SERVERIT} | Asnje perditesim. Sistemi eshte i perditesuar." || true
        regjistro "===== abissnet update-watchdog perfundoi (asnje pune) ====="
        exit 0
    fi

    regjistro "$NUMRI_PERDITESIMEVE perditesim(e) te disponueshme:"
    regjistro "$PERDITESIMET_GATI"

    local lista_paketave
    lista_paketave="$(echo "$PERDITESIMET_GATI" | head -50 | pastro_markdown | sed 's/^/- /')"
    local shkurtuar=""
    if [[ "$NUMRI_PERDITESIMEVE" -gt 50 ]]; then
        shkurtuar="%0A(... dhe $((NUMRI_PERDITESIMEVE - 50)) te tjera)"
    fi

    local vonesa_min=$((VONESA_SEKONDA / 60))
    local mesazhi="*abissnet update\\-watchdog*%0A"
    mesazhi+="Host: \`${EMRI_SERVERIT}\`%0A"
    mesazhi+="Distro: \`${distro}\`%0A"
    mesazhi+="Perditesime: *${NUMRI_PERDITESIMEVE}*%0A%0A"
    mesazhi+="\`\`\`%0A${lista_paketave}%0A\`\`\`"
    mesazhi+="${shkurtuar}%0A%0A"
    mesazhi+="Perditesimet do te zbatohen pas *${vonesa_min} minutash*."

    if ! dergo_telegram "$mesazhi"; then
        ndalo "Njoftimi Telegram deshtoi. Perditesimet nuk zbatohen pa njoftim."
    fi
    regjistro "Njoftimi u dergua. Pritje ${vonesa_min} minuta para zbatimit."

    sleep "$VONESA_SEKONDA"

    if ! kontrollo_hapesiren; then
        ndalo "Hapesira ne disk eshte nen ${HAPESIRA_MIN_MB}MB. Perditesimet nuk zbatohen."
    fi

    regjistro "Zbatim i perditesimeve"
    local koha_fillimit koha_mbarimit
    koha_fillimit="$(date +%s)"

    if zbato_perditesimet; then
        koha_mbarimit="$(date +%s)"
        local kaluar=$(( (koha_mbarimit - koha_fillimit) / 60 ))
        regjistro "Perditesimet u zbatuan me sukses ne ~${kaluar} min."

        local sherbimet_te_rinisura
        sherbimet_te_rinisura="$(rinise_sherbimet)"

        local mesazhi_perfundim="abissnet update\\-watchdog | Host: \`${EMRI_SERVERIT}\` | *${NUMRI_PERDITESIMEVE}* paketa u perditesuan ne ~${kaluar} min."
        if [[ -n "$sherbimet_te_rinisura" ]]; then
            mesazhi_perfundim+="%0ASherbimet e rinisura: \`${sherbimet_te_rinisura}\`"
        fi
        dergo_telegram "$mesazhi_perfundim" || true
    else
        regjistro "GABIM: Komanda e perditesimit deshtoi."
        dergo_telegram "abissnet update\\-watchdog | Host: \`${EMRI_SERVERIT}\` | Perditesimi deshtoi. Kontrollo log: \`${SKEDARI_LOG}\`" || true
    fi

    regjistro "===== abissnet update-watchdog perfundoi ====="
}

kryesore "$@"
