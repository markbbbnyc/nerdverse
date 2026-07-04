# sheets.sh — sourced by play.sh

show_character_sheets() {
    local player_name companion_name player_id companion_id
    player_name=$(party_player_name 2>/dev/null || echo "Pilgrim")
    companion_name=$(party_companion_name 2>/dev/null || echo "Guide Walker")
    player_id=$(party_player_id 2>/dev/null || echo "0")
    companion_id=$(party_companion_id 2>/dev/null || echo "0")

    local m_hp m_max m_coins m_xp m_xpmax m_loc m_title m_class row
    row=$(db_query_row "SELECT current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, title, class FROM characters WHERE is_player=TRUE LIMIT 1;")
    IFS=$'\t' read -r m_hp m_max m_coins m_xp m_xpmax m_loc m_title m_class <<< "$row"

    printf '%s%s%s  —  %s\n' "$BOLD" "$player_name" "$RESET" "$m_title"
    echo "────────────────────────────────────────────────────────────────────"
    printf "  NAME      : %-20s   CLASS  : %s\n" "$player_name" "${m_class:-Mage}"
    printf "  LOCATION  : %-20s   HP     : %d / %d\n" "$m_loc" "$m_hp" "$m_max"
    printf "  ROAD XP   : %d / %-3d                COINS  : %d silver\n" "$m_xp" "$m_xpmax" "$m_coins"
    echo
    echo "  EQUIPPED GEAR"
    echo "SELECT CONCAT(\"    \", item_name, \"  \", LEFT(COALESCE(effect,\"\"),48))
          FROM inventory i JOIN characters c ON i.character_id = c.id
          WHERE c.is_player=TRUE AND equipped=TRUE ORDER BY item_name;" | $MARIADB --silent --skip-column-names
    echo
    echo "  KNOWN TECHNIQUES"
    echo "SELECT CONCAT(\"    • \", ability_name, \" (Prof \", COALESCE(proficiency,0), \")  \", LEFT(description,30))
          FROM character_abilities a JOIN characters c ON a.character_id=c.id
          WHERE c.is_player=TRUE ORDER BY proficiency DESC, ability_name;" | $MARIADB --silent --skip-column-names
    echo
    echo "  CARRIED (selected)"
    echo "SELECT CONCAT(\"    • \", item_name)
          FROM inventory i JOIN characters c ON i.character_id = c.id
          WHERE c.is_player=TRUE AND equipped=FALSE ORDER BY item_name LIMIT 12;" | $MARIADB --silent --skip-column-names
    echo

    printf '%s%s%s\n' "$BOLD$YELLOW" "────────────────────────────────────────────────────────────────────" "$RESET"
    echo

    local s_hp s_max s_notes s_lvl s_rxp s_rxmax s_bk s_title s_class
    row=$(db_query_row "SELECT current_hp, max_hp, notes, prog_level, road_xp, road_xp_max, breakthrough_pending, title, class FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;")
    _old_ifs="$IFS"
    IFS=$'\t'
    read -r s_hp s_max s_notes s_lvl s_rxp s_rxmax s_bk s_title s_class <<< "$row" || true
    IFS="$_old_ifs"

    printf '%s%s%s\n' "$BOLD" "$companion_name" "$RESET"
    echo "────────────────────────────────────────────────────────────────────"
    printf "  TITLE     : %s\n" "${s_title:-Companion}"
    printf "  CLASS     : %-30s HP : %d / %d\n" "${s_class:-Healer-Archer}" "$s_hp" "$s_max"
    printf "  ROAD XP   : %d / %-3d                LEVEL : %s" "${s_rxp:-0}" "${s_rxmax:-10}" "${s_lvl:-1}"
    [[ "${s_bk:-0}" -eq 1 ]] && printf "  ◆ BREAKTHROUGH READY"
    echo
    if declare -f load_sera_state >/dev/null 2>&1; then
        load_sera_state 2>/dev/null || true
    fi
    local trust bond
    trust=$(sera_clamp_meter "${SERA_TRUST:-20}" 2>/dev/null || echo "20")
    bond=$(sera_clamp_meter "${SERA_BOND:-15}" 2>/dev/null || echo "15")
    echo
    echo "  CONNECTION (companion meters)"
    printf "  TRUST     : %3d/100  — belief in your choices on the road\n" "$trust"
    printf "  BOND      : %3d/100  — closeness grown by shared moments\n" "$bond"
    echo
    echo "  COMBAT TECHNIQUES (active slots)"
    echo "SELECT CONCAT(\"    • \", ability_name, \" (Prof \", COALESCE(proficiency,0), \")  \", LEFT(description,36))
          FROM character_abilities a JOIN characters c ON a.character_id=c.id
          WHERE c.is_player=FALSE AND a.combat_active=1 ORDER BY a.combat_slot;" | $MARIADB --silent --skip-column-names
    echo
    echo "  UNLOCKS (components / passives / combos)"
    echo "SELECT CONCAT(\"    • \", display_name, \" [\", unlock_type, \"]\")
          FROM character_unlocks u JOIN characters c ON u.character_id=c.id
          WHERE c.is_player=FALSE ORDER BY unlocked_at;" | $MARIADB --silent --skip-column-names
    echo
    echo "  PRACTICE (muscle memory)"
    echo "SELECT CONCAT(\"    • \", practice_key, \": \", points)
          FROM character_practice p JOIN characters c ON p.character_id=c.id
          WHERE c.is_player=FALSE ORDER BY points DESC;" | $MARIADB --silent --skip-column-names
    echo
    echo "  NOTES"
    printf "    \"%s\"\n" "${s_notes:0:60}"
    echo

    printf '%s%s%s\n' "$BOLD$CYAN" "════════════════════════════════════════════════════════════════════" "$RESET"
    printf '  %sAS/400-style record  •  live party data from this session DB%s\n' "$GRAY" "$RESET"
}