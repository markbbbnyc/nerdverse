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

# 2. Create nerdverse.env if it doesn't exist
if [[ ! -f nerdverse.env ]]; then
    echo
    echo "Creating nerdverse.env (edit this on new systems)..."
    cat > nerdverse.env << 'EOC'
# nerdverse.env - local configuration (git-ignored)
DB_USER=mark
DB_NAME=nerdverse2
DB_HOST=localhost

# If you use password auth instead of socket / .my.cnf, set:
# DB_PASS=yourpassword
EOC
    echo "  Created nerdverse.env — review and edit if needed."
fi

# 3. Source helpers
source scripts/db.sh

echo
echo "Checking database connectivity..."
if ! db_check; then
    echo
    echo "We will try to help create the database and user."
    db_ensure_database || {
        echo "Manual steps:"
        echo "  1. mariadb -u root"
        echo "  2. CREATE DATABASE IF NOT EXISTS nerdverse2;"
        echo "  3. CREATE USER 'mark'@'localhost' IDENTIFIED BY 'yourpass';"
        echo "  4. GRANT ALL ON nerdverse2.* TO 'mark'@'localhost';"
        echo "  5. Re-run this bootstrap."
        exit 1
    }
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
