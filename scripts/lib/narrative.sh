# scripts/lib/narrative.sh — Story log & dialogue helpers

log_narrative() {
    local entry="$1"
    local loc="${LOCATION:-Brindleford}"
    local esc_entry esc_loc
    esc_entry=$(printf '%s' "$entry" | sed "s/'/''/g")
    esc_loc=$(printf '%s' "$loc" | sed "s/'/''/g")
    echo "INSERT INTO session_log (log_type, entry, location, character_name)
          VALUES ('NARRATIVE', '$esc_entry', '$esc_loc', 'Sera');" | $MARIADB >/dev/null
}

sera_says() {
    local line="$1"
    printf '%sSera:%s "%s"\n' "$YELLOW" "$RESET" "$line"
    log_narrative "Sera: ${line}"
}