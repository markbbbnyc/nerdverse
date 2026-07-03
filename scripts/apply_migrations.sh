#!/usr/bin/env bash
# scripts/apply_migrations.sh
# Idempotent migration runner for Nerdverse.
# Run this as many times as you like.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/db.sh"

MIGRATIONS_DIR="${PROJECT_ROOT}/sql/migrations"
SEEDS_DIR="${PROJECT_ROOT}/sql/seeds"

echo "=== Nerdverse Migration Runner ==="
echo "Database: ${DB_NAME}  User: ${DB_USER}"

db_check || exit 1

# The database + dedicated user are ensured by bootstrap.sh.
# We just make sure the schema_migrations table exists.

# Ensure migrations table exists (it is created by 001)
$MARIADB -e "CREATE TABLE IF NOT EXISTS schema_migrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;"

echo
echo "Applying migrations from ${MIGRATIONS_DIR}..."

# Process migrations in lexical order (001_..., 002_...)
for mig in $(ls -1 "${MIGRATIONS_DIR}"/*.sql 2>/dev/null | sort); do
    name=$(basename "$mig" .sql)
    
    # Check if already applied
    applied=$(echo "SELECT COUNT(*) FROM schema_migrations WHERE migration='${name}';" | $MARIADB_QUIET)
    
    if [[ "$applied" -eq "0" ]]; then
        echo "  → Applying ${name}"
        if $MARIADB < "$mig"; then
            echo "INSERT INTO schema_migrations (migration) VALUES ('${name}');" | $MARIADB >/dev/null
            echo "    ✓ ${name} applied"
        else
            echo "    ✗ FAILED: ${name}" >&2
            exit 1
        fi
    else
        echo "  ✓ ${name} already applied (skipped)"
    fi
done

echo
echo "Applying seeds from ${SEEDS_DIR} (idempotent inserts)..."

for seed in $(ls -1 "${SEEDS_DIR}"/*.sql 2>/dev/null | sort); do
    name=$(basename "$seed")
    echo "  → Running seed: ${name}"
    if $MARIADB < "$seed"; then
        echo "    ✓ seed complete"
    else
        echo "    ! seed had errors (may be harmless if using ON DUPLICATE)" >&2
    fi
done

echo
echo "=== Migration run complete ==="

# Show current migration state
echo
echo "Applied migrations:"
echo "SELECT migration, applied_at FROM schema_migrations ORDER BY id;" | $MARIADB
