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

cc_tty() {
    local tty="${NERDVERSE_TTY:-/dev/tty}"
    if [[ -e "$tty" ]] && [[ -r "$tty" ]]; then
        printf '%s' "$tty"
    else
        printf '%s' "/dev/stdin"
    fi
}

cc_drain_tty() {
    local tty tries=0
    tty=$(cc_tty)
    [[ "$tty" == "/dev/stdin" ]] && return 0
    while read -r -t 0.02 _junk <"$tty" 2>/dev/null; do
        tries=$(( tries + 1 ))
        [[ $tries -gt 50 ]] && break
    done
}

# Block on real TTY; never treat spurious empty as input in public mode.
cc_read_tty() {
    local val tty
    tty=$(cc_tty)
    while true; do
        if [[ "$tty" == "/dev/stdin" ]]; then
            read -r val
        else
            read -r val <"$tty" 2>/dev/null || read -r val
        fi
        val="${val//$'\r'/}"
        val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        case "$val" in
            ''|$'\e'|$'\e'*|$'\x1b'*)
                [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]] && continue
                printf '%s' "$val"
                return 0
                ;;
            *)
                printf '%s' "$val"
                return 0
                ;;
        esac
    done
}

# Prompts must go to the terminal, not stdout — used inside $().
cc_prompt_line() {
    local prompt="$1"
    local default="$2"
    local val tty
    tty=$(cc_tty)
    {
        printf '%s%s%s' "$GREEN" "$prompt" "$RESET"
        [[ -n "$default" ]] && printf ' %s[%s]%s' "$DIM" "$default" "$RESET"
        if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
            printf ' %s(type . = default)%s' "$DIM" "$RESET"
        fi
        printf ': '
    } >"$tty"
    val=$(cc_read_tty)
    if [[ -z "$val" || "$val" == "." ]]; then
        printf '%s\n' "$default"
    else
        printf '%s\n' "$val"
    fi
}

cc_roll_public_defaults() {
    # shellcheck source=scripts/lib/public_names.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/public_names.sh"
    cc_public_random_defaults
}

cc_finalize_registration() {
    local player="$1" companion="$2" title="$3" surname="$4"

    if ! game_db_create_web_session "$companion"; then
        echo "ERROR: could not create game database." >&2
        return 1
    fi

    local esc_player esc_comp esc_title esc_companion_full
    esc_player=$(printf '%s' "$player" | sed "s/'/''/g")
    esc_comp=$(printf '%s' "$companion" | sed "s/'/''/g")
    esc_title=$(printf '%s' "$title" | sed "s/'/''/g")
    esc_companion_full=$(printf '%s' "${companion} ${surname}" | sed "s/'/''/g")

    db_exec "UPDATE characters SET name='${esc_player}', title='${esc_title}' WHERE is_player=TRUE;"
    db_exec "UPDATE characters SET name='${esc_companion_full}' WHERE is_player=FALSE;"
    db_exec "UPDATE session_log SET character_name='${esc_comp}' WHERE character_name IN ('Sera','Guide');"

    ws_set "player_display_name" "$player"
    ws_set "companion_display_name" "$companion"
    ws_set "companion_surname" "$surname"
    ws_set "game_initialized" "public_arc_start"

    log_narrative "New public-terminal life: ${player} with companion ${companion} ${surname}."
    export NERDVERSE_PLAYER_NAME="$player"
    if declare -f tel_event >/dev/null 2>&1; then
        tel_event "wizard_complete" "registration" "" "player=${player};companion=${companion}"
    fi
    echo
    printf '  %sLife registered.%s  The forge awaits.\n' "$GREEN" "$RESET"
    sleep 1
    return 0
}

# One-shot public lane: roll names, confirm once, no blank-line races.
character_create_wizard_public() {
    local player companion title surname confirm tty
    IFS=$'\t' read -r player companion title surname <<< "$(cc_roll_public_defaults)"
    tty=$(cc_tty)
    cc_drain_tty

    clear_screen
    draw_operator_banner "main"
    echo
    draw_screen_header "${ICON_CHAR}NERDVERSE — NEW LIFE REGISTRATION"
    echo
    printf '  %sOne-shot pilgrim run.%s  Names rolled for this tab only.\n\n' "$AMBER" "$RESET"
    printf '    %sPilgrim:%s   %s — %s\n' "$CYAN" "$RESET" "$player" "$title"
    printf '    %sCompanion:%s %s %s\n\n' "$CYAN" "$RESET" "$companion" "$surname"
    {
        printf '  %sPress . (period) then Enter to begin with these names.%s\n' "$GREEN" "$RESET"
        printf '  %sPress e then Enter to customize.%s\n\n' "$DIM" "$RESET"
        printf '  %s>%s ' "$BRIGHT_GREEN" "$RESET"
    } >"$tty"

    while true; do
        confirm=$(cc_read_tty)
        case "$confirm" in
            .|begin|start|y|yes)
                echo
                printf '  %sCreating life:%s %s + %s %s …\n' "$CYAN" "$RESET" "$player" "$companion" "$surname"
                cc_finalize_registration "$player" "$companion" "$title" "$surname"
                return $?
                ;;
            e|edit|custom)
                echo
                character_create_wizard_manual "$player" "$companion" "$title" "$surname"
                return $?
                ;;
            *)
                printf '  %sType . to begin or e to edit names.%s\n' "$AMBER" "$RESET" >"$tty"
                printf '  %s>%s ' "$BRIGHT_GREEN" "$RESET" >"$tty"
                ;;
        esac
    done
}

character_create_wizard_manual() {
    local default_player="${1:-Meyiu}" default_companion="${2:-Sera}"
    local default_title="${3:-The Sinner Who Still Chooses}" default_surname="${4:-Thornwake}"
    local companion_raw player_raw companion player title surname tty

    tty=$(cc_tty)
    cc_drain_tty
    printf '  %sCustomize your pilgrims.%s  Type . at any prompt for the bracketed default.\n\n' "$DIM" "$RESET" >"$tty"

    player_raw=$(cc_prompt_line "Your character name" "$default_player")
    player=$(cc_sanitize_name "$player_raw" "$default_player")

    companion_raw=$(cc_prompt_line "Companion name (walks beside you)" "$default_companion")
    companion=$(cc_sanitize_name "$companion_raw" "$default_companion")

    title=$(cc_prompt_line "Character epithet (short)" "$default_title")
    surname="${default_surname}"

    echo
    printf '  %sCreating life:%s %s + %s %s …\n' "$CYAN" "$RESET" "$player" "$companion" "$surname"
    cc_finalize_registration "$player" "$companion" "$title" "$surname"
}

# Interactive wizard → fresh DB + renamed characters. Sets active save in session dir.
character_create_wizard() {
    if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
        character_create_wizard_public
        return $?
    fi

    local companion_raw player_raw companion player title surname
    local default_player="Meyiu" default_companion="Sera"
    local default_title="The Sinner Who Still Chooses" default_surname="Thornwake"

    clear_screen
    draw_operator_banner "main"
    echo
    draw_screen_header "${ICON_CHAR}NERDVERSE — NEW LIFE REGISTRATION"
    echo
    printf '  %sWelcome, operator.%s  One life. No reloads. Choose who walks the road.\n\n' "$AMBER" "$RESET"

    character_create_wizard_manual "$default_player" "$default_companion" "$default_title" "$default_surname"
}