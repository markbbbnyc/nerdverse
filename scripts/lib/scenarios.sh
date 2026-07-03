# scripts/lib/scenarios.sh — Brindleford location scenarios (mill, bridge, …)

_bump_preparedness() {
    local level
    level=$(ws_get "brindleford_preparedness")
    case "$level" in
        Low)    ws_set "brindleford_preparedness" "Medium" ;;
        Medium) ws_set "brindleford_preparedness" "Medium-High" ;;
    esac
}

_player_has_item() {
    local key="$1"
    local q
    q=$(db_query "SELECT COALESCE(SUM(quantity),0) FROM inventory i JOIN characters c ON i.character_id=c.id WHERE c.is_player=TRUE AND i.item_key='${key}';")
    [[ "${q:-0}" -gt 0 ]]
}

_consume_item() {
    local key="$1"
    db_exec "UPDATE inventory i JOIN characters c ON i.character_id=c.id SET i.quantity = GREATEST(0, i.quantity - 1) WHERE c.is_player=TRUE AND i.item_key='${key}' AND i.quantity > 0;"
}

# --- Old Mill: sabotage, food supply, real choices ---
scenario_mill() {
    local status
    status=$(ws_get "mill_status")
    status="${status:-unexamined}"

    echo
    draw_screen_header "${ICON_FORGE}THE OLD MILL — FOOD & IRON"

    case "$status" in
        patched)
            echo "The wheel turns steadier now. Wet grain still smells, but the sabotage pin is gone."
            sera_says "You fixed what you could. The village eats a little safer tonight."
            read -r -p "Press enter..."
            return 0
            ;;
        reported)
            echo "Sheriff Marn posted a watch near the mill after your report. The wheel still groans."
            sera_says "Good. Eyes on the problem beat heroics in the dark."
            read -r -p "Press enter..."
            return 0
            ;;
        grain_burned)
            echo "Charred husks behind the mill. Wasteful — but the rot won't spread."
            sera_says "Hard choice. I'd rather waste grain than lose the whole store."
            read -r -p "Press enter..."
            return 0
            ;;
    esac

    echo "The wheel groans one full turn every three heartbeats — too slow."
    echo "Under the axle: a pin filed nearly through. Deliberate. Recent."
    echo "In the storehouse: grain runs warm. Rot has started in one corner."
    echo
    sera_says "Sabotage on the wheel. Rot in the grain. Pick your poison — we can't fix everything in one breath."
    echo
    printf '%sWhat does Meyiu do?%s\n' "$BOLD$GREEN" "$RESET"
    if _player_has_item "repair_bundle"; then
        printf '  %s[1]%s Use the Repair Bundle on the axle (save the wheel)\n' "$GREEN" "$RESET"
    else
        printf '  %s[1]%s (No repair bundle — cannot fix the wheel today)\n' "$DIM" "$RESET"
    fi
    printf '  %s[2]%s Run to the Sheriff — report sabotage before fixing alone\n' "$GREEN" "$RESET"
    printf '  %s[3]%s Burn the rotting grain now (waste food, stop the spread)\n' "$GREEN" "$RESET"
    printf '  %s[0]%s Step back for now\n' "$DIM" "$RESET"
    echo

    read -r -p "> " choice
    case "$choice" in
        1)
            if ! _player_has_item "repair_bundle"; then
                echo "You lack the kit to do this properly."
                read -r -p "Press enter..."
                return 0
            fi
            _consume_item "repair_bundle"
            ws_set "mill_status" "patched"
            ws_set "brindleford_food_supply" "stabilizing"
            ws_set "last_major_event" "Meyiu used the repair bundle to fix sabotaged mill axle."
            _bump_preparedness
            log_narrative "Meyiu repaired the sabotaged mill wheel with the oilcloth kit."
            echo
            echo "Oil, cord, and steady hands. The wheel finds its rhythm again."
            sera_says "Practical. That's the whole sermon."
            sera_apply_bond_change 1 2 1
            if declare -f prog_practice >/dev/null 2>&1; then
                prog_practice "Meyiu" "practical,strength" 3
                prog_practice "Sera Thornwake" "science,medicine" 4
                prog_grant_unlock "Sera Thornwake" "chill_residue" "component" "Chill Residue Vial" \
                    "Harvested from mill mist. Inert until fire meets it." 1 "mill_repair"
                prog_sera_milestone "Science isn't abstract for her." "She measured the mist while you turned the wheel." "curious-warm"
                db_exec "UPDATE characters SET road_xp = road_xp + 3 WHERE name='Sera Thornwake';"
                prog_sync_breakthrough "Sera Thornwake"
            fi
            ;;
        2)
            ws_set "mill_status" "reported"
            ws_set "last_major_event" "Mill sabotage reported to Sheriff Marn."
            _bump_preparedness
            log_narrative "Meyiu reported mill sabotage to the Sheriff."
            echo
            echo "Marn's face hardens. \"I'll post a watch. You did right.\""
            sera_exercise_agency "defend measured scouts village"
            ;;
        3)
            ws_set "mill_status" "grain_burned"
            ws_set "brindleford_food_supply" "tight_but_safe"
            ws_set "last_major_event" "Rotten mill grain burned to halt spread."
            log_narrative "Meyiu burned the rotting grain at the Old Mill."
            echo
            echo "Smoke stings. A quarter of the store is ash. The rest might keep."
            sera_says "Ugly math. I'd do it again if I had to."
            sera_apply_bond_change 0 1 1
            ;;
        *)
            echo "The mill keeps groaning. The choice can wait — but not forever."
            ;;
    esac
    read -r -p "Press enter..."
}

