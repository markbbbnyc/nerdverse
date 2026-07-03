#!/usr/bin/env bash
# play.sh - Nerdverse main loop (Phase 0)
# Pure bash + MariaDB.
#
# Immersive terminal experience:
# - Full-screen canvas (clear + centered + adaptive width via tput/stty)
# - AS/400-style push/pop screen navigation (F3/Enter to back)
# - Green phosphor / amber aesthetic, sparse icons, visible-length layout
# - [7] World Map, [8] Local Map, [9] Character Sheets (live DB)
# - Robust on macOS, Linux (Ubuntu/Arch), ssh (-t), tmux, non-tty
#
# The database *is* the save file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source scripts/db.sh

# Defensive init for set -u (unbound variable) safety in all environments (ssh, tmux, pipes, etc.)
BOLD=""
RESET=""
GREEN=""
DIM=""
BRIGHT_GREEN=""
AMBER=""
YELLOW=""
CYAN=""
GRAY=""
WHITE=""

# === Terminal & Presentation (green screen + modern old-school canvas) ===
# Detect size for centering / immersive feel (not true fullscreen, but "full screen" vibe)
get_cols() {
    # Robust for ssh, tmux, linux ttys, mac, non-interactive
    if command -v tput >/dev/null 2>&1; then
        tput cols 2>/dev/null || echo 80
    elif command -v stty >/dev/null 2>&1; then
        stty size 2>/dev/null | awk '{print $2}' || echo 80
    else
        echo 80
    fi
}
get_lines() {
    if command -v tput >/dev/null 2>&1; then
        tput lines 2>/dev/null || echo 24
    elif command -v stty >/dev/null 2>&1; then
        stty size 2>/dev/null | awk '{print $1}' || echo 24
    else
        echo 24
    fi
}

# Green phosphor / amber old terminal aesthetic with fantasy accents
# Use tput when available for maximum compatibility (ssh, tmux, linux ttys, mac)
# Falls back to hard-coded for when tput not present or TERM=dumb
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    BOLD=$(tput bold 2>/dev/null || printf '\033[1m')
    RESET=$(tput sgr0 2>/dev/null || printf '\033[0m')
    GREEN=$(tput setaf 2 2>/dev/null || printf '\033[32m')
    DIM=$(tput dim 2>/dev/null || printf '\033[2;32m')
    # For bright green: try to combine bold + green
    BRIGHT_GREEN=$( { tput bold; tput setaf 2; } 2>/dev/null || printf '\033[1;32m' )
    AMBER=$(tput setaf 3 2>/dev/null || printf '\033[33m')
    YELLOW=$( { tput bold; tput setaf 3; } 2>/dev/null || printf '\033[1;33m' )
    CYAN=$(tput setaf 6 2>/dev/null || printf '\033[36m')
    GRAY=$(printf '\033[38;5;250m')  # nice eyecandy mid-grey (much better contrast on macOS Terminal dark bg)
    WHITE=$(tput setaf 7 2>/dev/null || printf '\033[37m')
else
    # Fallback using actual escape (for very old/minimal systems)
    _e=$(printf '\033')
    BOLD="${_e}[1m"
    RESET="${_e}[0m"
    GREEN="${_e}[32m"
    DIM="${_e}[2;32m"
    BRIGHT_GREEN="${_e}[1;32m"
    AMBER="${_e}[33m"
    YELLOW="${_e}[1;33m"
    CYAN="${_e}[36m"
    GRAY="${_e}[38;5;250m"  # nice eyecandy mid-grey (much better contrast on macOS Terminal dark bg)
    WHITE="${_e}[37m"
fi

# Nerdfont icons (enhances on terminals with nerdfonts; graceful degradation)
ICON_MAP="🗺 "
ICON_CHAR="👤 "
ICON_SCROLL="📜 "
ICON_FORGE="⚒ "
ICON_EXIT="⏏ "

# Centering helpers for that "full screen" old terminal canvas feel
# Strip ANSI for correct visible length (so color codes don't mess up centering)
visible_len() {
    local s="$1"
    # Remove ESC [ ... m sequences (covers tput and hard-coded)
    s=$(printf %s "$s" | sed -E 's/\x1b\[[0-9;]*m//g' 2>/dev/null || echo "$s")
    echo "${#s}"
}

