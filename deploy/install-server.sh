#!/usr/bin/env bash
# install-server.sh — Idempotent Ubuntu install for Nerdverse public terminal.
#
# Run as root on the server (invoked by deploy/bootstrap-remote.sh or deploy/spin-up.sh).
#
# Installs to /opt/nerdverse-public — never touches the author's local Life-2 save.
# Public browser tabs each get nerdverse_web_{hex} (see sql/seeds/003_public_terminal_fresh.sql).
# Shared DB nerdverse_public is schema-only (NERDVERSE_PUBLIC_SERVER=1 bootstrap).
#
# Re-run safely for updates: git pull, migrations, nginx reload, ttyd restart.

set -euo pipefail

INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
REPO_URL="${NERDVERSE_REPO_URL:-https://github.com/markbbbnyc/nerdverse.git}"
GIT_REF="${NERDVERSE_GIT_REF:-main}"
PLAY_USER="${NERDVERSE_PLAY_USER:-nerdverse-play}"
SESSION_ROOT="/var/lib/nerdverse/sessions"
TELEMETRY_ROOT="/var/lib/nerdverse/telemetry"
TTYD_VERSION="${TTYD_VERSION:-1.7.7}"
SOURCE_ARCHIVE="${NERDVERSE_SOURCE_ARCHIVE:-}"
INSTALL_FROM_SOURCE="${NERDVERSE_INSTALL_FROM_SOURCE:-0}"

log() { echo "[install] $*"; }
die() { echo "[install] ERROR: $*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
    die "Run as root on the Ubuntu server."
fi

export DEBIAN_FRONTEND=noninteractive
log "Installing packages …"
apt-get update -qq
apt-get install -y -qq git mariadb-server nginx openssl curl ca-certificates \
    apache2-utils build-essential cmake libjson-c-dev libwebsockets-dev

systemctl enable mariadb nginx
systemctl start mariadb || true

# --- ttyd (prebuilt binary) ---
if [[ ! -x /usr/local/bin/ttyd ]]; then
    log "Installing ttyd ${TTYD_VERSION} …"
    arch=$(uname -m)
    case "$arch" in
        x86_64)  TTYD_ARCH="x86_64" ;;
        aarch64) TTYD_ARCH="aarch64" ;;
        *) die "Unsupported arch: $arch" ;;
    esac
    tmp=$(mktemp -d)
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
        -o "${tmp}/ttyd"
    install -m 755 "${tmp}/ttyd" /usr/local/bin/ttyd
    rm -rf "${tmp}"
fi

# --- play user (no login shell — ttyd invokes cage directly) ---
if ! id "${PLAY_USER}" &>/dev/null; then
    useradd --system --home "${SESSION_ROOT}" --shell /usr/sbin/nologin "${PLAY_USER}"
fi
mkdir -p "${SESSION_ROOT}" "${TELEMETRY_ROOT}"
chown "${PLAY_USER}:${PLAY_USER}" "${SESSION_ROOT}" "${TELEMETRY_ROOT}"
chmod 750 "${SESSION_ROOT}"
chmod 755 "${TELEMETRY_ROOT}"

# --- application tree ---
_install_from_archive() {
    [[ -f "${SOURCE_ARCHIVE}" ]] || die "Source archive missing: ${SOURCE_ARCHIVE}"
    log "Unpacking source archive → ${INSTALL_ROOT}"
    mkdir -p "${INSTALL_ROOT}"
    tar -xzf "${SOURCE_ARCHIVE}" -C "${INSTALL_ROOT}"
}

if [[ "${INSTALL_FROM_SOURCE}" == "1" ]]; then
    _install_from_archive
elif [[ ! -d "${INSTALL_ROOT}/.git" ]]; then
    if [[ -f "${SOURCE_ARCHIVE}" ]]; then
        _install_from_archive
    else
        log "Cloning ${REPO_URL} (${GIT_REF}) → ${INSTALL_ROOT}"
        git clone --branch "${GIT_REF}" --depth 1 "${REPO_URL}" "${INSTALL_ROOT}"
    fi
