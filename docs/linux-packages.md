# Linux Target System — Package Requirements

This document lists the packages you need to install on a fresh Linux system so that **Nerdverse** (the bash + MariaDB game + documentation) works fully.

The goal is **idempotent, repeatable setup** across your machines.

## Quick One-Liner Check

After cloning the repo, run:

```bash
./bootstrap.sh
```

It will tell you if the MariaDB client is missing and give hints.

---

## 1. Core Packages (Required to Play)

### Debian / Ubuntu / Linux Mint / Pop!_OS / elementary OS

```bash
sudo apt update
sudo apt install -y \
    mariadb-client \
    git \
    bash \
    coreutils \
    sed \
    gawk
```

**For local MariaDB server** (if you want to run the DB locally):

```bash
sudo apt install -y mariadb-server
sudo systemctl enable --now mariadb
# Then run the user creation steps from bootstrap / companion docs
```

### Fedora / Rocky Linux / AlmaLinux / CentOS Stream

```bash
sudo dnf install -y \
    mariadb \
    git \
    bash \
    coreutils \
    sed \
    gawk
```

**Server**:

```bash
sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb
```

### Arch Linux / Manjaro

```bash
sudo pacman -Syu --needed \
    mariadb-clients \
    git \
    bash \
    coreutils \
    sed \
    gawk
```

**Server**:

```bash
sudo pacman -S --needed mariadb
sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sudo systemctl enable --now mariadb
```

### openSUSE Tumbleweed / Leap

```bash
sudo zypper install -y \
    mariadb-client \
    git \
    bash \
    coreutils \
    sed \
    gawk
```

**Server**:

```bash
sudo zypper install -y mariadb
sudo systemctl enable --now mariadb
```

---

## 2. Documentation Building (Optional but Recommended)

These allow you to run `./docs/build-docs.sh` and get nice PDFs.

### Debian / Ubuntu family

```bash
sudo apt install -y \
    texlive-latex-base \
    texlive-fonts-recommended \
    texlive-latex-extra \
    texlive-latex-recommended \
    pandoc   # optional but excellent for HTML
```

For a full experience (bigger download):

```bash
sudo apt install -y texlive-full
```

### Fedora family

```bash
sudo dnf install -y \
    texlive-scheme-basic \
    texlive-collection-fontsrecommended \
    texlive-collection-latex \
    pandoc
```

Full:

```bash
sudo dnf install -y texlive-scheme-full
```

### Arch

```bash
sudo pacman -S --needed \
    texlive-basic \
    texlive-latexrecommended \
    texlive-fontsrecommended \
    pandoc
```

### openSUSE

```bash
sudo zypper install -y \
    texlive-latex \
    texlive-fonts \
    pandoc
```

> **Tip**: You can skip the LaTeX packages entirely if you only use the Markdown version (`docs/nerdverse-companion.md`), which renders perfectly on GitHub and most editors.

---

## 3. Nice-to-Have / Future Enhancements

These are not required today but make the experience better as we expand the engine:

```bash
# Better terminal UI / menus (when we add whiptail/dialog support)
# Debian/Ubuntu
sudo apt install -y whiptail dialog figlet

# Fedora
sudo dnf install -y whiptail dialog figlet

# Arch
sudo pacman -S --needed whiptail dialog figlet
```

- `figlet` or `toilet`: fancier ASCII art
- `whiptail` / `dialog`: prettier menus in the future
- `jq`: if we ever use JSON in bash scripts

---

## 4. Post-Install Steps (MariaDB User)

After installing the client + (optionally) server, make sure you have a user that can access `nerdverse2`.

Typical commands (run as root or with sudo):

```sql
CREATE DATABASE IF NOT EXISTS nerdverse2;
CREATE USER 'mark'@'localhost' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON nerdverse2.* TO 'mark'@'localhost';
FLUSH PRIVILEGES;
```

Then copy `nerdverse.env.example` → `nerdverse.env` and edit it.

See `README.md` and `docs/nerdverse-companion.md` (Runbook section) for full details.

---

## 5. Full "Fresh Linux Box" Checklist

1. `sudo apt update && sudo apt upgrade -y` (or equivalent)
2. Install core packages from section 1
3. (Optional) Install LaTeX + pandoc from section 2
4. Install MariaDB server if desired + create user + database
5. `git clone https://github.com/markbbbnyc/nerdverse.git`
6. `cd nerdverse`
7. `cp nerdverse.env.example nerdverse.env` (edit if needed)
8. `./bootstrap.sh`
9. `./play.sh`

---

## Notes for the Project

- This list is maintained in `docs/linux-packages.md`
- The `bootstrap.sh` script will warn you about missing `mariadb` / `mysql` client.
- The `docs/build-docs.sh` will tell you when LaTeX is missing.
- Keep this document in sync when we add new dependencies (e.g. when we add `dialog` menus or better ASCII tools).

Last updated: 2026-07-02 (Phase 0)