center_line() {
    local text="$1"
    local width=${2:-$(get_cols)}
    local len=$(visible_len "$text")
    local pad=$(( (width - len) / 2 ))
    (( pad < 0 )) && pad=0
    # Use printf for everything to avoid interpretation issues
    printf "%*s%s\n" "$pad" "" "$text"
}

# Draw a full-width-ish box header (AS/400 screen title bar)
draw_screen_header() {
    local title="$1"
    local cols=$(get_cols)
    local w=$(( cols > 78 ? 78 : cols - 2 ))
    local line
    line=$(printf "%${w}s" | tr ' ' '═')
    printf '%s╔%s╗%s\n' "$BRIGHT_GREEN" "$line" "$RESET"
    # Print left border + title (title may contain icons with multibyte)
    printf '%s║%s %s' "$BRIGHT_GREEN" "$RESET" "$title"
    # Use visible len so multibyte icons don't throw off the right border too badly
    local title_vis=$(visible_len "$title")
    local used=$(( 2 + title_vis ))
    local right_pad=$(( w - used ))
    (( right_pad < 0 )) && right_pad=0
    printf '%*s%s║%s\n' "$right_pad" "" "$BRIGHT_GREEN" "$RESET"
    printf '%s╚%s╝%s\n' "$BRIGHT_GREEN" "$line" "$RESET"
}

# AS/400 style footer
draw_footer() {
    echo
    printf '%sF3=Back%s   %sF5=Refresh%s   %s0=Quit%s   %sEnter=Continue%s\n' \
        "$DIM" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET" "$GRAY" "$RESET"
    printf '%s%s%s\n' "$DIM" "────────────────────────────────────────────────────────────────────" "$RESET"
}

# === Push/Pop Screen Navigation (AS/400 operator style) ===
declare -a SCREEN_STACK
SCREEN_STACK=("main")