# --- Sheriff: defense planning (not always another scout ambush) ---
scenario_sheriff() {
    local last_evt scouts
    last_evt=$(ws_get "last_major_event")
    scouts=$(ws_get "sheriff_scouts_cleared")

    echo
    draw_screen_header "${ICON_CHAR}SHERIFF MARN — VILLAGE DEFENSE"

    if [[ "$last_evt" == *"defeated Black Bridge Scout"* && "${scouts}" != "yes" ]]; then
        ws_set "sheriff_scouts_cleared" "yes"
        echo "Marn kicks the scout's token across the floor. It clinks like a verdict."
        echo "\"That one won't report back. The next one will come looking.\""
        sera_says "Good. Use the breathing room — don't waste it on speeches."
    else
        echo "Sheriff Marn's desk is maps, names, and coffee gone cold."
        sera_says "He's carrying the village in his shoulders. Give him something usable."
    fi

    echo
    printf '  %s[1]%s Draft a dusk watch rotation with Marn and Sera\n' "$GREEN" "$RESET"
    printf '  %s[2]%s Show the Black Bridge token — press for gang timeline\n' "$GREEN" "$RESET"
    printf '  %s[3]%s Post a decoy at the medicine room (bait retaliation away from families)\n' "$YELLOW" "$RESET"
    printf '  %s[4]%s Ride out to challenge any lurkers (likely contact)\n' "$RED" "$RESET"
    printf '  %s[0]%s Leave while the office is still quiet\n' "$DIM" "$RESET"
    echo

    read -r -p "> " choice
    case "$choice" in
        1)
            ws_set "brindleford_preparedness" "Medium"
            ws_set "last_major_event" "Meyiu coordinated dusk watch with Sheriff Marn and Sera."
            log_narrative "Meyiu set a dusk watch rotation with Marn; Sera assigned triage fallback."
            echo
            echo "Marn nods. \"Two on the mill path, one on the inn road. Sera's signal if anyone bleeds.\""
            sera_exercise_agency "defend measured scouts village"
            sera_apply_bond_change 1 1 1
            ;;
        2)
            if _player_has_item "black_bridge_token" || _player_has_item "Black Bridge-Token"; then
                ws_set "black_bridge_gang_status" "Retaliation likely by dusk; Toll-Saint may send a probe first."
                ws_set "bridge_intel" "Probe likely before main push; scout patrols already short-handed."
                ws_set "last_major_event" "Meyiu pressed Marn on gang timeline using captured token."
                log_narrative "Sheriff Marn read the token marks — retaliation probe expected by dusk."
                echo
                echo "Marn's jaw tightens. \"Probe first. Then punishment. We have hours, not days.\""
                sera_says "Then we spend those hours like coin — not like confetti."
                sera_apply_bond_change 2 0 0
            else
                echo "You have no gang token to show. Marn can only guess from rumor."
                sera_says "Words without proof still beat panic. But barely."
            fi
            ;;
        3)
            ws_set "medicine_decoy_set" "yes"
            ws_set "last_major_event" "Decoy posted at medicine room to draw gang attention."
            log_narrative "Meyiu approved Sera's decoy plan at the medicine room."
            echo
            echo "Sera rigs a lantern and moves the crate shadow. \"If they come hungry for medicine, they come to us.\""
            sera_exercise_agency "medicine room triage decoy"
            sera_apply_bond_change 1 2 1
            if [[ $(( RANDOM % 100 )) -lt 35 ]]; then
                echo
                printf '%s%s%s\n' "$RED" "A silhouette tests the alley behind the room — not the main push yet." "$RESET"
                start_encounter "Black Bridge Probe" 10
                return 0
            fi
            ;;
        4)
            echo "You step into the lane. Boots answer from the wrong direction."
            log_narrative "Meyiu rode out from the Sheriff's office seeking contact."
            start_encounter "Black Bridge Scout" 14
            return 0
            ;;
        *)
            echo "The office holds its breath. The village does too."
            ;;
    esac
    read -r -p "Press enter..."
}

