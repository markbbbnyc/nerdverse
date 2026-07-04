#!/usr/bin/env bash
# scripts/apply_migrations.sh
# Idempotent migration + map loader for Nerdverse.
#
# Usage:
#   ./scripts/apply_migrations.sh              # migrations + catalog only (preserves save)
#   ./scripts/apply_migrations.sh --fresh    # wipe game state + load fresh starting save
#
# Fresh seed also runs automatically when no player character exists (first install).
#
# Seed lanes:
#   002_fresh_game.sql           — author Life-2 checkpoint (local dev)
#   003_public_terminal_fresh.sql — anonymous public terminal (NERDVERSE_PUBLIC_FRESH_SEED=1)
# Public servers set NERDVERSE_PUBLIC_SERVER=1 / NERDVERSE_SKIP_GAME_SEED=1 at bootstrap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/db.sh"

MIGRATIONS_DIR="${PROJECT_ROOT}/sql/migrations"
SEEDS_DIR="${PROJECT_ROOT}/sql/seeds"
CATALOG_SEED="001_catalog.sql"
FRESH_SEED="profiles/author_checkpoint.sql"
PUBLIC_FRESH_SEED="profiles/public_arc_start.sql"

FRESH_MODE=0
QUIET=0

for arg in "$@"; do
    case "$arg" in
        --fresh) FRESH_MODE=1 ;;
        --quiet|-q) QUIET=1 ;;
    esac
done

if [[ "${NERDVERSE_FRESH_SEED:-}" == "1" ]]; then
    FRESH_MODE=1
fi

if [[ "${NERDVERSE_PUBLIC_FRESH_SEED:-}" == "1" ]]; then
    FRESH_MODE=1
    FRESH_SEED="${PUBLIC_FRESH_SEED}"
fi

_log() {
    if [[ $QUIET -eq 0 ]]; then
        echo "$@"
    fi
}

db_reset_game_state() {
    _log "  → Resetting live game state (characters, inventory, world progress) ..."
    # Order matters for foreign keys; locations + maps + schema_migrations are preserved.
    $MARIADB <<'SQL'
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE session_log;
TRUNCATE TABLE inventory;
TRUNCATE TABLE character_abilities;
TRUNCATE TABLE characters;
DELETE FROM world_state;
UPDATE locations SET visited = FALSE;
SET FOREIGN_KEY_CHECKS = 1;
SQL
    _log "    ✓ game state cleared"
}

db_has_player() {
    local count
    count=$(echo "SELECT COUNT(*) FROM characters WHERE is_player = TRUE;" | $MARIADB_QUIET 2>/dev/null || echo "0")
    [[ "${count:-0}" -gt 0 ]]
}

_log "=== Nerdverse Migration Runner ==="
_log "Database: ${DB_NAME}  User: ${DB_USER}"

db_check || exit 1

$MARIADB -e "CREATE TABLE IF NOT EXISTS schema_migrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;"

_log
_log "Applying migrations from ${MIGRATIONS_DIR}..."

for mig in $(ls -1 "${MIGRATIONS_DIR}"/*.sql 2>/dev/null | sort); do
    name=$(basename "$mig" .sql)

    applied=$(echo "SELECT COUNT(*) FROM schema_migrations WHERE migration='${name}';" | $MARIADB_QUIET)

    if [[ "$applied" -eq "0" ]]; then
        _log "  → Applying ${name}"
        if $MARIADB < "$mig"; then
            echo "INSERT INTO schema_migrations (migration) VALUES ('${name}');" | $MARIADB >/dev/null
            _log "    ✓ ${name} applied"
        else
            echo "    ✗ FAILED: ${name}" >&2
            exit 1
        fi
    else
        _log "  ✓ ${name} already applied (skipped)"
    fi
done

_log
_log "Applying catalog seeds — safe, does not touch save progress ..."
for cat in "${CATALOG_SEED}" "003_progression_catalog.sql"; do
    if [[ -f "${SEEDS_DIR}/${cat}" ]]; then
        if $MARIADB < "${SEEDS_DIR}/${cat}"; then
            _log "    ✓ ${cat} complete"
        else
            echo "    ✗ ${cat} failed" >&2
            exit 1
        fi
    fi
done

# Decide whether to load the fresh starting save
RUN_FRESH=0
if [[ "${NERDVERSE_PUBLIC_SERVER:-}" == "1" || "${NERDVERSE_SKIP_GAME_SEED:-}" == "1" ]]; then
    _log
    _log "Public server / skip flag — no shared playable seed on template DB."
elif [[ $FRESH_MODE -eq 1 ]]; then
    RUN_FRESH=1
    _log
    _log "Fresh game requested (--fresh)."
elif ! db_has_player; then
    RUN_FRESH=1
    _log
    _log "No player character found — first install; loading fresh starting save."
fi

if [[ $RUN_FRESH -eq 1 ]]; then
    if [[ $FRESH_MODE -eq 1 ]]; then
        db_reset_game_state
    fi
    _log "  → Running fresh game seed: ${FRESH_SEED}"
    if [[ -f "${SEEDS_DIR}/${FRESH_SEED}" ]]; then
        if $MARIADB < "${SEEDS_DIR}/${FRESH_SEED}"; then
            _log "    ✓ fresh game seed complete"
        else
            echo "    ✗ fresh game seed failed" >&2
            exit 1
        fi
    else
        echo "    ✗ missing ${FRESH_SEED}" >&2
        exit 1
    fi
else
    _log
    _log "Existing save detected — fresh game seed skipped (use --fresh to reset)."
fi

_log
_log "Loading whimsical maps (from maps/*.txt) into database..."
MAPS_DIR="${PROJECT_ROOT}/maps"
if [[ -d "$MAPS_DIR" ]]; then
    for mfile in $(ls -1 "${MAPS_DIR}"/*.txt 2>/dev/null | sort); do
        map_key=$(basename "$mfile" .txt)
        raw_title=$(head -n 1 "$mfile")
        title_esc=$(printf '%s' "$raw_title" | sed "s/'/''/g")
        ascii=$(tail -n +2 "$mfile")

        case "$map_key" in
            world)   mtype="world"; related="" ;;
            *)       mtype="local"; related="$map_key" ;;
        esac

        if (
            printf "INSERT INTO maps (map_key, title, ascii, map_type, related_location, revealed)
VALUES ('%s', '%s', '" "$map_key" "$title_esc"
            printf '%s' "$ascii" | sed "s/'/''/g"
            printf "', '%s', '%s', TRUE)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    ascii = VALUES(ascii),
    map_type = VALUES(map_type),
    related_location = VALUES(related_location),
    revealed = TRUE;\n" "$mtype" "$related"
        ) | $MARIADB 2>/dev/null; then
            _log "  ✓ map '${map_key}' loaded/updated"
        elif [[ $QUIET -eq 0 ]]; then
            echo "    ✗ map '${map_key}' skipped" >&2
        fi
    done
else
    _log "  (no maps/ dir found — skipping)"
fi

_log
_log "=== Migration run complete ==="

if [[ $QUIET -eq 0 ]]; then
    echo
    echo "Applied migrations:"
    echo "SELECT migration, applied_at FROM schema_migrations ORDER BY id;" | $MARIADB
fi