else
    log "Updating ${INSTALL_ROOT} (git pull) …"
    git -C "${INSTALL_ROOT}" fetch origin "${GIT_REF}"
    git -C "${INSTALL_ROOT}" checkout "${GIT_REF}"
    git -C "${INSTALL_ROOT}" pull --ff-only origin "${GIT_REF}" || true
fi

# --- env file (first install only — preserves existing secrets on re-run) ---
if [[ ! -f "${INSTALL_ROOT}/nerdverse.env" ]]; then
    cp "${INSTALL_ROOT}/deploy/nerdverse.env.public.example" "${INSTALL_ROOT}/nerdverse.env"
    if grep -q 'CHANGE_ME' "${INSTALL_ROOT}/nerdverse.env"; then
        pass=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
        setup_pass=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
        sed -i "s/CHANGE_ME_STRONG_PASSWORD/${pass}/" "${INSTALL_ROOT}/nerdverse.env"
        sed -i "s/CHANGE_ME_SETUP_PASSWORD/${setup_pass}/" "${INSTALL_ROOT}/nerdverse.env"
        sed -i 's/^DB_SETUP_USER=root$/DB_SETUP_USER=nerdverse_setup/' "${INSTALL_ROOT}/nerdverse.env"
        log "Generated DB_PASS + DB_SETUP_PASS in nerdverse.env (save securely)."
    fi
fi

