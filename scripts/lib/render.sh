# render.sh — Screen renderers (operator console presentation)

render_location_flavor() {
    case "${LOCATION_KEY}" in
        medicine)
            sera_says "Here we are. The crate is still sealed. Let's see what's inside and what we can use."
            ;;
        sheriff)
            sera_says "Sheriff Marn looks tired. The village needs a plan, not a speech."
            ;;
        inn)
            sera_says "Food and a roof would be good later. Right now the road is still asking things of us."
            ;;
        mill)
            sera_says "That wheel turns too slow. Something's wrong here — rot, sabotage, or worse."
            ;;
        bridge)
            sera_says "That's gang country. We don't stroll in unless we're ready to pay a real price."
            ;;
        *)
            show_ascii_forge
            sera_says "Medicine room next. Unless you plan to treat stab wounds with personal growth."
            ;;
    esac
}

render_main() {
    clear_screen
    travel_load_current
    load_sera_state 2>/dev/null || true

    local cols bond
    cols=$(get_cols)
    bond=$(sera_clamp_meter "${SERA_BOND:-25}" 2>/dev/null || echo "25")

    draw_operator_banner "main"

    if ui_use_compact; then
        echo
        draw_main_hud_compact "$bond"
        echo
        case "${LOCATION_KEY}" in
            medicine) printf '  %sSera:%s "%s"\n' "$YELLOW" "$RESET" "Crate's still ours. So is the night — for now." ;;
            sheriff)  printf '  %sSera:%s "%s"\n' "$YELLOW" "$RESET" "Marn needs a plan. We brought him one." ;;
            mill)     printf '  %sSera:%s "%s"\n' "$YELLOW" "$RESET" "Wheel's turning. So are we." ;;
            *)        printf '  %sSera:%s "%s"\n' "$YELLOW" "$RESET" "Pick the next honest move." ;;
        esac
        echo
        printf '%s┌─ COMMAND LEDGER ─────────────────────────────────────────────────┐%s\n' "$GREEN" "$RESET"
        draw_ledger_option 1 "Travel (route matrix)" "1|F1"
        draw_ledger_option 2 "Inventory manifest" "2|F2"
        draw_ledger_option 3 "Open channel — Sera" "3"
        draw_ledger_option 4 "$(travel_local_action_label)" "4|F4"
        draw_ledger_option 7 "World map" "7|F7"
        draw_ledger_option 8 "Local grid" "8|F8"
        draw_ledger_option 9 "Persona records" "9|F9"
        draw_ledger_option 0 "Sign off + handoff" "0|F12"
        printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$GREEN" "$RESET"
        draw_footer
        echo
        printf '  %s>%s Option / PF-key: ' "$BRIGHT_GREEN" "$RESET"
        RENDER_PROMPT_SHOWN=1
        return
    fi

    echo
    center_line "${BOLD}TACTICAL PERSONA OPS${RESET}  ${DIM}│ inventory became story │${RESET}" "$cols"
    echo

    draw_screen_header "${ICON_CHAR}OPERATOR: MEYIU — THE SINNER WHO STILL CHOOSES"

    draw_location_panel
    draw_world_clock_line
    draw_sera_operator_glyph "$bond"
    echo

    show_status
    echo
    render_location_flavor
    echo

    if declare -f prog_rank_context_actions >/dev/null 2>&1; then
        printf '%s┌─ PROMINENT ACTIONS HERE (ranked for your build) ──────────────────┐%s\n' "$CYAN" "$RESET"
        prog_rank_context_actions 3
        printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$CYAN" "$RESET"
        echo
    fi

    printf '%s┌─ COMMAND LEDGER ── SELECT FUNCTION ─────────────────────────────────┐%s\n' "$GREEN" "$RESET"
    draw_ledger_option 1 "Walk to another place (route matrix)" "1|F1"
    draw_ledger_option 2 "Inventory manifest — equipped + carried" "2|F2"
    draw_ledger_option 3 "Open channel — Sera Thornwake" "3"
    draw_ledger_option 4 "$(travel_local_action_label)" "4|F4"
    draw_ledger_option 7 "Unfold world map (known lands)" "7|F7"
    draw_ledger_option 8 "Local terrain study (this grid)" "8|F8"
    draw_ledger_option 9 "Persona records — Meyiu / Sera" "9|F9"
    draw_ledger_option 0 "Sign off — preserve save + LLM handoff" "0|F12"
    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$GREEN" "$RESET"
    draw_footer
    echo
    printf '  %s>%s Option / PF-key: ' "$BRIGHT_GREEN" "$RESET"

    RENDER_PROMPT_SHOWN=1
}

render_travel() {
    clear_screen
    travel_load_current

    draw_operator_banner "travel"
    echo
    draw_screen_header "${ICON_MAP}ROUTE MATRIX — DEPARTURE: ${LOCATION:-HERE}"

    local desc
    desc=$(travel_location_description)
    [[ -n "$desc" ]] && printf '  %s%s%s\n\n' "$GRAY" "$desc" "$RESET"

    printf '%s┌─ OPEN ROUTES (locations.connected_to) ───────────────────────────┐%s\n' "$GREEN" "$RESET"
    travel_build_exit_menu_ledger

    if [[ ${#TRAVEL_EXIT_KEYS[@]} -eq 0 ]]; then
        printf '  %s(no edges in route matrix from this node)%s\n' "$DIM" "$RESET"
    fi
    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$GREEN" "$RESET"
    echo
    draw_ledger_option 0 "Remain at current grid coordinates" "0|F3"
    draw_footer
}

render_world_map() {
    clear_screen
    draw_operator_banner "world_map"
    echo
    draw_screen_header "${ICON_MAP}CARTOGRAPHY — WORLD LAYER"
    show_world_map
    echo
    printf '%s(intel logged to persona memory)%s\n' "$DIM" "$RESET"
    draw_footer
}

render_local_map() {
    clear_screen
    draw_operator_banner "local_map"
    echo
    draw_screen_header "${ICON_MAP}CARTOGRAPHY — LOCAL GRID: ${LOCATION:-}"
    show_local_map
    draw_footer
}

render_character_sheets() {
    clear_screen
    draw_operator_banner "character_sheets"
    echo
    draw_screen_header "${ICON_SCROLL}PERSONA RECORDS — CLASSIFIED PILGRIM"
    show_character_sheets
    draw_footer
}

render_inventory() {
    clear_screen
    draw_operator_banner "inventory"
    echo
    draw_screen_header "${ICON_CHAR}INVENTORY MANIFEST — MEYIU"
    echo
    printf '%s%s%s\n' "$DIM" "LINE ITEMS (equipped first, slot-aware):" "$RESET"
    echo "SELECT CONCAT('  ', COALESCE(CONCAT('[', slot, '] '), ''), item_name, ' (x', quantity, ')') FROM inventory WHERE character_id = (SELECT id FROM characters WHERE is_player=TRUE) ORDER BY equipped DESC, slot, item_name;" | $MARIADB
    echo
    printf '%s%s%s\n' "$GRAY" "Arsenal discipline applies. Every item is a promise." "$RESET"
    draw_footer
}