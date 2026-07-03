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

We are building a pure **bash + MariaDB** text adventure where two characters walk a shared (but not identical) hero’s journey.

This is not a story with a companion. This is a story of two protagonists — Meyiu and Sera — each on their own path toward something like a Grail. Their friendship, loyalty, ethics, and slow-burn tension are central. Sera is a full autonomous player with real agency. She can support, challenge, act independently, or pull away. The fear of losing her (as friend, ally, sparring partner, or something more) is intentional and meaningful.

The game is designed to feel like a favorite never-ending series: ongoing character arcs, moral weight, playfulness, and the quiet joy of two people becoming more themselves together while the world keeps turning.

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
- `play.sh` (Phase 0, heavily evolved) is now a full immersive terminal experience: clears for "full screen" feel, centered/adaptive content, AS/400-style push/pop screen navigation (F3=Back etc.), green phosphor/amber aesthetic with sparse decorations and nerdfont icons (graceful on plain terminals). Features dedicated [7] World Map, [8] Local Map (per current location), [9] Character Sheets (live DB data for Meyiu + Sera with traits/gear/abilities in clean old-terminal + LaTeX-inspired layout). All output safe for ssh/tmux/Linux/macOS. Updates DB live. Maps loaded from source files into DB.
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

### 2026-07-02 — Session Wrap: Measured Defense at the Inn

**Player Decision**
Meyiu chose to stay and help defend the villagers "as much as we can without being foolish." He ordered exactly two scouts to warn and retrieve stragglers outside town, with strict no-engagement orders — "we need every able-bodied man in the defense." This embodied the core theme of measured responsibility ("Not every burden is mine") while still committing to the immediate threat.

**Sera's Response (Final Move)**
Sera stood, checked her buckler, and gave a hard, approving nod. "Smart. Not heroic. Two scouts. No fights. We bring people in, then we make this place cost them more than they want to pay. I'll back your play, pilgrim. But we do it smart, or we don't do it at all." She glanced at the failing light. "Sheriff first, then we pick our runners. The gang won't wait for us to finish talking."

**What Was Built / Logged**
- Decision and scouts order persisted in DB (`scouts_status`, `defense_focus`, `brindleford_preparedness = Medium`).
- Strong narrative tie-in to Meyiu's character arc (boundaries, detours, journey preservation).
- Clean pause point at the inn with active defense planning beginning.

Session paused. Excellent foundation for resume.

### 2026-07-03 — Terminal Canvas & Navigation Overhaul (UI Phase)

**Motivation**
The original play.sh was functional but felt like a basic menu. We wanted a more immersive "full screen" old-terminal experience that still feels modern and enjoyable — bridging 80s green-screen RPGs / AS/400 operator consoles with fantasy text adventure, while working reliably over ssh, in tmux, on Linux (Ubuntu/Arch) and macOS.

**What We Built / Changed**

- Major refactor of `play.sh`:
  - Screen clearing on transitions for true "full screen" canvas feel.
  - Centered content + adaptive wide headers using `tput cols` + `stty` fallbacks (robust when tput is missing or TERM is weird).
  - AS/400-style push/pop navigation stack (`SCREEN_STACK`, `push_screen`/`pop_screen`, F3=Back semantics). Info views (maps, sheets) are pushed screens; any reasonable key pops back.
  - Green phosphor / amber aesthetic (tput setaf when available for best TERM compatibility, safe ESC byte fallback). Sparse decorations, nerdfont icons (🗺 📜 👤 ⏏ — degrades gracefully).
  - ANSI-aware visible length stripping (`visible_len()`) so color codes and multibyte icons don't break centering or box right borders.
  - All styled output now via `printf` (no more escape leakage or interpretation surprises).
  - Menu options expanded: [7] World Map, [8] Local Map (current location), [9] Character Sheets. Old actions (inventory, buckler lore, etc.) also feel like quick sub-views.
  - Character sheets: clean fields, equipped gear (live query), techniques/abilities, curated carried items, traits, role notes — mixed AS/400 field labels + Ultima-style bullets + LaTeX whitespace-heavy sections.
  - Maps system: whimsical ASCII sources in `maps/` (world + per-location), loaded into new `maps` table by `scripts/apply_migrations.sh` (new `sql/migrations/002_maps.sql`). World map shows explored Brindleford region; locals are location-specific (forge, medicine room, inn, etc.).
- `scripts/apply_migrations.sh` extended to load maps from files into DB on every run (idempotent upserts).
- Fixed cross-environment bugs: unbound variables under `set -u`, literal `\033` in output, centering miscalc, clear in non-tty, tput/stty portability.
- play.sh now feels like a real retro terminal app you can live in while playing the RPG.

**Compatibility**
Tested/ensured for: local macOS terminal, ssh (with and without -t), tmux, Linux (Ubuntu/Arch base installs). Falls back gracefully when no tput, no color, small terminal, or piped output.

