# scripts/lib/progression.sh — Practice, breakthrough levels, combos, context actions
#
# Design: 2-3 combat actives; many inert components; surprise combinations.
# Sera progresses on her own track — player is "in the room" for her milestones.

PROG_LEVEL_THRESHOLDS=(0 10 25 45 70)

COMBAT_ZONE=""
COMBAT_SERA_LAST=""
COMBAT_MARK_ACTIVE=0

_prog_char_id() {
    local name="${1:-Meyiu}"
    db_query "SELECT id FROM characters WHERE name='${name}' LIMIT 1;"
}

# Companion progression snapshot (same mechanics as player — separate track).
prog_load_sera_progress() {
    local row _old_ifs
    row=$(db_query_row "SELECT prog_level, road_xp, road_xp_max, breakthrough_pending FROM characters WHERE name='Sera Thornwake' LIMIT 1;")
    _old_ifs="$IFS"
    IFS=$'\t'
    read -r SERA_PROG_LEVEL SERA_ROAD_XP SERA_ROAD_XP_MAX SERA_BREAKTHROUGH_PENDING <<< "$row" || true
    IFS="$_old_ifs"
    SERA_PROG_LEVEL="${SERA_PROG_LEVEL:-1}"
    SERA_ROAD_XP="${SERA_ROAD_XP:-0}"
    SERA_ROAD_XP_MAX="${SERA_ROAD_XP_MAX:-10}"
    SERA_BREAKTHROUGH_PENDING="${SERA_BREAKTHROUGH_PENDING:-0}"
}

prog_show_sera_progress() {
    prog_load_sera_progress
    local pk pts tags
    printf '  %sSera progression%s  Lv%s  Road %d/%d' \
        "$CYAN" "$RESET" "$SERA_PROG_LEVEL" "$SERA_ROAD_XP" "$SERA_ROAD_XP_MAX"
    [[ "${SERA_BREAKTHROUGH_PENDING:-0}" -eq 1 ]] && printf '  %s◆ BREAKTHROUGH READY%s' "$AMBER" "$RESET"
    echo
    tags=""
    while IFS=$'\t' read -r pk pts; do
        [[ -z "$pk" ]] && continue
        tags="${tags}${tags:+, }${pk}:${pts}"
    done < <(prog_top_practices "Sera Thornwake" 3)
    [[ -n "$tags" ]] && printf '  %sPractice:%s %s\n' "$DIM" "$RESET" "$tags"
}

_prog_diminishing() {
    local current="${1:-0}"
    local gain="${2:-1}"
    if [[ $current -ge 40 ]]; then
        echo $(( gain / 3 + 1 ))
    elif [[ $current -ge 20 ]]; then
        echo $(( gain / 2 + 1 ))
    else
        echo "$gain"
    fi
}

