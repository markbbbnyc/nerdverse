# scripts/lib/sera.sh — Sera agency, trust & bond (0–100 emotional meters)
#
# Design: actions > words. Meaningful shared moments move the needle slowly.
# Decay only when a turn passes without real connection. Never inflate past 100.
# "Shared" and "Sera led" counters are unbounded memory; Trust/Bond are bounded feel.

# Set by apply functions when this turn earned trust or bond; play.sh reads for decay.
SERA_TURN_HAD_GAIN=0

load_sera_state() {
    SERA_TRUST=$(db_query "SELECT value FROM world_state WHERE state_key='sera_trust_level';")
    SERA_BOND=$(db_query "SELECT value FROM world_state WHERE state_key='sera_bond_level';")
    SERA_MOOD=$(db_query "SELECT value FROM world_state WHERE state_key='sera_mood';")
    SERA_GRAIL=$(db_query "SELECT value FROM world_state WHERE state_key='sera_personal_grail';")
    SERA_PRINCIPLES=$(db_query "SELECT value FROM world_state WHERE state_key='sera_core_principles';")
    SERA_ROMANTIC=$(db_query "SELECT value FROM world_state WHERE state_key='sera_romantic_tension';")
    SERA_JOINT=$(db_query "SELECT value FROM world_state WHERE state_key='sera_joint_experiences';")
    SERA_LEAD=$(db_query "SELECT value FROM world_state WHERE state_key='sera_leadership_moments';")
    SERA_LAST_ACTION=$(db_query "SELECT value FROM world_state WHERE state_key='sera_last_action';")
    SERA_RECENT_EVENT=$(db_query "SELECT value FROM world_state WHERE state_key='sera_recent_event';")
}

sera_update_state() {
    local key="$1"
    local value="$2"
    db_exec "UPDATE world_state SET value='${value}' WHERE state_key='${key}';"
}

# Clamp emotional meters to 0–100 (never "149%").
sera_clamp_meter() {
    local v="${1:-0}"
    [[ "$v" -lt 0 ]] && v=0
    [[ "$v" -gt 100 ]] && v=100
    echo "$v"
}

# One-time hygiene for saves that inflated before the cap existed.
sera_normalize_saved_stats() {
    load_sera_state
    local t b
    t=$(sera_clamp_meter "${SERA_TRUST:-35}")
    b=$(sera_clamp_meter "${SERA_BOND:-25}")
    if [[ "$t" != "${SERA_TRUST}" || "$b" != "${SERA_BOND}" ]]; then
        sera_update_state "sera_trust_level" "$t"
        sera_update_state "sera_bond_level" "$b"
    fi
}

# Core apply: single place for all trust/bond changes.
# Optional: count as a shared-life moment (increments joint counter).
sera_apply_bond_change() {
    local trust_delta="${1:-0}"
    local bond_delta="${2:-0}"
    local count_joint="${3:-0}"

    load_sera_state
    local t b
    t=$(sera_clamp_meter $(( ${SERA_TRUST:-35} + trust_delta )) )
    b=$(sera_clamp_meter $(( ${SERA_BOND:-25} + bond_delta )) )

    sera_update_state "sera_trust_level" "$t"
    sera_update_state "sera_bond_level" "$b"

    if [[ $count_joint -eq 1 ]]; then
        local new_joint=$(( ${SERA_JOINT:-0} + 1 ))
        db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_joint_experiences\", \"$new_joint\") ON DUPLICATE KEY UPDATE value = \"$new_joint\";"
    fi

    if [[ $trust_delta -gt 0 || $bond_delta -gt 0 ]]; then
        SERA_TURN_HAD_GAIN=1
    fi

    SERA_TRUST=$t
    SERA_BOND=$b
}

# Decay only on turns where nothing real happened — not after meaningful connection.
apply_sera_decay() {
    if [[ "${SERA_TURN_HAD_GAIN:-0}" -eq 1 ]]; then
        SERA_TURN_HAD_GAIN=0
        return 0
    fi
    load_sera_state
    local t b
    t=$(sera_clamp_meter $(( ${SERA_TRUST:-35} - 1 )) )
    b=$(sera_clamp_meter $(( ${SERA_BOND:-25} - 1 )) )
    sera_update_state "sera_trust_level" "$t"
    sera_update_state "sera_bond_level" "$b"
    SERA_TURN_HAD_GAIN=0
}

