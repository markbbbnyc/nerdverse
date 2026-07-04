# Nerdverse

**Meyiu — The Sinner Who Still Chooses**

A pure bash + MariaDB text RPG. The database is the save file.

## Philosophy

- Context before category.
- Repair must become practical.
- You are unfinished, not erased.
- We build the engine while we play the game.

## Quick Start

```bash
git clone <repo-url>
cd nerdverse
cp nerdverse.env.example nerdverse.env   # first time only
./bootstrap.sh
./play.sh
```

Bootstrap is **idempotent** — safe to re-run. It creates a dedicated MariaDB app user (`nerdverse`) and applies migrations.

## Play

| Command | Purpose |
|---------|---------|
| `./play.sh` | Resume active save (daily backup + safe migrations) |
| `./play.sh --new-game Sera` | New life in `nerdverse{N}_Sera` (old saves kept) |
| `./scripts/restore_db.sh --latest` | Restore from local SQL backup |
| Quit game (`0`) | Writes `saves/session_handoff.md` for Grok/LLM resume |

Active save: `saves/active_db` (overrides `nerdverse.env` `DB_NAME`).

## Public terminal (browser players)

Separate deploy lane for anonymous one-shot lives — **not** your author save.

```bash
./deploy/spin-up.sh root@YOUR_SERVER_IP
```

Each browser tab gets an isolated `nerdverse_web_*` database (profile `sql/seeds/profiles/public_arc_start.sql`). Full ops runbook: **`deploy/README.md`**. Content pipeline: **`docs/content-pipeline.md`**. Session changelog: **`docs/updates.md`**.

| Command | Purpose |
|---------|---------|
| `./deploy/spin-up.sh root@host` | Provision / update a public game server |
| `./play.sh --public-terminal` | Local test of the sandboxed session path |

## Project Layout

```
play.sh                 # Main loop (thin orchestrator)
bootstrap.sh            # First-time / idempotent setup
scripts/
  db.sh backup.sh game_db.sh apply_migrations.sh restore_db.sh
  lib/                  # Game modules (ui, travel, sera, combat, maps, …)
sql/migrations/         # Schema (versioned, re-runnable)
sql/seeds/              # Catalog (safe) + fresh game (new lives only)
maps/                   # ASCII map sources → loaded into DB
deploy/                 # Public terminal: spin-up, nginx, ttyd, sandbox
saves/db/               # Local MariaDB dumps (git-ignored)
docs/nerdverse-companion.md   # Diary, runbook, lore, roadmap
docs/updates.md               # Deploy & engine session changelog
docs/content-pipeline.md      # DEV → public content flow
deploy/README.md        # Public server install & security model
```

## Current Phase

**Phase 0 — The First Forge**

Brindleford Vale: forge, medicine room, inn, sheriff, mill, bridge — connected via the `locations` table. Travel **[1]**, local action **[4]**. AS/400 operator UI (compact on short terminals: auto ≤30 rows, or `NERDVERSE_COMPACT=1`). **Dual-track progression:** Meyiu and Sera each have level, Road XP, practice, unlocks, and breakthrough ceremonies (shown on HUD, status, **[9]** persona records). Party combos, 2–3 combat actives. Sera trust/bond 0–100; DM + terminal play via `saves/session_handoff.md`.

Full living state, diary, and roadmap: **`docs/nerdverse-companion.md`**

## Documentation

- **`docs/nerdverse-companion.md`** — primary daily read (diary + runbook + mechanics)
- **`docs/linux-packages.md`** — distro package lists
- **`docs/build-docs.sh`** — optional PDF/HTML from LaTeX/Markdown

## Requirements

MariaDB client + bash. See `docs/linux-packages.md` for per-distro install commands.