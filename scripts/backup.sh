#!/usr/bin/env bash
# scripts/backup.sh — MariaDB backup & restore for nerdverse2
#
# Daily backup runs automatically from play.sh (at most once per calendar day).
# Manual restore: ./scripts/restore_db.sh [--latest | path/to/backup.sql]

# Expects scripts/db.sh to be sourced first (DB_USER, DB_NAME, DB_HOST, DB_PASS).

_BACKUP_DIR="${NERDVERSE_BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/saves/db}"
_LAST_BACKUP_MARKER="${_BACKUP_DIR}/.last_backup_date"
_BACKUP_RETENTION_DAYS="${NERDVERSE_BACKUP_RETENTION_DAYS:-30}"

_build_mariadb_dump_cmd() {
    local user="$1"
    if [[ -n "${DB_PASS:-}" ]]; then
        echo "mariadb-dump -u ${user} -p${DB_PASS} -h ${DB_HOST} --single-transaction --routines --triggers ${DB_NAME}"
    else
        echo "mariadb-dump --no-defaults -u ${user} -h ${DB_HOST} --single-transaction --routines --triggers ${DB_NAME}"
    fi
}

# Prefer mariadb-dump; fall back to mysqldump on older installs.
_dump_client() {
    if command -v mariadb-dump >/dev/null 2>&1; then
        echo "mariadb-dump"
    elif command -v mysqldump >/dev/null 2>&1; then
        echo "mysqldump"
    else
        echo ""
    fi
}

db_backup_ensure_dir() {
    mkdir -p "${_BACKUP_DIR}"
    touch "${_BACKUP_DIR}/.gitkeep" 2>/dev/null || true
}

# Create a timestamped SQL dump. Optional tag argument (default: YYYY-MM-DD_HHMMSS).
db_backup_create() {
    local tag="${1:-$(date +%Y-%m-%d_%H%M%S)}"
    local dump_client
    dump_client=$(_dump_client)

    if [[ -z "$dump_client" ]]; then
        echo "ERROR: mariadb-dump / mysqldump not found in PATH." >&2
        return 1
    fi

    db_backup_ensure_dir
    local safe_db="${DB_NAME:-nerdverse2}"
    local outfile="${_BACKUP_DIR}/${safe_db}_${tag}.sql"

    echo "[backup] Writing ${outfile} ..."
    if eval "$(_build_mariadb_dump_cmd "${DB_USER}")" > "${outfile}"; then
        echo "[backup] OK ($(wc -c < "${outfile}" | tr -d ' ') bytes)"
        echo "${outfile}"
        return 0
    fi

    echo "ERROR: backup failed." >&2
    rm -f "${outfile}"
    return 1
}

# Run at most one backup per calendar day (called from play.sh).
db_backup_daily() {
    db_backup_ensure_dir
    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "${_LAST_BACKUP_MARKER}" ]] && [[ "$(cat "${_LAST_BACKUP_MARKER}")" == "${today}" ]]; then
        return 0
    fi

    local outfile
    if outfile=$(db_backup_create "${today}"); then
        echo "${today}" > "${_LAST_BACKUP_MARKER}"
        db_backup_prune_old
        return 0
    fi
    return 1
}

# Drop backups older than retention window (by filename date prefix).
db_backup_prune_old() {
    local cutoff_epoch
    cutoff_epoch=$(date -v-"${_BACKUP_RETENTION_DAYS}"d +%s 2>/dev/null || date -d "${_BACKUP_RETENTION_DAYS} days ago" +%s 2>/dev/null || echo 0)

    local f base y m d file_epoch
    for f in "${_BACKUP_DIR}"/*.sql; do
        [[ -f "$f" ]] || continue
        base=$(basename "$f")
        # {dbname}_YYYY-MM-DD.sql or {dbname}_YYYY-MM-DD_HHMMSS.sql
        if [[ "$base" =~ _([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
            y="${BASH_REMATCH[1]}"
            m="${BASH_REMATCH[2]}"
            d="${BASH_REMATCH[3]}"
            file_epoch=$(date -j -f "%Y-%m-%d" "${y}-${m}-${d}" +%s 2>/dev/null || date -d "${y}-${m}-${d}" +%s 2>/dev/null || echo 0)
            if [[ "$file_epoch" -gt 0 && "$file_epoch" -lt "$cutoff_epoch" ]]; then
                rm -f "$f"
                echo "[backup] pruned old backup: ${base}"
            fi
        fi
    done
}

db_backup_list() {
    db_backup_ensure_dir
    ls -1t "${_BACKUP_DIR}"/nerdverse2_*.sql 2>/dev/null || true
}

db_backup_latest() {
    db_backup_list | head -n 1
}

# Restore nerdverse2 from a .sql dump file.
db_restore_from() {
    local infile="$1"
    if [[ ! -f "$infile" ]]; then
        echo "ERROR: backup file not found: ${infile}" >&2
        return 1
    fi

    echo "[restore] Restoring ${DB_NAME} from ${infile} ..."
    if $MARIADB < "$infile"; then
        echo "[restore] OK"
        return 0
    fi
    echo "ERROR: restore failed." >&2
    return 1
}