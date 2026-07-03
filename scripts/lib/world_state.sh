# scripts/lib/world_state.sh — world_state key helpers

ws_get() {
    db_query "SELECT value FROM world_state WHERE state_key='${1}';"
}

ws_set() {
    local key="$1" val="$2"
    local esc
    esc=$(printf '%s' "$val" | sed "s/'/''/g")
    db_exec "INSERT INTO world_state (state_key, value) VALUES ('${key}', '${esc}') ON DUPLICATE KEY UPDATE value='${esc}';"
}