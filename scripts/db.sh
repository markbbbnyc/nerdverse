#!/usr/bin/env bash
# scripts/db.sh - Database helper functions for Nerdverse (pure bash + mariadb)

# Load config if present
if [[ -f "$(dirname "$0")/../nerdverse.env" ]]; then
    source "$(dirname "$0")/../nerdverse.env"
fi

DB_USER="${DB_USER:-mark}"
DB_NAME="${DB_NAME:-nerdverse2}"
DB_HOST="${DB_HOST:-localhost}"

# Common mariadb flags (use -N -B for machine readable when needed)
MARIADB="mariadb -u ${DB_USER} -h ${DB_HOST} -D ${DB_NAME}"

# For queries that should not echo "OK" etc.
MARIADB_QUIET="mariadb -u ${DB_USER} -h ${DB_HOST} -D ${DB_NAME} --silent --skip-column-names"

log_db() {
    echo "[DB] $*" >&2
}

db_exec() {
    # Execute SQL from stdin or arg
    if [[ -n "$1" ]]; then
        echo "$1" | $MARIADB
    else
        $MARIADB
    fi
}

db_query() {
    # Return query result (first column by default)
    echo "$1" | $MARIADB_QUIET
}

db_query_row() {
    # Return full row tab separated
    echo "$1" | mariadb -u "${DB_USER}" -h "${DB_HOST}" -D "${DB_NAME}" --silent --batch
}

# Check that we can connect
db_check() {
    if ! $MARIADB -e "SELECT 1;" >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to MariaDB as user '${DB_USER}' on database '${DB_NAME}'." >&2
        echo "Make sure the server is running and the user has access." >&2
        echo "On new systems run something like:" >&2
        echo "  mariadb -u root -e \"CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY 'password'; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';\"" >&2
        return 1
    fi
    return 0
}

# Ensure the database exists (may need higher privileges on first run)
db_ensure_database() {
    local root_cmd="mariadb -u root -h ${DB_HOST}"
    if ! mariadb -u "${DB_USER}" -h "${DB_HOST}" -e "USE ${DB_NAME};" >/dev/null 2>&1; then
        echo "Database ${DB_NAME} does not exist or is not accessible by ${DB_USER}."
        echo "Attempting to create it (you may be prompted for root password)..."
        if mariadb -u root -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null; then
            echo "Database created."
            # Try to grant
            mariadb -u root -h "${DB_HOST}" -e "GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null || true
        else
            echo "Could not auto-create. Please create manually:"
            echo "  mariadb -u root -e \"CREATE DATABASE ${DB_NAME}; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';\""
            return 1
        fi
    fi
}