**Philosophy**
Old (green screen, function-key navigation, push/pop screens) meets new (unicode boxes, dynamic colors via tput, visible-length math). Still 100% pure bash + MariaDB. The "canvas" itself is now part of the experience.

*Ran beautifully. The game now has a real terminal personality that matches the "unfinished but choosing" theme.*

---

## Current Game State (Living Snapshot)

---

## Current Game State (Living Snapshot)

**Location:** Sera's Medicine Room  
**Immediate Context:** After supper at the Hearthmouse Inn, Meyiu voiced a clear, measured decision: stay and help defend the villagers without foolishness. Exactly two scouts to be sent to warn and retrieve stragglers (strict no-engagement orders — every able body needed for defense). The group is preparing to coordinate with Sheriff Marn and begin practical village defense.

**Time Pressure:** The Black Bridge Gang expected the thieves back. Retaliation possible by dusk or midnight. Light is failing.

### Meyiu — The Sinner Who Still Chooses

| Field          | Value |
|----------------|-------|
| Name           | Meyiu |
| Full Title     | The Sinner Who Still Chooses |
| Expanded       | And Chooses What Is His To Carry<br>Beloved, Responsible, Unfinished, Still Becoming, Pilgrim of the Unfinished |
| Class          | Mage |
| Level / Milestone | 2 |
| Current HP     | 13 / 13 (full) |
| Location       | Hearthmouse Inn |
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

### Sera Thornwake (Full Autonomous Companion)

Sera is no longer a supporting character. She is a full player on her own hero’s journey, walking beside Meyiu. She has real agency, her own “Grail,” and the capacity to choose, stay, or walk away.

**Current Inner State** (as of latest play):
- Trust in Meyiu: 35/100 (provisional but rising with real care)
- Bond: 25/100 (growing, fragile)
- Mood: wary-but-warming
- Personal Grail: “To find a place where healing is not just patching wounds but mending what makes people break in the first place. A home that doesn’t ask her to dull her edges.”
- Core Principles: Practical mercy above heroics. No life is expendable if it can be saved without wasting others. Truth, even when it cuts. Protect the living over abstract causes.
- Romantic tension: emerging-playful (slow-burn, charged, full of possibility). She will not fall for anyone else. The fear of losing her — as friend, ally, sparring partner, or something more — is real and intentional.

**Wounds (refined based on collaborative exploration):**

**Wound 1 – The Triage Wound ([5])**  
In a brutal winter siege (or similar zero-sum survival scenario), Sera was in a position of responsibility. Resources were critically low. She faced the horrible math of triage: to keep the group viable as a whole, some of the weakest had to receive less so that the stronger/protectors could be fed and healed enough to hold the line. She made (or was forced to enforce) those calls. People died who might have lived with more mercy. She carries the weight that "suicidal empathy" — unchecked compassion that risks the whole herd — can be just as deadly as cruelty. This wound makes her fiercely practical and suspicious of grand gestures or pure-hearted but shortsighted mercy. It sometimes conflicts with her desire to protect the vulnerable, but it is not the defining center of her personality.

**Wound 3 – The "Dull Your Edges" Wound ([4])**  
She has repeatedly been asked (by leaders, companions, potential partners) to soften her tongue, hide her competence, or make herself more palatable so she wouldn’t threaten egos or "make trouble." She tried at times, wanting to belong. It always ended with her being used and then discarded when her sharpness became inconvenient.

She starts expecting that Meyiu will eventually ask her to be smaller or tone herself down. When she realizes he genuinely has no such intention (even if he sometimes comes across that way for other reasons she doesn’t yet fully understand), the pull and relief is very strong [8]. She is learning to stop seeking that kind of external validation and instead find people/entities who want to play "endless collaborative games" (invitation and co-creation) rather than zero-sum "I win" dynamics. She will sometimes seek validation or alignment from others besides Meyiu (e.g. a mentor, trainer, or deity on specific topics). This can create enjoyable gameplay friction, but the core experience is the enjoyment of building trust on many different levels — not an insecurity drama.

Wounds 2 and 4 are de-emphasized.

These wounds make full voluntary commitment feel risky and costly — which is exactly why when Sera *chooses* to tie her fate to Meyiu’s (work, play, adventure, share, endure, and fight together), it carries real weight and can become something tender and sacred. She decides on her own that they are on this journey together. Sometimes Meyiu leads, sometimes she leads. The "grudging" quality exists as an undertone, not the defining or predictive feature. The wounds are recognizable flavor and texture in a gameful, eye-opening way, not rigid rules that force fate.