current_screen() {
    # Compatible with old bash (macOS default)
    local idx=$(( ${#SCREEN_STACK[@]} - 1 ))
    echo "${SCREEN_STACK[$idx]}"
}

push_screen() {
    SCREEN_STACK+=("$1")
}

pop_screen() {
    if (( ${#SCREEN_STACK[@]} > 1 )); then
        local idx=$(( ${#SCREEN_STACK[@]} - 1 ))
        unset "SCREEN_STACK[$idx]"
    fi
}

clear_screen() {
    # Only attempt full clear when we have a real terminal (ssh, tmux, local tty)
    # Prevents garbage in pipes, scripts, or dumb terminals
    if [[ -t 1 ]]; then
        if command -v tput >/dev/null 2>&1; then
            tput clear 2>/dev/null || printf '\033[2J\033[H'
        else
            printf '\033[2J\033[H'
        fi
    fi
}

# === Screen Renderers (full screen / centered / old terminal canvas) ===

render_main() {
    clear_screen

    local cols=$(get_cols)
    center_line "${BOLD}NERDVERSE — PHASE 0${RESET}  ${DIM}the sinner who still chooses${RESET}" $cols
    echo

    draw_screen_header "${ICON_CHAR}MEYIU  —  THE SINNER WHO STILL CHOOSES"

    show_status
    echo
    show_ascii_forge
    echo

    if [[ "${LOCATION}" == *"Medicine"* ]]; then
        sera_says "Here we are. The crate is still sealed. Let's see what's inside and what we can use."
    else
        sera_says "Medicine room next. Unless you plan to treat stab wounds with personal growth."
    fi

    echo
    printf '%sWhat does Meyiu do?%s\n' "$BOLD$GREEN" "$RESET"
    if [[ "${LOCATION}" == *"Medicine"* ]]; then
        printf '  %s[1]%s Inventory the recovered crate together\n' "$GREEN" "$RESET"
    else
        printf '  %s[1]%s Go to Sera'\''s medicine room (recommended)\n' "$GREEN" "$RESET"
    fi
    printf '  %s[2]%s Check inventory\n' "$GREEN" "$RESET"
    printf '  %s[3]%s Talk to Sera more\n' "$GREEN" "$RESET"
    printf '  %s[4]%s Visit the Hearthmouse Inn\n' "$GREEN" "$RESET"
    printf '  %s[5]%s Return to Sheriff Marn\n' "$GREEN" "$RESET"
    printf '  %s[6]%s Look at the new Ash-Wood Buckler\n' "$GREEN" "$RESET"
    printf '  %s[7]%s %sUnfold the known World Map%s\n' "$GREEN" "$RESET" "$ICON_MAP" ""
    printf '  %s[8]%s %sStudy the Local Map of here%s\n' "$GREEN" "$RESET" "$ICON_MAP" ""
    printf '  %s[9]%s %sExamine Character Sheets%s\n' "$GREEN" "$RESET" "$ICON_SCROLL" ""
    printf '  %s[0]%s %sQuit for now%s\n' "$GREEN" "$RESET" "$ICON_EXIT" ""
    echo

    draw_footer
}

render_world_map() {
    clear_screen
    draw_screen_header "${ICON_MAP}WORLD MAP — KNOWN LANDS"
    show_world_map
    echo
    printf '%s(Studied the lay of the land. The map is now part of memory.)%s\n' "$DIM" "$RESET"
    draw_footer
}

render_local_map() {
    clear_screen
    draw_screen_header "${ICON_MAP}LOCAL MAP — ${LOCATION:-Current Location}"
    show_local_map
    draw_footer
}

render_character_sheets() {
    clear_screen
    draw_screen_header "${ICON_SCROLL}PERSONA RECORDS"
    show_character_sheets
    draw_footer
}

# Simple inventory as its own screen for demo
render_inventory() {
    clear_screen
    draw_screen_header "${ICON_CHAR}INVENTORY"
    echo
    printf '%sMeyiu'\''s Inventory:%s\n' "$BOLD$GREEN" "$RESET"
    echo "SELECT CONCAT('  - ', item_name, ' (x', quantity, ')') FROM inventory WHERE character_id = (SELECT id FROM characters WHERE is_player=TRUE) ORDER BY equipped DESC, item_name;" | $MARIADB
    echo
    draw_footer
}


# Load current player state
load_player() {
    local row
    row=$(db_query_row "SELECT name, title, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location FROM characters WHERE is_player = TRUE LIMIT 1;")
    # name title cur max coins xp xpmax loc
    IFS=$'\t' read -r PLAYER_NAME PLAYER_TITLE CUR_HP MAX_HP COINS ROAD_XP ROAD_XP_MAX LOCATION <<< "$row"
}

load_sera() {
    local row
    row=$(db_query_row "SELECT current_hp, max_hp, notes FROM characters WHERE name = 'Sera Thornwake' LIMIT 1;")
    IFS=$'\t' read -r SERA_HP SERA_MAX SERA_NOTES <<< "$row"
}

load_world() {
    THREAT=$(db_query "SELECT value FROM world_state WHERE state_key='black_bridge_gang_status';")
    CHAPTER=$(db_query "SELECT value FROM world_state WHERE state_key='current_chapter';")
}

show_status() {
    load_player
    load_sera
    load_world
    load_sera_state   # for trust/bond/joint

    # Content only — outer header provided by render_main via draw_screen_header
    printf "  ${GREEN}Location${RESET} : %s\n" "${LOCATION}"
    printf "  ${GREEN}HP${RESET}       : ${BRIGHT_GREEN}%d${RESET} / %d\n" "$CUR_HP" "$MAX_HP"
    printf "  ${GREEN}Coins${RESET}    : %d silver\n" "$COINS"
    printf "  ${GREEN}Road XP${RESET}  : %d / %d\n" "$ROAD_XP" "$ROAD_XP_MAX"
    echo
    printf '  %sSera Thornwake%s  (HP %d/%d)  —  %s%s...%s\n' \
        "$AMBER" "$RESET" "$SERA_HP" "$SERA_MAX" "$GRAY" "${SERA_NOTES:0:70}" "$RESET"
    echo
    # Visible "Sera is choosing" reward - core dopamine
    local joint=${SERA_JOINT:-0}
    local lead=${SERA_LEAD:-0}
    printf '  %sSera'\''s Bond with you:%s  Trust %s  |  Bond %s  |  Shared: %s | Sera led: %s\n' \
        "$GREEN" "$RESET" "${SERA_TRUST:-35}" "${SERA_BOND:-25}" "$joint" "$lead"
    echo

    # Explicit "Sera is choosing this" feeling
    if [[ "${SERA_BOND:-25}" -ge 40 ]]; then
        printf '  %sSera has chosen to walk this road with you.%s\n' "$AMBER" "$RESET"
    elif [[ "${SERA_BOND:-25}" -ge 25 ]]; then
        printf '  %sSera is still choosing whether to fully tie her fate to yours.%s\n' "$DIM" "$RESET"
    fi
    echo
    printf '%sChapter: %s%s\n' "$DIM" "$CHAPTER" "$RESET"
    printf '%sThreat : %s%s\n' "$DIM" "$THREAT" "$RESET"
    echo
}

show_ascii_forge() {
    cat << 'ART'
          .--.
         /    \
        |  FORGE |
         \  __  /
          | |  | |
   +------| |  | |------+
   |  Ash-Wood Buckler  |
   |   + Repair Bundle  |
   +--------------------+
ART
}

show_ascii_sera() {
    cat << 'ART'
          o
         /|\
        / | \     Sera Thornwake
       /  |  \    bow • buckler • healer
ART
}

log_narrative() {
    local entry="$1"
    local loc="${LOCATION:-Brindleford}"
    # Escape ' by doubling for use inside '... ' SQL string literals
    local esc_entry
    local esc_loc
    esc_entry=$(printf '%s' "$entry" | sed "s/'/''/g")
    esc_loc=$(printf '%s' "$loc" | sed "s/'/''/g")
    echo "INSERT INTO session_log (log_type, entry, location, character_name)
          VALUES ('NARRATIVE', '$esc_entry', '$esc_loc', 'Sera');" | $MARIADB >/dev/null
}

sera_says() {
    local line="$1"
    printf '%sSera:%s "%s"\n' "$YELLOW" "$RESET" "$line"
    log_narrative "Sera: ${line}"
}

# === Sera Agency System (full autonomous companion) ===
# Sera is a full player. She chooses the journey.
# Togetherness is built through bantering + actions that "walk the talk."
# Major reward: the felt sense that she is actively choosing you.
# Leadership ~70% Meyiu / 30% Sera. Wins and losses are lessons.
# She will sometimes seek alignment elsewhere on specific topics (15%).
# She decides on her own. Sometimes she leads. The bond grows through shared experience.
#
# Mechanics notes (slow burn):
# - Base gains are small (+1 to +4).
# - Pure repetition (same context twice) heavily reduces or zeros gains.
# - "talk" only gives meaningful bond if it follows a real action (defend/joint/medicine).
# - Actions (joint, defend, medicine together) are the main drivers.
# - Words contextualize and amplify actions, but do not replace them.

load_sera_state() {
    SERA_TRUST=$(db_query "SELECT value FROM world_state WHERE state_key='sera_trust_level';")
    SERA_BOND=$(db_query "SELECT value FROM world_state WHERE state_key='sera_bond_level';")
    SERA_MOOD=$(db_query "SELECT value FROM world_state WHERE state_key='sera_mood';")
    SERA_GRAIL=$(db_query "SELECT value FROM world_state WHERE state_key='sera_personal_grail';")
    SERA_PRINCIPLES=$(db_query "SELECT value FROM world_state WHERE state_key='sera_core_principles';")
    SERA_ROMANTIC=$(db_query "SELECT value FROM world_state WHERE state_key='sera_romantic_tension';")
    SERA_JOINT=$(db_query "SELECT value FROM world_state WHERE state_key='sera_joint_experiences';")
    SERA_LEAD=$(db_query "SELECT value FROM world_state WHERE state_key='sera_leadership_moments';")
    SERA_LAST_ACTION=$(db_query "SELECT value FROM world_state WHERE state_key='sera_last_action';")
    SERA_RECENT_EVENT=$(db_query "SELECT value FROM world_state WHERE state_key='sera_recent_event';")
}

sera_update_state() {
    local key="$1"
    local value="$2"
    db_exec "UPDATE world_state SET value='${value}' WHERE state_key='${key}';"
}

# Call this after meaningful shared actions or experiences.
# This is one of the primary ways the bond grows.
# Repetition is devalued unless context changed.
sera_record_joint_experience() {
    load_sera_state
    local current=${SERA_JOINT:-0}
    local new=$(( current + 1 ))
    db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_joint_experiences\", \"$new\") ON DUPLICATE KEY UPDATE value = \"$new\";"

    local gain_t=2
    local gain_b=3

    # Diminishing returns on pure repetition
    if [[ "$SERA_LAST_ACTION" == *"joint"* || "$SERA_LAST_ACTION" == *"talk"* ]]; then
        gain_t=1
        gain_b=1
    fi

    local t=$(( ${SERA_TRUST:-35} + gain_t ))
    local b=$(( ${SERA_BOND:-25} + gain_b ))
    [[ $t -gt 100 ]] && t=100
    db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_trust_level\", \"$t\") ON DUPLICATE KEY UPDATE value = \"$t\";"
    db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_bond_level\", \"$b\") ON DUPLICATE KEY UPDATE value = \"$b\";"

    sera_update_state "sera_last_action" "joint"
}

# Sera exercises agency. She is choosing.
# This should feel visible and rewarding to the player.
# Gains are deliberately small and context-sensitive for a slow-burn arc.
sera_exercise_agency() {
    load_sera_state

    local choice_context="$1"
    local trust_change=0
    local bond_change=0
    local mood_shift=""
    local her_action=""
    local her_words=""

    # Base small gains. Repetition and lack of context heavily penalize.
    local is_repeat=0
    if [[ -n "$SERA_LAST_ACTION" && "$choice_context" == *"$SERA_LAST_ACTION"* ]]; then
        is_repeat=1
    fi

    case "$choice_context" in
        *"defend"*|*"protect"*|*"measured"*|*"scouts"*)
            # Strong meaningful action
            trust_change=3
            bond_change=4
            her_words="You meant it. Not just talk. I saw it in the orders — and in what you were willing to risk yourself."
            her_action="Sera takes initiative (30% lead): \"I'll decide who among the villagers gets the first of the limited healing and set the fallback signal with the scouts. You focus on the Sheriff. We split the load.\""
            if [[ "${SERA_BOND:-0}" -ge 35 ]]; then
                her_action="$her_action She later quietly sets a simple watch rotation with two villagers based on her own judgment."
            fi
            sera_update_state "sera_recent_event" "meaningful_action"
            ;;
        *"risk"*|*"heroic"*|*"noble"*|*"but"*)
            trust_change=-4
            mood_shift="cutting"
            her_words="That was the kind of brave that gets good people killed. We don't have that luxury."
            ;;
        *"listened"*|*"saw me"*|*"didn't ask me to shrink"*)
            # Words after action are good. Pure spam is weak.
            if [[ "$SERA_LAST_ACTION" == *"defend"* || "$SERA_LAST_ACTION" == *"joint"* || "$SERA_LAST_ACTION" == *"medicine"* ]]; then
                bond_change=3
                trust_change=2
                her_words="You looked at me like I'm allowed to be exactly this sharp and still worth keeping around."
            else
                bond_change=1
                trust_change=1
                her_words="I heard you. Let's see it in what we do next."
            fi
            if [[ "$SERA_ROMANTIC" == *"emerging"* ]]; then
                her_action="She stays a little closer while you work. No big gesture — just presence that wasn't there before."
            fi
            if [[ "${SERA_BOND:-0}" -ge 30 ]]; then
                her_action="$her_action She mentions quietly that Old Brenn gave her a small tip on the buckler straps that helped."
            fi
            ;;
        *"follow"*|*"medicine"*|*"room"*)
            trust_change=2
            bond_change=3
            her_words="Good. Let's get to work then. The sooner we know what's in this crate, the better."
            her_action="Sera moves to the crate and starts carefully opening it, taking the lead on the inspection."
            sera_update_state "sera_recent_event" "meaningful_action"
            ;;
        *"talk"*)
            # Pure talk is weak unless it follows real action
            if [[ "$SERA_RECENT_EVENT" == "meaningful_action" ]]; then
                bond_change=3
                trust_change=2
                sera_update_state "sera_recent_event" ""
                her_words="I heard you. That lands differently after what we just went through together."
            elif [[ "$SERA_LAST_ACTION" == *"defend"* || "$SERA_LAST_ACTION" == *"joint"* || "$SERA_LAST_ACTION" == *"medicine"* ]]; then
                bond_change=2
                trust_change=1
                her_words="I heard you. That means something after what we just did."
            else
                bond_change=0
                trust_change=0
                her_words="I hear you. Now let's show it with what we do."
            fi
            ;;
        *)
            her_words="We'll see what that actually costs."
            ;;
    esac

    # Apply repetition penalty (slower burn) for most contexts
    if [[ $is_repeat -eq 1 && "$choice_context" != *"defend"* ]]; then
        trust_change=$(( trust_change / 2 ))
        bond_change=$(( bond_change / 2 ))
    fi
    if [[ $trust_change -lt 1 && $bond_change -lt 1 && $is_repeat -eq 1 ]]; then
        trust_change=0
        bond_change=0
        if [[ -z "$mood_shift" ]]; then
            mood_shift="bored"
            her_words="We've been over this. Let's do something that actually moves us."
        fi
    fi

    local new_trust=$(( ${SERA_TRUST:-35} + trust_change ))
    local new_bond=$(( ${SERA_BOND:-25} + bond_change ))
    [[ $new_trust -lt 0 ]] && new_trust=0
    [[ $new_trust -gt 100 ]] && new_trust=100

    sera_update_state "sera_trust_level" "$new_trust"
    sera_update_state "sera_bond_level" "$new_bond"
    [[ -n "$mood_shift" ]] && sera_update_state "sera_mood" "$mood_shift"

    # Remember what we just did for future repetition/context checks
    if [[ -n "$choice_context" ]]; then
        sera_update_state "sera_last_action" "$choice_context"
    fi

    # Set recent_event for context-sensitive bonuses (e.g. talk after action)
    if [[ "$choice_context" == *"defend"* || "$choice_context" == *"joint"* || "$choice_context" == *"medicine"* || "$choice_context" == *"follow"* ]]; then
        sera_update_state "sera_recent_event" "meaningful_action"
    fi

    if [[ -n "$her_words" ]]; then
        echo
        printf '%sSera:%s "%s"\n' "$YELLOW" "$RESET" "$her_words"
        log_narrative "Sera (choosing the journey): ${her_words}"
    fi

    # Make the "Sera chose this" feeling explicit after meaningful agency
    if [[ $bond_change -gt 1 || $trust_change -gt 1 ]]; then
        echo -e "${AMBER}Sera looks at you for a long moment, then nods once. \"Alright. We do this together.\"${RESET}"
        log_narrative "Sera explicitly chooses the journey with you."
    fi

    if [[ -n "$her_action" ]]; then
        echo -e "${GRAY}Sera moves on her own: ${her_action}${RESET}"
        log_narrative "Sera acted independently: ${her_action}"
        # Track her 30% leadership with upsert
        local lead=${SERA_LEAD:-0}
        local newlead=$(( lead + 1 ))
        db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_leadership_moments\", \"$newlead\") ON DUPLICATE KEY UPDATE value = \"$newlead\";"
    fi

    if [[ $new_trust -lt 20 ]]; then
        echo -e "${DIM}(The choice to stay is more visible right now. And more fragile.)${RESET}"
    fi
}

# === Map viewing (new in this pass) ===
resolve_location_key() {
    local loc="$1"
    case "$loc" in
        *"Forge"*|*"forge"*)     echo "forge" ;;
        *"Medicine"*|*"medicine"*) echo "medicine" ;;
        *"Inn"*|*"inn"*)         echo "inn" ;;
        *"Sheriff"*|*"sheriff"*) echo "sheriff" ;;
        *"Mill"*|*"mill"*)       echo "mill" ;;
        *"Bridge"*|*"bridge"*)   echo "bridge" ;;
        *)                       echo "forge" ;;
    esac
}

