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
- `install-deps.sh` or see `docs/linux-packages.md` — target Linux package list
- `scripts/` — db helpers, migration runner
- `sql/migrations/` — numbered, re-runnable schema
- `sql/seeds/` — initial world + character state
- `docs/` — companion docs (.md is the easy daily read, .tex for PDF, build-docs.sh)
- `nerdverse.env` — local DB config (**never committed** — use `nerdverse.env.example`)

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

## Documentation

The main living documentation lives in `docs/`:

- **`nerdverse-companion.md`** — Primary easily human-consumable version (Markdown). This renders beautifully on GitHub with no extra tools. Read this for the diary, runbook, current game state, and mechanics.
- **`nerdverse-companion.tex`** — Structured LaTeX source (for nice PDF/print versions).
- **`nerdverse-companion.html`** — Auto-generated basic HTML fallback.
- **`build-docs.sh`** — Run this script to regenerate PDF (if `pdflatex` is installed) and HTML.

**Recommendation:** Use the `.md` file day-to-day. Run `./docs/build-docs.sh` after significant updates.

The LaTeX and Markdown versions are kept in sync manually for now.

## Target Linux Systems — Package Requirements

See **`docs/linux-packages.md`** for the complete, maintained list of packages for Debian/Ubuntu, Fedora, Arch, openSUSE, etc.

It covers:
- MariaDB client (required to play)
- Git & basic shell tools
- LaTeX (optional — for building nice PDFs of the companion docs)
- Pandoc (optional — better HTML)
- Nice-to-haves (dialog, figlet, etc.)

Quick Ubuntu example:

```bash
sudo apt update
sudo apt install -y mariadb-client git
# For PDF/docs:
# sudo apt install -y texlive-latex-base texlive-fonts-recommended pandoc
cp nerdverse.env.example nerdverse.env
./bootstrap.sh
./play.sh
```

## Git & Remote Repository

This project is designed to live on GitHub under the `markbbbnyc` account for easy cloning across all your Linux machines.

See the Development Diary in the companion docs for setup history.
