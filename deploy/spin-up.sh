#!/usr/bin/env bash
# spin-up.sh — One command: provision a fresh Nerdverse public game server.
#
# From your dev machine (SSH key to root@host required):
#   ./deploy/spin-up.sh root@203.0.113.10
#
# Optional environment:
#   NERDVERSE_REPO_URL=...     Git remote (default: markbbbnyc/nerdverse)
#   NERDVERSE_GIT_REF=main      Branch or tag to deploy
#   NERDVERSE_ADMIN_USER=dashboard
#   NERDVERSE_ADMIN_PASS=secret  (random if unset on first install)
#   NERDVERSE_INSTALL_FROM_SOURCE=1  Use uploaded checkout instead of git clone
#
# Your local Life-2 save (saves/, nerdverse2) is never touched.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/bootstrap-remote.sh" "${1:?Usage: $0 root@SERVER_IP}"