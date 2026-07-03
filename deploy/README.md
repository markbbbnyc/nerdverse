# Nerdverse Public Terminal Deploy

**Stretch goal:** browser → nginx → ttyd → sandboxed `play.sh` — without touching Mark's local Life 2 save.

## Architecture (two lanes, one repo)

| Lane | Where | Database | Purpose |
|------|-------|----------|---------|
| **Dev / Life game** | Your Mac (`~/Projects/nerdverse`) | `nerdverse2`, etc. | Continue your story |
| **Public fresh play** | Ubuntu `/opt/nerdverse-public` | `nerdverse_web_{hex}` per browser session | New visitors |

We use a **`deploy/` folder** in the same git repo (not a hard fork). Your local `saves/active_db` and `nerdverse2` are never deployed.

### Idempotent updates

Re-run `deploy/install-server.sh` on the server (or `bootstrap-remote.sh` from your Mac):

1. `git pull` in `/opt/nerdverse-public`
2. `./bootstrap.sh` / migrations (catalog only — no `--fresh` on existing template)
3. `systemctl restart nerdverse-ttyd`

Per-player session DBs under `/var/lib/nerdverse/sessions/` are **not** wiped.

## Sandbox (no shell escape)

- `ttyd -c deploy/sandbox/nerdverse-cage.sh` — no login shell
- User `nerdverse-play` has `/usr/sbin/nologin`
- `PATH` limited to `deploy/bin-cage/` (only `play` shim)
- Ctrl+C trapped; Sign Off (`0` / `F12`) exits session cleanly
- Crash → cage re-launches `play.sh`, never `/bin/bash`

## Character setup

First connect in a session → wizard (`character_create_wizard`):

- Player name, companion name, epithet
- Creates isolated `nerdverse_web_*` database
- Fresh Brindleford seed, then renames characters

## Quick deploy

```bash
# From your Mac (SSH key to root@24.144.103.2):
chmod +x deploy/bootstrap-remote.sh deploy/install-server.sh
./deploy/bootstrap-remote.sh root@24.144.103.2
```

Then open `http://24.144.103.2/` → **Play Game**.

## Files

| Path | Role |
|------|------|
| `deploy/bootstrap-remote.sh` | SSH orchestrator from dev machine |
| `deploy/install-server.sh` | Idempotent Ubuntu install on server |
| `deploy/sandbox/nerdverse-cage.sh` | Locked game session loop |
| `deploy/web/nerdverse.html` | Landing page |
| `deploy/nginx/nerdverse.conf` | Static + `/play/` proxy |
| `deploy/systemd/nerdverse-ttyd.service` | ttyd unit |
| `scripts/lib/character_create.sh` | Registration wizard |

## TLS (recommended)

Add certbot after HTTP works:

```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d your.domain
```