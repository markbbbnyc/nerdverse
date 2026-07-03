#!/usr/bin/env bash
# bootstrap.sh
# Idempotent full bootstrap for a new (or existing) Nerdverse installation.
# Safe to run multiple times on the same or new machine.
#
# Usage:
#   ./bootstrap.sh
#
# After first run you can usually just do:
#   ./scripts/apply_migrations.sh
#   ./play.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

# 4. Run all migrations + seeds (the real work)
echo
./scripts/apply_migrations.sh

echo
echo "=========================================="
echo "  Bootstrap complete."
echo
echo "  Next steps:"
echo "    ./play.sh          # start the game (once implemented)"
echo "    ./scripts/apply_migrations.sh   # re-apply safely later"
echo
echo "  On a brand new Linux box:"
echo "    git clone <your-repo>"
echo "    cd nerdverse"
echo "    ./bootstrap.sh"
echo "=========================================="
