# scripts/lib/mode.sh — Environment lane: dev (author) vs public (browser players)
#
# dev:     local Life-2, LLM handoff, author checkpoint seed for --fresh
# public:  nerdverse_web_* sessions, telemetry, cage entry, arc-start seed
#
# Set NERDVERSE_MODE explicitly on servers; auto-detected from NERDVERSE_PUBLIC_TERMINAL.

mode_resolve() {
    if [[ -n "${NERDVERSE_MODE:-}" ]]; then
        printf '%s' "${NERDVERSE_MODE}"
        return
    fi
    if [[ "${NERDVERSE_PUBLIC_TERMINAL:-}" == "1" ]]; then
        printf 'public'
    else
        printf 'dev'
    fi
}

mode_is_public() {
    [[ "$(mode_resolve)" == "public" ]]
}

mode_is_dev() {
    ! mode_is_public
}

mode_allows_handoff() {
    mode_is_dev
}

mode_allows_telemetry() {
    mode_is_public
}

mode_allows_breakthrough_on_start() {
    mode_is_dev
}