#!/usr/bin/env bash
# play.sh - Nerdverse main loop (Phase 0)
# Pure bash + MariaDB. The database *is* the save file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
LIB_DIR="${SCRIPT_DIR}/scripts/lib"

NEW_GAME=0
COMPANION_NAME="Sera"
PUBLIC_TERMINAL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --new-game) NEW_GAME=1; shift ;;
        --public-terminal) PUBLIC_TERMINAL=1; export NERDVERSE_PUBLIC_TERMINAL=1; shift ;;  # sandboxed web lane
        --companion|--companion=*)
            if [[ "$1" == --companion=* ]]; then
                COMPANION_NAME="${1#*=}"; shift
            else
                COMPANION_NAME="${2:-Sera}"; shift 2
            fi
            ;;
        --help|-h)
            cat <<'EOF'
Nerdverse — play.sh

  ./play.sh                         Resume the active save
  ./play.sh --new-game [Companion]    New life → nerdverse{N}_{Companion}
  ./play.sh --public-terminal         Sandboxed public server session (no handoff)

On quit: writes saves/session_handoff.md for Grok/LLM continuity.
Restore: ./scripts/restore_db.sh --latest
EOF
            exit 0
            ;;
        *)
            if [[ $NEW_GAME -eq 1 && "$1" != --* ]]; then
                COMPANION_NAME="$1"; shift
            else
                echo "Unknown option: $1 (try --help)" >&2; exit 1
            fi
            ;;
    esac
done

source scripts/db.sh
source scripts/backup.sh
source scripts/game_db.sh

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/narrative.sh"
source "${LIB_DIR}/world_state.sh"
source "${LIB_DIR}/travel.sh"
source "${LIB_DIR}/player.sh"
source "${LIB_DIR}/sera.sh"
source "${LIB_DIR}/progression.sh"
source "${LIB_DIR}/combat.sh"
source "${LIB_DIR}/scenarios.sh"
source "${LIB_DIR}/maps.sh"
source "${LIB_DIR}/sheets.sh"
source "${LIB_DIR}/render.sh"
source "${LIB_DIR}/handoff.sh"
source "${LIB_DIR}/character_create.sh"
source "${LIB_DIR}/mode.sh"
source "${LIB_DIR}/party.sh"
source "${LIB_DIR}/telemetry.sh"

DB_NAME=$(game_db_resolve_active)
db_reinit

# Public terminal: hard gate — never load author/shared DBs (nerdverse2, nerdverse_public).
if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
    if [[ -z "${NERDVERSE_ACTIVE_DB_FILE:-}" || ! -f "${NERDVERSE_ACTIVE_DB_FILE}" ]]; then
        echo "ERROR: Public session missing isolated active_db pointer." >&2
        exit 1
    fi
    if ! game_db_is_web_session "${DB_NAME}"; then
        echo "ERROR: Public sessions must use isolated nerdverse_web_* databases (got: ${DB_NAME})." >&2
        exit 1
    fi
fi

if [[ $NEW_GAME -eq 1 ]]; then
    command -v mariadb >/dev/null 2>&1 || { echo "Run ./bootstrap.sh first."; exit 1; }
    game_db_create_new "$COMPANION_NAME" || exit 1
elif ! db_check; then
    echo "Run ./bootstrap.sh first."
    exit 1
fi

if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" != "1" ]]; then
    db_backup_daily >/dev/null 2>&1 || echo "Warning: daily backup failed." >&2
fi
./scripts/apply_migrations.sh --quiet || true
travel_normalize_character_locations
sera_normalize_saved_stats
prog_normalize_saves

SCREEN_STACK=("main")

# Breakthrough ceremonies if road XP threshold crossed (play-shaped unlocks)
if mode_allows_breakthrough_on_start && [[ -t 0 ]]; then
    prog_maybe_breakthrough_ceremonies
fi

# Drain stray bytes from browser terminal handshake before first menu read
if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
    sleep 0.15
    tty=$(game_input_tty)
    if [[ "$tty" != "/dev/stdin" ]] && [[ -e "$tty" ]] && [[ -r "$tty" ]]; then
        while read -r -t 0.01 _junk <"$tty" 2>/dev/null; do :; done
    fi
fi

handle_local_action() {
    SERA_TURN_HAD_GAIN=0
    travel_load_current

    case "${LOCATION_KEY}" in
        medicine)
            db_exec "UPDATE world_state SET value = 'Working in the medicine room with Sera.' WHERE state_key = 'last_major_event';"
            log_narrative "$(party_player_name) worked with $(party_companion_short) in the medicine room."
            sera_exercise_agency "follow medicine room action"
            heal_player
            read -r -p "Press enter..."
            ;;
        sheriff) scenario_sheriff ;;
        inn)
            echo
            echo "You take a modest meal. The common room hums with worry about the gang."
            sera_says "Eat. Listen. But don't mistake rest for being done."
            log_narrative "$(party_player_name) took a meal at the Hearthmouse Inn and listened to village rumors."
            read -r -p "Press enter..."
            ;;
        forge)
            echo
            printf '%sAsh-Wood Buckler%s\n' "$BOLD" "$RESET"
            echo "  Passive Guard: reduce first physical hit by 1 (once/round)"
            echo "  Breathguard: once per battle, reduce one hit by 3 + gain +1 Focus"
            echo "  It still smells faintly of the forge and the road."
            log_narrative "$(party_player_name) studied the Ash-Wood Buckler with care."
            read -r -p "Press enter..."
            ;;
        mill)   scenario_mill ;;
        bridge) scenario_bridge_action ;;
        *)
            echo "You take stock of where you stand."
            read -r -p "Press enter..."
            ;;
    esac
}

