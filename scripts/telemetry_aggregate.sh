#!/usr/bin/env bash
# telemetry_aggregate.sh — Roll up public-terminal JSONL into stats.json for admin dashboard.

set -euo pipefail

TELEMETRY_DIR="${NERDVERSE_TELEMETRY_DIR:-/var/lib/nerdverse/telemetry}"
TELEMETRY_FILE="${TELEMETRY_DIR}/events.jsonl"
TELEMETRY_STATS="${TELEMETRY_DIR}/stats.json"

[[ -f "${TELEMETRY_FILE}" ]] || {
    printf '{"generated_at":"%s","total_events":0,"sessions":0,"message":"no telemetry yet"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${TELEMETRY_STATS}"
    exit 0
}

LOCK_FILE="${TELEMETRY_DIR}/.aggregate.lock"
exec 9>"${LOCK_FILE}"
flock -w 10 9 || exit 0

TELEMETRY_TMP="${TELEMETRY_STATS}.tmp.$$"
python3 - "${TELEMETRY_FILE}" "${TELEMETRY_TMP}" <<'PY'
import json, sys, collections
from datetime import datetime, timezone
from pathlib import Path

src, out = Path(sys.argv[1]), Path(sys.argv[2])
events = []
for line in src.read_text(encoding="utf-8", errors="replace").splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        events.append(json.loads(line))
    except json.JSONDecodeError:
        continue

sessions = set()
session_starts = 0
session_ends = 0
wizard_complete = 0
wizard_abandon = 0
choices = collections.Counter()
screens = collections.Counter()
players = collections.Counter()
recent = []

for e in events:
    sid = e.get("session") or "unknown"
    sessions.add(sid)
    et = e.get("type") or ""
    if et == "session_start":
        session_starts += 1
    elif et == "session_end":
        session_ends += 1
    elif et == "wizard_complete":
        wizard_complete += 1
        p = (e.get("player") or "").strip()
        if not p:
            detail = e.get("detail") or ""
            if "player=" in detail:
                for part in detail.split(";"):
                    if part.startswith("player="):
                        p = part.split("=", 1)[1]
                        break
        if p:
            players[p] += 1
    elif et == "wizard_abandon":
        wizard_abandon += 1
    elif et == "menu_choice":
        ch = e.get("choice") or "?"
        sc = e.get("screen") or "?"
        choices[f"{sc}:{ch}"] += 1
        screens[sc] += 1

    recent.append(e)

recent = recent[-40:][::-1]

def top(counter, n=12):
    return [{"key": k, "count": v} for k, v in counter.most_common(n)]

stats = {
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "total_events": len(events),
    "unique_sessions": len(sessions),
    "session_starts": session_starts,
    "session_ends": session_ends,
    "wizard_completions": wizard_complete,
    "wizard_dropoffs": max(0, session_starts - wizard_complete),
    "completion_rate_pct": round(100 * wizard_complete / session_starts, 1) if session_starts else 0,
    "top_choices": top(choices),
    "top_screens": top(screens),
    "top_player_names": top(players, 20),
    "recent_events": recent[:25],
}

out.write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
PY

mv -f "${TELEMETRY_TMP}" "${TELEMETRY_STATS}"
chmod 644 "${TELEMETRY_STATS}" 2>/dev/null || true