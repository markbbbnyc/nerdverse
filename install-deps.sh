#!/usr/bin/env bash
# install-deps.sh
#
# Helper to show (and optionally install) the packages needed for Nerdverse
# on common Linux distributions.
#
# Usage:
#   ./install-deps.sh          # show commands for your distro
#   ./install-deps.sh --install   # try to install (requires sudo)

set -euo pipefail

INSTALL=false
if [[ "${1:-}" == "--install" ]]; then
    INSTALL=true
fi

echo "=== Nerdverse Linux Dependency Helper ==="
echo

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release >/dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

show_and_run() {
    local cmd="$1"
    echo "$cmd"
    if $INSTALL; then
        eval "sudo $cmd"
    fi
}

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary)
        echo "Detected: Debian/Ubuntu family ($DISTRO)"
        echo
        echo "Core packages:"
        show_and_run "apt update"
        show_and_run "apt install -y mariadb-client git bash coreutils sed gawk"
        echo
        echo "For full documentation building (PDF + HTML):"
        echo "  apt install -y texlive-latex-base texlive-fonts-recommended texlive-latex-extra pandoc"
        echo "  (or texlive-full for everything)"
        ;;
    fedora|rocky|almalinux|centos)
        echo "Detected: Fedora family ($DISTRO)"
        echo
        echo "Core:"
        show_and_run "dnf install -y mariadb git bash coreutils sed gawk"
        echo
        echo "Docs:"
        echo "  dnf install -y texlive-scheme-basic texlive-collection-fontsrecommended pandoc"
        ;;
    arch|manjaro)
        echo "Detected: Arch family ($DISTRO)"
        echo
        echo "Core:"
        show_and_run "pacman -Syu --needed mariadb-clients git bash coreutils sed gawk"
        echo
        echo "Docs:"
        echo "  pacman -S --needed texlive-basic texlive-latexrecommended pandoc"
        ;;
    opensuse*|suse)
        echo "Detected: openSUSE ($DISTRO)"
        echo
        echo "Core:"
        show_and_run "zypper install -y mariadb-client git bash coreutils sed gawk"
        echo
        echo "Docs:"
        echo "  zypper install -y texlive-latex texlive-fonts pandoc"
        ;;
    *)
        echo "Unknown or unsupported distro: $DISTRO"
        echo
        echo "Please consult docs/linux-packages.md for manual instructions."
        exit 1
        ;;
esac

echo
echo "After installing, run:"
echo "  cp nerdverse.env.example nerdverse.env"
echo "  ./bootstrap.sh"
echo
if ! $INSTALL; then
    echo "Re-run with --install to actually install the packages."
fi