while true; do
    _screen=$(current_screen)
    render_${_screen}

    if [[ "${RENDER_PROMPT_SHOWN:-0}" == "1" ]]; then
        RENDER_PROMPT_SHOWN=0
        choice=$(read_game_choice 1)
    else
        choice=$(read_game_choice 0)
    fi
    choice=$(normalize_choice "$choice")
    tel_event "menu_choice" "$_screen" "$choice" "${LOCATION_KEY:-}"

    case "$_screen" in
        main)
            if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]] && ! is_valid_main_choice "$choice"; then
                continue
            fi
            case "$choice" in
                f5)
                    continue
                    ;;
                1|travel|go|walk)
                    SERA_TURN_HAD_GAIN=0
                    push_screen "travel"
                    ;;
                2|inventory|inv|i)
                    SERA_TURN_HAD_GAIN=0
                    push_screen "inventory"
                    ;;
                3|talk|sera|t)
                    SERA_TURN_HAD_GAIN=0
                    load_sera_state
                    clear_screen
                    draw_operator_banner "main"
                    echo
                    draw_screen_header "${ICON_CHAR}COMPANION CHANNEL — $(party_companion_name 2>/dev/null || echo GUIDE) [LIVE]"
                    draw_sera_operator_glyph "$(sera_clamp_meter "${SERA_BOND:-25}")"
                    echo
                    printf '%s┌─ OPEN CHANNEL — AUTONOMOUS PLAYER SESSION ──────────────────────┐%s\n' "$CYAN" "$RESET"
                    printf '%s│%s Protocol: dialogue confirms meters; actions move the needle.     %s│%s\n' "$CYAN" "$RESET" "$CYAN" "$RESET"
                    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$CYAN" "$RESET"
                    echo
                    sera_says "You bought practical gear instead of shiny magic. That counts for something."
                    sera_says "Do not wave the buckler around like a dinner plate."
                    sera_exercise_agency "talk"
                    echo
                    draw_pf_key_strip "main"
                    read_game_confirm "Press enter to return to command ledger..."
                    ;;
                4|act|do|local)
                    handle_local_action
                    ;;
                7|world|map|maps)
                    SERA_TURN_HAD_GAIN=0
                    push_screen "world_map"
                    ;;
                8|localmap|look|here)
                    SERA_TURN_HAD_GAIN=0
                    push_screen "local_map"
                    ;;
                9|sheet|sheets|char)
                    SERA_TURN_HAD_GAIN=0
                    push_screen "character_sheets"
                    ;;
                0|q|quit|exit)
                    travel_load_current
                    if [[ "${PUBLIC_TERMINAL:-0}" -eq 1 || "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
                        echo
                        printf '%s╔════════════════════════════════════════════════════════════════╗%s\n' "$GREEN" "$RESET"
                        printf '%s║  SESSION SIGNED OFF — save preserved in isolated life DB       ║%s\n' "$GREEN" "$RESET"
                        printf '%s║  Close this window to end. No shell access.                    ║%s\n' "$GREEN" "$RESET"
                        printf '%s╚════════════════════════════════════════════════════════════════╝%s\n' "$GREEN" "$RESET"
                        echo "Life: ${DB_NAME} ($(game_db_label "$DB_NAME"))."
                        tel_event "session_end" "main" "0" "db=${DB_NAME}"
                        exit 0
                    fi
                    handoff_path=$(handoff_write)
                    echo "Save preserved in ${DB_NAME} ($(game_db_label "$DB_NAME"))."
                    echo "$(party_player_name) stands at $(ui_unescape_sql "${LOCATION}")."
                    echo "LLM handoff: ${handoff_path}"
                    exit 0
                    ;;
                *)
                    SERA_TURN_HAD_GAIN=0
                    echo "Unknown option. Use ledger number or PF-key (F1 Travel, F4 Act, F12 Signoff)."
                    read_game_confirm "Press enter..."
                    ;;
            esac
            apply_sera_decay
            ;;
        travel)
            case "$choice" in
                0|back|b|f3)
                    pop_screen
                    ;;
                *)
                    dest=$(travel_resolve_choice "$choice")
                    if [[ -n "$dest" ]]; then
                        travel_to "$dest" || true
                        read_game_confirm "Press enter..."
                        pop_screen
                    else
                        echo "Pick a path number, or 0 / F3 to return."
                    fi
                    ;;
            esac
            ;;
        world_map|local_map|character_sheets|inventory)
            case "$choice" in
                f5) continue ;;
                0|f3|back|b) pop_screen ;;
                *)
                    echo "Press 0 or F3 to return to command ledger."
                    ;;
            esac
            ;;
        *)
            pop_screen
            ;;
    esac
done