# Meaningful shared action (called alone — never stacked with agency on same turn).
sera_record_joint_experience() {
    load_sera_state
    local gain_t=1 gain_b=1
    if [[ "$SERA_LAST_ACTION" == *"joint"* ]]; then
        gain_t=0
        gain_b=0
    fi
    if [[ $gain_t -gt 0 || $gain_b -gt 0 ]]; then
        sera_apply_bond_change "$gain_t" "$gain_b" 1
        sera_update_state "sera_last_action" "joint"
        sera_update_state "sera_recent_event" "meaningful_action"
    fi
}

sera_exercise_agency() {
    load_sera_state

    local choice_context="$1"
    local trust_change=0
    local bond_change=0
    local count_joint=0
    local mood_shift=""
    local her_action=""
    local her_words=""

    local is_repeat=0
    if [[ -n "$SERA_LAST_ACTION" && "$choice_context" == *"$SERA_LAST_ACTION"* ]]; then
        is_repeat=1
    fi

    case "$choice_context" in
        *"defend"*|*"protect"*|*"measured"*|*"scouts"*)
            trust_change=2
            bond_change=2
            count_joint=1
            her_words="You meant it. Not just talk. I saw it in the orders — and in what you were willing to risk yourself."
            her_action="Sera takes initiative (30% lead): \"I'll decide who among the villagers gets the first of the limited healing and set the fallback signal with the scouts. You focus on the Sheriff. We split the load.\""
            if [[ "${SERA_BOND:-0}" -ge 35 ]]; then
                her_action="$her_action She later quietly sets a simple watch rotation with two villagers based on her own judgment."
            fi
            sera_update_state "sera_recent_event" "meaningful_action"
            ;;
        *"risk"*|*"heroic"*|*"noble"*|*"but"*)
            trust_change=-3
            bond_change=-2
            mood_shift="cutting"
            her_words="That was the kind of brave that gets good people killed. We don't have that luxury."
            ;;
        *"listened"*|*"saw me"*|*"didn't ask me to shrink"*)
            if [[ "$SERA_LAST_ACTION" == *"defend"* || "$SERA_LAST_ACTION" == *"joint"* || "$SERA_LAST_ACTION" == *"medicine"* ]]; then
                bond_change=1
                trust_change=1
                her_words="You looked at me like I'm allowed to be exactly this sharp and still worth keeping around."
            else
                trust_change=0
                bond_change=0
                her_words="I heard you. Let's see it in what we do next."
            fi
            if [[ "$SERA_ROMANTIC" == *"emerging"* ]]; then
                her_action="She stays a little closer while you work. No big gesture — just presence that wasn't there before."
            fi
            ;;
        *"follow"*|*"medicine"*|*"room"*)
            trust_change=1
            bond_change=2
            count_joint=1
            her_words="Good. Let's get to work then. The sooner we know what's in this crate, the better."
            her_action="Sera moves to the crate and starts carefully opening it, taking the lead on the inspection."
            sera_update_state "sera_recent_event" "meaningful_action"
            ;;
        *"talk"*)
            if [[ "$SERA_RECENT_EVENT" == "meaningful_action" ]]; then
                bond_change=1
                trust_change=1
                sera_update_state "sera_recent_event" ""
                her_words="I heard you. That lands differently after what we just went through together."
            elif [[ "$SERA_LAST_ACTION" == *"defend"* || "$SERA_LAST_ACTION" == *"joint"* || "$SERA_LAST_ACTION" == *"medicine"* ]]; then
                bond_change=1
                trust_change=0
                her_words="I heard you. That means something after what we just did."
            else
                bond_change=0
                trust_change=0
                her_words="I hear you. Now let's show it with what we do."
            fi
            ;;
        *)
            her_words="We'll see what that actually costs."
            ;;
    esac

    if [[ $is_repeat -eq 1 && "$choice_context" != *"defend"* ]]; then
        trust_change=$(( trust_change / 2 ))
        bond_change=$(( bond_change / 2 ))
    fi
    if [[ $trust_change -eq 0 && $bond_change -eq 0 && $is_repeat -eq 1 && -z "$mood_shift" ]]; then
        mood_shift="bored"
        her_words="We've been over this. Let's do something that actually moves us."
    fi

    if [[ $trust_change -ne 0 || $bond_change -ne 0 ]]; then
        sera_apply_bond_change "$trust_change" "$bond_change" "$count_joint"
    fi
    [[ -n "$mood_shift" ]] && sera_update_state "sera_mood" "$mood_shift"

    if [[ -n "$choice_context" ]]; then
        sera_update_state "sera_last_action" "$choice_context"
    fi
    if [[ "$choice_context" == *"defend"* || "$choice_context" == *"medicine"* || "$choice_context" == *"follow"* ]]; then
        sera_update_state "sera_recent_event" "meaningful_action"
    fi

    local new_trust=${SERA_TRUST:-35}
    local new_bond=${SERA_BOND:-25}

    if [[ -n "$her_words" ]]; then
        echo
        printf '%sSera:%s "%s"\n' "$YELLOW" "$RESET" "$her_words"
        log_narrative "Sera (choosing the journey): ${her_words}"
    fi

    if [[ $trust_change -gt 0 || $bond_change -gt 0 ]]; then
        if [[ $new_bond -ge 70 ]]; then
            echo -e "${AMBER}Sera looks at you warmly. \"We do this together. I trust you.\"${RESET}"
        elif [[ $new_bond -ge 45 ]]; then
            echo -e "${AMBER}Sera looks at you for a long moment, then nods once. \"Alright. We do this together.\"${RESET}"
        fi
        if [[ $bond_change -ge 2 || $trust_change -ge 2 ]]; then
            log_narrative "Sera explicitly chooses the journey with you."
        fi
    fi

    if [[ -n "$her_action" ]]; then
        echo -e "${GRAY}Sera moves on her own: ${her_action}${RESET}"
        log_narrative "Sera acted independently: ${her_action}"
        local lead=${SERA_LEAD:-0}
        local newlead=$(( lead + 1 ))
        db_exec "INSERT INTO world_state (state_key, value) VALUES (\"sera_leadership_moments\", \"$newlead\") ON DUPLICATE KEY UPDATE value = \"$newlead\";"
    fi

    if [[ $new_trust -lt 20 ]]; then
        echo -e "${DIM}(The choice to stay is more visible right now. And more fragile.)${RESET}"
    fi
}