fetch_map_ascii() {
    local key="$1"
    # --raw preserves literal newlines and box-drawing characters in the whimsical art
    echo "SELECT ascii FROM maps WHERE map_key='${key//\'/\'\'}' LIMIT 1;" \
        | $MARIADB --silent --skip-column-names --raw 2>/dev/null || echo ""
}

show_world_map() {
    local title ascii
    title=$(db_query "SELECT title FROM maps WHERE map_key='world' LIMIT 1;")
    ascii=$(fetch_map_ascii "world")
    if [[ -z "$ascii" ]]; then
        echo "(The world map has not yet been drawn. Keep exploring.)"
        return
    fi
    # Title is now provided by draw_screen_header in the render wrapper
    echo "$ascii"
    log_narrative "Meyiu spread the world map across a flat rock and studied the shape of everything known."
}

show_local_map() {
    local key ascii
    key=$(resolve_location_key "${LOCATION:-Brindleford Forge}")
    ascii=$(fetch_map_ascii "$key")
    if [[ -z "$ascii" ]]; then
        echo "You take a slow walk around and commit the details of this place to memory."
        echo "(No detailed local map has been inked yet.)"
    else
        echo "$ascii"
    fi
    log_narrative "Meyiu paused and really looked at the ${LOCATION:-surroundings}, fixing it in memory."
}

