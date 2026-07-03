#!/usr/bin/env bash
# scripts/restore_db.sh — Restore nerdverse2 from a local SQL backup
#
# Usage:
#   ./scripts/restore_db.sh --latest
#   ./scripts/restore_db.sh --list
#   ./scripts/restore_db.sh saves/db/nerdverse2_2026-07-03.sql

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

source "${SCRIPT_DIR}/db.sh"
source "${SCRIPT_DIR}/backup.sh"

usage() {
    cat <<EOF
Restore nerdverse2 from a local MariaDB dump.

  ./scripts/restore_db.sh --list              List available backups (newest first)
  ./scripts/restore_db.sh --latest            Restore the most recent backup
  ./scripts/restore_db.sh <path-to.sql>     Restore a specific dump file

Backups live in: saves/db/
EOF
}

if ! db_check; then
    exit 1
fi

case "${1:-}" in
    --list|-l)
        echo "Available backups (newest first):"
        db_backup_list | sed 's/^/  /'
        exit 0
        ;;
    --latest)
        latest=$(db_backup_latest)
        if [[ -z "$latest" ]]; then
            echo "No backups found in saves/db/" >&2
            exit 1
        fi
        echo "Latest backup: ${latest}"
        read -r -p "Restore this backup? This overwrites current game state. [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
        # Safety snapshot before destructive restore
        db_backup_create "pre-restore_$(date +%Y-%m-%d_%H%M%S)" >/dev/null
        db_restore_from "$latest"
        ;;
    --help|-h|"")
        usage
        exit 0
        ;;
    *)
        if [[ ! -f "$1" ]]; then
            echo "ERROR: file not found: $1" >&2
            exit 1
        fi
        read -r -p "Restore from '$1'? This overwrites current game state. [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
        db_backup_create "pre-restore_$(date +%Y-%m-%d_%H%M%S)" >/dev/null
        db_restore_from "$1"
        ;;
esac