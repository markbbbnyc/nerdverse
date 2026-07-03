# scripts/lib/handoff.sh — LLM session handoff (written on quit)

HANDOFF_FILE="${NERDVERSE_HANDOFF_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/saves/session_handoff.md}"

handoff_write() {
    travel_normalize_character_locations
    travel_load_current
    load_player
    load_sera_state
    load_world

    local outfile="$HANDOFF_FILE"
    mkdir -p "$(dirname "$outfile")"

    local mill_status bridge_intel preparedness food last_evt chapter threat
    mill_status=$(db_query "SELECT value FROM world_state WHERE state_key='mill_status';")
    bridge_intel=$(db_query "SELECT value FROM world_state WHERE state_key='bridge_intel';")
    preparedness=$(db_query "SELECT value FROM world_state WHERE state_key='brindleford_preparedness';")
    food=$(db_query "SELECT value FROM world_state WHERE state_key='brindleford_food_supply';")
    last_evt=$(db_query "SELECT value FROM world_state WHERE state_key='last_major_event';")
    chapter="${CHAPTER:-}"
    threat="${THREAT:-}"

    local trust bond joint lead
    trust=$(sera_clamp_meter "${SERA_TRUST:-35}")
    bond=$(sera_clamp_meter "${SERA_BOND:-25}")
    joint=${SERA_JOINT:-0}
    lead=${SERA_LEAD:-0}

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo "# Nerdverse Session Handoff"
        echo ""
        echo "Generated: ${ts}"
        echo "Database: \`${DB_NAME}\` ($(game_db_label "$DB_NAME"))"
        echo ""
        echo "> Paste this file (or its contents) into Grok at the start of a play/build session."
        echo "> The database is still the authoritative save — this is the human/LLM briefing."
        echo ""
        echo "---"
        echo ""
        echo "## Resume Prompt (copy to Grok)"
        echo ""
        echo '```'
        echo "Continue Nerdverse. Meyiu — The Sinner Who Still Chooses."
        echo "DB: ${DB_NAME}. Location: ${LOCATION} (${LOCATION_KEY})."
        echo "HP ${CUR_HP}/${MAX_HP} | Coins ${COINS} | Road XP ${ROAD_XP}/${ROAD_XP_MAX}"
        echo "Sera: Trust ${trust}/100, Bond ${bond}/100 | Shared ${joint} | She led ${lead}"
        echo "Chapter: ${chapter}"
        echo "Threat: ${threat}"
        echo "Last event: ${last_evt}"
        echo "Mill: ${mill_status:-unexamined} | Food: ${food:-at_risk} | Preparedness: ${preparedness:-Low}"
        [[ -n "$bridge_intel" ]] && echo "Bridge intel: ${bridge_intel}"
        echo ""
        echo "DM MODE: Chat-room banter play. React as Sera in-scene; unfold her arc beside Meyiu."
        echo "Player must be IN THE ROOM for Sera milestones — celebrate, grieve, quiet presence."
        echo "Progression: practice tags + rare breakthrough levels (2-3 combat actives max)."
        echo "Run ./play.sh on the machine to apply mechanical updates after narrative choices."
        echo '```'
        echo ""
        echo "## Meyiu (player character)"
        echo ""
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| Location | ${LOCATION} (\`${LOCATION_KEY}\`) |"
        echo "| HP | ${CUR_HP} / ${MAX_HP} |"
        echo "| Coins | ${COINS} silver |"
        echo "| Road XP | ${ROAD_XP} / ${ROAD_XP_MAX} |"
        local plvl spend
        plvl=$(db_query "SELECT prog_level FROM characters WHERE is_player=TRUE LIMIT 1;")
        spend=$(db_query "SELECT breakthrough_pending FROM characters WHERE is_player=TRUE LIMIT 1;")
        echo "| Level | ${plvl:-1} |"
        [[ "${spend:-0}" -eq 1 ]] && echo "| Breakthrough | READY (run ./play.sh) |"
        echo ""
        echo "## Sera Thornwake (LLM-played companion)"
        echo ""
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| Trust | ${trust}/100 |"
        echo "| Bond | ${bond}/100 |"
        echo "| Shared moments | ${joint} |"
        echo "| Leadership moments | ${lead} |"
        echo "| Mood | ${SERA_MOOD:-(unset)} |"
        echo ""
        echo "## World flags"
        echo ""
        echo "- **Chapter:** ${chapter}"
        echo "- **Threat:** ${threat}"
        echo "- **Last major event:** ${last_evt}"
        echo "- **Mill status:** ${mill_status:-unexamined}"
        echo "- **Food supply:** ${food:-at_risk}"
        echo "- **Village preparedness:** ${preparedness:-Low}"
        [[ -n "$bridge_intel" ]] && echo "- **Bridge intel:** ${bridge_intel}"
        echo ""
        echo "## Open threads (suggested)"
        echo ""
        local pike hunt
        pike=$(ws_get "pike_hunt_status" 2>/dev/null || echo "")
        [[ -n "$pike" && "$pike" != "NULL" ]] && echo "- **Pike hunt:** ${pike} (see council_decision, garran_pike_status)"
        echo "- Medicine crate inventory (if not fully resolved)"
        echo "- Depart the vale after Pike — Meyiu/Sera road continues east"
        echo "- Combo fusion / equipment UI (engine milestones)"
        echo ""
        echo "## Recent session log (newest first)"
        echo ""
        echo '```'
        echo "SELECT CONCAT(log_time, ' [', log_type, '] ', entry) FROM session_log ORDER BY id DESC LIMIT 12;" \
            | $MARIADB --silent --skip-column-names 2>/dev/null || echo "(no log entries)"
        echo '```'
        echo ""
        echo "## After the LLM session"
        echo ""
        echo "Mechanical changes made in narrative should be mirrored when possible via \`./play.sh\`"
        echo "or direct DB updates. Re-run \`./play.sh\` to refresh backups and handoff on next quit."
        echo ""
    } > "$outfile"

    echo "$outfile"
}