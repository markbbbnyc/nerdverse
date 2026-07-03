#!/usr/bin/env bash
# nerdverse-cage.sh — Public terminal jail: game only, no interactive shell.
# Invoked by ttyd as the nerdverse-play user. No bash prompt on exit.

set -euo pipefail

INSTALL_ROOT="${NERDVERSE_INSTALL_ROOT:-/opt/nerdverse-public}"
SESSION_ROOT="${NERDVERSE_SESSION_ROOT:-/var/lib/nerdverse/sessions}"
SESSION_ID="${NERDVERSE_SESSION_ID:-ttyd_${TTYD_PID:-$$}_$RANDOM}"

export NERDVERSE_PUBLIC_TERMINAL=1
export NERDVERSE_COMPACT=1
export NERDVERSE_SESSION_DIR="${SESSION_ROOT}/${SESSION_ID}"
export NERDVERSE_ACTIVE_DB_FILE="${NERDVERSE_SESSION_DIR}/active_db"
export NERDVERSE_HANDOFF_FILE="${NERDVERSE_SESSION_DIR}/handoff.md"
export PATH="${INSTALL_ROOT}/deploy/bin-cage:${PATH}"
export HOME="${NERDVERSE_SESSION_DIR}"
export TMOUT=0

umask 077
mkdir -p "${NERDVERSE_SESSION_DIR}"
cd "${INSTALL_ROOT}" || { echo "Install root missing: ${INSTALL_ROOT}"; exit 1; }

# No job control / no accidental shell escape via Ctrl-Z
set +m 2>/dev/null || true

_on_trap() {
    echo
    echo "[NERDVERSE] Signal ignored — use Sign Off (0 / F12) to end session."
}
trap _on_trap INT TSTP HUP

# Character wizard if this browser session has no save yet
if [[ ! -f "${NERDVERSE_ACTIVE_DB_FILE}" ]]; then
    source scripts/db.sh
    source scripts/game_db.sh
    source scripts/lib/ui.sh
    source scripts/lib/narrative.sh
    source scripts/lib/world_state.sh
    source scripts/lib/character_create.sh
    db_reinit
    character_create_wizard || exit 1
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

echo
printf '\033[32mThank you for walking the road. Close this tab.\033[0m\n'
sleep 5
exit 0