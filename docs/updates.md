# Nerdverse — Session Updates

Chronological deploy and engine notes. Author Life-2 save (`nerdverse2`) is never listed here — it stays local.

---

## 2026-07-04 — Public terminal hardening & UX

### Engine (both lanes)
- **`scripts/lib/mode.sh`** — `dev` vs `public` lane detection.
- **`scripts/lib/party.sh`** — Party-agnostic names in HUD, ledger, combat (no hardcoded Meyiu/Sera in public UI).
- **Seed profiles** — `sql/seeds/profiles/public_arc_start.sql` (full arc ch.1) vs `author_checkpoint.sql` (dev only).
- **Balance telemetry** — `tel_balance()` + combat/breakthrough events; admin dashboard KPIs.

### Security
- Public sessions **must** use `nerdverse_web_*` DBs; `play.sh --public-terminal` hard-gates on session `active_db`.
- Author save never deployed; `nerdverse_public` is schema-only template.

### Telemetry & admin
- systemd `ReadWritePaths` includes telemetry dir (events were silently dropped before).
- Dashboard **Refresh now** replaces KPI rows (`replaceChildren`) instead of stacking duplicates.
- Cron aggregate every 2 minutes on server.

### Public UX (playtest-driven)
| Issue | Fix |
|-------|-----|
| Pre-registration banner showed `OPERATOR │ nerdverse_public` | Registration shows **`NEW PILGRIM │ Tab · new life`** until `nerdverse_web_*` exists |
| Garbled registration box borders (emoji width) | ASCII `[*]` headers + `visible_len()` wide-char aware + ASCII `-` borders on public terminal |
| Silent freeze after pressing `.` during DB provision | Player-facing progress: *Forging your life…* → *Provisioning* → *Seeding Brindleford Vale*; technical logs → stderr |
| `Warning: daily backup failed.` on public tabs | Skip `db_backup_daily` when `NERDVERSE_PUBLIC_TERMINAL=1` |

### Deploy
- **`deploy/spin-up.sh`** — one-command provision from Mac.
- Live reference server: `http://24.144.103.2/` (landing), `/play/`, `/admin/` (htpasswd: `dashboard` / `lookatme`).
- Idempotent updates preserve per-tab `nerdverse_web_*` databases and session dirs.

### Playtest summary (new-user, ~2 min)
- Random pilgrim/companion names per tab ✅
- Isolated `nerdverse_web_{hex}` per session ✅
- Chapter 1 start at Brindleford Forge ✅
- Travel, inventory, sign-off ✅
- Telemetry funnel: `session_start` → `wizard_complete` → `menu_choice` → `session_end`

### Docs added/updated
- `docs/content-pipeline.md` — DEV → staging → PRD content flow
- `deploy/README.md` — ops runbook
- `docs/nerdverse-companion.md` — continue-prompt + public lane status
- `README.md` — public terminal pointers
- This file

**Git:** `113362d` on `main` (UX + docs: `e426bfb`) — `https://github.com/markbbbnyc/nerdverse.git`

---

## 2026-07-03 — Public terminal lane & progression

- AS/400 operator UI, compact mode, PF-keys.
- Dual-track progression (Meyiu + Sera), breakthrough ceremonies.
- `deploy/` lane: nginx, ttyd, `nerdverse-cage.sh`, per-session DB wizard.
- Telemetry JSONL + admin dashboard.

---

*Next session candidates: Trust/Bond decay feedback after travel, companion channel polish, Pike hunt scenario, TLS on public host.*

*Session closed 2026-07-04.*