#!/usr/bin/env bash
# play.sh - Nerdverse main loop (Phase 0)
# Pure bash + MariaDB. The database *is* the save file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
LIB_DIR="${SCRIPT_DIR}/scripts/lib"

NEW_GAME=0
COMPANION_NAME="Sera"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --new-game) NEW_GAME=1; shift ;;
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

DB_NAME=$(game_db_resolve_active)
db_reinit

if [[ $NEW_GAME -eq 1 ]]; then
    command -v mariadb >/dev/null 2>&1 || { echo "Run ./bootstrap.sh first."; exit 1; }
    game_db_create_new "$COMPANION_NAME" || exit 1
elif ! db_check; then
    echo "Run ./bootstrap.sh first."
    exit 1
fi

db_backup_daily >/dev/null 2>&1 || echo "Warning: daily backup failed." >&2
./scripts/apply_migrations.sh --quiet || true
travel_normalize_character_locations
sera_normalize_saved_stats
prog_normalize_saves

SCREEN_STACK=("main")

# Breakthrough ceremonies if road XP threshold crossed (play-shaped unlocks)
if [[ -t 0 ]]; then
    prog_maybe_breakthrough_ceremonies
fi

handle_local_action() {
    SERA_TURN_HAD_GAIN=0
    travel_load_current

    case "${LOCATION_KEY}" in
        medicine)
            db_exec "UPDATE world_state SET value = 'Working in the medicine room with Sera.' WHERE state_key = 'last_major_event';"
            log_narrative "Meyiu worked with Sera in the medicine room."
            sera_exercise_agency "follow medicine room action"
            heal_player
            read -r -p "Press enter..."
            ;;
        sheriff) scenario_sheriff ;;
        inn)
            echo
            echo "You take a modest meal. The common room hums with worry about the gang."
            sera_says "Eat. Listen. But don't mistake rest for being done."
            log_narrative "Meyiu took a meal at the Hearthmouse Inn and listened to village rumors."
            read -r -p "Press enter..."
            ;;
        forge)
            echo
            printf '%sAsh-Wood Buckler%s\n' "$BOLD" "$RESET"
            echo "  Passive Guard: reduce first physical hit by 1 (once/round)"
            echo "  Breathguard: once per battle, reduce one hit by 3 + gain +1 Focus"
            echo "  It still smells faintly of the forge and the road."
            log_narrative "Meyiu studied the Ash-Wood Buckler with care."
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
        read -r choice
    else
        read -r -p "> " choice
    fi
    choice=$(normalize_choice "$choice")

    case "$_screen" in
        main)
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
                    draw_screen_header "${ICON_CHAR}COMPANION CHANNEL — SERA THORNWAKE [LIVE]"
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
                    read -r -p "Press enter to return to command ledger..."
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
                    handoff_path=$(handoff_write)
                    echo "Save preserved in ${DB_NAME} ($(game_db_label "$DB_NAME"))."
                    echo "Meyiu stands at $(ui_unescape_sql "${LOCATION}")."
                    echo "LLM handoff: ${handoff_path}"
                    exit 0
                    ;;
                *)
                    SERA_TURN_HAD_GAIN=0
                    echo "Unknown option. Use ledger number or PF-key (F1 Travel, F4 Act, F12 Signoff)."
                    read -r -p "Press enter..."
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
                        read -r -p "Press enter..."
                    else
                        echo "Pick a path number, or 0 to stay."
                        read -r -p "Press enter..."
                    fi
                    pop_screen
                    ;;
            esac
            ;;
        world_map|local_map|character_sheets|inventory)
            if [[ "$choice" == "f5" ]]; then
                continue
            fi
            pop_screen
            ;;
        *)
            pop_screen
            ;;
    esac
done