# Tiny ASCII meter for status line (8 chars).
sera_meter_bar() {
    local value="${1:-0}"
    local filled=$(( value * 8 / 100 ))
    local empty=$(( 8 - filled ))
    local bar=""
    bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
    bar+=$(printf '%*s' "$empty" '' | tr ' ' '░')
    echo "$bar"
}

# Called after combat — ties mechanics to Sera's voice (LLM play continues from here).
sera_react_to_combat() {
    local outcome="$1"
    local enemy_name="${2:-foe}"
    local hp_before="${3:-0}"
    local hp_after="${4:-0}"
    local hp_lost=$(( hp_before - hp_after ))
    [[ $hp_lost -lt 0 ]] && hp_lost=0

    load_sera_state
    local bond=${SERA_BOND:-25}

    echo
    case "$outcome" in
        victory)
            if [[ $hp_lost -eq 0 ]]; then
                sera_says "Clean. You didn't perform bravery — you solved the problem."
                sera_apply_bond_change 1 1 0
            elif [[ $hp_lost -le 3 ]]; then
                sera_says "You paid a little blood and kept your head. I'll take that trade."
                sera_apply_bond_change 1 2 1
            else
                sera_says "You won. Don't confuse surviving with being reckless next time."
                sera_apply_bond_change 0 1 0
            fi
            if [[ $bond -ge 55 ]]; then
                echo -e "${GRAY}Sera checks your wounds without being asked.${RESET}"
            fi
            ws_set "last_major_event" "Meyiu defeated ${enemy_name} (${hp_lost} HP lost)."
            ;;
        defeat)
            sera_says "Stay down. Breathe. We leave before they bring friends."
            sera_apply_bond_change -1 -1 0
            ws_set "last_major_event" "Meyiu was driven back by ${enemy_name}."
            echo -e "${DIM}(The road feels longer when your body says no.)${RESET}"
            ;;
        *)
            sera_says "We walk away while we still can."
            ;;
    esac
    log_narrative "Sera after combat (${outcome} vs ${enemy_name}): trust/bond adjusted."
}