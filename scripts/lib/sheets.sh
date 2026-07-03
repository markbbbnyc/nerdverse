# sheets.sh — sourced by play.sh

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
    echo "SELECT CONCAT(\"    • \", ability_name, \" (Prof \", COALESCE(proficiency,0), \")  \", LEFT(description,30))
          FROM character_abilities a JOIN characters c ON a.character_id=c.id
          WHERE c.name=\"Meyiu\" ORDER BY proficiency DESC, ability_name;" | $MARIADB --silent --skip-column-names
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
