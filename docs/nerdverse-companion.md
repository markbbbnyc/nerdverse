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

## Continue Prompt for Grok (Memento Notes)

**Current Agreed Direction (as of latest session):**
- One-life, non-repeatable journeys (roguelike + Tamagotchi spirit). Once a life is lived, it is over. No new game, no reloads for the same characters.
- The engine is a **canvas** for characters to grow, unfold, and impress themselves onto the world.
- Future: Players create their own player + companion characters (different wounds, grails, personalities). Engine provides scenarios, physics, and systems.
- Long-term: JRPG tactical combat (FF/Diablo style), character progression, possible multi-player hosted worlds.
- Current focus (B): Build the "physics" and canvas (combat, action systems, extensible characters) while keeping the current run sacred and meaningful. Meta/emo/philosophical side + mechanical frame together.

**What was just implemented (2026-07-03 — play/build session):**
- **AS/400 operator UI:** screen IDs, ledger menu, PF-keys, compact mode for ≤30-row terminals (`NERDVERSE_COMPACT=1`).
- **Progression system (`005_progression.sql`):** practice tags, breakthrough levels, 2–3 combat actives, combos, inert shiny components.
- **Sera in combat:** ally avatar cards (Meyiu │ Sera │ Foe), autonomous support turns, `IN THE ROOM` milestones.
- **Scenarios:** `scenario_sheriff` (defense planning, not repeat scout ambush), mill/bridge stakes, Pike hunt council hook.
- **DM play mode:** chat-room banter with Grok as DM + Sera; `session_handoff.md` includes DM resume prompt.
- **Save safety:** daily backup, `restore_db.sh`, multi-life DBs, modular `scripts/lib/*.sh`.

**Life 2 (legacy) — session paused at (2026-07-03):**
- **Chapter:** *The Morning After the Toll*
- **Where:** Hearthmouse Inn — dawn council done; **Pike hunt organizing** (dusk tomorrow)
- **Meyiu:** Lv2, HP 13/13, Road XP 11/25, unlock: Field Mender's Habit
- **Sera:** Lv2, Road XP 3/25, Trust/Bond 100, mood `easy-with-you`, unlocks: Chill Residue, Field Lab Satchel
- **Sera progression UI:** HUD, status, persona records `[9]`, handoff — same visibility as Meyiu
- **Combo discovered:** Thermal Shock (Frozen Ground + Firebolt)
- **Village:** mill patched, food stabilizing, preparedness **High**, families evacuated then secured
- **Black Bridge:** Toll-Saint wounded/retreated; Garran Pike withdrew — **hunt authorized before Meyiu/Sera depart the vale**

**Public terminal deploy (stretch goal — `deploy/` lane):**
- Ubuntu: `./deploy/bootstrap-remote.sh root@24.144.103.2` → `/opt/nerdverse-public`
- nginx landing + ttyd `/play/` sandbox (no shell escape)
- Per-session DB `nerdverse_web_*` + character wizard; **does not touch local Life 2**
- Idempotent updates: re-run `deploy/install-server.sh` on server
- See **`deploy/README.md`**

**Next sprint candidates:**
- **Pike hunt scenario** — tactical hunt with volunteer loss budget (≤3), combo combat, deterrence outcome
- Combo **fusion** (permanent Shatterheat Bolt / fused skill slot)
- Healing potion use in/post combat
- Equipment equip UI; enemy table in DB
- In-game save selector; ttyd/nginx operator-console notes

**Principles:**
- One life per set of characters. Permanent consequences.
- Actions > words, but words contextualize and make actions "seen".
- Build the frame so different characters can play different stories on the same canvas.
- Mix mechanical depth (combat, progression) with emotional depth (bond, ethics, growth).
- Play/build cycle continues; test in current run where it fits.

Read this section at the start of any new session to stay aligned.

## Roadmap & Milestones

This is the living roadmap for building the "canvas" — the physics, systems, and mechanics that will allow many different characters (and their companions) to live unique, non-repeatable lives.

