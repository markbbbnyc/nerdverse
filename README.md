# Nerdverse

**Meyiu — The Sinner Who Still Chooses**

A pure bash + MariaDB solo text RPG / interactive story.

## Philosophy

- Context before category.
- Repair must become practical.
- You are unfinished, not erased.
- We build the engine while we play the game.

## Quick Start (on this machine or any Linux/Mac with MariaDB client)

```bash
git clone <repo-url>
cd nerdverse

# First time (or after fresh clone)
./bootstrap.sh

# Play
./play.sh
```

The bootstrap is **idempotent**. You can run it again safely.

## Project Structure

- `bootstrap.sh` — one-command setup for new systems
- `play.sh` — the game
- `scripts/` — db helpers, migration runner
- `sql/migrations/` — numbered, re-runnable schema
- `sql/seeds/` — initial world + character state
- `docs/nerdverse-companion.tex` — the living diary + runbook + game documentation
- `nerdverse.env` — local DB config (git-ignored)

## Current Phase

**Phase 0 — The First Forge**

We are at the very beginning of Brindleford. State is loaded directly from the original restart packet.

## Long-term Goals

- Build a real, playable text RPG engine using only bash + MariaDB.
- Keep a beautiful, readable companion document that ages well.
- Make the entire thing trivially installable on any of my Linux boxes.
- Gradually peel away the need for Grok so I can play solo later.
- Have fun and learn.

## Notes for Future Mark

When you come back to this in 2027 or later:
- Read the companion .tex (or the compiled PDF).
- Run `./bootstrap.sh` then `./play.sh`.
- The database *is* the save file.

Enjoy the road.
