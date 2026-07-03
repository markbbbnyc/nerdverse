#!/usr/bin/env bash
# bootstrap-remote.sh — Push Nerdverse public terminal to a remote Ubuntu server via SSH.
#
# Usage (from your Mac/dev machine):
#   ./deploy/bootstrap-remote.sh
#   ./deploy/bootstrap-remote.sh root@24.144.103.2
#   NERDVERSE_REPO_URL=https://github.com/you/nerdverse.git ./deploy/bootstrap-remote.sh root@host
#
# Does NOT touch your local nerdverse2 save — installs to /opt/nerdverse-public on the server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${1:-root@24.144.103.2}"
REPO_URL="${NERDVERSE_REPO_URL:-}"

cd "${PROJECT_ROOT}"

echo "=============================================="
echo "  NERDVERSE PUBLIC TERMINAL — REMOTE BOOTSTRAP"
echo "  Target: ${TARGET}"
echo "  Server install root: /opt/nerdverse-public"
echo "  Your local save: UNTOUCHED"
echo "=============================================="
echo

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "${TARGET}" "echo ok" 2>/dev/null; then
    echo "SSH to ${TARGET} failed."
    echo "Ensure: ssh root@24.144.103.2 works (key or agent), then re-run."
    exit 1
fi

# Upload install script + deploy bundle (for offline/airgap fallback)
TMP_REMOTE="/tmp/nerdverse-install-$$"
ssh "${TARGET}" "mkdir -p ${TMP_REMOTE}"

scp -q "${SCRIPT_DIR}/install-server.sh" "${TARGET}:${TMP_REMOTE}/"
tar -C "${SCRIPT_DIR}" -czf - . | ssh "${TARGET}" "tar -xzf - -C ${TMP_REMOTE}/deploy-bundle"

# Prefer git clone on server; pass repo URL if set, else default in install-server.sh
ssh "${TARGET}" bash -s -- "${TMP_REMOTE}" "${REPO_URL}" <<'REMOTE'
set -euo pipefail
TMP_REMOTE="$1"
REPO_URL="${2:-}"
[[ -n "${REPO_URL}" ]] && export NERDVERSE_REPO_URL="${REPO_URL}"
bash "${TMP_REMOTE}/install-server.sh"
rm -rf "${TMP_REMOTE}"
REMOTE

echo
echo "Remote bootstrap finished."
echo "  http://24.144.103.2/       — nerdverse.html"
echo "  http://24.144.103.2/play/  — sandboxed game terminal"
echo
echo "Update later (idempotent): re-run this script or ssh and run:"
echo "  bash /opt/nerdverse-public/deploy/install-server.sh"