# combat.sh — Turn combat with ally cards, 3-option menu, combos

COMBAT_OUTCOME="withdrawn"

function draw_combat_header() {
    local enemy_name="$1"
    clear_screen
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}║              ⚔  FIELD CONTACT — ALLY CARDS ACTIVE  ⚔           ║${RESET}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

function _combat_hp_bar() {
    local cur="$1" max="$2" width="${3:-8}"
    local filled=$(( cur * width / max ))
    (( filled > width )) && filled=$width
    local empty=$(( width - filled ))
    printf '%s%s' "$(printf '%*s' "$filled" '' | tr ' ' '█')" "$(printf '%*s' "$empty" '' | tr ' ' '░')"
}

function draw_ascii_combatants() {
    local player_hp=$1 player_max=$2 enemy_hp=$3 enemy_max=$4 enemy_name="$5"
    local sera_hp sera_max p_label c_label
    sera_hp=$(db_query "SELECT current_hp FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;")
    sera_max=$(db_query "SELECT max_hp FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;")
    sera_hp="${sera_hp:-14}"; sera_max="${sera_max:-14}"
    p_label=$(party_player_name 2>/dev/null || echo "PILGRIM")
    c_label=$(party_companion_short 2>/dev/null || echo "GUIDE")
    p_label="${p_label:0:6}"; c_label="${c_label:0:6}"

    local pbar ebar sbar
    pbar=$(_combat_hp_bar "$player_hp" "$player_max")
    sbar=$(_combat_hp_bar "$sera_hp" "$sera_max")
    ebar=$(_combat_hp_bar "$enemy_hp" "$enemy_max")

    echo
    printf "  ${GREEN}%-6s${RESET}          ${CYAN}%-6s${RESET}              ${RED}FOE${RESET}\n" "$p_label" "$c_label"
    echo -e "  ${GREEN}╔══════════════╗${RESET}  ${CYAN}╔══════════════╗${RESET}  ${RED}╔══════════════╗${RESET}"
    printf "  ${GREEN}║%-14s║${RESET}  ${CYAN}║%-14s║${RESET}  ${RED}║%-14s║${RESET}\n" " Zen-Mage" " Companion" "${enemy_name:0:14}"
    echo -e "  ${GREEN}║     /\\       ║${RESET}  ${CYAN}║     o        ║${RESET}  ${RED}║     o        ║${RESET}"
    echo -e "  ${GREEN}║    /  \\      ║${RESET}  ${CYAN}║    /|\\       ║${RESET}  ${RED}║    /|\\       ║${RESET}"
    echo -e "  ${GREEN}║   |buck|     ║${RESET}  ${CYAN}║   bow|shield ║${RESET}  ${RED}║   blade|rage ║${RESET}"
    echo -e "  ${GREEN}║    ||||      ║${RESET}  ${CYAN}║    steady    ║${RESET}  ${RED}║    hostile   ║${RESET}"
    if [[ -n "${COMBAT_ZONE}" ]]; then
        printf "  ${GREEN}║ zone:%-7s║${RESET}  ${CYAN}║ zone:%-7s║${RESET}  ${RED}║ zone:%-7s║${RESET}\n" \
            "ready" "${COMBAT_ZONE:0:7}" "threat"
    fi
    printf "  ${GREEN}║%s %2d/%-2d║${RESET}  ${CYAN}║%s %2d/%-2d║${RESET}  ${RED}║%s %2d/%-2d║${RESET}\n" \
        "$pbar" "$player_hp" "$player_max" "$sbar" "$sera_hp" "$sera_max" "$ebar" "$enemy_hp" "$enemy_max"
    echo -e "  ${GREEN}╚══════════════╝${RESET}  ${CYAN}╚══════════════╝${RESET}  ${RED}╚══════════════╝${RESET}"
    echo
}