# Apply practice to one or more tags: "arcane,practical"
prog_practice() {
    local char_name="${1:-Meyiu}"
    local tags="${2:-}"
    local amount="${3:-1}"
    local cid tag pts gain

    [[ -z "$tags" ]] && return 0
    cid=$(_prog_char_id "$char_name")
    [[ -z "$cid" ]] && return 0

    IFS=',' read -ra _tags <<< "$tags"
    for tag in "${_tags[@]}"; do
        tag=$(printf '%s' "$tag" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$tag" ]] && continue
        pts=$(db_query "SELECT points FROM character_practice WHERE character_id=${cid} AND practice_key='${tag}';")
        pts="${pts:-0}"
        gain=$(_prog_diminishing "$pts" "$amount")
        db_exec "INSERT INTO character_practice (character_id, practice_key, points)
                 VALUES (${cid}, '${tag}', ${gain})
                 ON DUPLICATE KEY UPDATE points = points + ${gain};"
    done
}

prog_practice_get() {
    local char_name="${1:-Meyiu}"
    local tag="$2"
    local cid
    cid=$(_prog_char_id "$char_name")
    db_query "SELECT points FROM character_practice WHERE character_id=${cid} AND practice_key='${tag}';"
}

prog_top_practices() {
    local char_name="${1:-Meyiu}"
    local cid limit="${2:-3}"
    cid=$(_prog_char_id "$char_name")
    echo "SELECT practice_key, points FROM character_practice
          WHERE character_id=${cid} ORDER BY points DESC LIMIT ${limit};" | $MARIADB --silent --skip-column-names 2>/dev/null || true
}

prog_has_unlock() {
    local char_name="$1"
    local key="$2"
    local cid
    cid=$(_prog_char_id "$char_name")
    local n
    n=$(db_query "SELECT COUNT(*) FROM character_unlocks WHERE character_id=${cid} AND unlock_key='${key}';")
    [[ "${n:-0}" -gt 0 ]]
}

prog_grant_unlock() {
    local char_name="$1"
    local key="$2"
    local utype="${3:-component}"
    local dname="$4"
    local desc="${5:-}"
    local shiny="${6:-0}"
    local note="${7:-}"
    local cid esc_d esc_n esc_note

    cid=$(_prog_char_id "$char_name")
    [[ -z "$cid" ]] && return 1
    if prog_has_unlock "$char_name" "$key"; then
        return 0
    fi
    esc_d=$(printf '%s' "$dname" | sed "s/'/''/g")
    esc_n=$(printf '%s' "$desc" | sed "s/'/''/g")
    esc_note=$(printf '%s' "$note" | sed "s/'/''/g")
    db_exec "INSERT INTO character_unlocks (character_id, unlock_key, unlock_type, display_name, description, is_shiny, source_note)
             VALUES (${cid}, '${key}', '${utype}', '${esc_d}', '${esc_n}', ${shiny}, '${esc_note}');"
    log_narrative "${char_name} unlocked: ${dname}."
    return 0
}

# Road XP overflow → breakthrough flag (not automatic level)
prog_sync_breakthrough() {
    local char_name="${1:-Meyiu}"
    local rxp rxpmax level pending cid
    cid=$(_prog_char_id "$char_name")
    rxp=$(db_query "SELECT road_xp FROM characters WHERE id=${cid};")
    rxpmax=$(db_query "SELECT road_xp_max FROM characters WHERE id=${cid};")
    level=$(db_query "SELECT prog_level FROM characters WHERE id=${cid};")
    level="${level:-1}"
    rxp="${rxp:-0}"
    rxpmax="${rxpmax:-10}"

    if [[ $rxp -ge $rxpmax ]]; then
        db_exec "UPDATE characters SET breakthrough_pending=1 WHERE id=${cid};"
    fi
}

prog_breakthrough_ready() {
    local char_name="${1:-Meyiu}"
    local cid ready
    cid=$(_prog_char_id "$char_name")
    ready=$(db_query "SELECT breakthrough_pending FROM characters WHERE id=${cid};")
    [[ "${ready:-0}" -eq 1 ]]
}

prog_level_threshold() {
    local level="${1:-2}"
    local idx=$(( level - 1 ))
    if [[ $idx -ge 0 && $idx -lt ${#PROG_LEVEL_THRESHOLDS[@]} ]]; then
        echo "${PROG_LEVEL_THRESHOLDS[$idx]}"
    else
        echo $(( 70 + (level - 5) * 25 ))
    fi
}

# Level-up ceremony — 3 options shaped by play style; always one shiny toy
prog_level_up_ceremony() {
    local char_name="${1:-Meyiu}"
    local cid level top1 top2 top3
    cid=$(_prog_char_id "$char_name")
    level=$(db_query "SELECT prog_level FROM characters WHERE id=${cid};")
    level="${level:-1}"

    clear_screen
    draw_operator_banner "main"
    echo
    draw_screen_header "${ICON_SCROLL}BREAKTHROUGH — ${char_name} LEVEL $(( level + 1 ))"

    if [[ "$char_name" == "Meyiu" ]]; then
        printf '  %sThe road bends. Not louder — %sdeeper%s.%s\n\n' "$AMBER" "$BOLD" "$RESET" "$RESET"
    else
        printf '  %sSera meets your eyes. She does not perform joy — she %slets you see it%s.%s\n\n' \
            "$AMBER" "$BOLD" "$RESET" "$RESET"
    fi

    top1=$(prog_practice_get "$char_name" "arcane"); top1="${top1:-0}"
    top2=$(prog_practice_get "$char_name" "practical"); top2="${top2:-0}"
    top3=$(prog_practice_get "$char_name" "medicine"); top3="${top3:-0}"
    local science=$(prog_practice_get "$char_name" "science"); science="${science:-0}"
    local tactics=$(prog_practice_get "$char_name" "tactics"); tactics="${tactics:-0}"

    local o1k o1n o1d o2k o2n o2d o3k o3n o3d
    if [[ "$char_name" == "Meyiu" ]]; then
        if [[ $top1 -ge $top2 ]]; then
            o1k="unlock_thermal_recipe"; o1n="Thermal Shock (combo recipe)"; o1d="Inert until Sera primes cold — then devastating."
            o2k="ember_lens"; o2n="Ember Lens (shiny component)"; o2d="Useless alone. Combines with chill residue later."
            o3k="breathguard_ii"; o3n="Breathguard II"; o3d="Buckler + focus synergy — defensive flex."
        else
            o1k="practical_mender"; o1n="Field Mender's Habit (passive)"; o1d="Repairs and triage actions heal +1 HP quietly."
            o2k="watch_chalk"; o2n="Watch Chalk (shiny toy)"; o2d="Marks maps. Inert in combat — until paired with tactics."
            o3k="penitent_insight"; o3n="Penitent's Insight"; o3d="Intellect passive — debuffs land easier."
        fi
    else
        if [[ $science -ge 3 || "$(ws_get "mill_status" 2>/dev/null || true)" == "patched" ]]; then
            o1k="sera_field_lab"; o1n="Field Lab Satchel (science)"; o1d="Frozen Ground gains +1 zone turn. Shiny, smells like copper."
            o2k="chill_residue"; o2n="Chill Residue vial (component)"; o2d="Inert until Meyiu casts fire — then Thermal Shock awakens."
            o3k="sera_quiet_rally"; o3n="Quiet Rally (passive)"; o3d="Village fear drops one notch after shared victories."
        else
            o1k="sera_triage_ii"; o1n="Triage Mark II"; o1d="Your next strike after her mark hits harder."
            o2k="bandage_charms"; o2n="Bandage Charms (shiny)"; o2d="Useless in a sword fight. Precious in the medicine room."
            o3k="scout_whisper"; o3n="Scout Whisper"; o3d="Bridge intel actions cost less panic."
        fi
    fi

    draw_ledger_option 1 "$o1n" "1"
    printf '       %s%s%s\n' "$GRAY" "$o1d" "$RESET"
    draw_ledger_option 2 "$o2n" "2"
    printf '       %s%s%s\n' "$GRAY" "$o2d" "$RESET"
    draw_ledger_option 3 "$o3n" "3"
    printf '       %s%s%s\n' "$GRAY" "$o3d" "$RESET"
    echo
    printf '  %s>%s Choose breakthrough (1-3): ' "$BRIGHT_GREEN" "$RESET"
    read -r pick

    local uk un ud ut shiny=0
    case "$pick" in
        1) uk="$o1k"; un="$o1n"; ud="$o1d"; ut="combo" ;;
        2) uk="$o2k"; un="$o2n"; ud="$o2d"; ut="component"; shiny=1 ;;
        3) uk="$o3k"; un="$o3n"; ud="$o3d"; ut="passive" ;;
        *) uk="$o2k"; un="$o2n"; ud="$o2d"; ut="component"; shiny=1 ;;
    esac
    [[ "$uk" == *"shiny"* || "$uk" == *"lens"* || "$uk" == *"chalk"* || "$uk" == *"charms"* || "$uk" == *"lab"* ]] && shiny=1

    prog_grant_unlock "$char_name" "$uk" "$ut" "$un" "$ud" "$shiny" "level_$(( level + 1 ))_ceremony"

    local new_level=$(( level + 1 ))
    local next_max
    next_max=$(prog_level_threshold $(( new_level + 1 )))
    db_exec "UPDATE characters SET prog_level=${new_level}, breakthrough_pending=0,
             road_xp = GREATEST(0, road_xp - road_xp_max), road_xp_max=${next_max}
             WHERE id=${cid};"

    echo
    if [[ "$char_name" == "Sera Thornwake" || "$char_name" == "Sera" ]]; then
        sera_says "I felt that land. Thank you for being in the room — not just watching."
        prog_practice "Sera Thornwake" "medicine" 1
    else
        printf '  %s%s%s\n' "$GREEN" "Breakthrough recorded. New complexity, not just louder noise." "$RESET"
    fi
    log_narrative "${char_name} breakthrough → level ${new_level}: ${un}"
    read -r -p "Press enter to continue..."
}