**Core Philosophy**
- One life per set of characters (no new game for the same people).
- Growth through use ("muscle memory") more than point assignment.
- Contextual practice matters (creative or difficult use accelerates development).
- Atrophy is real (neglect skills → they degrade).
- Equipment and abilities are deeply integrated.
- The engine provides the frame; characters impress themselves on it.

### Milestone 1: Core Canvas & One-Life Foundation (Done)
- Persistent world in MariaDB (the save file); multi-life DB naming; backup/restore.
- Immersive terminal UI (push/pop navigation, green phosphor aesthetic).
- Character sheets, inventory, world state, ASCII maps.
- Sera agency with 0–100 trust/bond, contextual talk, leadership counter.
- Location graph travel (`locations.connected_to`) + per-place actions.
- Basic combat prototype with mage abilities.
- `play.sh` split into sourced modules under `scripts/lib/`.

### Milestone 2: Equipment & Ability System (Phase 1 — In Progress)
- **Done:** `005_progression` migration; `scripts/lib/progression.sh`; combat ally cards; combo recipes; breakthrough ceremonies in `./play.sh` (runs for **both** Meyiu and Sera).
- **Done:** Dual-track progression — Sera has her own `prog_level`, `road_xp`, `character_practice`, `character_unlocks`; shown on compact HUD (`Lv` / `Rx`), full status, `[9]` sheets, handoff.
- Proper equipment slots (weapon, off-hand, armor, focus, accessory...).
- Equipment modifiers that affect abilities and combat (e.g. staff boosts Firebolt damage).
- Pull abilities dynamically from `character_abilities` table into combat.
- Basic proficiency tracking (usage counter) on abilities.
- First usage-based bonuses (e.g. repeated Firebolt use slowly increases power or adds effects).
- Equip/unequip flow visible in inventory and status.

### Milestone 3: Usage-Based Skill Development (Muscle Memory)
- Abilities improve primarily through use, not points.
- Contextual bonuses: difficult or creative use (e.g. casting while defending, while low HP, while performing another action) grants faster growth.
- "Practice" actions or mini-scenarios that deliberately train skills.
- Proficiency levels unlock new options or stronger versions of abilities.

### Milestone 4: Atrophy & Maintenance
- Unused abilities slowly lose proficiency over "time" (action count or sessions).
- Neglect has visible consequences (weaker effects, failed casts, Sera comments).
- Optional "maintenance" or training activities to keep skills sharp.

### Milestone 5: Skill Trees / Progression
- Progression emerges from demonstrated mastery + contextual breakthroughs.
- Branching based on how the character actually plays (not just assigned points).
- Different characters discover different paths.

### Milestone 6: Tactical Combat Depth (JRPG / FF / Diablo Style)
- Full turn-based tactical combat with proper ability integration.
- Elements, status effects, targeting, positioning concepts.
- Risk/reward, overcast, combo potential.
- Combat that meaningfully affects the relationship (Sera reacts to performance).

### Milestone 7: Character Creation & Custom Lives
- Simple creation flow for new player + companion characters.
- Define starting wounds, grails, core abilities, equipment kits.
- Support for multiple "lives" (each a fresh, non-repeatable story on the same canvas).
- **In-game save selector** (`play.sh` menu): list `nerdverse2_Sera`, `nerdverse3_Elara`, … and switch active life without deleting old databases. (`./play.sh --new-game [Companion]` already creates `nerdverse{N}_{Name}` per life; selector UI deferred.)

### Milestone 8: World Reactivity & Legacy
- Characters leave lasting marks on the world (reputation, changed locations, persistent events).
- World remembers and reacts to the specific people who lived there.

### Milestone 9: Multi-Player / Hosted Worlds (Long-term Vision)
- Multiple players can create their own characters + companions.
- Shared or parallel worlds.
- Eventually a hosted canvas where different "lives" can interact or leave echoes.

**Current Focus**: Milestone 2 (Equipment + Ability System) + playtesting travel/bond pacing in the active Brindleford life.

**Recent Polish (Combat UI)**: Combat avatars are now bordered game-card tiles with larger width (20-char inner) and extra internal padding/empty lines so the ASCII art and minimal HP stats (bar + numbers) are not "boxed in". PLAYER and ENEMY labels above, consistent borders for visual guidance and reduced eye strain. Fixed HP line padding for alignment. Updated in draw_ascii_combatants().

