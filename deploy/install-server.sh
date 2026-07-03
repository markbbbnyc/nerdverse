#!/usr/bin/env bash
# install-server.sh — Idempotent Ubuntu server install for Nerdverse public terminal.
# Run ON the server as root (invoked by bootstrap-remote.sh).
#
# Installs to /opt/nerdverse-public — separate from any developer local save.

set -euo pipefail

INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
REPO_URL="${NERDVERSE_REPO_URL:-https://github.com/markbbbnyc/nerdverse.git}"
GIT_REF="${NERDVERSE_GIT_REF:-main}"
PLAY_USER="${NERDVERSE_PLAY_USER:-nerdverse-play}"
SESSION_ROOT="/var/lib/nerdverse/sessions"
TTYD_VERSION="${TTYD_VERSION:-1.7.7}"

log() { echo "[install] $*"; }

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root on the Ubuntu server." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
log "Installing packages …"
apt-get update -qq
apt-get install -y -qq git mariadb-server nginx openssl curl ca-certificates \
    build-essential cmake git libjson-c-dev libwebsockets-dev

systemctl enable mariadb nginx
systemctl start mariadb || true

# --- ttyd (binary release) ---
if [[ ! -x /usr/local/bin/ttyd ]]; then
    log "Installing ttyd ${TTYD_VERSION} …"
    arch=$(uname -m)
    case "$arch" in
        x86_64)  TTYD_ARCH="x86_64" ;;
        aarch64) TTYD_ARCH="aarch64" ;;
        *) echo "Unsupported arch: $arch"; exit 1 ;;
    esac
    tmp=$(mktemp -d)
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd-${TTYD_ARCH}" \
        -o "${tmp}/ttyd"
    install -m 755 "${tmp}/ttyd" /usr/local/bin/ttyd
    rm -rf "${tmp}"
fi

# --- play user (no login shell — ttyd invokes cage directly) ---
if ! id "${PLAY_USER}" &>/dev/null; then
    useradd --system --home "${SESSION_ROOT}" --shell /usr/sbin/nologin "${PLAY_USER}"
fi
mkdir -p "${SESSION_ROOT}"
chown "${PLAY_USER}:${PLAY_USER}" "${SESSION_ROOT}"
chmod 750 "${SESSION_ROOT}"

# --- application tree ---
if [[ ! -d "${INSTALL_ROOT}/.git" ]]; then
    log "Cloning ${REPO_URL} → ${INSTALL_ROOT}"
    git clone --branch "${GIT_REF}" --depth 1 "${REPO_URL}" "${INSTALL_ROOT}"
else
    log "Updating ${INSTALL_ROOT} (git pull) …"
    git -C "${INSTALL_ROOT}" fetch origin "${GIT_REF}"
    git -C "${INSTALL_ROOT}" checkout "${GIT_REF}"
    git -C "${INSTALL_ROOT}" pull --ff-only origin "${GIT_REF}" || true
fi

# --- env file ---
if [[ ! -f "${INSTALL_ROOT}/nerdverse.env" ]]; then
    cp "${INSTALL_ROOT}/deploy/nerdverse.env.public.example" "${INSTALL_ROOT}/nerdverse.env"
    # Generate DB password if placeholder
    if grep -q 'CHANGE_ME' "${INSTALL_ROOT}/nerdverse.env"; then
        pass=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
        sed -i "s/CHANGE_ME_STRONG_PASSWORD/${pass}/" "${INSTALL_ROOT}/nerdverse.env"
        log "Generated DB_PASS in nerdverse.env (save it securely)."
    fi
fi
chown root:"${PLAY_USER}" "${INSTALL_ROOT}/nerdverse.env"
chmod 640 "${INSTALL_ROOT}/nerdverse.env"

# --- executable bits ---
chmod +x "${INSTALL_ROOT}/play.sh" "${INSTALL_ROOT}/bootstrap.sh"
chmod +x "${INSTALL_ROOT}/deploy/sandbox/nerdverse-cage.sh"
chmod +x "${INSTALL_ROOT}/deploy/bin-cage/play"
chmod +x "${INSTALL_ROOT}/scripts/"*.sh 2>/dev/null || true
find "${INSTALL_ROOT}/scripts" -name '*.sh' -exec chmod +x {} \;

chown -R root:root "${INSTALL_ROOT}"
chmod -R a+rX "${INSTALL_ROOT}"
chmod 750 "${INSTALL_ROOT}/deploy/sandbox"

# --- MariaDB bootstrap (template DB only — web lives use nerdverse_web_*) ---
log "Bootstrapping MariaDB (template ${INSTALL_ROOT}) …"
cd "${INSTALL_ROOT}"
./bootstrap.sh

# --- nginx ---
log "Configuring nginx …"
cp "${INSTALL_ROOT}/deploy/nginx/nerdverse.conf" /etc/nginx/sites-available/nerdverse
ln -sf /etc/nginx/sites-available/nerdverse /etc/nginx/sites-enabled/nerdverse
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# --- systemd ttyd ---
log "Installing nerdverse-ttyd service …"
cp "${INSTALL_ROOT}/deploy/systemd/nerdverse-ttyd.service" /etc/systemd/system/nerdverse-ttyd.service
systemctl daemon-reload
systemctl enable nerdverse-ttyd
systemctl restart nerdverse-ttyd

log "Done."
log "  Landing:  http://$(hostname -I | awk '{print $1}')/"
log "  Terminal: http://$(hostname -I | awk '{print $1}')/play/"
log "  Health:   http://$(hostname -I | awk '{print $1}')/health"
log ""
log "Local developer saves are NOT on this host. Public lane only."
log "Re-run this script to idempotently update code + migrations."