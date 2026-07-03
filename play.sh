#!/usr/bin/env bash
# play.sh - Nerdverse main loop (Phase 0)
# Pure bash + MariaDB. Minimal but real.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source scripts/db.sh

# Colors (portable enough)
if [[ -t 1 ]]; then
    BOLD="\033[1m"; RESET="\033[0m"
    GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; RED="\033[31m"; GRAY="\033[90m"
else
    BOLD=""; RESET=""; GREEN=""; YELLOW=""; CYAN=""; RED=""; GRAY=""
fi

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

    echo
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  MEYIU  —  THE SINNER WHO STILL CHOOSES${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    printf "  Location : %s\n" "${LOCATION}"
    printf "  HP       : ${GREEN}%d${RESET} / %d\n" "$CUR_HP" "$MAX_HP"
    printf "  Coins    : %d silver\n" "$COINS"
    printf "  Road XP  : %d / %d\n" "$ROAD_XP" "$ROAD_XP_MAX"
    echo
    echo -e "  ${YELLOW}Sera Thornwake${RESET}  (HP ${SERA_HP}/${SERA_MAX})  —  ${GRAY}${SERA_NOTES:0:70}...${RESET}"
    echo
    echo -e "${GRAY}Chapter: ${CHAPTER}${RESET}"
    echo -e "${GRAY}Threat : ${THREAT}${RESET}"
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
    echo "INSERT INTO session_log (log_type, entry, location, character_name)
          VALUES ('NARRATIVE', '${entry//\'/\'\'}', '${LOCATION:-Brindleford}', 'Sera');" | $MARIADB >/dev/null
}

sera_says() {
    local line="$1"
    echo -e "${YELLOW}Sera:${RESET} \"${line}\""
    log_narrative "Sera: ${line}"
}

# === Main game loop (very small in Phase 0) ===

echo -e "${BOLD}Nerdverse — Phase 0${RESET}"
echo "Loading state from MariaDB..."

if ! db_check; then
    echo "Run ./bootstrap.sh first."
    exit 1
fi

# Make sure schema + seed are present
./scripts/apply_migrations.sh >/dev/null 2>&1 || true

show_status
show_ascii_forge

echo
sera_says "Medicine room next. Unless you plan to treat stab wounds with personal growth."

echo
echo -e "${BOLD}What does Meyiu do?${RESET}"
echo "  [1] Go to Sera's medicine room (recommended)"
echo "  [2] Check inventory"
echo "  [3] Talk to Sera more"
echo "  [4] Visit the Hearthmouse Inn"
echo "  [5] Return to Sheriff Marn"
echo "  [6] Look at the new Ash-Wood Buckler"
echo "  [0] Quit for now"
echo

read -r -p "> " choice

case "$choice" in
    1|medicine)
        echo
        echo -e "${GREEN}You head toward Sera's medicine room together.${RESET}"
        db_exec "UPDATE characters SET location = 'Sera''s Medicine Room' WHERE is_player = TRUE;"
        db_exec "UPDATE world_state SET value = 'Arrived at medicine room to inventory the recovered crate.' WHERE state_key = 'last_major_event';"
        log_narrative "Meyiu chose to follow Sera to the medicine room."
        show_status
        echo
        sera_says "Good. The crate is still sealed. Let's see what the gang tried to steal from my patients."
        echo
        echo "(Phase 0 is minimal. We will expand commands and world reactions in the next passes.)"
        echo "For now, the state is saved. Run ./play.sh again to continue."
        ;;
    2|inventory)
        echo
        echo -e "${BOLD}Meyiu's Inventory:${RESET}"
        echo "SELECT CONCAT('  - ', item_name, ' (x', quantity, ')') FROM inventory WHERE character_id = (SELECT id FROM characters WHERE is_player=TRUE) ORDER BY equipped DESC, item_name;" | $MARIADB
        echo
        read -r -p "Press enter to continue..."
        ./play.sh   # restart loop for simplicity in phase 0
        ;;
    3|talk)
        echo
        sera_says "You bought practical gear instead of shiny magic. That counts for something."
        sera_says "Do not wave the buckler around like a dinner plate. Keep it between your ribs and the thing trying to open them."
        echo
        read -r -p "Press enter..."
        ./play.sh
        ;;
    4|inn)
        echo
        echo "You consider the inn, but Sera gives you a look."
        sera_says "Later. We have work."
        read -r -p "Press enter..."
        ./play.sh
        ;;
    5|sheriff)
        echo
        sera_says "Sheriff Marn can wait five minutes. The medicine won't."
        read -r -p "Press enter..."
        ./play.sh
        ;;
    6|buckler)
        echo
        echo -e "${BOLD}Ash-Wood Buckler${RESET}"
        echo "  Passive Guard: reduce first physical hit by 1 (once/round)"
        echo "  Breathguard: once per battle, reduce one hit by 3 + gain +1 Focus"
        echo
        echo "It still smells faintly of the forge and the road."
        read -r -p "Press enter..."
        ./play.sh
        ;;
    0|q|quit|exit)
        echo "Save point preserved in the database."
        echo "Meyiu remains at the forge for now."
        exit 0
        ;;
    *)
        echo "Later we will have a better parser. For now..."
        ./play.sh
        ;;
esac
