# The Nerdverse Companion

**Meyiu — The Sinner Who Still Chooses**

*A Living Diary, Runbook & Game Documentation*

**Started:** 2026-07-02  
**Current Version:** Phase 0 — The First Forge  
**Co-crafters:** Mark & Grok

---

## Introduction & Intent

This document is the living heart of the **Nerdverse** project.

It serves three purposes at once:

- A **diary** of our shared play and creation sessions.
- A **runbook** with idempotent bootstrap and migration instructions so the game can be installed on any Linux system (or future Mac) with MariaDB.
- A **game documentation** that remains enjoyable to read years later — for you, or for others if the game ever becomes public.

### Design Philosophy

(stolen shamelessly from the game's own themes)

- *You are unfinished, not erased.*
- *Context before category.*
- *Repair must become practical.*

We are building a pure **bash + MariaDB** text adventure / solo RPG engine. No Python, no Node, no fancy frameworks. The goal is maximum portability and learnability.

---

## Development Diary

### 2026-07-02 — Phase 0: The Forge Begins (Session 1)

**In-Game Situation at Start**

Meyiu stands at Brindleford Forge after purchasing the Ash-Wood Buckler (crafted from captured bandit materials) and a Repair and Supply Bundle. Coins: 4 silver. HP 11/13. Road XP 5/10. Sera Thornwake is with him, provisionally trusting after the road ambush where the medicine crate was saved.

Sera's suggestion: "Medicine room next. Unless you plan to treat stab wounds with personal growth."

**What We Built Today**

- Initialized git repository for full GitHub portability.
- Created clean project skeleton: `sql/`, `scripts/`, `docs/`, `bin/`, `saves/`, `logs/`.
- Created this companion document (both LaTeX and Markdown).
- Designed initial idempotent MariaDB schema focused on characters, inventory, world state, and session logging.
- Wrote the first migration and seed that exactly reproduces the restart packet state.
- Created the foundation for a pure-bash CLI that loads state from the database.
- Began the bootstrap/install scripts (idempotent by design).

**Technical Decisions Made**

- Pure bash + `mariadb` client only. Scripts must run on minimal Linux installs.
- Configuration via environment variables + optional `nerdverse.env` file.
- Migrations are numbered and tracked in a `schema_migrations` table.
- All SQL is written to be re-runnable safely (`CREATE ... IF NOT EXISTS`, `INSERT ... ON DUPLICATE KEY UPDATE` or `INSERT IGNORE`).
- Narrative will live in this document + in-game `session_log` table.

### 2026-07-02 — Bootstrap & First Engine Run

The foundation scripts are now real and tested:

- `bootstrap.sh` creates `nerdverse.env`, ensures DB access, and delegates to the migration runner.
- `scripts/apply_migrations.sh` is fully idempotent. It applies `sql/migrations/*.sql` in order and records them in `schema_migrations`. Seeds are re-runnable.
- `scripts/db.sh` centralizes connection logic and helpers.
- `play.sh` (Phase 0) loads live state from the database, prints a nice status block, shows crude ASCII, and lets you pick basic actions. It already updates the DB for some choices.
- Full initial world (Meyiu + Sera stats, inventory with correct equipped flags, passives, Brindleford locations, world_state flags) was seeded exactly from the restart packet.

*Ran successfully on the original machine. The state in nerdverse2 matches the PDF save point.*

We are now ready to step into the medicine room together.

### 2026-07-02 — First Real Play: The Medicine Room (Session 1 continued)

**Player Action**

Meyiu followed Sera to the medicine room. He playfully held her accountable for days of promises to heal him that kept getting postponed. Mentioned his ribs hurt. Expressed interest in seeing how good a healer she actually is, in case she becomes a proper adventuring companion.

**What Happened in Play**

- Locations updated in DB: both characters now in "Sera's Medicine Room".
- Narrative and companion logs written.
- Sera finally tended to Meyiu. Used field-healer technique (modeled on her "Healer's Rebuke"): healed 4 HP. Meyiu is now at full 13/13.
- Banter established: Sera deflects with sharp humor but shows competence and growing respect.
- They begin inventorying the recovered medicine crate together.

This session demonstrated early companion interaction and healing mechanics. Good test of flavor text + mechanical update loop.

State saved. Ready for next input.

---

## Current Game State (Living Snapshot)

**Location:** Sera's Medicine Room  
**Immediate Context:** Meyiu and Sera have entered the medicine room to inventory the recovered medicine crate. Meyiu's ribs have been tended.

**Time Pressure:** The Black Bridge Gang expected the thieves back. Retaliation possible by dusk or midnight.

### Meyiu — The Sinner Who Still Chooses

| Field          | Value |
|----------------|-------|
| Name           | Meyiu |
| Full Title     | The Sinner Who Still Chooses |
| Expanded       | And Chooses What Is His To Carry<br>Beloved, Responsible, Unfinished, Still Becoming, Pilgrim of the Unfinished |
| Class          | Mage |
| Level / Milestone | 2 |
| Current HP     | 13 / 13 (full) |
| Coins          | 4 silver |
| Road XP        | 5 / 10 |
| Location       | Sera's Medicine Room |
| Main Attack    | Firebolt (6 damage) |
| Improved       | Zen-Mage Firebolt (6 + overkill heal +1) |

**Equipped & Key Boons**
- Ashen Prayer Bead (+1 Focus on calm magical/spiritual control actions)
- Penitent's Wrap (once per battle, reduce incoming damage by 2)
- Ash-Wood Buckler (Passive Guard: reduce first physical hit by 1; Breathguard: reduce one hit by 3 +1 Focus)

**Key Inventory Items**
- Healing Potion (restores 6 HP)
- Leechheart Pearl
- Repair and Supply Bundle (recent)
- Cinder Nameplate, Black Brazier-Glass Shard, Gray-Blue Question Slip, White Quill Splinter, Road Knife, Black Bridge-Token, etc.

### Sera Thornwake (Companion Prospect)

| Field   | Value |
|---------|-------|
| HP      | 14 / 14 |
| Role    | Field-healer, trail archer, buckler fighter |
| Status  | With Meyiu in Brindleford, provisional trust. Not yet permanently recruited. |

Her abilities (known):
- Bow Shot — 3 damage
- Buckler Guard — reduce damage to self or ally by 2 (once per round)
- Healer's Rebuke — heal 4 HP and deliver an insult (once)

### The Black Bridge Gang (Current Threat)

Leader: Garran Pike (Bridge-Mouth). Champion: Toll-Saint (heavy shieldman). Strength: 9–12 fighters. Base: abandoned tollhouse.

---

## World & Lore Notes

### Brindleford (Current Chapter: The Road of Bread and Iron)

A rain-soaked village near an old iron bridge.

Problems:
- Medicine shortages + cough-fever
- Weak defenses
- Black Bridge Gang controlling the bridge
- Slow/possibly sabotaged Old Mill
- Injured smith (Old Brenn)

**Key Locations (initial map)**

```
[ Inn (Hearthmouse) ]     [ Forge (Cold Forge / Old Brenn) ]
           \                     /
            \                   /
[ Well ] -- [ Sheriff Marn ] -- [ Medicine Room (Sera) ]
           /
[ Road to Old Mill ]
           |
[ Iron Bridge / Gang Tollhouse ]
```

---

## Runbook: Bootstrap & Migration

### Requirements (Linux or macOS)

- MariaDB client (`mariadb` or `mysql` command)
- Bash (4+ recommended)
- Git (for cloning the repo)
- A MariaDB user that can create the `nerdverse2` database and tables

### Idempotent Bootstrap

The goal: on a fresh system you should be able to:

```bash
git clone <repo>
cd nerdverse
./bootstrap.sh
./play.sh
```

And later:

```bash
./bootstrap.sh   # safe to re-run
```

### First-Time Setup on a New Machine

1. Install MariaDB server + client.
2. Create the database user (example):

   ```sql
   CREATE USER 'mark'@'localhost' IDENTIFIED BY 'yourpassword';
   GRANT ALL ON nerdverse2.* TO 'mark'@'localhost';
   FLUSH PRIVILEGES;
   ```

3. (Optional but recommended) Create a `nerdverse.env` file (see template).
4. Run `./bootstrap.sh`

### Configuration

Create `nerdverse.env` (git-ignored):

```bash
# nerdverse.env - local configuration (git-ignored)
DB_USER=mark
DB_NAME=nerdverse2
DB_HOST=localhost

# If you use password auth instead of socket / .my.cnf, set:
# DB_PASS=yourpassword
```

The scripts will source this if present.

---

## Technical Architecture (Current)

- All state lives in MariaDB `nerdverse2`.
- Bash scripts only for the engine and UI.
- Migrations are plain `.sql` files applied in lexical order.
- A `schema_migrations` table prevents re-application.
- Session log is append-only for narrative + debugging.
- Future: simple command dispatch in bash using `case` + functions.

---

## Documentation Strategy

This project maintains **two versions** of the companion document:

- `nerdverse-companion.tex` — The structured LaTeX source (for beautiful printed/PDF versions when you have a TeX installation).
- `nerdverse-companion.md` — The easily human-consumable Markdown version (renders beautifully on GitHub, readable anywhere with zero dependencies).

A build script (`docs/build-docs.sh`) will attempt to produce a PDF from the `.tex` when `pdflatex` is available on the system.

The Markdown version is the primary "always available" documentation.

---

## Session Log

### 2026-07-02 — First Forge Session

Initial scaffolding complete. We are standing at the forge door with Sera.

*"Loaded save: Meyiu is at Brindleford Forge after buying the Ash-Wood Buckler and Repair and Supply Bundle. Sera is urging him toward her medicine room..."*

**Continued in the Medicine Room session** (see diary above).

---

## Appendix: Original Restart Packet Summary

(The full 20-page PDF `Nerdverse_2.pdf` is kept in the project root for reference. Key mechanical and narrative elements have been transcribed into the schema seed and this document.)

---

*End of current companion document. This file is updated live as we play and build.*