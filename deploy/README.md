# Nerdverse Public Terminal — Deploy & Ops

Browser → **nginx** → **ttyd** → **nerdverse-cage.sh** → isolated `nerdverse_web_*` MariaDB per browser tab.

Your author Life-2 save (`nerdverse2`, `saves/active_db`) **never** leaves your dev machine.

## Content pipeline

Engine + world catalog ship on every deploy; your Life-2 save does not. See **`docs/content-pipeline.md`** for DEV + LLM DM workflow, seed profiles, and telemetry-driven balance.

## Two lanes, one repo

| Lane | Host | Database | Seed |
|------|------|----------|------|
| **Author / dev** | Your Mac | `nerdverse2`, `nerdverse{N}_Companion` | `sql/seeds/002_fresh_game.sql` (your checkpoint) |
| **Public terminal** | Ubuntu server | `nerdverse_web_{hex}` per tab | `sql/seeds/profiles/public_arc_start.sql` (full arc ch.1) |

Shared template DB `nerdverse_public` holds **schema only** — no playable characters.

## Spin up a new game server (≈2 minutes)

**Requirements:** Ubuntu 22.04+ (or similar), root SSH, outbound HTTPS.

```bash
# From your Mac — one command:
chmod +x deploy/spin-up.sh deploy/bootstrap-remote.sh deploy/install-server.sh
./deploy/spin-up.sh root@YOUR_SERVER_IP
```

Equivalent:

```bash
./deploy/bootstrap-remote.sh root@YOUR_SERVER_IP
```

**On the server directly** (after `git clone`):

```bash
sudo bash /opt/nerdverse-public/deploy/install-server.sh
```

The install script is **idempotent** — safe to re-run for updates.

### What gets installed

| Component | Path / service |
|-----------|----------------|
| App tree | `/opt/nerdverse-public` |
| Play sessions | `/var/lib/nerdverse/sessions/{session_id}/active_db` |
| Telemetry | `/var/lib/nerdverse/telemetry/events.jsonl` |
| nginx site | `/etc/nginx/sites-available/nerdverse` |
| Web terminal | `systemd` unit `nerdverse-ttyd` (port 7681, proxied at `/play/`) |
| Play user | `nerdverse-play` (no login shell) |

### Endpoints after install

| URL | Purpose |
|-----|---------|
| `http://SERVER/` | Landing (`deploy/web/nerdverse.html`) |
| `http://SERVER/play/` | Sandboxed game terminal |
| `http://SERVER/about.html` | Full lore / operator page |
| `http://SERVER/health` | Health check (nginx) |
| `http://SERVER/admin/` | Author telemetry dashboard (HTTP basic auth) |

Admin credentials are printed at install time. Override before spin-up:

```bash
NERDVERSE_ADMIN_USER=dashboard NERDVERSE_ADMIN_PASS='your-secret' \
  ./deploy/spin-up.sh root@YOUR_SERVER_IP
```

## Security model

1. **Session isolation** — Each browser tab gets `nerdverse_web_{random_hex}`. `play.sh --public-terminal` **refuses** to run without a session `active_db` pointing at a `nerdverse_web_*` database.
2. **Separate seeds** — Public lives use `sql/seeds/profiles/public_arc_start.sql` (via `003_public_terminal_fresh.sql`), not the author checkpoint in `profiles/author_checkpoint.sql`.
3. **No shell** — `nerdverse-cage.sh` traps signals; Sign Off (`0` / F12) ends the session. `PATH` is `deploy/bin-cage/` only.
4. **Credentials** — `nerdverse.env` is `root:nerdverse-play` mode `640`. Session dirs are `nerdverse-play` only.
5. **Telemetry** — `stats.json` is owned by `nerdverse-play` so live aggregates work.

## Player flow

1. Open `/play/` → registration rolls random names (banner: **NEW PILGRIM │ Tab · new life**).
2. Press `.` + Enter to confirm (or `e` to customize).
3. Progress lines while MariaDB provisions: *Forging your life…* → *Provisioning* → *Seeding Brindleford Vale*.
4. Wizard creates `nerdverse_web_*`, renames pilgrim + companion, sets `active_db` in session dir.
5. Command ledger runs until Sign Off (`0` / F12). Public tabs skip daily SQL backup (no player-visible warnings).

### Public terminal UX notes

- Headers use ASCII `[*]` prefixes and `-` box borders (ttyd-safe; emoji breaks width math).
- Trust/Bond spelled out on compact HUD (not `T/B`).
- Companion name in ledger/quotes uses the registered name, not author defaults.
- Technical DB logs (`[web-session]`, `Ensuring database…`) go to stderr — not shown in the browser terminal.

## Environment variables (server install)

| Variable | Default | Purpose |
|----------|---------|---------|
| `NERDVERSE_INSTALL_ROOT` | `/opt/nerdverse-public` | Install path |
| `NERDVERSE_REPO_URL` | `https://github.com/markbbbnyc/nerdverse.git` | Git remote |
| `NERDVERSE_GIT_REF` | `main` | Branch / tag |
| `NERDVERSE_PLAY_USER` | `nerdverse-play` | Sandboxed Unix user |
| `NERDVERSE_ADMIN_USER` | `dashboard` | Admin dashboard htpasswd user |
| `NERDVERSE_ADMIN_PASS` | *(random on first install)* | Admin dashboard password |
| `NERDVERSE_INSTALL_FROM_SOURCE` | `0` | `1` = unpack uploaded tarball instead of git clone |
| `NERDVERSE_SOURCE_ARCHIVE` | *(set by bootstrap-remote)* | Path to `nerdverse-src.tar.gz` on server |

Server `nerdverse.env` is created from `deploy/nerdverse.env.public.example` with generated `DB_PASS` and `DB_SETUP_PASS` on first install.

## Updates (no save wipe)

**From your Mac:**

```bash
./deploy/spin-up.sh root@YOUR_SERVER_IP   # re-runs full idempotent install
```

**On server only:**

```bash
bash /opt/nerdverse-public/deploy/update-public.sh
```

Per-player `nerdverse_web_*` databases and session dirs are **not** deleted by updates.

## TLS (recommended)

```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d play.yourdomain.com
```

## File map

| Path | Role |
|------|------|
| `deploy/spin-up.sh` | One-command entry point |
| `deploy/bootstrap-remote.sh` | SSH orchestrator from dev machine |
| `deploy/install-server.sh` | Idempotent Ubuntu install (root) |
| `deploy/update-public.sh` | Fast git pull + migrations + ttyd restart |
| `deploy/sandbox/nerdverse-cage.sh` | Locked session loop |
| `deploy/web/` | Static HTML + admin dashboard |
| `deploy/nginx/nerdverse.conf` | Static + `/play/` proxy + `/admin/` |
| `deploy/systemd/nerdverse-ttyd.service` | ttyd unit |
| `scripts/lib/telemetry.sh` | JSONL event logging |
| `scripts/telemetry_aggregate.sh` | Roll-up for admin dashboard |
| `sql/seeds/003_public_terminal_fresh.sql` | Public fresh-game orchestrator |
| `sql/seeds/profiles/public_arc_start.sql` | Chapter 1 pilgrim start (public) |
| `sql/seeds/profiles/author_checkpoint.sql` | Author mid-arc checkpoint (dev only) |
| `docs/updates.md` | Session changelog (deploy + engine) |

## Scaling to multiple worlds

Each Ubuntu VM (or region) is independent:

```bash
./deploy/spin-up.sh root@us-east.example.com
./deploy/spin-up.sh root@eu-west.example.com
```

No shared database between servers — each host is a self-contained public shard.