We will continue to interleave "play" and "build" so the systems are validated through actual use.

---

## Development Diary

### 2026-07-03 — Brindleford Defense, Progression & DM Play (Session 2)

**Play mode:** Grok as DM + Sera; Mark as Meyiu; chat-room banter with `./play.sh` + MariaDB as mechanical law.

**In-game arc (Life 2, `nerdverse2`):**
- Repelled Black Bridge probe at medicine room; discovered **Thermal Shock** combo.
- Evacuated families to inn; deterred main push with coordinated Frozen Ground + Firebolt (Toll-Saint wounded, Pike withdrew).
- Quiet channel with Sera (bond 100, mood `easy-with-you`); dawn council with Marn.
- **Paused:** Pike hunt organizing — 8 volunteers, dusk tomorrow; Meyiu/Sera field advisors; crush Pike before continuing east.

**Engine shipped this session:**
- `005_progression.sql` — practice, unlocks, combos, breakthrough levels.
- `scripts/lib/progression.sh`, enhanced `combat.sh` (ally cards), `scenario_sheriff`, compact AS/400 main screen.
- Handoff + DM resume prompt; backup `nerdverse2_2026-07-03_session_end.sql`.

**Resume:** Paste `saves/session_handoff.md` into Grok, or `./play.sh` for operator UI. Next beat: **Pike hunt**.

### 2026-07-03 — Sera progression visibility

Mechanics were already on Sera's `characters` row; UI was Meyiu-only. Fixed: compact HUD shows `Sera … Lv2 Rx 3/25`; persona records list her techniques, unlocks, practice; combat victory grants Sera **+2** Road XP.

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

### 2026-07-03 — Engine Hardening & Relationship Pacing Sprint

**Built**
- Save pipeline: daily backup, restore script, non-destructive catalog seeds, `--new-game` → `nerdverse{N}_{Companion}`.
- `play.sh` → thin main loop + `scripts/lib/` modules.
- Trust/Bond capped 0–100; anti-grind rebalance; meter display.
- `locations` table wired to gameplay: [1] Travel, [4] act-here per `location_key`.
- Migration `004_location_keys`.

**Design note:** Sera is played by the LLM (Grok/Mark sessions); meters confirm what dialogue already showed — not a keyboard smasher.

---

## Current Game State (Living Snapshot)

> **Authoritative state is always the database.** Run `./play.sh` or query `characters` / `world_state`. Numbers below reflect **Life 2 (legacy)** as of last session pause.

**Arc:** *The Morning After the Toll* — Brindleford secured (mill patched, families safe, main push repelled). **Pike hunt** organizing at Hearthmouse Inn; Meyiu/Sera depart the vale after crushing Pike.

**Resume:** `saves/active_db` → usually `nerdverse2`; handoff in `saves/session_handoff.md`.

### Meyiu (Life 2 pause)

| Field | Value |
|-------|-------|
| HP | 13 / 13 |
| Level | 2 |
| Road XP | 11 / 25 |
| Location | Hearthmouse Inn (`inn`) |

### Sera Thornwake (companion — LLM-played, full progression track)

Sera is a full autonomous protagonist, not support. Trust/Bond are **0–100** meters. She uses the **same progression mechanics** as Meyiu on her own `characters` row:

| Field | Value (Life 2 pause) |
|-------|----------------------|
| Level | 2 |
| Road XP | 3 / 25 |
| Trust / Bond | 100 / 100 |
| Practice (top) | medicine, science, tactics |
| Unlocks | Chill Residue Vial, Field Lab Satchel |

**Breakthrough ceremonies:** On `./play.sh` start (interactive TTY), if `breakthrough_pending=1` for either character, a level-up ceremony runs — Meyiu first, then Sera. Options are shaped by each character's practice tags.

**Where to see Sera progression in-game:** compact HUD (`Sera … Lv Rx`), full status (non-compact), **[9] Persona records**, `saves/session_handoff.md` on quit.