function start_encounter() {
    local enemy_name="$1"
    local enemy_max_hp="${2:-18}"
    local enemy_hp=$enemy_max_hp

    local player_name companion_name
    player_name=$(party_player_name 2>/dev/null || echo "Pilgrim")
    companion_name=$(party_companion_name 2>/dev/null || echo "Guide")
    local player_hp player_max hp_at_start outcome rounds=0 damage_taken=0
    player_hp=$(db_query "SELECT current_hp FROM characters WHERE is_player=TRUE LIMIT 1;")
    player_max=$(db_query "SELECT max_hp FROM characters WHERE is_player=TRUE LIMIT 1;")
    hp_at_start=$player_hp
    outcome="withdrawn"
    COMBAT_OUTCOME="withdrawn"
    COMBAT_ZONE=""
    COMBAT_SERA_LAST=""
    COMBAT_MARK_ACTIVE=0

    if declare -f tel_balance >/dev/null 2>&1; then
        tel_balance "combat_start" "encounter" "enemy=${enemy_name};enemy_hp=${enemy_max_hp}"
    fi

    draw_combat_header "$enemy_name"
    prog_sera_milestone "She's here." "Not behind you. Beside you." "battle-focus"

    while [[ $player_hp -gt 0 && $enemy_hp -gt 0 ]]; do
        rounds=$(( rounds + 1 ))
        draw_ascii_combatants "$player_hp" "$player_max" "$enemy_hp" "$enemy_max_hp" "$enemy_name"

        if declare -f prog_sera_combat_turn >/dev/null 2>&1; then
            prog_sera_combat_turn "$enemy_hp"
        fi

        eval $(get_equipment_modifiers)
        local spell_mod=${spell_bonus:-0}
        local phys_mod=${phys_bonus:-0}

        echo -e "${BOLD}Your flex (pick 1-3):${RESET}"
        local i=1
        declare -a ability_list=()
        while IFS=$'\t' read -r akey aname adesc uses prof; do
            ability_list[$i]="$akey"
            local display_name="$aname"
            [[ ${prof:-0} -gt 0 ]] && display_name="$aname (Prof $prof)"
            printf "  %s) %s\n" "$i" "$display_name"
            ((i++))
        done < <(prog_get_combat_abilities 2>/dev/null || get_player_abilities)

        if [[ ${#ability_list[@]} -eq 0 ]]; then
            ability_list[1]="basic_attack"
            echo "  1) Basic Attack"
        fi

        read -r -p "> " action

        local defended=0
        local ability_key="${ability_list[$action]:-basic_attack}"
        local base=4 is_spell=0 combo_bonus=0 combo_key=""

        case "$ability_key" in
            *firebolt*|*Firebolt*)
                base=6; is_spell=1
                echo -e "${YELLOW}You channel and release a roaring Zen-Mage Firebolt!${RESET}"
                if [[ -n "$COMBAT_SERA_LAST" ]]; then
                    combo_key=$(prog_combo_check "$COMBAT_SERA_LAST" "$ability_key" 2>/dev/null || true)
                fi
                if [[ -z "$combo_key" && "$COMBAT_ZONE" == "frozen" ]]; then
                    combo_key=$(prog_combo_check "sera_frozen_ground" "$ability_key" 2>/dev/null || true)
                fi
                ;;
            *breath*|*buckler*)
                echo "You activate Breathguard — the buckler flares."
                defended=3
                ;;
            *wrap*|*penitent*)
                echo "Penitent's Wrap — you brace for impact."
                defended=2
                ;;
            *)
                echo "You strike!"
                ;;
        esac

        if [[ -n "$combo_key" ]]; then
            combo_bonus=$(db_query "SELECT bonus_damage FROM combo_recipes WHERE combo_key='${combo_key}';")
            combo_bonus="${combo_bonus:-4}"
            prog_discover_combo "$combo_key" 2>/dev/null || true
            local flavor
            flavor=$(db_query "SELECT narrative_flavor FROM combo_recipes WHERE combo_key='${combo_key}';")
            printf '  %s%s%s\n' "$YELLOW" "${flavor:-Pressure rupture!}" "$RESET"
            prog_practice "$player_name" "arcane,tactics" 2
            prog_practice "$companion_name" "science,medicine" 1
        fi

        if [[ $defended -eq 0 ]]; then
            local roll=$(( RANDOM % 5 + 1 ))
            local prof_bonus=0 prof
            prof=$(db_query "SELECT proficiency FROM character_abilities WHERE character_id=(SELECT id FROM characters WHERE is_player=TRUE LIMIT 1) AND ability_key='${ability_key}';")
            prof_bonus=$(( ${prof:-0} / 3 ))
            local dmg=$(( base + roll + (is_spell ? spell_mod : phys_mod) + prof_bonus + combo_bonus ))
            [[ $COMBAT_MARK_ACTIVE -eq 1 ]] && dmg=$(( dmg + 2 ))
            echo "  The attack strikes for ${dmg} damage!"
            enemy_hp=$(( enemy_hp - dmg ))
            COMBAT_MARK_ACTIVE=0
            COMBAT_ZONE=""

            if [[ $enemy_hp -le 0 ]]; then
                local overkill=$(( -enemy_hp ))
                local heal=$(( overkill + 1 ))
                player_hp=$(( player_hp + heal ))
                [[ $player_hp -gt $player_max ]] && player_hp=$player_max
                db_exec "UPDATE characters SET current_hp=$player_hp WHERE is_player=TRUE;"
                echo -e "  ${GREEN}Overkill! You siphon ${heal} life force back.${RESET}"
            fi

            if [[ $is_spell -eq 1 ]]; then
                db_exec "UPDATE character_abilities SET proficiency = COALESCE(proficiency,0) + 1
                         WHERE character_id = (SELECT id FROM characters WHERE is_player=TRUE LIMIT 1)
                         AND ability_key LIKE '%firebolt%';"
                prog_practice "$player_name" "arcane,focus" 1
            elif [[ $defended -gt 0 ]]; then
                prog_practice "$player_name" "practical,strength" 1
            fi
        else
            prog_practice "$player_name" "practical,strength" 1
        fi

        if [[ $enemy_hp -gt 0 ]]; then
            echo
            echo "${enemy_name} lunges!"
            local edmg=$(( 3 + RANDOM % 4 ))
            if [[ $defended -gt 0 ]]; then
                edmg=$(( edmg - defended ))
                [[ $edmg -lt 1 ]] && edmg=1
                echo "  Your defense reduces it to ${edmg} damage!"
            fi
            player_hp=$(( player_hp - edmg ))
            damage_taken=$(( damage_taken + edmg ))
            [[ $player_hp -lt 0 ]] && player_hp=0
            db_exec "UPDATE characters SET current_hp=$player_hp WHERE is_player=TRUE;"
            echo "  You take ${edmg} damage. (HP: ${player_hp})"
        fi

        if [[ $enemy_hp -le 0 ]]; then
            echo
            echo -e "${GREEN}=== VICTORY ===${RESET}"
            echo "${enemy_name} crumples."
            log_narrative "${player_name} defeated a ${enemy_name} with mage fire and buckler discipline."
            db_exec "UPDATE characters SET road_xp = road_xp + 3 WHERE is_player=TRUE;"
            db_exec "UPDATE characters SET road_xp = road_xp + 2 WHERE is_player=FALSE;"
            prog_practice "$player_name" "tactics" 1
            prog_practice "$companion_name" "medicine,tactics" 1
            if declare -f prog_sync_breakthrough >/dev/null 2>&1; then
                prog_sync_breakthrough "$player_name"
                prog_sync_breakthrough "$companion_name"
            fi
            outcome="victory"
            COMBAT_OUTCOME="victory"
            break
        fi
        if [[ $player_hp -le 0 ]]; then
            echo
            echo -e "${RED}=== DEFEAT ===${RESET}"
            log_narrative "${player_name} was overwhelmed in combat."
            outcome="defeat"
            COMBAT_OUTCOME="defeat"
            break
        fi

        read -r -p "Press enter for next round..." dummy
    done

    player_hp=$(db_query "SELECT current_hp FROM characters WHERE is_player=TRUE LIMIT 1;")
    if declare -f sera_react_to_combat >/dev/null 2>&1; then
        sera_react_to_combat "$outcome" "$enemy_name" "$hp_at_start" "$player_hp"
    fi
    if [[ "$outcome" == "victory" ]]; then
        prog_sera_milestone "Wild celebration optional." "She allows herself one fierce squeeze of your hand." "bright-aftermath"
    fi

    if declare -f tel_balance >/dev/null 2>&1; then
        tel_balance "combat_end" "$outcome" "enemy=${enemy_name};rounds=${rounds};damage_taken=${damage_taken};hp_end=${player_hp}"
    fi

    read -r -p "Press enter to return to the road..."
}