#!/usr/bin/env bash
# update-public.sh — Idempotent code + schema update on public server (no save wipe).
# Run on server: bash /opt/nerdverse-public/deploy/update-public.sh

set -euo pipefail
INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
cd "${INSTALL_ROOT}"
git pull --ff-only origin "${NERDVERSE_GIT_REF:-main}" || true
./scripts/apply_migrations.sh --quiet
systemctl restart nerdverse-ttyd
echo "[update-public] Engine updated. Session DBs (nerdverse_web_*) preserved."