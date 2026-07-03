#!/usr/bin/env bash
# bootstrap.sh
# Idempotent full bootstrap for a new (or existing) Nerdverse installation.
# Safe to run multiple times on the same or new machine.
#
# Usage:
#   ./bootstrap.sh              # setup DB + migrations (preserves existing save)
#   ./bootstrap.sh --fresh      # wipe game state and start a new life
#
# After first run you can usually just do:
#   ./play.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FRESH_FLAG=()
for arg in "$@"; do
    case "$arg" in
        --fresh) FRESH_FLAG+=(--fresh) ;;
        --help|-h)
            echo "Usage: ./bootstrap.sh [--fresh]"
            echo "  --fresh   Reset game state and load the Brindleford Forge starting save"
            exit 0
            ;;
    esac
done

echo "=========================================="
echo "  NERDVERSE BOOTSTRAP"
echo "  Pure bash + MariaDB"
echo "=========================================="
echo

# 1. Basic sanity
if ! command -v mariadb >/dev/null 2>&1 && ! command -v mysql >/dev/null 2>&1; then
    echo "ERROR: 'mariadb' or 'mysql' client not found in PATH."
    echo "Please install MariaDB client first."
    echo "  macOS:  brew install mariadb"
    echo "  Debian/Ubuntu: sudo apt install mariadb-client"
    echo "  Fedora: sudo dnf install mariadb"
    exit 1
fi

echo "MariaDB client found: $(mariadb --version 2>/dev/null || mysql --version)"

echo
echo "If you are on a fresh Linux system, see docs/linux-packages.md"
echo "for the recommended package list (mariadb-client, git, LaTeX, etc.)."

# 2. Create nerdverse.env if it doesn't exist
if [[ ! -f nerdverse.env ]]; then
    echo
    echo "Creating nerdverse.env with dedicated game app user..."
    cat > nerdverse.env << 'EOC'
# nerdverse.env - local configuration (git-ignored)
DB_USER=nerdverse
DB_NAME=nerdverse2
DB_HOST=localhost

# Leave empty for socket/.my.cnf auth (recommended for local dev)
# DB_PASS=

# Privileged account used only during bootstrap (your personal user or root)
# DB_SETUP_USER=root
# DB_SETUP_PASS=
EOC
    echo "  Created nerdverse.env — review and edit DB_SETUP_USER if needed."
fi

# 3. Source helpers
source scripts/db.sh
source scripts/backup.sh

echo
echo "Setting up dedicated database user and privileges (using privileged account if needed)..."
db_ensure_database_and_user

echo
echo "Checking runtime connectivity as the game app user (${DB_USER})..."
if ! db_check; then
    echo
    echo "Runtime connection as '${DB_USER}' failed."
    echo "Check your nerdverse.env and that the privileged setup succeeded."
    echo "You may need to set DB_SETUP_USER and DB_SETUP_PASS temporarily."
    exit 1
fi

# 4. Safety backup before a destructive fresh start
if [[ ${#FRESH_FLAG[@]} -gt 0 ]]; then
    echo
    echo "Taking a safety backup before fresh reset ..."
    db_backup_create "pre-fresh_$(date +%Y-%m-%d_%H%M%S)" || true
fi

# 5. Run migrations (+ fresh seed only when --fresh or first install)
echo
if [[ ${#FRESH_FLAG[@]} -gt 0 ]]; then
    ./scripts/apply_migrations.sh "${FRESH_FLAG[@]}"
else
    ./scripts/apply_migrations.sh
fi

echo
echo "=========================================="
echo "  Bootstrap complete."
echo
echo "  Next steps:"
echo "    ./play.sh                       # start / resume the game"
echo "    ./play.sh --new-game            # new life in nerdverse3, nerdverse4, ... (keeps old saves)"
echo "    ./bootstrap.sh --fresh          # reset THIS database only (destructive)"
echo "    ./scripts/restore_db.sh --list  # restore from daily backup if needed"
echo
echo "  On a brand new Linux box:"
echo "    git clone <your-repo>"
echo "    cd nerdverse"
echo "    ./bootstrap.sh"
echo "=========================================="