# --- Bridge: risk on arrival + deliberate local action ---
scenario_bridge_on_arrival() {
    local alert
    alert=$(ws_get "bridge_alert_level")
    echo
    printf '%s%s%s\n' "$RED" "Iron Bridge — gang ground. The tollhouse smoke tastes like borrowed time." "$RESET"

    # First approach: meaningful chance of contact
    if [[ "$(ws_get "bridge_arrival_scouted")" != "yes" ]]; then
        ws_set "bridge_arrival_scouted" "yes"
        if [[ $(( RANDOM % 100 )) -lt 42 ]]; then
            echo "A picket breaks cover — he saw you the moment you stepped into the open."
            log_narrative "Black Bridge picket spotted Meyiu on approach to Iron Bridge."
            start_encounter "Black Bridge Picket" 12
            return 0
        fi
        echo "You freeze. A patrol passes on the far bank. They didn't see you. Yet."
        ws_set "bridge_alert_level" "heightened"
        log_narrative "Meyiu approached Iron Bridge unseen — for now."
    elif [[ "$alert" == "heightened" && $(( RANDOM % 100 )) -lt 25 ]]; then
        echo "This time the river carries laughter — and a scout turning your way."
        start_encounter "Black Bridge Scout" 14
    fi
}

scenario_bridge_action() {
    echo
    draw_screen_header "${ICON_MAP}IRON BRIDGE — GANG TOLLHOUSE"
    echo "Smoke. Iron water. Voices that don't sound like villagers."
    echo
    sera_says "We can learn from a distance. Or we can pay tuition with blood. Choose."
    echo
    printf '  %s[1]%s Watch from the treeline (safer — gather intel)\n' "$GREEN" "$RESET"
    printf '  %s[2]%s Move closer — test what they will do\n' "$YELLOW" "$RESET"
    printf '  %s[3]%s Pull back — live to choose a smarter day\n' "$DIM" "$RESET"
    echo

    read -r -p "> " choice
    case "$choice" in
        1)
            ws_set "bridge_intel" "9-12 fighters; Toll-Saint champion; Garran Pike leads"
            ws_set "bridge_alert_level" "watched"
            log_narrative "Meyiu and Sera watched the Iron Bridge gang from cover."
            echo
            echo "You count nine visible fighters, maybe more inside. A shield-man the size of a door."
            sera_says "Now we know the price of walking in. We don't pay it today."
            sera_apply_bond_change 1 1 1
            ;;
        2)
            echo "Gravel shifts. Someone shouts. Steel answers."
            log_narrative "Meyiu tested the bridge approach — contact forced."
            start_encounter "Black Bridge Scout" 14
            ;;
        3)
            echo "You fade back into the treeline. The bridge keeps its secrets."
            log_narrative "Meyiu withdrew from Iron Bridge before contact."
            sera_says "Smart. Curiosity isn't courage if it gets us killed for free."
            ;;
        *)
            echo "The river waits."
            ;;
    esac
    read -r -p "Press enter..."
}