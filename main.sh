#!/bin/bash
set -Eeuo pipefail

# ============================================================
# KERAMAT EMPIRE - Bootstrap / Authorization
# Supports Debian 12/13, Ubuntu 22.04/24.04/26.04/26.10; Ubuntu 20.04 legacy
# ============================================================

export DEBIAN_FRONTEND=noninteractive

Green="\e[92;1m"
BlueBee="\033[94;1m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[96;1m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
NC='\e[0m'

TIME="$(date '+%d %b %Y')"
data_server="$(date)"
date_list="$(date '+%Y-%m-%d')"

REPO="https://raw.githubusercontent.com/hassinz27/Keramat_Empire/main/"
data_ip="${REPO}ip"

get_public_ip() {
    local ip=""

    if command -v curl >/dev/null 2>&1; then
        ip="$(curl -4fsSL --max-time 10 https://api.ipify.org 2>/dev/null || true)"
    fi

    if [[ -z "${ip}" ]] && command -v wget >/dev/null 2>&1; then
        ip="$(wget -qO- --timeout=10 https://api.ipify.org 2>/dev/null || true)"
    fi

    printf '%s\n' "${ip}"
}

ipsaya="$(get_public_ip)"

if [[ -z "${ipsaya}" ]]; then
    echo -e "${YELLOW}Tidak dapat mengesan public IPv4 VPS.${NC}"
    echo -e "${YELLOW}Pastikan curl atau wget tersedia dan internet boleh dicapai.${NC}"
    exit 1
fi

echo -e "Memeriksa VPS Anda..."
sleep 0.5

checking_sc() {
    local useexp=""

    if command -v curl >/dev/null 2>&1; then
        useexp="$(curl -4fsSL --max-time 15 "${data_ip}" 2>/dev/null |
            awk -v ip="${ipsaya}" '$1 == ip {print $3; exit}')"
    elif command -v wget >/dev/null 2>&1; then
        useexp="$(wget -qO- --timeout=15 "${data_ip}" 2>/dev/null |
            awk -v ip="${ipsaya}" '$1 == ip {print $3; exit}')"
    fi

    if [[ -z "${useexp}" ]]; then
        echo -e "${REDBG} Authorization data tidak dapat dibaca. ${NC}"
        echo -e "${YELLOW}Semak sambungan internet atau fail authorization GitHub.${NC}"
        exit 1
    fi

    if [[ "${date_list}" < "${useexp}" ]]; then
        return 0
    fi

    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    echo -e "\033[42m          404 NOT FOUND AUTOSCRIPT          \033[0m"
    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    echo
    echo -e "${RED}PERMISSION DENIED !${NC}"
    echo -e "   ${YELLOW}Your VPS${NC} ${ipsaya} ${YELLOW}Has been Banned${NC}"
    echo -e "     ${YELLOW}Buy access permissions for scripts${NC}"
    echo -e "             ${YELLOW}Contact Admin :${NC}"
    echo -e "      \033[0;36mTelegram${NC} t.me/@KERAMAT_EMPIRE"
    echo -e "      ${GREEN}WhatsApp${NC} wa.me/-"
    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    exit 1
}

checking_sc

clear
export IP="${ipsaya}"

echo -e "${BlueBee}╔════════════════════════════════════════════════╗${NC}"
echo -e "\033[96;1m                       KERAMAT STORE               \033[0m"
echo -e "${BlueBee}╚════════════════════════════════════════════════╝${NC}"
echo

# Detect and validate supported operating systems.
if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: /etc/os-release tidak dijumpai."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

OS_ID="${ID:-unknown}"
OS_VERSION_ID="${VERSION_ID:-unknown}"
OS_CODENAME="${VERSION_CODENAME:-}"
OS_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
OS_Name="${OS_NAME}"
Kernel="$(uname -r)"
ARCH="$(uname -m)"
Arch="${ARCH}"

OS_SUPPORT_LEVEL="current"

export OS_ID OS_VERSION_ID OS_CODENAME
export OS_NAME OS_Name Kernel ARCH Arch OS_SUPPORT_LEVEL

case "${OS_ID}" in
    debian)
        case "${OS_VERSION_ID%%.*}" in
            12|13) ;;
            *)
                echo "ERROR: Debian ${OS_VERSION_ID} belum disokong."
                exit 1
                ;;
        esac
        ;;
    ubuntu)
        case "${OS_VERSION_ID}" in
            20.04)
                OS_SUPPORT_LEVEL="legacy"
                ;;
            22.04|24.04|26.04|26.10)
                ;;
            *)
                echo "ERROR: Ubuntu ${OS_VERSION_ID} belum disokong."
                exit 1
                ;;
        esac
        ;;
    *)
        echo "ERROR: OS tidak disokong: ${OS_ID} (${OS_NAME})."
        exit 1
        ;;