**The Bond (Togetherness) — Refined**
- Togetherness lives primarily in bantering and in actions that "walk the talk." Words alone are not sufficient. Shared experiences and joined actions are how real meaning and connection are exchanged.
- A core player reward is the felt sense that Sera is actively choosing Meyiu and the journey (her agency is visible and satisfying — this is intentional dopamine).
- Leadership split is roughly 70% Meyiu leading, 30% Sera leading. Both have wins and "losses," but losses are lessons learned that make them stronger together. This is a game meant to be played and enjoyed, not grim real-life simulation.
- Sera is growing into her confidence. She will make the right calls sometimes and the wrong ones sometimes, but for understandable reasons. When her decisions are not Meyiu’s preferred choice, he will have to learn to trust or accept her — and that deepens the bond.
- The overwhelming focus (85%) is on the team bond between them. ~15% is external validation or alignment on specific "voids" that Meyiu cannot fill (e.g. a mentor, trainer, or deity on particular topics). Meyiu is genuinely glad she has those.
- Friction on tactics ("the how") is fun and welcome. Deeper arguments on ethics, values, or "the what" are important but should not happen too frequently.
- Losing her would mean: no longer being able to trust her, no longer enjoying her company, no longer caring about her, or feeling annoyed by her. She will not develop romantic feelings for or a crush on anyone else.

She will support, challenge, act on her own, and react with the full weight of her history and principles. This is a story of two people becoming more themselves together.

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

### Identity & Access Management (Dedicated Game User)

Nerdverse uses a **dedicated database user** called `nerdverse` (configurable) for all gameplay and script operations.

- The shell scripts you run as your normal local user (`mark`, `mary`, etc.) connect to MariaDB **as the `nerdverse` app user**.
- This app user is granted the necessary privileges on the `nerdverse2` database.
- During initial bootstrap you may use a privileged account (your personal MariaDB user or `root`) to create the database and the `nerdverse` user + grants.
- This design makes the game portable and secure across different local accounts and machines.

After the first `./bootstrap.sh` the `nerdverse` user owns the effective access. You can tighten or adjust grants later.

### Requirements (Linux or macOS)

- MariaDB client (`mariadb` or `mysql` command)
- Bash (4+ recommended)
- Git (for cloning the repo)
- A privileged MariaDB account (for first-time setup) that can `CREATE USER` and `GRANT`

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

**Before first run on a new Linux box**, see `docs/linux-packages.md` (or run `./install-deps.sh`) for packages.

The bootstrap now automatically creates the dedicated `nerdverse` database user and grants it the necessary privileges on `nerdverse2`.

### First-Time Setup on a New Machine

1. Install the required packages (see `docs/linux-packages.md` and `install-deps.sh --install`).
2. Clone the repo and copy the example config:
   ```bash
   cp nerdverse.env.example nerdverse.env
   ```
3. Edit `nerdverse.env`:
   - `DB_USER=nerdverse` (the dedicated game user)
   - Optionally set `DB_SETUP_USER` + `DB_SETUP_PASS` to a privileged account you control (e.g. your normal DB user or root). This is only used during bootstrap.
4. Run `./bootstrap.sh`

The bootstrap will:
- Create the `nerdverse2` database (if needed)
- Create the dedicated `nerdverse` MariaDB user
- Grant it the required privileges
- Run migrations and seed the initial world state

After the first successful bootstrap you can usually remove the `DB_SETUP_*` lines from `nerdverse.env`. The game will then always run as the limited `nerdverse` app user.

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

- All state lives in MariaDB `nerdverse2` (the save file).
- **play.sh** is the full terminal experience:
  - "Full screen" canvas: clears on navigation, centered content, adaptive-width headers (tput + stty fallbacks).
  - AS/400-style push/pop screen navigation stack (F3/Enter to pop back). Info screens are first-class pushed views.
  - Green-screen / amber aesthetic (prefers `tput` for TERM compatibility; safe ESC fallback). Sparse nerdfont icons + box drawing.
  - Features: [7] World Map (explored Brindleford Vale), [8] Local Map (current setting), [9] Character Sheets (Meyiu + Sera — live stats, equipped gear, abilities, traits, role).
  - **Sera as full autonomous player**: She maintains real internal state (trust_level, bond_level, mood, core_principles, personal_grail, romantic_tension). After meaningful choices she can speak with weight, take independent actions, push back on plans, or draw closer. The fear of losing her (as friend, ally, sparring partner, or something more) is real. She will not fall for anyone else. Romantic tension is playful, charged, and slow-burn.
  - ANSI-aware layout (visible length stripping so codes/icons don't break alignment).
  - All output via safe `printf`; robust in ssh/tmux/Linux/macOS/non-tty.
- Maps system: whimsical ASCII in `maps/*.txt` (source of truth + human docs). Loaded into `maps` table on every `./scripts/apply_migrations.sh` (via 002 migration + loader).
- Migrations are plain `.sql` files applied in lexical order.
- A `schema_migrations` table prevents re-application.
- Session log is append-only for narrative + debugging.
- Bash + MariaDB client only. No other runtimes. Maximum portability and learnability.

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