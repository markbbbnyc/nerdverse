# Nerdverse Content Pipeline — DEV → Public

One engine, three layers. Your Life-2 save never ships; game content does.

## Layers

| Layer | What | Where it lives | Ships to public? |
|-------|------|----------------|------------------|
| **Engine** | `play.sh`, `scripts/lib/*`, combat, travel, UI | Git repo | Yes — every deploy |
| **World catalog** | Locations, maps, combo recipes, progression catalog | `sql/seeds/001_catalog.sql`, `003_progression_catalog.sql`, `maps/`, migrations | Yes — on `apply_migrations` |
| **Start profiles** | Initial pilgrim/companion/inventory/world_state snapshot | `sql/seeds/profiles/` | Profile choice only |
| **Player state** | HP, XP, inventory qty, story flags, session_log | MariaDB per save (`nerdverse2`, `nerdverse_web_*`) | **Never** (author DB stays local) |

## Seed profiles

| Profile | File | Used when |
|---------|------|-----------|
| **Author checkpoint** | `profiles/author_checkpoint.sql` | Local `--fresh`, `--new-game` base (Meyiu mid-arc resume) |
| **Public arc start** | `profiles/public_arc_start.sql` | New browser tab — **full Brindleford arc from chapter 1** |

Public players get the **same storyline arc** (forge → medicine → sheriff → mill → bridge) with neutral starting stats. They do not start at your personal checkpoint.

## Local DEV + LLM DM workflow

1. **Play** `./play.sh` — your `nerdverse2` save (Prio 1; backup via `saves/db/`).
2. **Build content** while playing with Grok/LLM as DM:
   - New locations → `001_catalog.sql` + `maps/newplace.txt`
   - New enemies/scenarios → `scripts/lib/scenarios.sh`, `combat.sh`
   - New items/abilities → migrations or `003_progression_catalog.sql`
   - Schema changes → `sql/migrations/NNN_name.sql`
3. **Test migrations** `./scripts/apply_migrations.sh` (preserves your save).
4. **Test public path** locally (or playtest on server via `/play/`):
   ```bash
   export NERDVERSE_PUBLIC_TERMINAL=1
   export NERDVERSE_COMPACT=1
   export NERDVERSE_ACTIVE_DB_FILE=/tmp/test_web/active_db
   export NERDVERSE_SESSION_DIR=/tmp/test_web
   mkdir -p /tmp/test_web
   ./deploy/sandbox/nerdverse-cage.sh   # or play.sh --public-terminal after wizard
   ```
   Checklist: random names (not Meyiu/Sera), `nerdverse_web_*` in session `active_db`, forge ledger, telemetry `wizard_complete` event.
5. **Commit** engine + catalog changes (not `saves/`, not `nerdverse.env`).
6. **Promote** `./deploy/spin-up.sh root@STAGING` → UAT → PRD (same git ref).

Handoff (`saves/session_handoff.md`) is **dev-only** — LLM continuity for your session, not deployed.

## What flows on deploy

```
git push → spin-up.sh → install-server.sh
  → git pull on server
  → apply_migrations (catalog + new migrations)
  → restart ttyd
  → existing nerdverse_web_* player DBs unchanged
```

New public tabs after deploy get updated **engine + catalog** on their next fresh seed; existing tabs keep their in-progress DB until they sign off.

## Telemetry → balance loop

Public `/admin/` dashboard tracks:

- Session funnel (starts → registrations → sign-offs)
- Menu choices (where players get stuck)
- **Combat win rate**, avg damage taken, avg rounds (tune enemy HP/damage)
- Balance signal counts (`combat_end`, `breakthrough`, etc.)

Use this to adjust `combat.sh` enemy stats, Road XP awards, practice gains, and scenario rewards — then redeploy engine only.

## Environment promotion

| Env | Host | `NERDVERSE_GIT_REF` | Player data |
|-----|------|---------------------|-------------|
| DEV | Your Mac | `main` / feature branches | `nerdverse2` |
| Staging | droplet | tag or branch | `nerdverse_web_*` test traffic |
| UAT | droplet | release candidate tag | invited testers |
| PRD | droplet | release tag | live public |

```bash
NERDVERSE_GIT_REF=v0.5.0 ./deploy/spin-up.sh root@prd.example.com
```

## Rules

- **Never** restore `nerdverse2` SQL to a public server.
- **Never** put author story state in `001_catalog.sql` (neutral world text only).
- **Do** add new world content to catalog + lib scripts so both lanes benefit.
- **Do** keep `author_checkpoint.sql` for your personal resume point only.