esac

case "${ARCH}" in
    x86_64|amd64|aarch64|arm64) ;;
    *)
        echo "WARNING: Architecture ${ARCH} belum diuji sepenuhnya."
        ;;
esac

echo "OS detected : ${OS_NAME}"
echo "OS ID       : ${OS_ID}"
echo "OS version  : ${OS_VERSION_ID}"
echo "Support     : ${OS_SUPPORT_LEVEL}"
echo "Architecture: ${ARCH}"

if [[ "${OS_SUPPORT_LEVEL}" == "legacy" ]]; then
    echo
    echo "WARNING: Ubuntu 20.04 is in legacy compatibility mode."
    echo "Standard security support ended on 31 May 2025."
    echo "Use Ubuntu Pro/ESM or migrate to a supported Ubuntu release."
fi


function first_setup() {
    clear
    print_install "Setup System & Dependencies"

    export DEBIAN_FRONTEND=noninteractive

    if [[ "${EUID}" -ne 0 ]]; then
        print_error "Installer mesti dijalankan sebagai root."
        return 1
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        print_error "APT package manager tidak tersedia."
        return 1
    fi

    if ! apt-get update -y; then
        print_error "Gagal mengemaskini APT repository."
        return 1
    fi

    # Essential bootstrap packages only.
    if ! apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        debconf-utils \
        unzip \
        zip \
        git; then
        print_error "Gagal memasang bootstrap packages."
        return 1
    fi

    # Preseed iptables-persistent questions before installation.
    if command -v debconf-set-selections >/dev/null 2>&1; then
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true \
            | debconf-set-selections

        echo iptables-persistent iptables-persistent/autosave_v6 boolean true \
            | debconf-set-selections
    fi

    print_success "System Setup"
}
clear

function nginx_install() {
    clear

    print_install "Setup Nginx - ${OS_NAME}"

    apt-get update -y
    apt-get install -y nginx

    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl restart nginx

    if ! systemctl is-active --quiet nginx; then
        print_error "Nginx gagal berjalan"
        return 1
    fi

    print_success "Nginx"
}

TIMES="10"
CHATID=""
KEY=""
URL="https://api.telegram.org/bot$KEY/sendMessage"

# ============================================================
# BASE PACKAGES
# ============================================================

