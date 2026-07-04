# scripts/lib/ui.sh — AS/400 operator console / arsenal inventory aesthetic
# WarGames-meets-field-ops: professional green-screen that secretly became an RPG.

BOLD=""; RESET=""; GREEN=""; DIM=""; BRIGHT_GREEN=""
AMBER=""; YELLOW=""; CYAN=""; GRAY=""; WHITE=""; RED=""

ICON_MAP="🗺 "
ICON_CHAR="👤 "
ICON_SCROLL="📜 "
ICON_FORGE="⚒ "
ICON_EXIT="⏏ "

declare -a SCREEN_STACK
SCREEN_STACK=("main")

# Screen registry (operator console IDs) — case-based for macOS /bin/bash 3.2
ui_screen_id() {
    local screen="${1:-$(current_screen)}"
    case "$screen" in
        main)             echo "SCR010-MAIN" ;;
        travel)           echo "SCR020-TRVL" ;;
        inventory)        echo "SCR030-INV" ;;
        world_map)        echo "SCR070-MAPW" ;;
        local_map)        echo "SCR071-MAPL" ;;
        character_sheets) echo "SCR090-PERS" ;;
        *)                echo "SCR000-UNKN" ;;
    esac
}

ui_init() {
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        BOLD=$(tput bold 2>/dev/null || printf '\033[1m')
        RESET=$(tput sgr0 2>/dev/null || printf '\033[0m')
        GREEN=$(tput setaf 2 2>/dev/null || printf '\033[32m')
        DIM=$(tput dim 2>/dev/null || printf '\033[2;32m')
        BRIGHT_GREEN=$( { tput bold; tput setaf 2; } 2>/dev/null || printf '\033[1;32m' )
        AMBER=$(tput setaf 3 2>/dev/null || printf '\033[33m')
        YELLOW=$( { tput bold; tput setaf 3; } 2>/dev/null || printf '\033[1;33m' )
        CYAN=$(tput setaf 6 2>/dev/null || printf '\033[36m')
        GRAY=$(printf '\033[38;5;250m')
        WHITE=$(tput setaf 7 2>/dev/null || printf '\033[37m')
        RED=$(tput setaf 1 2>/dev/null || printf '\033[31m')
    else
        local _e
        _e=$(printf '\033')
        BOLD="${_e}[1m"; RESET="${_e}[0m"; GREEN="${_e}[32m"; DIM="${_e}[2;32m"
        BRIGHT_GREEN="${_e}[1;32m"; AMBER="${_e}[33m"; YELLOW="${_e}[1;33m"
        CYAN="${_e}[36m"; GRAY="${_e}[38;5;250m"; WHITE="${_e}[37m"; RED="${_e}[31m"
    fi
}

get_cols() {
    if command -v tput >/dev/null 2>&1; then
        tput cols 2>/dev/null || echo 80
    elif command -v stty >/dev/null 2>&1; then
        stty size 2>/dev/null | awk '{print $2}' || echo 80
    else
        echo 80
    fi
}

get_lines() {
    if command -v tput >/dev/null 2>&1; then
        tput lines 2>/dev/null || echo 24
    elif command -v stty >/dev/null 2>&1; then
        stty size 2>/dev/null | awk '{print $1}' || echo 24
    else
        echo 24
    fi
}

# ttyd / web terminals sometimes report 0 columns — never draw a zero-width box.
ui_box_width() {
    local cols w
    cols=$(get_cols)
    if [[ ! "$cols" =~ ^[0-9]+$ ]] || (( cols < 50 )); then
        cols=72
    fi
    w=$(( cols > 78 ? 78 : cols - 2 ))
    (( w < 56 )) && w=56
    printf '%s' "$w"
}

ui_fill_repeat() {
    local count="$1" char="$2" i
    for (( i=0; i<count; i++ )); do
        printf '%s' "$char"
    done
}

