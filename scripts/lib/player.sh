# scripts/lib/player.sh — Player state, status display, equipment

load_player() {
    local row _old_ifs
    row=$(db_query_row "SELECT name, title, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, location_key FROM characters WHERE is_player = TRUE LIMIT 1;")
    _old_ifs="$IFS"
    IFS=$'\t'
    read -r PLAYER_NAME PLAYER_TITLE CUR_HP MAX_HP COINS ROAD_XP ROAD_XP_MAX LOCATION LOCATION_KEY <<< "$row" || true
    IFS="$_old_ifs"
    if [[ "${LOCATION_KEY}" == "NULL" || -z "${LOCATION_KEY}" ]]; then
        LOCATION_KEY="forge"
    fi
    LOCATION=$(ui_unescape_sql "${LOCATION}")
}

load_sera() {
    local row _old_ifs
    row=$(db_query_row "SELECT current_hp, max_hp, notes FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;")
    _old_ifs="$IFS"
    IFS=$'\t'
    read -r SERA_HP SERA_MAX SERA_NOTES <<< "$row" || true
    IFS="$_old_ifs"
}

load_world() {
    THREAT=$(db_query "SELECT value FROM world_state WHERE state_key='black_bridge_gang_status';")
    CHAPTER=$(db_query "SELECT value FROM world_state WHERE state_key='current_chapter';")
}

heal_player() {
    local cur_hp max_hp heal_amount new_hp player_name companion_name
    player_name=$(party_player_name 2>/dev/null || echo "Pilgrim")
    companion_name=$(party_companion_short 2>/dev/null || echo "Guide")
    cur_hp=$(db_query "SELECT current_hp FROM characters WHERE is_player=TRUE LIMIT 1;")
    max_hp=$(db_query "SELECT max_hp FROM characters WHERE is_player=TRUE LIMIT 1;")
    if [[ $cur_hp -lt $max_hp ]]; then
        heal_amount=$(( max_hp - cur_hp ))
        [[ $heal_amount -lt 1 ]] && heal_amount=1
        new_hp=$max_hp
        db_exec "UPDATE characters SET current_hp=$new_hp WHERE is_player=TRUE;"
        echo -e "${GREEN}${companion_name} tends to your wounds with skill and care, fully restoring you to ${new_hp} HP.${RESET}"
        log_narrative "${companion_name} healed ${player_name} for ${heal_amount} HP in the medicine room."
    else
        echo -e "${GREEN}${companion_name} checks you over — you're already in good shape.${RESET}"
    fi
}

get_equipment_modifiers() {
    local spell_bonus=0 phys_bonus=0
    while IFS=$'\t' read -r item_key effect tags; do
        if [[ "$tags" == *"focus"* || "$item_key" == *"staff"* || "$item_key" == *"crystal"* ]]; then
            spell_bonus=$(( spell_bonus + 1 ))
        fi
        if [[ "$tags" == *"weapon"* ]]; then
            phys_bonus=$(( phys_bonus + 1 ))
        fi
    done < <(echo "SELECT item_key, effect, tags FROM inventory i JOIN characters c ON i.character_id = c.id WHERE c.is_player=TRUE AND equipped=TRUE;" | $MARIADB --silent --skip-column-names)
    echo "spell_bonus=$spell_bonus phys_bonus=$phys_bonus"
}

get_player_abilities() {
    echo "SELECT ability_key, ability_name, description, uses_remaining, proficiency
          FROM character_abilities a JOIN characters c ON a.character_id = c.id
          WHERE c.is_player=TRUE ORDER BY proficiency DESC, ability_name;" | $MARIADB --silent --skip-column-names
}

