# scripts/lib/telemetry.sh — Public-terminal engagement telemetry (JSONL)

tel_init() {
    TELEMETRY_DIR="${NERDVERSE_TELEMETRY_DIR:-/var/lib/nerdverse/telemetry}"
    TELEMETRY_FILE="${TELEMETRY_DIR}/events.jsonl"
    TELEMETRY_STATS="${TELEMETRY_DIR}/stats.json"
    mkdir -p "${TELEMETRY_DIR}" 2>/dev/null || true
}

tel_json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

tel_event() {
    local event_type="${1:-event}"
    local screen="${2:-}"
    local choice="${3:-}"
    local detail="${4:-}"

    [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]] || return 0
    tel_init

    local ts session db player
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    session="${NERDVERSE_SESSION_ID:-unknown}"
    db="${DB_NAME:-}"
    player="${NERDVERSE_PLAYER_NAME:-}"

    {
        printf '{"ts":"%s","session":"%s","db":"%s","player":"%s","type":"%s","screen":"%s","choice":"%s","detail":"%s"}\n' \
            "$(tel_json_escape "$ts")" \
            "$(tel_json_escape "$session")" \
            "$(tel_json_escape "$db")" \
            "$(tel_json_escape "$player")" \
            "$(tel_json_escape "$event_type")" \
            "$(tel_json_escape "$screen")" \
            "$(tel_json_escape "$choice")" \
            "$(tel_json_escape "$detail")"
    } >> "${TELEMETRY_FILE}" 2>>"${TELEMETRY_DIR}/.write-errors.log" || true

    case "$event_type" in
        session_start|session_end|wizard_complete|wizard_abandon)
            tel_refresh_stats_sync
            ;;
        menu_choice)
            tel_refresh_stats_async
            ;;
    esac
}

tel_refresh_stats_sync() {
    local root="${NERDVERSE_INSTALL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local agg="${root}/scripts/telemetry_aggregate.sh"
    [[ -f "$agg" ]] || return 0
    bash "$agg" >/dev/null 2>&1 || true
}

tel_refresh_stats_async() {
    local root="${NERDVERSE_INSTALL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local agg="${root}/scripts/telemetry_aggregate.sh"
    [[ -f "$agg" ]] || return 0
    ( bash "$agg" >/dev/null 2>&1 & ) || true
}