ui_box_pad_line() {
    local width="$1"
    shift
    local content="$*" vis pad
    vis=$(visible_len "$content")
    pad=$(( width - vis ))
    (( pad < 0 )) && pad=0
    printf '%s%*s' "$content" "$pad" ""
}

# Compact layout for MacBook / short terminals (default when height ≤ 30 rows).
ui_use_compact() {
    [[ "${NERDVERSE_COMPACT:-}" == "0" ]] && return 1
    [[ "${NERDVERSE_COMPACT:-}" == "1" ]] && return 0
    local lines
    lines=$(get_lines)
    [[ "${lines:-24}" -le 30 ]]
}

visible_len() {
    local s="$1"
    s=$(printf %s "$s" | sed -E 's/\x1b\[[0-9;]*m//g' 2>/dev/null || echo "$s")
    echo "${#s}"
}

center_line() {
    local text="$1"
    local width=${2:-$(get_cols)}
    local len pad
    len=$(visible_len "$text")
    pad=$(( (width - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%*s%s\n" "$pad" "" "$text"
}

# Undo SQL-style doubled quotes for display (Sera''s → Sera's).
ui_unescape_sql() {
    printf '%s' "$1" | sed "s/''/'/g"
}

# Lowercase for bash 3.2 (macOS /bin/bash has no ${var,,}).
_ui_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Normalize F-keys and aliases → menu numbers / f3 / 0
normalize_choice() {
    local raw
    raw=$(_ui_lower "$1")
    raw="${raw//[[:space:]]/}"
    # Strip common prefixes: PF01, F01
    raw="${raw#pf}"
    case "$raw" in
        f1|f01|pf1)  echo "1" ;;
        f2|f02|pf2)  echo "2" ;;
        f3|f03|pf3|back|exit|cancel) echo "f3" ;;
        f4|f04|pf4)  echo "4" ;;
        f5|f05|pf5|refresh) echo "f5" ;;
        f7|f07|pf7)  echo "7" ;;
        f8|f08|pf8)  echo "8" ;;
        f9|f09|pf9)  echo "9" ;;
        f10|f12|pf12|signoff|logout) echo "0" ;;
        q|quit|x)     echo "0" ;;
        "")           echo "" ;;
        *)            echo "$raw" ;;
    esac
}

game_input_tty() {
    local tty="${NERDVERSE_TTY:-/dev/tty}"
    if [[ -e "$tty" ]] && [[ -r "$tty" ]] && [[ -c "$tty" || -w "$tty" ]]; then
        printf '%s' "$tty"
    else
        printf '%s' "/dev/stdin"
    fi
}

# Read menu input from the real TTY (web ttyd); ignore empty/control noise.
read_game_choice() {
    local prompt_shown="${1:-0}"
    local choice tty
    tty=$(game_input_tty)
    while true; do
        if [[ "$prompt_shown" != "1" ]]; then
            printf '> ' >"$tty" 2>/dev/null || printf '> '
        fi
        if [[ "$tty" == "/dev/stdin" ]]; then
            read -r choice
        else
            read -r choice <"$tty" 2>/dev/null || read -r choice
        fi
        choice="${choice//$'\r'/}"
        choice=$(printf '%s' "$choice" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        case "$choice" in
            ''|$'\e'|$'\e'*|$'\x1b'*)
                [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]] && continue
                ;;
            *)
                printf '%s' "$choice"
                return 0
                ;;
        esac
        [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" != "1" ]] && break
    done
    printf '%s' "$choice"
}

read_game_confirm() {
    local msg="${1:-Press enter...}"
    local tty
    tty=$(game_input_tty)
    printf '%s' "$msg"
    if [[ "$tty" == "/dev/stdin" ]]; then
        read -r _dummy
    else
        read -r _dummy <"$tty" 2>/dev/null || read -r _dummy
    fi
}

