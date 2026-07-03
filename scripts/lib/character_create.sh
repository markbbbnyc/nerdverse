# scripts/lib/character_create.sh — Simple player + companion setup (public terminal / new lives)

cc_sanitize_name() {
    local raw="$1"
    local fallback="$2"
    raw=$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    raw=$(printf '%s' "$raw" | sed 's/[^A-Za-z0-9 _'\''-]//g')
    if [[ ${#raw} -lt 2 ]]; then
        echo "$fallback"
        return
    fi
    if [[ ${#raw} -gt 24 ]]; then
        raw="${raw:0:24}"
    fi
    printf '%s' "$raw"
}

cc_prompt_line() {
    local prompt="$1"
    local default="$2"
    local val
    printf '%s%s%s' "$GREEN" "$prompt" "$RESET"
    [[ -n "$default" ]] && printf ' %s[%s]%s' "$DIM" "$default" "$RESET"
    printf ': '
    read -r val
    if [[ -z "$val" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

# Interactive wizard → fresh DB + renamed characters. Sets active save in session dir.
character_create_wizard() {
    local companion_raw player_raw companion player title

    clear_screen
    draw_operator_banner "main"
    echo
    draw_screen_header "${ICON_CHAR}NERDVERSE — NEW LIFE REGISTRATION"
    echo
    printf '  %sWelcome, operator.%s  One life. No reloads. Choose who walks the road.\n\n' "$AMBER" "$RESET"

    player_raw=$(cc_prompt_line "Your character name" "Meyiu")
    player=$(cc_sanitize_name "$player_raw" "Meyiu")

    companion_raw=$(cc_prompt_line "Companion name (walks beside you)" "Sera")
    companion=$(cc_sanitize_name "$companion_raw" "Sera")

    title=$(cc_prompt_line "Character epithet (short)" "The Sinner Who Still Chooses")

    echo
    printf '  %sCreating life:%s %s + %s Thornwake …\n' "$CYAN" "$RESET" "$player" "$companion"

    if ! game_db_create_web_session "$companion"; then
        echo "ERROR: could not create game database." >&2
        return 1
    fi

    local esc_player esc_comp esc_title esc_sera_full
    esc_player=$(printf '%s' "$player" | sed "s/'/''/g")
    esc_comp=$(printf '%s' "$companion" | sed "s/'/''/g")
    esc_title=$(printf '%s' "$title" | sed "s/'/''/g")
    esc_sera_full=$(printf '%s' "${companion} Thornwake" | sed "s/'/''/g")

    db_exec "UPDATE characters SET name='${esc_player}', title='${esc_title}' WHERE is_player=TRUE;"
    db_exec "UPDATE characters SET name='${esc_sera_full}' WHERE name='Sera Thornwake';"
    db_exec "UPDATE session_log SET character_name='${esc_comp}' WHERE character_name='Sera';"

    ws_set "player_display_name" "$player"
    ws_set "companion_display_name" "$companion"
    ws_set "game_initialized" "public_terminal_life"

    log_narrative "New public-terminal life: ${player} with companion ${companion} Thornwake."
    echo
    printf '  %sLife registered.%s  The forge awaits.\n' "$GREEN" "$RESET"
    sleep 1
    return 0
}