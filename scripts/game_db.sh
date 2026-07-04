#!/usr/bin/env bash
# scripts/game_db.sh — Multi-save database helpers
#
# Naming: nerdverse{N}_{Companion}  (e.g. nerdverse2_Sera, nerdverse3_Elara)
# Legacy nerdverse{N} databases (no suffix) are still supported.
# Active save: saves/active_db (overridable via NERDVERSE_ACTIVE_DB_FILE for public tabs)
#
# Public terminal: nerdverse_web_{hex} — created by game_db_create_web_session()
# using 003_public_terminal_fresh.sql. Never falls back to nerdverse2 or nerdverse_public.

_GAME_DB_PREFIX="${NERDVERSE_DB_PREFIX:-nerdverse}"
_DEFAULT_ACTIVE_DB_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/saves/active_db"

game_db_active_file() {
    if [[ -n "${NERDVERSE_ACTIVE_DB_FILE:-}" ]]; then
        echo "${NERDVERSE_ACTIVE_DB_FILE}"
    else
        echo "${_DEFAULT_ACTIVE_DB_FILE}"
    fi
}

game_db_resolve_active() {
    local active_file
    active_file=$(game_db_active_file)
    if [[ -f "${active_file}" ]]; then
        cat "${active_file}"
    else
        echo "${DB_NAME:-nerdverse2}"
    fi
}

game_db_set_active() {
    local name="$1" active_file
    active_file=$(game_db_active_file)
    mkdir -p "$(dirname "${active_file}")"
    printf '%s\n' "$name" > "${active_file}"
    export DB_NAME="$name"
    db_reinit
}

# "Sera Thornwake" → "Sera"; strips unsafe characters for DB names.
game_db_sanitize_companion() {
    local raw="${1:-Companion}"
    raw="${raw%% *}"
    raw=$(printf '%s' "$raw" | sed 's/[^A-Za-z0-9_]//g')
    [[ -z "$raw" ]] && raw="Companion"
    local first="${raw:0:1}"
    local rest="${raw:1}"
    printf '%s%s' "$(printf '%s' "$first" | tr '[:lower:]' '[:upper:]')" "${rest}"
}

game_db_list() {
    echo "SHOW DATABASES LIKE '${_GAME_DB_PREFIX}%';" | $MARIADB_QUIET 2>/dev/null | sort -V
}

# Extract slot number from nerdverse2 or nerdverse2_Sera
_game_db_slot_number() {
    local db="$1"
    if [[ "$db" =~ ^${_GAME_DB_PREFIX}([0-9]+)(_.*)?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# Human label for a save database
game_db_label() {
    local db="$1"
    if [[ "$db" =~ ^${_GAME_DB_PREFIX}([0-9]+)_([A-Za-z0-9_]+)$ ]]; then
        echo "Life ${BASH_REMATCH[1]} — ${BASH_REMATCH[2]}"
    elif [[ "$db" =~ ^${_GAME_DB_PREFIX}([0-9]+)$ ]]; then
        echo "Life ${BASH_REMATCH[1]} (legacy)"
    elif [[ "$db" =~ ^${_GAME_DB_PREFIX}_web_([0-9a-f]+)$ ]]; then
        echo "Web · ${BASH_REMATCH[1]:0:8}"
    else
        echo "$db"
    fi
}

game_db_is_web_session() {
    [[ "${1:-${DB_NAME:-}}" =~ ^${_GAME_DB_PREFIX}_web_[0-9a-f]+$ ]]
}

# Web/public session DB: nerdverse_web_{hex} — isolated from local nerdverse2 saves.
game_db_create_web_session() {
    local companion_name="${1:-Sera}"
    local suffix new_name
    suffix=$(openssl rand -hex 4 2>/dev/null || echo "$RANDOM$RANDOM")
    new_name="nerdverse_web_${suffix}"

    if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
        echo "[web-session] Creating isolated database '${new_name}' ..." >&2
        if declare -f cc_public_progress >/dev/null 2>&1; then
            cc_public_progress "  ▸ Seeding Brindleford Vale (chapter 1)"
        fi
    else
        echo "[web-session] Creating isolated database '${new_name}' ..."
    fi
    local prev_name="${DB_NAME}"
    export DB_NAME="$new_name"
    db_reinit

    db_ensure_database_and_user

    if ! db_check; then
        export DB_NAME="$prev_name"
        db_reinit
        echo "ERROR: could not connect to '${new_name}'." >&2
        return 1
    fi

    local apply_script
    apply_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply_migrations.sh"
    NERDVERSE_PUBLIC_FRESH_SEED=1 NERDVERSE_FRESH_SEED=1 "$apply_script" --fresh --quiet

    game_db_set_active "$new_name"
    if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
        echo "[web-session] Ready: ${new_name}" >&2
    else
        echo "[web-session] Ready: ${new_name}"
    fi
    return 0
}

# Next free name: nerdverse{N}_{Companion}
game_db_next_name() {
    local companion
    companion=$(game_db_sanitize_companion "${1:-Sera}")

    local highest=1
    local db num
    while IFS= read -r db; do
        [[ -z "$db" ]] && continue
        num=$(_game_db_slot_number "$db")
        [[ -n "$num" && "$num" -gt "$highest" ]] && highest=$num
    done < <(game_db_list)

    local n=$(( highest + 1 ))
    local candidate="${_GAME_DB_PREFIX}${n}_${companion}"

    while echo "$(game_db_list)" | grep -qx "$candidate"; do
        (( n++ ))
        candidate="${_GAME_DB_PREFIX}${n}_${companion}"
    done

    echo "$candidate"
}

# Create a brand-new game database (does not touch existing saves).
game_db_create_new() {
    local companion_name="${1:-Sera}"
    local new_name
    new_name=$(game_db_next_name "$companion_name")

    echo "[new-game] Creating database '${new_name}' ($(game_db_label "$new_name")) ..."
    echo "[new-game] Existing saves are preserved."

    local prev_name="${DB_NAME}"
    export DB_NAME="$new_name"
    db_reinit

    db_ensure_database_and_user

    if ! db_check; then
        export DB_NAME="$prev_name"
        db_reinit
        echo "ERROR: could not connect to new database '${new_name}'." >&2
        return 1
    fi

    local apply_script
    apply_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply_migrations.sh"
    NERDVERSE_FRESH_SEED=1 "$apply_script" --fresh --quiet

    game_db_set_active "$new_name"
    echo "[new-game] Ready. Active save: ${new_name}"
    return 0
}