is_valid_main_choice() {
    case "$1" in
        f5|1|2|3|4|7|8|9|0|travel|go|walk|inventory|inv|i|talk|sera|t|act|do|local|world|map|maps|localmap|look|here|sheet|sheets|char|q|quit|exit)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_overlay_return_choice() {
    case "$1" in
        f5|0|f3|back|b) return 0 ;;
        *) return 1 ;;
    esac
}

# Top operator banner — arsenal inventory program that forgot it became a game
draw_operator_banner() {
    local scr db_label op_name
    scr=$(ui_screen_id "${1:-$(current_screen)}")
    op_name="OPERATOR"
    if declare -f party_player_name >/dev/null 2>&1; then
        op_name=$(party_player_name 2>/dev/null || echo "OPERATOR")
        [[ -z "$op_name" ]] && op_name="OPERATOR"
    fi
    db_label=""
    if declare -f game_db_label >/dev/null 2>&1 && [[ -n "${DB_NAME:-}" ]]; then
        db_label=$(game_db_label "${DB_NAME}" 2>/dev/null || true)
    fi
    local w line_body
    w=$(ui_box_width)

    if ui_use_compact && [[ "${1:-$(current_screen)}" == "main" ]]; then
        [[ -z "$db_label" && -n "${DB_NAME:-}" ]] && db_label="${DB_NAME}"
        line_body=$(printf ' NERDVERSE OS/400  %s│%s %s  %s│%s %s  %s│%s %s' \
            "$DIM" "$RESET" "$scr" "$DIM" "$RESET" "$op_name" "$DIM" "$RESET" "${db_label:-PUBLIC}")
        printf '%s╔' "$BRIGHT_GREEN"
        ui_fill_repeat "$w" "═"
        printf '╗%s\n' "$RESET"
        printf '%s║%s' "$BRIGHT_GREEN" "$RESET"
        ui_box_pad_line "$w" "$line_body"
        printf '%s║%s\n' "$BRIGHT_GREEN" "$RESET"
        printf '%s╚' "$BRIGHT_GREEN"
        ui_fill_repeat "$w" "═"
        printf '╝%s\n' "$RESET"
        return
    fi

    printf '%s╔' "$BRIGHT_GREEN"
    ui_fill_repeat "$w" "═"
    printf '╗%s\n' "$RESET"
    printf '%s║%s' "$BRIGHT_GREEN" "$RESET"
    printf ' NERDVERSE OS/400  %s│%s  ARSENAL INVENTORY / FIELD OPS  %s│%s  %s%s' \
        "$DIM" "$RESET" "$DIM" "$RESET" "$scr" "$RESET"
    local line1_len=$(( 19 + 3 + 33 + 3 + ${#scr} ))
    printf '%*s%s║%s\n' $(( w - line1_len )) "" "$BRIGHT_GREEN" "$RESET"

    printf '%s║%s' "$BRIGHT_GREEN" "$RESET"
    printf ' SUBSYS: BRINDLEFORD VALE  %s│%s  OP: %s  %s│%s  CLASS: PILGRIM-OPS' \
        "$DIM" "$RESET" "$op_name" "$DIM" "$RESET"
    local line2_len=54
    printf '%*s%s║%s\n' $(( w - line2_len )) "" "$BRIGHT_GREEN" "$RESET"

    if [[ -n "$db_label" ]]; then
        printf '%s║%s' "$BRIGHT_GREEN" "$RESET"
        printf ' SAVE: %s%s%s  %s│%s  SESSION: TTY-ACTIVE  %s│%s  WARGAMES-OK' \
            "$CYAN" "${db_label}" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET"
        local line3_len=$(( 7 + ${#db_label} + 3 + 24 + 3 + 11 ))
        printf '%*s%s║%s\n' $(( w - line3_len )) "" "$BRIGHT_GREEN" "$RESET"
    fi
    printf '%s╚' "$BRIGHT_GREEN"
    ui_fill_repeat "$w" "═"
    printf '╝%s\n' "$RESET"
}

draw_screen_header() {
    local title="$1"
    local w line title_vis used right_pad sid
    w=$(ui_box_width)
    line=$(printf '%*s' "$w" '' | tr ' ' '─')
    sid=$(ui_screen_id)

    printf '%s┌%s┐%s\n' "$GREEN" "$line" "$RESET"
    printf '%s│%s %s' "$GREEN" "$RESET" "$title"
    title_vis=$(visible_len "$title")
    used=$(( 2 + title_vis ))
    right_pad=$(( w - used - ${#sid} - 2 ))
    (( right_pad < 0 )) && right_pad=0
    printf '%*s%s %s│%s\n' "$right_pad" "" "$DIM${sid}${RESET}" "$GREEN" "$RESET"
    printf '%s└%s┘%s\n' "$GREEN" "$line" "$RESET"
}

# Ledger-style menu row with dotted leader
draw_ledger_option() {
    local num="$1"
    local label="$2"
    local key_hint="${3:-}"
    local width=56
    local num_fmt label_plain dots_count
    num_fmt=$(printf '%02d' "$num" 2>/dev/null || printf '%s' "$num")
    label_plain="$label"
    dots_count=$(( width - ${#label_plain} - ${#num_fmt} - 6 ))
    (( dots_count < 2 )) && dots_count=2
    local dots
    dots=$(printf '%*s' "$dots_count" '' | tr ' ' '.')

    printf '  %s%s%s %s%s%s' "$BRIGHT_GREEN" "$num_fmt" "$RESET" "$GREEN" "$label_plain" "$RESET"
    printf ' %s' "$dots"
    if [[ -n "$key_hint" ]]; then
        printf ' %s[%s]%s' "$DIM" "$key_hint" "$RESET"
    fi
    echo
}

draw_location_panel() {
    local loc_key="${LOCATION_KEY:-forge}"
    local loc_name
    loc_name=$(ui_unescape_sql "${LOCATION:-Unknown}")
    local danger mill food
    danger=$(db_query "SELECT danger_level FROM locations WHERE key_name='${loc_key}' LIMIT 1;" 2>/dev/null || echo "0")
    danger="${danger:-0}"
    mill=$(ws_get "mill_status" 2>/dev/null || echo "")
    food=$(ws_get "brindleford_food_supply" 2>/dev/null || echo "")

    local threat_bar i filled
    filled=$(( danger * 5 / 5 ))
    (( filled > 5 )) && filled=5
    threat_bar=""
    for (( i=0; i<5; i++ )); do
        if (( i < filled )); then threat_bar+="█"; else threat_bar+="░"; fi
    done

    echo
    printf '%s┌─ WHERE YOU ARE ── FIELD GRID ─────────────────────────────────────┐%s\n' "$CYAN" "$RESET"
    printf '%s│%s LOC %-8s │ %s%-42s%s │\n' "$CYAN" "$RESET" "$loc_key" "$WHITE" "${loc_name:0:42}" "$RESET"
    printf '%s│%s THREAT %s%s%s (lvl %s/5)  │  MILL: %-11s  │  FOOD: %-10s │\n' \
        "$CYAN" "$RESET" "$AMBER" "$threat_bar" "$RESET" "$danger" "${mill:---}" "${food:---}"
    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$CYAN" "$RESET"
}

draw_sera_operator_glyph() {
    local bond="${1:-25}"
    local glyph msg color comp
    comp=$(party_companion_short 2>/dev/null || echo "Guide")
    if [[ "$bond" -ge 80 ]]; then
        glyph="◈"; msg="${comp}: has chosen this road"; color="$AMBER"
    elif [[ "$bond" -ge 55 ]]; then
        glyph="◆"; msg="${comp}: walking with you"; color="$GREEN"
    elif [[ "$bond" -ge 30 ]]; then
        glyph="◆"; msg="${comp}: still choosing"; color="$YELLOW"
    else
        glyph="◇"; msg="${comp}: weighing whether to stay"; color="$DIM"
    fi
    printf '  %s%s %s%s   %s(COMPANION CHANNEL — autonomous player)%s\n' \
        "$color" "$glyph" "$msg" "$RESET" "$DIM" "$RESET"
}

draw_world_clock_line() {
    local threat chapter
    threat=$(ws_get "black_bridge_gang_status" 2>/dev/null || echo "")
    chapter=$(ws_get "current_chapter" 2>/dev/null || echo "")
    [[ -z "$threat" ]] && threat="Unknown pressure on the vale."
    printf '  %s⏱ %s%s  %s│%s  %s%s%s\n' \
        "$DIM" "Light failing" "$RESET" "$DIM" "$RESET" "$GRAY" "${chapter:-The road continues.}" "$RESET"
    printf '  %s⚠ %s%s\n' "$DIM" "${threat:0:68}" "$RESET"
}

draw_main_hud_compact() {
    local bond="${1:-25}"
    local loc_key="${LOCATION_KEY:-?}"
    local loc_name threat chapter glyph
    loc_name=$(ui_unescape_sql "${LOCATION:-?}")
    threat=$(ws_get "black_bridge_gang_status" 2>/dev/null || echo "")
    chapter=$(ws_get "current_chapter" 2>/dev/null || echo "")
    if [[ "$bond" -ge 80 ]]; then glyph="◈"
    elif [[ "$bond" -ge 55 ]]; then glyph="◆"
    else glyph="◇"; fi
    load_player 2>/dev/null || true
    load_sera 2>/dev/null || true
    load_sera_state 2>/dev/null || true
    if declare -f prog_load_sera_progress >/dev/null 2>&1; then
        prog_load_sera_progress
    fi
    local t b sera_lv sera_rxp sera_rxmax comp_short w inner line_body
    sera_lv="${SERA_PROG_LEVEL:-1}"
    sera_rxp="${SERA_ROAD_XP:-0}"
    sera_rxmax="${SERA_ROAD_XP_MAX:-10}"
    comp_short="Guide"
    if declare -f party_companion_short >/dev/null 2>&1; then
        comp_short=$(party_companion_short 2>/dev/null || echo "Guide")
    elif [[ -n "${COMPANION_DISPLAY_NAME:-}" ]]; then
        comp_short="${COMPANION_DISPLAY_NAME}"
    fi
    t=$(sera_clamp_meter "${SERA_TRUST:-35}" 2>/dev/null || echo "35")
    b=$(sera_clamp_meter "${SERA_BOND:-25}" 2>/dev/null || echo "25")
    local plvl
    plvl=$(db_query "SELECT prog_level FROM characters WHERE is_player=TRUE LIMIT 1;" 2>/dev/null || echo "1")
    w=$(ui_box_width)
    inner=$w

    printf '%s┌' "$CYAN"
    ui_fill_repeat "$w" "─"
    printf '┐%s\n' "$RESET"
    line_body=$(printf ' %-10s %-24s HP %2d/%-2d  Lv%-2s  %d silver' \
        "$loc_key" "${loc_name:0:24}" "${CUR_HP:-?}" "${MAX_HP:-?}" "$plvl" "${COINS:-0}")
    printf '%s│%s' "$CYAN" "$RESET"
    ui_box_pad_line "$inner" "$line_body"
    printf '%s│%s\n' "$CYAN" "$RESET"
    line_body=$(printf ' %s  HP %2d/%-2d  Road %2d/%-2d  Lv%-2s' \
        "${comp_short:0:12}" "${SERA_HP:-0}" "${SERA_MAX:-0}" "$sera_rxp" "$sera_rxmax" "$sera_lv")
    printf '%s│%s' "$CYAN" "$RESET"
    ui_box_pad_line "$inner" "$line_body"
    printf '%s│%s\n' "$CYAN" "$RESET"
    line_body=$(printf ' %sTrust %3d/100%s   %sBond %3d/100%s   %s%s%s' \
        "$DIM" "$t" "$RESET" "$DIM" "$b" "$RESET" "$AMBER" "$glyph" "$RESET")
    printf '%s│%s' "$CYAN" "$RESET"
    ui_box_pad_line "$inner" "$line_body"
    printf '%s│%s\n' "$CYAN" "$RESET"
    [[ "${SERA_BREAKTHROUGH_PENDING:-0}" -eq 1 ]] && {
        line_body=$(printf ' %s◆ %s BREAKTHROUGH READY%s' "$AMBER" "$comp_short" "$RESET")
        printf '%s│%s' "$CYAN" "$RESET"
        ui_box_pad_line "$inner" "$line_body"
        printf '%s│%s\n' "$CYAN" "$RESET"
    }
    line_body=$(printf ' %s%s%s' "$GRAY" "${chapter:-The road continues.}" "$RESET")
    printf '%s│%s' "$CYAN" "$RESET"
    ui_box_pad_line "$inner" "$line_body"
    printf '%s│%s\n' "$CYAN" "$RESET"
    line_body=$(printf ' ⚠ %s%s%s' "$DIM" "${threat:0:58}" "$RESET")
    printf '%s│%s' "$CYAN" "$RESET"
    ui_box_pad_line "$inner" "$line_body"
    printf '%s│%s\n' "$CYAN" "$RESET"
    printf '%s└' "$CYAN"
    ui_fill_repeat "$w" "─"
    printf '┘%s\n' "$RESET"
}

draw_pf_key_strip() {
    local screen="${1:-$(current_screen)}"
    if ui_use_compact && [[ "$screen" == "main" ]]; then
        printf '  %sPF:%s F1Go F2Inv F4Act F7Map F8Grid F9Rec %sF12Out%s\n' \
            "$DIM" "$RESET" "$AMBER" "$RESET"
        return
    fi
    echo
    printf '%s┌─ PF-KEY STRIP ── FUNCTION KEYS ───────────────────────────────────┐%s\n' "$DIM" "$RESET"
    case "$screen" in
        main)
            printf '%s│%s  %sF1%s Travel   %sF2%s Manifest   %sF3%s —   %sF4%s Act-Here   %sF7%s World   %sF8%s Grid   %sF9%s Records   %sF12%s Signoff %s│%s\n' \
                "$DIM" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$DIM" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$AMBER" "$RESET" "$DIM" "$RESET"
            ;;
        travel)
            printf '%s│%s  %sF3%s Back   %s1-9%s Select route   %sEnter%s Confirm   %s0%s Remain at grid %s│%s\n' \
                "$DIM" "$RESET" "$GREEN" "$RESET" "$DIM" "$RESET" "$GRAY" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET"
            ;;
        *)
            printf '%s│%s  %sF3%s Back   %sF5%s Refresh   %s0%s Return to ledger %s│%s\n' \
                "$DIM" "$RESET" "$GREEN" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET" "$DIM" "$RESET"
            ;;
    esac
    printf '%s└──────────────────────────────────────────────────────────────────┘%s\n' "$DIM" "$RESET"
    printf '  %s▸ NERDVERSE TTY%s  %s│%s  nginx → tmux → ttyd → you fell into the operator console.\n' "$GRAY" "$RESET" "$DIM" "$RESET"
}

draw_footer() {
    draw_pf_key_strip "$(current_screen)"
}

current_screen() {
    local idx=$(( ${#SCREEN_STACK[@]} - 1 ))
    echo "${SCREEN_STACK[$idx]}"
}

push_screen() {
    SCREEN_STACK+=("$1")
}

pop_screen() {
    if (( ${#SCREEN_STACK[@]} > 1 )); then
        local idx=$(( ${#SCREEN_STACK[@]} - 1 ))
        unset "SCREEN_STACK[$idx]"
    fi
}

clear_screen() {
    if [[ -t 1 ]]; then
        if command -v tput >/dev/null 2>&1; then
            tput clear 2>/dev/null || printf '\033[2J\033[H'
        else
            printf '\033[2J\033[H'
        fi
    fi
}

ui_init