# Install optional packages without making the entire installer fail
# when a package is unavailable on a particular Debian/Ubuntu release.
function apt_install_optional() {
    local package
    local -a available=()
    local -a unavailable=()

    for package in "$@"; do
        if apt-cache show "${package}" >/dev/null 2>&1; then
            available+=("${package}")
        else
            unavailable+=("${package}")
        fi
    done

    if ((${#available[@]} > 0)); then
        if ! apt-get install -y --no-install-recommends "${available[@]}"; then
            echo -e "${YELLOW}Pemasangan kumpulan pakej pilihan gagal. Cuba satu per satu.${NC}"

            for package in "${available[@]}"; do
                if ! apt-get install -y --no-install-recommends "${package}"; then
                    echo -e "${YELLOW}Skip pakej pilihan: ${package}${NC}"
                fi
            done
        fi
    fi

    for package in "${unavailable[@]}"; do
        echo -e "${YELLOW}Pakej tidak tersedia pada repository OS ini. Skip: ${package}${NC}"
    done
}

function base_package() {
    clear
    print_install "Menginstall Packet Yang Dibutuhkan"

    export DEBIAN_FRONTEND=noninteractive

    if ! apt-get update -y; then
        print_error "Gagal mengemaskini APT repository."
        return 1
    fi

    # Essential runtime / networking tools.
    if ! apt-get install -y --no-install-recommends \
        bash-completion \
        bc \
        cron \
        curl \
        dnsutils \
        htop \
        jq \
        lsof \
        net-tools \
        netcat-openbsd \
        openssl \
        rsyslog \
        socat \
        tar \
        wget \
        xz-utils \
        screen \
        dos2unix \
        sed \
        grep \
        gawk \
        util-linux; then
        print_error "Gagal memasang runtime packages."
        return 1
    fi

    # Archive / source management.
    if ! apt-get install -y --no-install-recommends zip unzip git; then
        print_error "Gagal memasang archive tools."
        return 1
    fi

    apt_install_optional p7zip-full make build-essential cmake

    # Python 3 runtime. pip is optional.
    if ! apt-get install -y --no-install-recommends python3; then
        print_error "Python 3 gagal dipasang."
        return 1
    fi

    apt_install_optional python3-pip

    # VPN / firewall packages.
    if ! apt-get install -y --no-install-recommends \
        openvpn \
        easy-rsa \
        iptables \
        iptables-persistent; then
        print_error "Gagal memasang VPN / firewall packages."
        return 1
    fi

    apt_install_optional netfilter-persistent

    # Monitoring.
    if ! apt-get install -y --no-install-recommends vnstat; then
        print_error "VNStat gagal dipasang."
        return 1
    fi

    apt_install_optional speedtest-cli

    # Development libraries used by legacy optional modules.
    # libc6 is deliberately excluded: it is a core system package.
    apt_install_optional \
        libnss3 \
        libnss3-dev \
        libnspr4-dev \
        pkg-config \
        libpam0g-dev \
        libcap-ng-dev \
        libcap-ng-utils \
        libselinux1-dev \
        libcurl4-openssl-dev \
        libevent-dev \
        zlib1g-dev \
        libssl-dev \
        libsqlite3-dev \
        flex \
        bison \
        libxml-parser-perl

    # Time synchronization is optional.
    apt_install_optional chrony

    if command -v chronyc >/dev/null 2>&1; then
        systemctl enable --now chrony >/dev/null 2>&1 || \
        systemctl enable --now chronyd >/dev/null 2>&1 || true
    fi

    # Legacy menu compatibility.
    apt_install_optional sudo msmtp-mta bsd-mailx

    apt-get clean

    # Do not disable or purge UFW, nftables or firewalld.
    print_success "Packet Yang Dibutuhkan"
}
clear

function pasang_domain() {
    clear
    print_install "Domain"

    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}                 KERAMAT DOMAIN${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${YELLOW}Pastikan DNS A record domain sudah menunjuk ke:${NC}"
    echo -e "IP VPS : ${ipsaya}"
    echo

    local host1=""

    while true; do
        read -r -p "INPUT DOMAIN : " host1
        host1="${host1,,}"

        # Remove accidental URL prefix/path.
        host1="${host1#http://}"
        host1="${host1#https://}"
        host1="${host1%%/*}"

        if [[ -z "${host1}" ]]; then
            echo -e "${RED}Domain tidak boleh kosong.${NC}"
            continue
        fi

        if [[ ! "${host1}" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]; then
            echo -e "${RED}Format domain tidak sah: ${host1}${NC}"
            continue
        fi

        break
    done

    mkdir -p /etc/xray

    printf '%s\n' "${host1}" > /etc/xray/domain
    printf '%s\n' "${host1}" > /root/domain

    # Keep the compatibility variable used by older modules.
    domain="${host1}"
    export domain

    echo
    echo -e "${GREEN}Domain disimpan: ${host1}${NC}"

    local resolved_ip=""
    resolved_ip="$(getent ahostsv4 "${host1}" 2>/dev/null | awk 'NR==1 {print $1}')"

    if [[ -n "${resolved_ip}" ]]; then
        echo -e "${GREEN}DNS IPv4 : ${resolved_ip}${NC}"

        if [[ "${resolved_ip}" == "${ipsaya}" ]]; then
            echo -e "${GREEN}DNS OK - domain mengarah ke VPS ini.${NC}"
        else
            echo -e "${YELLOW}WARNING: domain belum mengarah ke IP VPS ini.${NC}"
            echo -e "${YELLOW}${host1} -> ${resolved_ip}${NC}"
            echo -e "${YELLOW}VPS       -> ${ipsaya}${NC}"
        fi
    else
        echo -e "${YELLOW}WARNING: domain belum resolve ke IPv4.${NC}"
        echo -e "${YELLOW}SSL akan gagal jika DNS belum siap.${NC}"
    fi

    print_success "Domain"
}

function pasang_ssl() {
    clear
    print_install "SSL Certificate"

    mkdir -p /etc/xray

    local domain_name="${domain:-}"

    if [[ -z "${domain_name}" ]] && [[ -s /etc/xray/domain ]]; then
        domain_name="$(head -n1 /etc/xray/domain | tr -d '\r\n' | xargs)"
    fi

    if [[ -z "${domain_name}" ]]; then
        print_error "Domain belum ditetapkan"
        return 1
    fi

    domain="${domain_name}"
    export domain

    if ! command -v certbot >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y certbot
    fi

    # Check DNS before requesting certificate.
    local resolved_ip=""
    resolved_ip="$(getent ahostsv4 "${domain_name}" 2>/dev/null | awk 'NR==1 {print $1}')"

    if [[ -z "${resolved_ip}" ]]; then
        print_error "Domain ${domain_name} tidak dapat resolve ke IPv4"
        echo -e "${YELLOW}Pastikan DNS A record sudah diarahkan ke ${ipsaya}.${NC}"
        return 1
    fi

    if [[ "${resolved_ip}" != "${ipsaya}" ]]; then
        print_error "DNS domain tidak mengarah ke VPS"
        echo -e "${YELLOW}${domain_name} -> ${resolved_ip}${NC}"
        echo -e "${YELLOW}VPS          -> ${ipsaya}${NC}"
        return 1
    fi

    local nginx_was_active=0
    local haproxy_was_active=0

    if systemctl is-active --quiet nginx; then
        nginx_was_active=1
    fi

    if systemctl is-active --quiet haproxy; then
        haproxy_was_active=1
    fi

    # Stop services that may occupy port 80.
    systemctl stop nginx >/dev/null 2>&1 || true
    systemctl stop haproxy >/dev/null 2>&1 || true

    local certbot_ok=0

    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --keep-until-expiring \
        --no-eff-email \
        -d "${domain_name}"; then
        certbot_ok=1
    fi

    # Restore services even if Certbot fails.
    if [[ "${nginx_was_active}" -eq 1 ]]; then
        systemctl start nginx >/dev/null 2>&1 || true
    fi

    if [[ "${haproxy_was_active}" -eq 1 ]]; then
        systemctl start haproxy >/dev/null 2>&1 || true
    fi

    if [[ "${certbot_ok}" -ne 1 ]]; then
        print_error "Gagal mendapatkan SSL certificate"
        return 1
    fi

    local cert_dir="/etc/letsencrypt/live/${domain_name}"

    if [[ ! -s "${cert_dir}/fullchain.pem" ]] ||
       [[ ! -s "${cert_dir}/privkey.pem" ]]; then
        print_error "Certificate SSL tidak lengkap"
        return 1
    fi

    ln -sfn "${cert_dir}/fullchain.pem" /etc/xray/fullchain.pem
    ln -sfn "${cert_dir}/privkey.pem" /etc/xray/private.key

    chmod 755 /etc/xray
    chmod 644 "${cert_dir}/fullchain.pem"
    chmod 600 "${cert_dir}/privkey.pem"

    print_success "SSL Certificate"
}

function install_xray() {
    clear
    print_install "Core Xray Latest Version"

    local xray_bin="/usr/local/bin/xray"
    local config="/etc/xray/config.json"
    local config_url="${REPO}files/config.json"
    local tmp_config="/tmp/keramat-xray-config.json"

    mkdir -p /etc/xray /run/xray

    # Install Xray rasmi.
    if ! bash -c "$(curl -4fsSL --max-time 60 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
        print_error "Installer rasmi Xray gagal"
        return 1
    fi

    if [[ ! -x "${xray_bin}" ]]; then
        print_error "Binary Xray tidak dijumpai"
        return 1
    fi

    # Cuba ambil config Keramat dari repository.
    rm -f "${tmp_config}"

    if curl -4fsSL --max-time 30 "${config_url}" -o "${tmp_config}" 2>/dev/null &&
       [[ -s "${tmp_config}" ]]; then

        mv "${tmp_config}" "${config}"
        chmod 0644 "${config}"

    else
        echo -e "${YELLOW}config.json Keramat tidak tersedia. Membina config VLESS TCP asas.${NC}"

        local vless_uuid
        vless_uuid="$(cat /proc/sys/kernel/random/uuid)"

        cat >"${config}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${vless_uuid}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

        chmod 0644 "${config}"
    fi

    # Validate config SEBELUM restart service.
    if ! "${xray_bin}" run -test -config "${config}" >/dev/null 2>&1; then
        print_error "Konfigurasi Xray tidak sah"
        echo -e "${YELLOW}Config: ${config}${NC}"
        return 1
    fi

    # Simpan maklumat ISP/city untuk menu.
    curl -4fsSL --max-time 15 https://ipinfo.io/city \
        >/etc/xray/city 2>/dev/null || true

    curl -4fsSL --max-time 15 https://ipinfo.io/org |
        cut -d " " -f 2-10 >/etc/xray/isp 2>/dev/null || true

    # Xray rasmi menggunakan systemd.
    # Keramat menggunakan /etc/xray/config.json.
    mkdir -p /etc/systemd/system/xray.service.d

    cat >/etc/systemd/system/xray.service.d/10-keramat.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
EOF

    systemctl daemon-reload

    if ! systemctl enable xray >/dev/null 2>&1; then
        print_error "Gagal enable service Xray"
        return 1
    fi

    if ! systemctl restart xray; then
        print_error "Gagal restart service Xray"
        return 1
    fi

    if ! systemctl is-active --quiet xray; then
        print_error "Service Xray gagal berjalan"
        return 1
    fi

    print_success "Core Xray Latest Version"
    print_success "Konfigurasi Xray"
}

function ssh() {
    clear
    print_install "OpenSSH"

    apt-get update -y
    apt-get install -y openssh-server openssh-client

    # Validate SSH configuration before restarting.
    if ! sshd -t; then
        print_error "Konfigurasi SSH tidak sah"
        return 1
    fi

    if systemctl enable ssh >/dev/null 2>&1; then
        systemctl restart ssh
    elif systemctl enable sshd >/dev/null 2>&1; then
        systemctl restart sshd
    else
        print_error "Unit OpenSSH tidak dijumpai"
        return 1
    fi

    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        print_success "OpenSSH"
        return 0
    fi

    print_error "OpenSSH gagal berjalan"
    return 1
}

function ins_dropbear() {
    clear
    print_install "Dropbear - Ports 109 / 143"

    export DEBIAN_FRONTEND=noninteractive

    if ! apt-get update -y ||
       ! apt-get install -y --no-install-recommends dropbear; then
        print_error "Gagal memasang Dropbear"
        return 1
    fi

    local config="/etc/default/dropbear"
    local backup_file=""
    local had_old_config=0
    local restart_ok=0
    local port
    local ss_bin=""

    for candidate in /usr/bin/ss /bin/ss; do
        if [[ -x "${candidate}" ]]; then
            ss_bin="${candidate}"
            break
        fi
    done

    if [[ -z "${ss_bin}" ]]; then
        print_error "Arahan ss tidak dijumpai"
        return 1
    fi

    mkdir -p /etc/default

    if [[ -f "${config}" ]]; then
        backup_file="$(mktemp)" || return 1
        if ! cp -a "${config}" "${backup_file}"; then
            rm -f "${backup_file}"
            print_error "Gagal backup konfigurasi Dropbear"
            return 1
        fi
        had_old_config=1
    fi

    # Do not take ports already owned by unrelated services.
    for port in 109 143; do
        if "${ss_bin}" -H -lntp 2>/dev/null |
            awk -v port="${port}" \
                '$4 ~ (":" port "$") && $0 !~ /dropbear/ {found=1}
                 END {exit !found}'; then
            [[ -n "${backup_file}" ]] && rm -f "${backup_file}"
            print_error "Port ${port} digunakan oleh servis lain"
            return 1
        fi
    done

    cat >"${config}" <<'EOF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_RECEIVE_WINDOW=65536
DROPBEAR_EXTRA_ARGS="-p 143"
EOF

    chmod 0644 "${config}"

    if systemctl cat dropbear >/dev/null 2>&1; then
        systemctl enable dropbear >/dev/null 2>&1 || true
        systemctl restart dropbear && restart_ok=1
    elif [[ -x /etc/init.d/dropbear ]]; then
        update-rc.d dropbear defaults >/dev/null 2>&1 || true
        /etc/init.d/dropbear restart && restart_ok=1
    fi

    if [[ "${restart_ok}" -ne 1 ]]; then
        if [[ "${had_old_config}" -eq 1 ]]; then
            cp -a "${backup_file}" "${config}"
        else
            rm -f "${config}"
        fi
        systemctl restart dropbear >/dev/null 2>&1 || true
        [[ -n "${backup_file}" ]] && rm -f "${backup_file}"
        print_error "Dropbear gagal dimulakan"
        return 1
    fi

    # Verify both TCP listeners belong to Dropbear.
    for port in 109 143; do
        if ! "${ss_bin}" -H -lntp 2>/dev/null |
            awk -v port="${port}" \
                '$4 ~ (":" port "$") && /dropbear/ {found=1}
                 END {exit !found}'; then

            if [[ "${had_old_config}" -eq 1 ]]; then
                cp -a "${backup_file}" "${config}"
            else
                rm -f "${config}"
            fi
            systemctl restart dropbear >/dev/null 2>&1 || true
            [[ -n "${backup_file}" ]] && rm -f "${backup_file}"

            print_error "Dropbear gagal listening pada port ${port}"
            return 1
        fi
    done

    [[ -n "${backup_file}" ]] && rm -f "${backup_file}"

    print_success "Dropbear - Ports 109 / 143"
}
function ins_openvpn() {
    clear
    print_install "OpenVPN"

    apt-get update -y
    apt-get install -y openvpn easy-rsa

    local openvpn_script="/tmp/keramat-openvpn.sh"

    # Optional Keramat installer. The base packages remain usable
    # even when no custom installer exists in the repository.
    if curl -4fsSL --max-time 30 "${REPO}files/openvpn" \
        -o "${openvpn_script}" && [[ -s "${openvpn_script}" ]]; then

        chmod 700 "${openvpn_script}"

        if ! bash "${openvpn_script}"; then
            rm -f "${openvpn_script}"
            print_error "Installer OpenVPN gagal"
            return 1
        fi

        rm -f "${openvpn_script}"
    else
        rm -f "${openvpn_script}"
        echo -e "${YELLOW}Installer OpenVPN Keramat tidak tersedia.${NC}"
        echo -e "${YELLOW}Package OpenVPN telah dipasang; konfigurasi boleh dibuat kemudian.${NC}"
    fi

    # Restart only real OpenVPN instance units when they exist.
    local restarted=0

    while IFS= read -r unit; do
        [[ -n "${unit}" ]] || continue
        systemctl enable "${unit}" >/dev/null 2>&1 || true
        systemctl restart "${unit}" >/dev/null 2>&1 || true
        restarted=1
    done < <(
        systemctl list-unit-files --type=service --no-legend 'openvpn-client@*.service' \
            'openvpn-server@*.service' 2>/dev/null |
        awk '{print $1}'
    )

    if [[ "${restarted}" -eq 0 ]]; then
        echo -e "${YELLOW}Tiada instance OpenVPN aktif untuk direstart.${NC}"
    fi

    print_success "OpenVPN"
}

function ins_backup() {
    clear
    print_install "Backup Tools"

    apt-get update -y
    apt-get install -y rclone

    # Keep an existing rclone configuration.
    # Never download credentials/tokens automatically from the repository.
    mkdir -p /root/.config/rclone

    if [[ -f /root/.config/rclone/rclone.conf ]]; then
        chmod 600 /root/.config/rclone/rclone.conf
    fi

    # Backup directory used by the menu.
    mkdir -p /home/files

    # Protect an existing mail configuration.
    # Do NOT create one with hardcoded credentials.
    if [[ -f /etc/msmtprc ]]; then
        chmod 600 /etc/msmtprc
    fi

    print_success "Backup Tools"
}

function ins_swab() {
    clear
    print_install "Performance / Swap / BBR"

    # --------------------------------------------------------
    # Swap
    # --------------------------------------------------------
    local swap_total_mb=0

    swap_total_mb="$(free -m | awk '/^Swap:/ {print $2+0}')"

    if [[ "${swap_total_mb}" -lt 512 ]]; then
        echo -e "${CYAN}Creating 1GB swap...${NC}"

        if [[ ! -f /swapfile ]]; then
            if command -v fallocate >/dev/null 2>&1; then
                fallocate -l 1G /swapfile
            else
                dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
            fi
        fi

        chmod 600 /swapfile

        if ! blkid /swapfile >/dev/null 2>&1; then
            mkswap /swapfile >/dev/null
        fi

        if ! swapon --show=NAME --noheadings | grep -qx '/swapfile'; then
            swapon /swapfile || true
        fi

        if ! grep -qE '^/swapfile[[:space:]]+none[[:space:]]+swap' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
    else
        echo -e "${GREENBG} Swap already available: ${swap_total_mb} MB ${FONT}"
    fi

    # --------------------------------------------------------
    # TCP BBR
    # --------------------------------------------------------
    mkdir -p /etc/sysctl.d

    cat > /etc/sysctl.d/99-keramat-network.conf <<'EOF'
# KERAMAT EMPIRE network tuning

net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system >/dev/null 2>&1 || true

    local congestion=""
    congestion="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"

    if [[ "${congestion}" == "bbr" ]]; then
        echo -e "${GREENBG} TCP BBR enabled ${FONT}"
    else
        echo -e "${YELLOW} TCP BBR tidak tersedia pada kernel ini. Skip.${NC}"
    fi

    # --------------------------------------------------------
    # Time synchronization
    # --------------------------------------------------------
    if command -v chronyc >/dev/null 2>&1; then
        chronyc makestep >/dev/null 2>&1 || true
    fi

    print_success "Performance / Swap / BBR"
}

function ins_Fail2ban() {
    clear
    print_install "Fail2ban"

    apt-get update -y
    apt-get install -y fail2ban

    mkdir -p /etc/fail2ban/jail.d

    cat > /etc/fail2ban/jail.d/keramat-sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF

    # Validate configuration before restart.
    if fail2ban-client -t >/dev/null 2>&1; then
        systemctl enable fail2ban >/dev/null 2>&1 || true
        systemctl restart fail2ban

        if systemctl is-active --quiet fail2ban; then
            print_success "Fail2ban"
            return 0
        fi
    fi

    print_error "Fail2ban gagal berjalan"
    return 1
}

function ins_epro() {
    clear
    print_install "Xray / Network Extras"

    # Xray's official installer already provides geoip.dat/geosite.dat.
    # Do not download or execute the old Keramat legacy WebSocket/EPRO
    # payloads unless they are rebuilt and tested separately.

    if [[ -x /usr/local/bin/xray ]]; then
        if /usr/local/bin/xray version >/dev/null 2>&1; then
            echo -e "${GREENBG} Xray binary tersedia ${FONT}"
        fi
    else
        echo -e "${YELLOW}Xray belum dipasang. Geo database di-skip.${NC}"
    fi

    # Optional BitTorrent blocking.
    # Only add the rules when the required tools are available.
    if command -v iptables >/dev/null 2>&1 && \
       command -v netfilter-persistent >/dev/null 2>&1; then

        iptables -C FORWARD -m string --string "get_peers" --algo bm -j DROP \
            >/dev/null 2>&1 || \
        iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP

        iptables -C FORWARD -m string --string "announce_peer" --algo bm -j DROP \
            >/dev/null 2>&1 || \
        iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP

        netfilter-persistent save >/dev/null 2>&1 || true
    fi

    print_success "Xray / Network Extras"
}

function ins_restart() {
    clear
    print_install "Restarting Keramat Services"

    systemctl daemon-reload

    # Restart only services that Keramat actually uses.
    local service
    local services=(
        nginx
        ssh
        dropbear
        fail2ban
        cron
        vnstat
        xray
    )

    for service in "${services[@]}"; do
        if systemctl cat "${service}" >/dev/null 2>&1; then
            systemctl restart "${service}" >/dev/null 2>&1 || \
                echo -e "${YELLOW}Skip: ${service}${NC}"
        fi
    done

    # Enable core services when their units exist.
    for service in nginx ssh dropbear fail2ban cron xray; do
        if systemctl cat "${service}" >/dev/null 2>&1; then
            systemctl enable "${service}" >/dev/null 2>&1 || true
        fi
    done

    # Persist firewall rules when available.
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    fi

    print_success "Keramat Services"
}

function install_menu() {
    clear
    print_install "Keramat Menu"

    local menu_zip="/tmp/keramat-menu.zip"
    local menu_dir="/tmp/keramat-menu"

    rm -rf "${menu_dir}" "${menu_zip}"
    mkdir -p "${menu_dir}" /usr/local/sbin

    if ! curl -4fsSL --max-time 30 "${REPO}menu.zip" -o "${menu_zip}"; then
        print_error "Gagal download menu.zip"
        return 1
    fi

    if ! unzip -t "${menu_zip}" >/dev/null 2>&1; then
        print_error "menu.zip rosak"
        rm -rf "${menu_dir}" "${menu_zip}"
        return 1
    fi

    unzip -q "${menu_zip}" -d "${menu_dir}"

    if [[ ! -d "${menu_dir}/menu" ]]; then
        print_error "Struktur menu.zip tidak sah"
        rm -rf "${menu_dir}" "${menu_zip}"
        return 1
    fi

    while IFS= read -r -d '' file; do
        local name
        name="$(basename "${file}")"

        # Only install regular files with safe command names.
        if [[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
            install -m 0755 "${file}" "/usr/local/sbin/${name}"
        fi
    done < <(find "${menu_dir}/menu" -maxdepth 1 -type f -print0)

    rm -rf "${menu_dir}" "${menu_zip}"

    if [[ ! -x /usr/local/sbin/menu ]]; then
        print_error "Command menu gagal dipasang"
        return 1
    fi

    if [[ ! -x /usr/local/sbin/welcome ]]; then
        print_error "Command welcome gagal dipasang"
        return 1
    fi

    print_success "Keramat Menu"
}

function profile(){
    clear

    mkdir -p /etc/keramat

    # Ensure administrative commands installed in /usr/local/sbin
    # are available in interactive root sessions.
    if ! grep -qF 'export PATH="/usr/local/sbin:/usr/local/bin:$PATH"' /root/.profile 2>/dev/null; then
        printf '%s\n' 'export PATH="/usr/local/sbin:/usr/local/bin:$PATH"' >> /root/.profile
    fi

    cat >/etc/cron.d/xp_all <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/local/sbin/xp
EOF

    cat >/etc/cron.d/logclean <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root /usr/local/sbin/clearlog
EOF

    cat >/etc/cron.d/log.nginx <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/5 * * * * root /usr/bin/truncate -s 0 /var/log/nginx/access.log
EOF

    cat >/etc/cron.d/log.xray <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/5 * * * * root /usr/bin/truncate -s 0 /var/log/xray/access.log
EOF

    # Automatic VPS maintenance reboot.
    # Default: enabled at 05:00 every day.
    printf '%s\n' 'enabled=true' 'hour=5' 'minute=0' \
        > /etc/keramat/auto-reboot

    cat >/etc/cron.d/keramat-auto-reboot <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 5 * * * root /usr/local/sbin/keramat-auto-reboot
EOF

    cat >/usr/local/sbin/keramat-auto-reboot <<'EOF'
#!/bin/sh

CONFIG="/etc/keramat/auto-reboot"

if [ -f "$CONFIG" ] && grep -q '^enabled=true$' "$CONFIG"; then
    /usr/bin/logger -t keramat "Scheduled maintenance reboot"
    /sbin/reboot
fi
EOF

    chmod 700 /usr/local/sbin/keramat-auto-reboot

    chmod 644 \
        /root/.profile \
        /etc/cron.d/xp_all \
        /etc/cron.d/logclean \
        /etc/cron.d/log.nginx \
        /etc/cron.d/log.xray \
        /etc/cron.d/keramat-auto-reboot

    # Add valid login shell only when it is not already present.
    if [[ -x /usr/sbin/nologin ]] && ! grep -qxF '/usr/sbin/nologin' /etc/shells; then
        printf '%s\n' '/usr/sbin/nologin' >> /etc/shells
    fi

    systemctl restart cron

    print_success "Menu Packet"
}

function enable_services() {
    clear
    print_install "Enable Service"

    systemctl daemon-reload

    # Enable services only when their systemd units exist.
    local service
    local services=(
        nginx
        xray
        cron
        dropbear
        fail2ban
        vnstat
    )

    for service in "${services[@]}"; do
        if systemctl cat "${service}" >/dev/null 2>&1; then
            systemctl enable "${service}" >/dev/null 2>&1 || true
        fi
    done

    # Restore persistent firewall rules when available.
    if command -v netfilter-persistent >/dev/null 2>&1; then
        if systemctl cat netfilter-persistent >/dev/null 2>&1; then
            systemctl enable netfilter-persistent >/dev/null 2>&1 || true
            systemctl start netfilter-persistent >/dev/null 2>&1 || true
        fi
    fi

    print_success "Enable Service"
    clear
}

function instal() {
    clear

    echo -e "${CYAN}"
    echo "======================================================"
    echo "              KERAMAT EMPIRE INSTALLER"
    echo "======================================================"
    echo -e "${NC}"
    echo -e "OS           : ${OS_NAME}"
    echo -e "Architecture : ${ARCH}"
    echo -e "Public IP    : ${ipsaya}"
    echo ""

    # --------------------------------------------------------
    # Required foundation
    # --------------------------------------------------------
    first_setup
    base_package
    nginx_install

    # --------------------------------------------------------
    # Domain / SSL
    # --------------------------------------------------------
    pasang_domain
    pasang_ssl

    # --------------------------------------------------------
    # Core proxy
    # --------------------------------------------------------
    install_xray

    # --------------------------------------------------------
    # SSH stack
    # --------------------------------------------------------
    ins_dropbear
    ssh

    # --------------------------------------------------------
    # Optional networking modules
    # --------------------------------------------------------
    # UDP Mini legacy module is intentionally skipped.
    ins_openvpn || echo -e "${YELLOW}OpenVPN gagal/skip.${NC}"

    # --------------------------------------------------------
    # Monitoring / backup / performance
    # --------------------------------------------------------
    ins_vnstat || echo -e "${YELLOW}VNStat gagal/skip.${NC}"
    ins_backup || echo -e "${YELLOW}Backup tools gagal/skip.${NC}"
    ins_swab || echo -e "${YELLOW}Performance tuning gagal/skip.${NC}"
    ins_Fail2ban || echo -e "${YELLOW}Fail2ban gagal/skip.${NC}"

    # --------------------------------------------------------
    # Legacy WebSocket / EPRO
    # --------------------------------------------------------
    ins_epro || echo -e "${YELLOW}EPRO/WebSocket legacy gagal/skip.${NC}"

    # --------------------------------------------------------
    # Final service reload
    # --------------------------------------------------------
    ins_restart

    # --------------------------------------------------------
    # Menu / profile
    # --------------------------------------------------------
    install_menu
    profile
    enable_services

    if command -v menu >/dev/null 2>&1; then
        menu
    fi

    print_success "Keramat Empire Installation"
}


instal
echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}          KERAMAT EMPIRE INSTALL SELESAI${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""
echo -e "OS           : ${OS_NAME}"
echo -e "Architecture : ${ARCH}"
echo -e "Public IP    : ${ipsaya}"
echo ""
echo -e "${YELLOW}VPS tidak akan reboot secara automatik.${NC}"
echo -e "${YELLOW}Sila reboot secara manual jika diperlukan.${NC}"
echo ""