# --- MariaDB setup user (provisions per-session nerdverse_web_* from cage) ---
_ensure_setup_user() {
    # shellcheck source=/dev/null
    source "${INSTALL_ROOT}/nerdverse.env"
    local setup_user="${DB_SETUP_USER:-nerdverse_setup}"
    local setup_pass="${DB_SETUP_PASS:-}"
    if [[ "${setup_user}" == "root" || -z "${setup_pass}" ]]; then
        log "WARN: DB_SETUP_USER/DB_SETUP_PASS not configured — public sessions may fail."
        return 0
    fi
    mariadb -u root <<SQL
CREATE USER IF NOT EXISTS '${setup_user}'@'localhost' IDENTIFIED BY '${setup_pass}';
CREATE USER IF NOT EXISTS '${setup_user}'@'127.0.0.1' IDENTIFIED BY '${setup_pass}';
GRANT CREATE, DROP, CREATE USER, RELOAD ON *.* TO '${setup_user}'@'localhost';
GRANT CREATE, DROP, CREATE USER, RELOAD ON *.* TO '${setup_user}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`nerdverse%\`.* TO '${setup_user}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON \`nerdverse%\`.* TO '${setup_user}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
    log "MariaDB setup user '${setup_user}' ready for web sessions."
}
_ensure_setup_user
chown root:"${PLAY_USER}" "${INSTALL_ROOT}/nerdverse.env"
chmod 640 "${INSTALL_ROOT}/nerdverse.env"

# --- executable bits ---
chmod +x "${INSTALL_ROOT}/play.sh" "${INSTALL_ROOT}/bootstrap.sh"
chmod +x "${INSTALL_ROOT}/deploy/sandbox/nerdverse-cage.sh"
chmod +x "${INSTALL_ROOT}/deploy/spin-up.sh" "${INSTALL_ROOT}/deploy/bootstrap-remote.sh" 2>/dev/null || true
chmod +x "${INSTALL_ROOT}/deploy/bin-cage/play"
chmod +x "${INSTALL_ROOT}/scripts/"*.sh 2>/dev/null || true
find "${INSTALL_ROOT}/scripts" -name '*.sh' -exec chmod +x {} \;
find "${INSTALL_ROOT}/deploy" -name '*.sh' -exec chmod +x {} \;

chown -R root:root "${INSTALL_ROOT}"
chmod -R a+rX "${INSTALL_ROOT}"
chown root:"${PLAY_USER}" "${INSTALL_ROOT}/deploy/sandbox"
chmod 750 "${INSTALL_ROOT}/deploy/sandbox"

# --- MariaDB bootstrap: schema template only (no author Life-2 seed) ---
log "Bootstrapping MariaDB schema (no shared playable save) …"
cd "${INSTALL_ROOT}"
NERDVERSE_PUBLIC_SERVER=1 NERDVERSE_SKIP_GAME_SEED=1 ./bootstrap.sh

# --- telemetry + admin dashboard ---
touch "${TELEMETRY_ROOT}/events.jsonl"
chown "${PLAY_USER}:${PLAY_USER}" "${TELEMETRY_ROOT}/events.jsonl"
chmod 664 "${TELEMETRY_ROOT}/events.jsonl"
sudo -u "${PLAY_USER}" bash "${INSTALL_ROOT}/scripts/telemetry_aggregate.sh" 2>/dev/null || true
chown "${PLAY_USER}:${PLAY_USER}" "${TELEMETRY_ROOT}/stats.json" 2>/dev/null || true
chmod 644 "${TELEMETRY_ROOT}/stats.json" 2>/dev/null || true
# Safety net: refresh dashboard stats even if an async aggregate was missed
CRON_FILE="/etc/cron.d/nerdverse-telemetry"
cat > "${CRON_FILE}" <<CRON
*/2 * * * * ${PLAY_USER} ${INSTALL_ROOT}/scripts/telemetry_aggregate.sh >/dev/null 2>&1
CRON
chmod 644 "${CRON_FILE}"

ADMIN_HTPASSWD="/etc/nginx/.htpasswd-nerdverse-admin"
ADMIN_USER="${NERDVERSE_ADMIN_USER:-dashboard}"
if [[ ! -f "${ADMIN_HTPASSWD}" ]]; then
    ADMIN_PASS="${NERDVERSE_ADMIN_PASS:-}"
    if [[ -z "$ADMIN_PASS" ]]; then
        ADMIN_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)
    fi
    htpasswd -bc "${ADMIN_HTPASSWD}" "${ADMIN_USER}" "${ADMIN_PASS}" >/dev/null
    log "Admin dashboard: http://$(hostname -I | awk '{print $1}')/admin/"
    log "  user=${ADMIN_USER}  pass=${ADMIN_PASS}"
else
    log "Admin htpasswd exists — not overwriting (${ADMIN_HTPASSWD})"
fi
chown root:www-data "${ADMIN_HTPASSWD}"
chmod 640 "${ADMIN_HTPASSWD}"

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

# --- post-install checks ---
SERVER_IP=$(hostname -I | awk '{print $1}')
_fail=0
systemctl is-active --quiet nerdverse-ttyd || { log "WARN: nerdverse-ttyd not active"; _fail=1; }
systemctl is-active --quiet nginx || { log "WARN: nginx not active"; _fail=1; }
curl -fsS "http://127.0.0.1/health" >/dev/null 2>&1 || { log "WARN: /health check failed"; _fail=1; }
curl -fsS -o /dev/null "http://127.0.0.1/play/" 2>&1 || log "NOTE: /play/ may return non-200 until first websocket (ttyd OK if service active)"

log "Done."
log "  Landing:  http://${SERVER_IP}/"
log "  Terminal: http://${SERVER_IP}/play/"
log "  Health:   http://${SERVER_IP}/health"
log "  Admin:    http://${SERVER_IP}/admin/"
log ""
log "Local developer saves are NOT on this host. Public lane only."
log "Spin up another shard: ./deploy/spin-up.sh root@OTHER_SERVER"
log "Update this host:      re-run install-server.sh or spin-up.sh"

[[ $_fail -eq 1 ]] && die "One or more services failed post-install checks."