show_character_sheets() {
    # Header now provided by render wrapper + draw_screen_header

    # --- MEYIU ---
    local m_hp m_max m_coins m_xp m_xpmax m_loc m_title
    local row
    row=$(db_query_row "SELECT current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, title FROM characters WHERE name='Meyiu' LIMIT 1;")
    IFS=$'\t' read -r m_hp m_max m_coins m_xp m_xpmax m_loc m_title <<< "$row"

    printf '%sMEYIU%s  —  %s\n' "$BOLD" "$RESET" "$m_title"
    echo "────────────────────────────────────────────────────────────────────"
    printf "  NAME      : %-20s   CLASS  : %s\n" "Meyiu" "Mage"
    printf "  LOCATION  : %-20s   HP     : %d / %d\n" "$m_loc" "$m_hp" "$m_max"
    printf "  ROAD XP   : %d / %-3d                COINS  : %d silver\n" "$m_xp" "$m_xpmax" "$m_coins"
    echo
    echo "  EQUIPPED GEAR"
    echo "SELECT CONCAT(\"    \", item_name, \"  \", LEFT(COALESCE(effect,\"\"),48))
          FROM inventory i JOIN characters c ON i.character_id = c.id
          WHERE c.name=\"Meyiu\" AND equipped=TRUE ORDER BY item_name;" | $MARIADB --silent --skip-column-names
    echo
    echo "  KNOWN TECHNIQUES"
    echo "SELECT CONCAT(\"    • \", ability_name, \"   \", LEFT(description,42))
          FROM character_abilities a JOIN characters c ON a.character_id=c.id
          WHERE c.name=\"Meyiu\" ORDER BY ability_name;" | $MARIADB --silent --skip-column-names
    echo
    echo "  CARRIED (selected)"
    echo "    • Healing Potion, Leechheart Pearl, Repair Bundle, Road Knife"
    echo "    • Cinder Nameplate, Black Bridge-Token, Gray-Blue Question Slip"
    echo "    • White Quill Splinter, Black Brazier-Glass Shard"
    echo
    echo "  TRAITS"
    echo "    Beloved • Responsible • Unfinished • Pilgrim of the Unfinished"
    echo "    \"And Chooses What Is His To Carry\""
    echo

    # separator + SERA
    printf '%s%s%s\n' "$BOLD$YELLOW" "────────────────────────────────────────────────────────────────────" "$RESET"
    echo

    local s_hp s_max s_notes
    row=$(db_query_row "SELECT current_hp, max_hp, notes FROM characters WHERE name='Sera Thornwake' LIMIT 1;")
    IFS=$'\t' read -r s_hp s_max s_notes <<< "$row"

    printf '%sSERA THORNWAKE%s\n' "$BOLD" "$RESET"
    echo "────────────────────────────────────────────────────────────────────"
    printf "  TITLE     : Field-healer, trail archer, buckler fighter\n"
    printf "  CLASS     : Healer-Archer                  HP : %d / %d\n" "$s_hp" "$s_max"
    echo
    echo "  GEAR"
    echo "    Trail Bow    Bow Shot: 3 damage"
    echo "    Buckler      Buckler Guard: reduce damage to self or ally by 2 (once/round)"
    echo
    echo "  ROLE"
    echo "    Provisional trust. May join permanently if Brindleford survives."
    echo "    Sharp-tongued, practical, protective. Controls the medicine room."
    echo
    echo "  NOTES"
    echo "    \"Medicine won't wait. Neither will I.\""
    echo

    printf '%s%s%s\n' "$BOLD$CYAN" "════════════════════════════════════════════════════════════════════" "$RESET"
    printf '  %sAS/400-style record  •  Ultima virtues  •  clean ledger%s\n' "$GRAY" "$RESET"
}

