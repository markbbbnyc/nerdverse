#!/usr/bin/env bash
# scripts/db.sh - Database helper functions for Nerdverse (pure bash + mariadb)
#
# Philosophy:
# - Runtime game scripts always connect as the dedicated low-privilege DB_USER (default: 'nerdverse')
# - Bootstrap/setup can use a privileged account (DB_SETUP_USER) to create the app user + grants.
# - This makes the game portable across any local user on Linux/macOS.

# Load config if present (preserve caller-exported DB_NAME for multi-save / --new-game)
_DB_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CALLER_DB_NAME="${DB_NAME:-}"
if [[ -f "${_DB_SH_DIR}/../nerdverse.env" ]]; then
    source "${_DB_SH_DIR}/../nerdverse.env"
fi
unset _DB_SH_DIR
if [[ -n "${_CALLER_DB_NAME}" ]]; then
    DB_NAME="${_CALLER_DB_NAME}"
fi
unset _CALLER_DB_NAME

# === Runtime (game) connection ===
DB_USER="${DB_USER:-nerdverse}"
DB_NAME="${DB_NAME:-nerdverse2}"
DB_HOST="${DB_HOST:-localhost}"
DB_PASS="${DB_PASS:-}"

# Build connection string (supports password or socket/.my.cnf auth)
# We use --no-defaults when no explicit password is provided in the env
# to avoid picking up passwords from ~/.my.cnf for the wrong user.
_build_mariadb_cmd() {
    local user="$1"
    local extra="$2"
    local charset="--default-character-set=utf8mb4"
    if [[ -n "$DB_PASS" ]]; then
        echo "mariadb ${charset} -u ${user} -p${DB_PASS} -h ${DB_HOST} -D ${DB_NAME} ${extra}"
    else
        # Ignore global .my.cnf defaults to prevent password leakage from other users
        echo "mariadb ${charset} --no-defaults -u ${user} -h ${DB_HOST} -D ${DB_NAME} ${extra}"
    fi
}

db_reinit() {
    MARIADB=$(_build_mariadb_cmd "${DB_USER}" "")
    MARIADB_QUIET=$(_build_mariadb_cmd "${DB_USER}" "--silent --skip-column-names")
}

db_reinit

# === Privileged / Setup connection (used only by bootstrap) ===
# Defaults to the current Unix user (often has socket privileges) or root.
# You can override in nerdverse.env with DB_SETUP_USER / DB_SETUP_PASS.
DEFAULT_SETUP_USER="${USER:-root}"
DB_SETUP_USER="${DB_SETUP_USER:-${DEFAULT_SETUP_USER}}"
DB_SETUP_PASS="${DB_SETUP_PASS:-}"

_build_setup_cmd() {
    local u="$1"
    if [[ -n "$DB_SETUP_PASS" ]]; then
        echo "mariadb -u ${u} -p${DB_SETUP_PASS} -h ${DB_HOST}"
    else
        # For privileged setup we usually want to allow .my.cnf or explicit user
        echo "mariadb -u ${u} -h ${DB_HOST}"
    fi
}

DB_SETUP_CMD=$(_build_setup_cmd "${DB_SETUP_USER}")

log_db() {
    echo "[DB] $*" >&2
}

# --- Runtime connections (used by play.sh, apply_migrations.sh etc.) ---

db_exec() {
    if [[ -n "$1" ]]; then
        echo "$1" | $MARIADB
    else
        $MARIADB
    fi
}

db_query() {
    echo "$1" | $MARIADB_QUIET
}

db_query_row() {
    if [[ -n "$DB_PASS" ]]; then
        echo "$1" | mariadb -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" -D "${DB_NAME}" --silent --batch
    else
        echo "$1" | mariadb --no-defaults -u "${DB_USER}" -h "${DB_HOST}" -D "${DB_NAME}" --silent --batch
    fi
}

db_check() {
    if ! $MARIADB -e "SELECT 1;" >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to MariaDB as app user '${DB_USER}' on database '${DB_NAME}'." >&2
        echo "The dedicated game user may not exist yet or have insufficient rights." >&2
        echo "Run ./bootstrap.sh (it will use a privileged account to create the app user)." >&2
        return 1
    fi
    return 0
}

# --- Privileged operations (only for bootstrap/setup) ---

db_setup_exec() {
    # Execute as the privileged setup user (no -D by default)
    if [[ -n "$1" ]]; then
        echo "$1" | $DB_SETUP_CMD
    else
        $DB_SETUP_CMD
    fi
}

db_ensure_database_and_user() {
    # This function is intended to be called during bootstrap with elevated rights.
    # It creates the database (if needed) and the dedicated game app user + grants.

    local app_user="${DB_USER}"
    local dbname="${DB_NAME}"

    echo "Ensuring database and dedicated game user '${app_user}' exist..."

    # Create database
    db_setup_exec "CREATE DATABASE IF NOT EXISTS \`${dbname}\`;" || true

    # Create the app user (idempotent)
    # We create without password first; if DB_PASS is set we alter it.
    db_setup_exec "
        CREATE USER IF NOT EXISTS '${app_user}'@'localhost';
        CREATE USER IF NOT EXISTS '${app_user}'@'127.0.0.1';
    " || true

    if [[ -n "$DB_PASS" ]]; then
        db_setup_exec "
            ALTER USER '${app_user}'@'localhost' IDENTIFIED BY '${DB_PASS}';
            ALTER USER '${app_user}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
        " || true
    fi

    # Grant comprehensive but dedicated rights to the app user
    # This allows full gameplay + running migrations/seeds.
    db_setup_exec "
        GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${app_user}'@'localhost';
        GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${app_user}'@'127.0.0.1';
    " || true

    echo "Database and app user privileges ensured."
}
