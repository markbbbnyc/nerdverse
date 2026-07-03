# scripts/lib/travel.sh — Movement via locations table (connected_to graph)

LOCATION_KEY="${LOCATION_KEY:-forge}"

# Infer location_key from legacy display name when column is empty.
travel_infer_key_from_display() {
    local loc="$1"
    case "$loc" in
        *"Medicine"*|*"medicine"*) echo "medicine" ;;
        *"Inn"*|*"inn"*|*"Hearthmouse"*) echo "inn" ;;
        *"Sheriff"*|*"sheriff"*) echo "sheriff" ;;
        *"Mill"*|*"mill"*) echo "mill" ;;
        *"Bridge"*|*"bridge"*) echo "bridge" ;;
        *"Forge"*|*"forge"*|*"Brenn"*) echo "forge" ;;
        *) echo "forge" ;;
    esac
}

# Backfill location_key on older saves; sync display_name from catalog.
travel_normalize_character_locations() {
    local row key display
    row=$(db_query_row "SELECT location, location_key FROM characters WHERE is_player = TRUE LIMIT 1;")
    IFS=$'\t' read -r _loc _key <<< "$row"

    if [[ -z "${_key}" || "${_key}" == "NULL" ]]; then
        key=$(travel_infer_key_from_display "${_loc}")
        display=$(db_query "SELECT display_name FROM locations WHERE key_name='${key}' LIMIT 1;")
        [[ -z "$display" ]] && display="${_loc:-Brindleford Forge}"
        display=$(ui_unescape_sql "$display")
        db_exec "UPDATE characters SET location_key='${key}', location='${display//\'/\'\'}' WHERE is_player = TRUE;"
        db_exec "UPDATE characters SET location_key='${key}', location='${display//\'/\'\'}' WHERE name='Sera Thornwake';"
    else
        display=$(ui_unescape_sql "${_loc}")
        if [[ "$display" != "${_loc}" ]]; then
            db_exec "UPDATE characters SET location='${display//\'/\'\'}' WHERE is_player = TRUE;"
            db_exec "UPDATE characters SET location='${display//\'/\'\'}' WHERE name='Sera Thornwake';"
        fi
    fi
}

travel_load_current() {
    local row _old_ifs
    row=$(db_query_row "SELECT location_key, location FROM characters WHERE is_player = TRUE LIMIT 1;")
    _old_ifs="$IFS"
    IFS=$'\t'
    read -r LOCATION_KEY LOCATION <<< "$row" || true
    IFS="$_old_ifs"
    LOCATION_KEY="${LOCATION_KEY:-forge}"
    LOCATION=$(ui_unescape_sql "${LOCATION:-}")
}

travel_location_display() {
    local key="${1:-$LOCATION_KEY}"
    db_query "SELECT display_name FROM locations WHERE key_name='${key}' LIMIT 1;"
}

travel_location_description() {
    local key="${1:-$LOCATION_KEY}"
    db_query "SELECT description FROM locations WHERE key_name='${key}' LIMIT 1;"
}

# Space-separated list of connected keys (parsed from comma list in DB).
travel_get_exits() {
    local key="${1:-$LOCATION_KEY}"
    local raw
    raw=$(db_query "SELECT connected_to FROM locations WHERE key_name='${key}' LIMIT 1;")
    if [[ -z "$raw" ]]; then
        return 0
    fi
    echo "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true
}

travel_can_reach() {
    local dest="$1"
    local from="${2:-$LOCATION_KEY}"
    local exit
    while IFS= read -r exit; do
        [[ "$exit" == "$dest" ]] && return 0
    done < <(travel_get_exits "$from")
    return 1
}

