#!/usr/bin/env bash
# update-public.sh — Fast idempotent update on an existing public server.
# Run on server as root: bash /opt/nerdverse-public/deploy/update-public.sh
#
# Preserves nerdverse_web_* session databases and /var/lib/nerdverse/sessions/.

set -euo pipefail
INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
PLAY_USER="${NERDVERSE_PLAY_USER:-nerdverse-play}"
TELEMETRY_ROOT="/var/lib/nerdverse/telemetry"

cd "${INSTALL_ROOT}"
git fetch origin "${NERDVERSE_GIT_REF:-main}"
git checkout "${NERDVERSE_GIT_REF:-main}"
git pull --ff-only origin "${NERDVERSE_GIT_REF:-main}" || true

find "${INSTALL_ROOT}/scripts" -name '*.sh' -exec chmod +x {} \;
find "${INSTALL_ROOT}/deploy" -name '*.sh' -exec chmod +x {} \;

./scripts/apply_migrations.sh --quiet

chown "${PLAY_USER}:${PLAY_USER}" "${TELEMETRY_ROOT}/stats.json" 2>/dev/null || true
sudo -u "${PLAY_USER}" bash "${INSTALL_ROOT}/scripts/telemetry_aggregate.sh" 2>/dev/null || true

cp "${INSTALL_ROOT}/deploy/nginx/nerdverse.conf" /etc/nginx/sites-available/nerdverse
nginx -t && systemctl reload nginx

cp "${INSTALL_ROOT}/deploy/systemd/nerdverse-ttyd.service" /etc/systemd/system/nerdverse-ttyd.service
systemctl daemon-reload
systemctl restart nerdverse-ttyd

echo "[update-public] Engine updated. Session DBs (nerdverse_web_*) preserved."