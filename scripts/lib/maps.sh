# maps.sh — sourced by play.sh

resolve_location_key() {
    if [[ -n "${LOCATION_KEY:-}" ]]; then
        echo "$LOCATION_KEY"
        return
    fi
    travel_infer_key_from_display "${1:-${LOCATION:-}}"
}

fetch_map_ascii() {
    local key="$1"
    # --raw preserves literal newlines and box-drawing characters in the whimsical art
    echo "SELECT ascii FROM maps WHERE map_key='${key//\'/\'\'}' LIMIT 1;" \
        | $MARIADB --silent --skip-column-names --raw 2>/dev/null || echo ""
}

show_world_map() {
    local title ascii
    title=$(db_query "SELECT title FROM maps WHERE map_key='world' LIMIT 1;")
    ascii=$(fetch_map_ascii "world")
    if [[ -z "$ascii" ]]; then
        echo "(The world map has not yet been drawn. Keep exploring.)"
        return
    fi
    # Title is now provided by draw_screen_header in the render wrapper
    echo "$ascii"
    log_narrative "Meyiu spread the world map across a flat rock and studied the shape of everything known."
}

show_local_map() {
    local key ascii
    key=$(resolve_location_key "${LOCATION:-}")
    ascii=$(fetch_map_ascii "$key")
    if [[ -z "$ascii" ]]; then
        echo "You take a slow walk around and commit the details of this place to memory."
        echo "(No detailed local map has been inked yet.)"
    else
        echo "$ascii"
    fi
    log_narrative "Meyiu paused and really looked at the ${LOCATION:-surroundings}, fixing it in memory."
}
