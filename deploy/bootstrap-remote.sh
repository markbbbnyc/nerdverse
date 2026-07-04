#!/usr/bin/env bash
# bootstrap-remote.sh — Push Nerdverse public terminal to a remote Ubuntu server via SSH.
#
# Usage (from your Mac/dev machine):
#   ./deploy/spin-up.sh root@SERVER          # preferred wrapper
#   ./deploy/bootstrap-remote.sh root@SERVER
#
# Environment (optional):
#   NERDVERSE_REPO_URL          Git remote (default in install-server.sh)
#   NERDVERSE_GIT_REF=main      Branch or tag
#   NERDVERSE_ADMIN_USER        Admin dashboard user (default: dashboard)
#   NERDVERSE_ADMIN_PASS        Admin password (random on first install if unset)
#   NERDVERSE_INSTALL_FROM_SOURCE=1  Install from uploaded checkout tarball
#
# Does NOT touch your local nerdverse2 save — installs to /opt/nerdverse-public.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${1:-}"
REPO_URL="${NERDVERSE_REPO_URL:-}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 root@SERVER_IP" >&2
    echo "  or:  ./deploy/spin-up.sh root@SERVER_IP" >&2
    exit 1
fi

# Extract host for post-install URLs (strip user@)
TARGET_HOST="${TARGET#*@}"
[[ "$TARGET_HOST" == "$TARGET" ]] && TARGET_HOST="$TARGET"

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
    echo "Ensure your SSH key is loaded, then re-run."
    exit 1
fi

TMP_REMOTE="/tmp/nerdverse-install-$$"
ssh "${TARGET}" "mkdir -p ${TMP_REMOTE}"

scp -q "${SCRIPT_DIR}/install-server.sh" "${TARGET}:${TMP_REMOTE}/"

# Full source tarball (fallback when git clone unavailable or INSTALL_FROM_SOURCE=1)
# Excludes git metadata, local saves, and machine-specific env.
tar -C "${PROJECT_ROOT}" -czf - \
    --exclude='.git' \
    --exclude='saves/db/*.sql' \
    --exclude='saves/active_db' \
    --exclude='saves/session_handoff.md' \
    --exclude='nerdverse.env' \
    --exclude='logs' \
    . | ssh "${TARGET}" "cat > ${TMP_REMOTE}/nerdverse-src.tar.gz"

ssh "${TARGET}" bash -s -- "${TMP_REMOTE}" "${REPO_URL}" "${NERDVERSE_GIT_REF:-main}" \
    "${NERDVERSE_INSTALL_FROM_SOURCE:-0}" <<'REMOTE'
set -euo pipefail
TMP_REMOTE="$1"
REPO_URL="${2:-}"
GIT_REF="${3:-main}"
INSTALL_FROM_SOURCE="${4:-0}"

export NERDVERSE_SOURCE_ARCHIVE="${TMP_REMOTE}/nerdverse-src.tar.gz"
export NERDVERSE_INSTALL_FROM_SOURCE="${INSTALL_FROM_SOURCE}"
export NERDVERSE_GIT_REF="${GIT_REF}"
[[ -n "${REPO_URL}" ]] && export NERDVERSE_REPO_URL="${REPO_URL}"
[[ -n "${NERDVERSE_ADMIN_USER:-}" ]] && export NERDVERSE_ADMIN_USER
[[ -n "${NERDVERSE_ADMIN_PASS:-}" ]] && export NERDVERSE_ADMIN_PASS

bash "${TMP_REMOTE}/install-server.sh"
rm -rf "${TMP_REMOTE}"
REMOTE

echo
echo "Remote bootstrap finished."
echo "  http://${TARGET_HOST}/       — landing"
echo "  http://${TARGET_HOST}/play/  — game terminal"
echo "  http://${TARGET_HOST}/admin/ — telemetry (htpasswd)"
echo
echo "Re-run to update (idempotent):"
echo "  ./deploy/spin-up.sh ${TARGET}"