**Inner state keys** (`world_state`):
- `sera_trust_level`, `sera_bond_level` (capped meters)
- `sera_joint_experiences`, `sera_leadership_moments` (unbounded memory)
- Mood, grail, principles, romantic tension (narrative / LLM)
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

**Key Locations** — stored in `locations` with `connected_to` edges. Travel in-game via **[1] Walk**. See `maps/world.txt` for ASCII art.

---

## Runbook (single source of truth)

See also **`README.md`** for a short overview. Details live here.

### Requirements

MariaDB client, bash, git. Privileged DB account for first bootstrap only. Packages: `docs/linux-packages.md`.

### First machine

```bash
cp nerdverse.env.example nerdverse.env
./bootstrap.sh
./play.sh
```

### Every session

```bash
./play.sh                    # backup (once/day) + migrations + resume
./play.sh --new-game Sera    # new DB nerdverse{N}_Sera; old lives kept
```

### Saves & backups

| What | Where |
|------|--------|
| Active DB name | `saves/active_db` |
| SQL dumps | `saves/db/{dbname}_YYYY-MM-DD.sql` |
| Restore | `./scripts/restore_db.sh --latest` |
| Reset one DB | `./bootstrap.sh --fresh` (destructive) |

**Seeds:** `001_catalog.sql` runs every time (safe). `002_fresh_game.sql` only on first install or `--fresh`.

### Config (`nerdverse.env`)

```bash
DB_USER=nerdverse
DB_NAME=nerdverse2
DB_HOST=localhost
# DB_SETUP_USER=   # privileged user, bootstrap only
```

Gameplay always uses the `nerdverse` app user. `DB_NAME` in env is the default; `saves/active_db` wins when present.

---

## Dual-track progression (Meyiu + Sera)

Both protagonists progress on **separate tracks** in the same database:

| Layer | Meyiu | Sera |
|-------|-------|------|
| **Breakthrough** | `prog_level`, `road_xp` / `road_xp_max`, `breakthrough_pending` | Same columns on her `characters` row |
| **Practice** | `character_practice` (strength, arcane, practical, …) | Own practice rows (medicine, science, tactics, …) |
| **Unlocks** | `character_unlocks` (passives, components, combos) | Own unlocks (e.g. Chill Residue, Field Lab Satchel) |
| **Combat** | Up to 3 `combat_active` abilities | Frozen Ground, Triage Mark; ally card each round |
| **Combos** | Party discoveries in `party_combos_discovered` | Primer abilities often Sera's (Thermal Shock) |

**Road XP sources (examples):** combat victory (Meyiu +3, Sera +2), mill repair (+3 Sera), shared scenarios. Threshold crossed → `breakthrough_pending`; ceremony consumes bar and raises `road_xp_max` (10 → 25 → 45 …).

**Design:** 2–3 combat menu options max; many inert components combine into surprises; level-ups add complexity, not raw stat inflation. Player should be **in the room** for Sera's milestones (DM play).

---

## Technical Architecture (Current)

- **State:** MariaDB per life (`nerdverse2`, `nerdverse3_Sera`, …). Tables: `characters`, `inventory`, `world_state`, `locations`, `maps`, `character_abilities`, `character_practice`, `character_unlocks`, `combo_recipes`, `party_combos_discovered`, `session_log`.
- **play.sh:** thin loop; logic in `scripts/lib/` (`ui`, `travel`, `player`, `sera`, `progression`, `combat`, `scenarios`, `maps`, `sheets`, `render`, `handoff`).
- **Movement:** `characters.location_key` ↔ `locations.key_name`; exits from `connected_to`; [1] Travel, [4] local action.
- **UI:** AS/400 operator console; compact mode when terminal ≤30 rows (`NERDVERSE_COMPACT=0` for full layout).
- **Sera:** trust/bond 0–100; full progression track; voice/agency via LLM/DM sessions.
- **Migrations:** `sql/migrations/*.sql` + `schema_migrations`; catalog seeds `001_catalog.sql`, `003_progression_catalog.sql`.
- Bash + MariaDB only.

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