prog_maybe_breakthrough_ceremonies() {
    if prog_breakthrough_ready "Meyiu"; then
        prog_level_up_ceremony "Meyiu"
    fi
    if prog_breakthrough_ready "Sera Thornwake"; then
        prog_level_up_ceremony "Sera Thornwake"
    fi
}

# Sera milestone — surfaced to player (in the room)
prog_sera_milestone() {
    local headline="$1"
    local detail="${2:-}"
    local mood="${3:-}"

    echo
    printf '%s┌─ SERA — IN THE ROOM ─────────────────────────────────────────────┐%s\n' "$CYAN" "$RESET"
    printf '%s│%s %s%s%s\n' "$CYAN" "$RESET" "$AMBER" "$headline" "$RESET"
    [[ -n "$detail" ]] && printf '%s│%s %s%s%s\n' "$CYAN" "$RESET" "$GRAY" "$detail" "$RESET"
    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$CYAN" "$RESET"
    log_narrative "Sera milestone: ${headline} ${detail}"
    [[ -n "$mood" ]] && sera_update_state "sera_mood" "$mood"
}

# Between-battle ranked actions for current location (max 5)
prog_rank_context_actions() {
    local loc="${LOCATION_KEY:-forge}"
    local -a actions=()
    local -a scores=()

    _add_action() {
        local score="$1"
        local label="$2"
        actions+=("$label")
        scores+=("$score")
    }

    case "$loc" in
        medicine)
            _add_action 100 "Work with Sera — heal & triage the crate"
            _add_action 85  "Inventory medicine (intel + practical practice)"
            if prog_has_unlock "Sera Thornwake" "bandage_charms" || [[ $(prog_practice_get "Sera Thornwake" "medicine") -ge 5 ]]; then
                _add_action 70 "Sort supplies with Sera (quiet shared work)"
            fi
            ;;
        mill)
            if [[ "$(ws_get mill_status)" == "patched" ]]; then
                _add_action 90 "Check wheel rhythm — science observation with Sera"
            else
                _add_action 100 "Investigate axle sabotage (repair bundle if carried)"
            fi
            _add_action 75 "Study grain store (food intel)"
            ;;
        sheriff)
            _add_action 100 "Coordinate village watch with Marn"
            _add_action 90  "Press gang token for timeline"
            _add_action 60  "Ride out — seek contact (combat)"
            ;;
        inn)
            _add_action 95 "Meal + listen for rumors (morale)"
            _add_action 70 "Rest — recover HP"
            ;;
        bridge)
            _add_action 100 "Scout tollhouse from treeline"
            _add_action 50 "Move closer — test their nerve (fight risk)"
            ;;
        forge)
            _add_action 90 "Study Ash-Wood Buckler"
            _add_action 70 "Talk with Old Brenn (practical lore)"
            ;;
        *)
            _add_action 50 "Look around"
            ;;
    esac

    # Emit sorted (simple bubble for small N)
    local i j
    for (( i=0; i<${#actions[@]}; i++ )); do
        for (( j=i+1; j<${#actions[@]}; j++ )); do
            if [[ ${scores[$j]} -gt ${scores[$i]} ]]; then
                local ts tl
                ts=${scores[$i]}; scores[$i]=${scores[$j]}; scores[$j]=$ts
                tl=${actions[$i]}; actions[$i]=${actions[$j]}; actions[$j]=$tl
            fi
        done
    done

    local max="${1:-3}"
    local n=${#actions[@]}
    (( n > max )) && n=$max
    for (( i=0; i<n; i++ )); do
        printf '  %s•%s %s\n' "$GREEN" "$RESET" "${actions[$i]}"
    done
}

prog_get_combat_abilities() {
    local char_name="${1:-Meyiu}"
    echo "SELECT ability_key, ability_name, description, uses_remaining, proficiency
          FROM character_abilities a JOIN characters c ON a.character_id = c.id
          WHERE c.name='${char_name}' AND a.combat_active = 1
          ORDER BY a.combat_slot ASC LIMIT 3;" | $MARIADB --silent --skip-column-names
}

prog_combo_check() {
    local primer="$1"
    local followup="$2"
    local key
    key=$(db_query "SELECT combo_key FROM combo_recipes
                    WHERE primer_key='${primer}' AND followup_key='${followup}' LIMIT 1;")
    [[ -n "$key" ]] && echo "$key"
}

prog_discover_combo() {
    local combo_key="$1"
    local n
    n=$(db_query "SELECT COUNT(*) FROM party_combos_discovered WHERE combo_key='${combo_key}';")
    if [[ "${n:-0}" -eq 0 ]]; then
        db_exec "INSERT INTO party_combos_discovered (combo_key) VALUES ('${combo_key}');"
        local name flavor
        name=$(db_query "SELECT display_name FROM combo_recipes WHERE combo_key='${combo_key}';")
        flavor=$(db_query "SELECT narrative_flavor FROM combo_recipes WHERE combo_key='${combo_key}';")
        echo
        printf '%s╔══ COMBO DISCOVERED: %s ══╗%s\n' "$YELLOW" "$name" "$RESET"
        printf '%s  %s%s\n' "$AMBER" "${flavor:-The world clicks into a new shape.}" "$RESET"
        log_narrative "Party discovered combo: ${name}"
        prog_sera_milestone "She grins — just barely." "You felt it too. ${name}." "bright-focus"
    fi
}

# Sera autonomous combat support (player sees her card act)
prog_sera_combat_turn() {
    local enemy_hp="$1"
    local bond
    load_sera_state
    bond=$(sera_clamp_meter "${SERA_BOND:-25}")

    COMBAT_SERA_LAST=""
    [[ $enemy_hp -le 0 ]] && return 0

    local science=$(prog_practice_get "Sera Thornwake" "science"); science="${science:-0}"
    local roll=$(( RANDOM % 100 ))

    if [[ $science -ge 2 || "$(ws_get "mill_status")" == "patched" ]] && [[ $roll -lt 45 ]]; then
        COMBAT_SERA_LAST="sera_frozen_ground"
        COMBAT_ZONE="frozen"
        echo -e "${CYAN}Sera lays Frozen Ground — the air crystallizes.${RESET}"
        prog_practice "Sera Thornwake" "science,medicine" 1
        db_exec "UPDATE character_abilities SET proficiency = COALESCE(proficiency,0)+1
                 WHERE character_id = (SELECT id FROM characters WHERE name='Sera Thornwake')
                 AND ability_key='sera_frozen_ground';"
        return 0
    fi

    if [[ $bond -ge 50 && $roll -lt 70 ]]; then
        COMBAT_SERA_LAST="sera_triage_mark"
        COMBAT_MARK_ACTIVE=1
        echo -e "${CYAN}Sera marks the foe — Triage focus.${RESET}"
        prog_practice "Sera Thornwake" "medicine,tactics" 1
        return 0
    fi

    echo -e "${GRAY}Sera holds the lane — present, not performing.${RESET}"
}

# Backfill existing saves after migration
prog_normalize_saves() {
    local cid_m cid_s rxp
    cid_m=$(_prog_char_id "Meyiu")
    cid_s=$(_prog_char_id "Sera Thornwake")
    [[ -z "$cid_m" ]] && return 0

    prog_sync_breakthrough "Meyiu"
    prog_sync_breakthrough "Sera Thornwake"

    # Mill + sheriff play → retro practice
    if [[ "$(ws_get "mill_status")" == "patched" ]]; then
        prog_practice "Meyiu" "practical,strength" 4
        prog_practice "Sera Thornwake" "science,medicine" 5
        prog_grant_unlock "Sera Thornwake" "chill_residue" "component" "Chill Residue Vial" \
            "Harvested from mill mist. Inert until fire meets it." 1 "mill_patched"
        local sp
        sp=$(prog_practice_get "Sera Thornwake" "science")
        if [[ ${sp:-0} -ge 5 ]]; then
            db_exec "UPDATE characters SET road_xp = GREATEST(road_xp, 10), road_xp_max = 10, breakthrough_pending = 1
                     WHERE id=${cid_s} AND breakthrough_pending = 0 AND prog_level = 1;"
        fi
    fi

    rxp=$(db_query "SELECT road_xp FROM characters WHERE id=${cid_m};")
    if [[ ${rxp:-0} -ge 10 ]]; then
        db_exec "UPDATE characters SET breakthrough_pending=1 WHERE id=${cid_m};"
    fi

    # Shared victories → tactics practice
    if [[ "$(ws_get "last_major_event")" == *"defeated"* ]]; then
        prog_practice "Meyiu" "arcane,tactics" 2
        prog_practice "Sera Thornwake" "tactics,medicine" 2
    fi
}