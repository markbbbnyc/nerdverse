# scripts/lib/party.sh — Resolve player/companion rows by is_player flag.
# Used by public terminal UI so banners/HUD show registered names, not hardcoded Meyiu/Sera.

party_player_name() {
    db_query "SELECT name FROM characters WHERE is_player=TRUE ORDER BY id LIMIT 1;"
}

party_player_title() {
    db_query "SELECT title FROM characters WHERE is_player=TRUE ORDER BY id LIMIT 1;"
}

party_player_header() {
    local name title
    name=$(party_player_name)
    title=$(party_player_title)
    name="${name:-Operator}"
    title="${title:-Pilgrim}"
    printf '%s — %s' "$name" "$title"
}

party_companion_name() {
    db_query "SELECT name FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;"
}

party_companion_short() {
    local full="${1:-$(party_companion_name)}"
    printf '%s' "${full%% *}"
}

party_player_id() {
    db_query "SELECT id FROM characters WHERE is_player=TRUE ORDER BY id LIMIT 1;"
}

party_companion_id() {
    db_query "SELECT id FROM characters WHERE is_player=FALSE ORDER BY id LIMIT 1;"
}