# === Main Navigation Loop (AS/400 push/pop screen style + full terminal canvas) ===

# Bootstrap check
if ! db_check; then
    echo "Run ./bootstrap.sh first."
    exit 1
fi

# Ensure schema + seed (idempotent)
./scripts/apply_migrations.sh >/dev/null 2>&1 || true

# Ensure Sera agency keys exist
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_trust_level\", \"35\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"35\");"
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_bond_level\", \"25\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"25\");"
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_joint_experiences\", \"0\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"0\");"
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_leadership_moments\", \"0\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"0\");"
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_last_action\", \"\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"\");"
db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_recent_event\", \"\") ON DUPLICATE KEY UPDATE value=COALESCE(value, \"\");"

# Initial push of main screen
SCREEN_STACK=("main")

while true; do
    _screen=$(current_screen)
    render_${_screen}

    read -r -p "> " choice

    case "$_screen" in
        main)
            case "$choice" in
                1|medicine)
                    db_exec "UPDATE characters SET location = 'Sera''s Medicine Room' WHERE is_player = TRUE;"
                    db_exec "UPDATE world_state SET value = 'Arrived at medicine room to inventory the recovered crate.' WHERE state_key = 'last_major_event';"
                    log_narrative "Meyiu chose to follow Sera to the medicine room."
                    sera_record_joint_experience
                    sera_exercise_agency "follow medicine room action"
                    read -r -p "Press enter to continue in the medicine room..."
                    ;;
                2|inventory)
                    push_screen "inventory"
                    ;;
                3|talk)
                    echo
                    sera_says "You bought practical gear instead of shiny magic. That counts for something."
                    sera_says "Do not wave the buckler around like a dinner plate. Keep it between your ribs and the thing trying to open them."
                    # Pure talk - small effect unless it follows real action
                    sera_exercise_agency "talk"
                    read -r -p "Press enter..."
                    ;;
                4|inn)
                    echo
                    echo "You consider the inn, but Sera gives you a look."
                    sera_says "Later. We have work."
                    read -r -p "Press enter..."
                    ;;
                5|sheriff)
                    echo
                    sera_says "Sheriff Marn can wait five minutes. The medicine won't."
                    sera_record_joint_experience
                    # Demo Sera agency with lead for testing
                    sera_exercise_agency "defend the village with measured plan"
                    read -r -p "Press enter..."
                    ;;
                6|buckler)
                    echo
                    printf '%sAsh-Wood Buckler%s\n' "$BOLD" "$RESET"
                    echo "  Passive Guard: reduce first physical hit by 1 (once/round)"
                    echo "  Breathguard: once per battle, reduce one hit by 3 + gain +1 Focus"
                    echo
                    echo "It still smells faintly of the forge and the road."
                    sera_record_joint_experience
                    read -r -p "Press enter..."
                    ;;
                7|world|map|maps)
                    push_screen "world_map"
                    ;;
                8|local|look|here|surroundings)
                    push_screen "local_map"
                    ;;
                9|sheet|sheets|char|chars|persona|personas)
                    push_screen "character_sheets"
                    # Reviewing sheets together counts as a small joint action
                    sera_record_joint_experience
                    ;;
                0|q|quit|exit|x)
                    echo "Save point preserved in the database."
                    echo "Meyiu remains at the forge for now."
                    exit 0
                    ;;
                f3|back|pop)
                    # no-op on main
                    ;;
                *)
                    echo "Unrecognized. Try 1-9 or 0."
                    read -r -p "Press enter..."
                    ;;
            esac
            ;;
        world_map|local_map|character_sheets|inventory)
            # Any reasonable input pops back (AS/400 "view then F3/exit")
            pop_screen
            ;;
        *)
            pop_screen
            ;;
    esac
done
