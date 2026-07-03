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
saves/db/               # Local MariaDB dumps (git-ignored)
docs/nerdverse-companion.md   # Diary, runbook, lore, roadmap
```

## Current Phase

**Phase 0 — The First Forge**

Brindleford Vale: forge, medicine room, inn, sheriff, mill, bridge — connected via the `locations` table. Travel **[1]**, local action **[4]**. AS/400 operator UI (compact on short terminals: auto ≤30 rows, or `NERDVERSE_COMPACT=1`). Progression: practice tags, rare breakthrough levels, 2–3 combat actives, party combos. Sera trust/bond 0–100; DM + terminal play supported via `saves/session_handoff.md`.

Full living state, diary, and roadmap: **`docs/nerdverse-companion.md`**

## Documentation

- **`docs/nerdverse-companion.md`** — primary daily read (diary + runbook + mechanics)
- **`docs/linux-packages.md`** — distro package lists
- **`docs/build-docs.sh`** — optional PDF/HTML from LaTeX/Markdown

## Requirements

MariaDB client + bash. See `docs/linux-packages.md` for per-distro install commands.