show_status() {
    load_player
    load_sera
    load_world
    load_sera_state

    # Location shown in operator WHERE YOU ARE panel on main screen
    printf "  ${GREEN}Grid${RESET}     : %s (${LOCATION_KEY:-?})\n" "$(ui_unescape_sql "${LOCATION}")"
    printf "  ${GREEN}HP${RESET}       : ${BRIGHT_GREEN}%d${RESET} / %d\n" "$CUR_HP" "$MAX_HP"
    printf "  ${GREEN}Coins${RESET}    : %d silver\n" "$COINS"
    printf "  ${GREEN}Road XP${RESET}  : %d / %d" "$ROAD_XP" "$ROAD_XP_MAX"
    local plvl pending
    plvl=$(db_query "SELECT prog_level FROM characters WHERE is_player=TRUE LIMIT 1;")
    pending=$(db_query "SELECT breakthrough_pending FROM characters WHERE is_player=TRUE LIMIT 1;")
    printf "  ${DIM}│ Lv%s" "${plvl:-1}"
    [[ "${pending:-0}" -eq 1 ]] && printf " ${AMBER}◆ BREAKTHROUGH READY${RESET}"
    echo
    echo
    local comp_display
    comp_display=$(party_companion_name 2>/dev/null || echo "Companion")
    printf '  %s%s%s  (HP %d/%d)  —  %s%s...%s\n' \
        "$AMBER" "$comp_display" "$RESET" "$SERA_HP" "$SERA_MAX" "$GRAY" "${SERA_NOTES:0:70}" "$RESET"
    if declare -f prog_show_sera_progress >/dev/null 2>&1; then
        prog_show_sera_progress
    fi
    echo

    local joint=${SERA_JOINT:-0} lead=${SERA_LEAD:-0}
    local t b t_bar b_bar
    t=$(sera_clamp_meter "${SERA_TRUST:-35}")
    b=$(sera_clamp_meter "${SERA_BOND:-25}")
    t_bar=$(sera_meter_bar "$t")
    b_bar=$(sera_meter_bar "$b")

    printf '  %sConnection with %s%s  (earned through shared action — not menu grinding)\n' \
        "$GREEN" "$(party_companion_short 2>/dev/null || echo Guide)" "$RESET"
    printf '    Trust  %3d/100  %s%s%s   Bond  %3d/100  %s%s%s\n' \
        "$t" "$DIM" "$t_bar" "$RESET" "$b" "$DIM" "$b_bar" "$RESET"
    printf '    Shared moments: %s   |   Times Sera led: %s\n' "$joint" "$lead"
    echo

    local bond_label=""
    if [[ $b -ge 80 ]]; then bond_label="Very close — she trusts you deeply"
    elif [[ $b -ge 60 ]]; then bond_label="Strong bond — she's choosing this road"
    elif [[ $b -ge 40 ]]; then bond_label="Growing — she's starting to believe in you"
    elif [[ $b -ge 25 ]]; then bond_label="Provisional — still deciding"
    else bond_label="Fragile — easy to lose"
    fi
    printf '  %sHer stance:%s %s\n' "$AMBER" "$RESET" "$bond_label"

    if [[ $b -ge 55 && $t -ge 50 ]]; then
        printf '  %sShe has chosen to walk this road with you.%s\n' "$AMBER" "$RESET"
    elif [[ $b -ge 30 ]]; then
        printf '  %sShe is still choosing whether to fully tie her fate to yours.%s\n' "$DIM" "$RESET"
    fi
    echo
    printf '%sChapter: %s%s\n' "$DIM" "$CHAPTER" "$RESET"
    printf '%sThreat : %s%s\n' "$DIM" "$THREAT" "$RESET"
    local mill food prep
    mill=$(ws_get "mill_status")
    food=$(ws_get "brindleford_food_supply")
    prep=$(ws_get "brindleford_preparedness")
    if [[ -n "$mill" || -n "$food" ]]; then
        printf '%sVillage%s  Mill: %s  |  Food: %s  |  Readiness: %s\n' \
            "$DIM" "$RESET" "${mill:-?}" "${food:-?}" "${prep:-?}"
    fi
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