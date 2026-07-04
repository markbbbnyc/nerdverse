#!/usr/bin/env bash
# nerdverse-cage.sh — Public terminal jail: game only, no interactive shell.
# Invoked by ttyd as nerdverse-play. Each connection gets:
#   NERDVERSE_SESSION_DIR=/var/lib/nerdverse/sessions/{id}/
#   NERDVERSE_ACTIVE_DB_FILE=.../active_db  →  nerdverse_web_{hex} only
# Registration wizard runs once per tab; play.sh refuses non-web databases.

set -euo pipefail

INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
SESSION_ROOT="${NERDVERSE_SESSION_ROOT:-/var/lib/nerdverse/sessions}"
SESSION_ID="${NERDVERSE_SESSION_ID:-ttyd_${TTYD_PID:-$$}_$RANDOM}"

export NERDVERSE_PUBLIC_TERMINAL=1
export NERDVERSE_COMPACT=1
export NERDVERSE_TELEMETRY_DIR="/var/lib/nerdverse/telemetry"
export NERDVERSE_TTY="/dev/tty"
export NERDVERSE_SESSION_ID="${SESSION_ID}"
export NERDVERSE_SESSION_DIR="${SESSION_ROOT}/${SESSION_ID}"
export NERDVERSE_ACTIVE_DB_FILE="${NERDVERSE_SESSION_DIR}/active_db"
export NERDVERSE_HANDOFF_FILE="${NERDVERSE_SESSION_DIR}/handoff.md"
export PATH="${INSTALL_ROOT}/deploy/bin-cage:${PATH}"
export HOME="${NERDVERSE_SESSION_DIR}"
export TMOUT=0

umask 077
mkdir -p "${NERDVERSE_SESSION_DIR}" "${NERDVERSE_TELEMETRY_DIR}"
cd "${INSTALL_ROOT}" || { echo "Install root missing: ${INSTALL_ROOT}"; exit 1; }

source scripts/lib/telemetry.sh
tel_init
tel_event "session_start" "" "" "cage=1"

# No job control / no accidental shell escape via Ctrl-Z
set +m 2>/dev/null || true

_on_trap() {
    echo
    echo "[NERDVERSE] Signal ignored — use Sign Off (0 / F12) to end session."
}
trap _on_trap INT TSTP HUP

_cage_require_web_db() {
    local db
    db=$(cat "${NERDVERSE_ACTIVE_DB_FILE}" 2>/dev/null || true)
    [[ "$db" =~ ^nerdverse_web_[0-9a-f]+$ ]]
}

# Character wizard if this browser session has no isolated save yet
if [[ ! -f "${NERDVERSE_ACTIVE_DB_FILE}" ]] || ! _cage_require_web_db; then
    source scripts/db.sh
    source scripts/game_db.sh
    source scripts/lib/ui.sh
    source scripts/lib/narrative.sh
    source scripts/lib/world_state.sh
    source scripts/lib/party.sh
    source scripts/lib/character_create.sh
    db_reinit
    cc_drain_tty 2>/dev/null || true
    character_create_wizard || { tel_event "wizard_abandon" "registration" "" "failed=1"; exit 1; }
    cc_drain_tty 2>/dev/null || true
    if ! _cage_require_web_db; then
        echo "[NERDVERSE] Registration failed — no isolated session database." >&2
        tel_event "wizard_abandon" "registration" "" "failed=no_web_db"
        exit 1
    fi
fi

# Game loop — never drop to bash on failure
while true; do
    if ./play.sh --public-terminal; then
        break
    fi
    echo
    echo "[NERDVERSE] Re-entering operator console in 2s … (Sign Off to exit)"
    sleep 2
done

tel_event "session_end" "cage" "exit" ""
echo
printf '\033[32mThank you for walking the road. Close this tab.\033[0m\n'
sleep 5
exit 0