travel_to() {
    local dest_key="$1"
    if ! travel_can_reach "$dest_key"; then
        echo "You cannot reach that place directly from here."
        return 1
    fi

    local display danger
    display=$(travel_location_display "$dest_key")
    danger=$(db_query "SELECT danger_level FROM locations WHERE key_name='${dest_key}' LIMIT 1;")

    local esc_display
    esc_display=$(printf '%s' "$display" | sed "s/'/''/g")

    db_exec "UPDATE characters SET location_key='${dest_key}', location='${esc_display}' WHERE is_player = TRUE;"
    db_exec "UPDATE characters SET location_key='${dest_key}', location='${esc_display}' WHERE name='Sera Thornwake';"
    db_exec "UPDATE locations SET visited = TRUE WHERE key_name = '${dest_key}';"

    travel_load_current
    LOCATION="$display"
    log_narrative "Meyiu and Sera walked to ${display}."

    if [[ "${danger:-0}" -ge 4 ]]; then
        echo
        printf '%s%s%s\n' "$RED" "The air here feels wrong. This road may cost more than miles." "$RESET"
    fi

    if [[ "$dest_key" == "bridge" ]] && declare -f scenario_bridge_on_arrival >/dev/null 2>&1; then
        scenario_bridge_on_arrival
    fi
    return 0
}

# Print numbered travel menu; sets TRAVEL_EXIT_KEYS array.
declare -a TRAVEL_EXIT_KEYS=()

travel_build_exit_menu() {
    TRAVEL_EXIT_KEYS=()
    local key display visited danger label i=1
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        display=$(travel_location_display "$key")
        visited=$(db_query "SELECT visited FROM locations WHERE key_name='${key}' LIMIT 1;")
        danger=$(db_query "SELECT danger_level FROM locations WHERE key_name='${key}' LIMIT 1;")
        label=""
        [[ "$visited" != "1" && "$visited" != "TRUE" ]] && label="${DIM}(unvisited)${RESET} "
        [[ "${danger:-0}" -ge 3 ]] && label="${label}${RED}⚠${RESET} "
        TRAVEL_EXIT_KEYS[$i]="$key"
        printf '  %s[%d]%s Walk to %s%s%s\n' "$GREEN" "$i" "$RESET" "$label" "$display" "$RESET"
        ((i++))
    done < <(travel_get_exits)
}

# Ledger-formatted exits for the route matrix screen
travel_build_exit_menu_ledger() {
    TRAVEL_EXIT_KEYS=()
    local key display visited danger label i=1
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        display=$(travel_location_display "$key")
        visited=$(db_query "SELECT visited FROM locations WHERE key_name='${key}' LIMIT 1;")
        danger=$(db_query "SELECT danger_level FROM locations WHERE key_name='${key}' LIMIT 1;")
        label="${display}"
        [[ "$visited" != "1" && "$visited" != "TRUE" ]] && label="${label} (unvisited)"
        [[ "${danger:-0}" -ge 3 ]] && label="${label} [THREAT]"
        TRAVEL_EXIT_KEYS[$i]="$key"
        if declare -f draw_ledger_option >/dev/null 2>&1; then
            draw_ledger_option "$i" "Route → ${label}" "${i}"
        else
            printf '  [%d] %s\n' "$i" "$label"
        fi
        ((i++))
    done < <(travel_get_exits)
}

travel_resolve_choice() {
    local choice="$1"
    local key="${TRAVEL_EXIT_KEYS[$choice]:-}"
    [[ -n "$key" ]] && echo "$key"
}

# Human label for the location-specific action on the main screen.
travel_local_action_label() {
    case "${LOCATION_KEY}" in
        medicine) echo "Work with Sera — heal & inventory the crate" ;;
        sheriff)  echo "Speak with Sheriff Marn about village defense" ;;
        inn)      echo "Take a meal and listen for rumors" ;;
        forge)    echo "Examine the Ash-Wood Buckler" ;;
        mill)     echo "Investigate the slow mill wheel" ;;
        bridge)   echo "Scout the tollhouse from a distance" ;;
        *)        echo "Look around and take stock" ;;
    esac
}