#!/bin/sh
# One-command bootstrap for Ubuntu Server, WSL2 and macOS.
#
# Usage (from a local checkout):
#   ./bootstrap.sh
#
# Usage (fresh machine, one line):
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.sh)"
#
# Set CHEZMOI_REPO to override the repository URL, or change REPO below.
set -eu

REPO="${CHEZMOI_REPO:-https://github.com/best-cloud/dotfiles.git}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || pwd)

# An explicit CHEZMOI_REPO wins; otherwise use the local checkout if there is
# one, and finally fall back to the repository URL.
if [ -z "${CHEZMOI_REPO:-}" ] && [ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]; then
    SOURCE="$SCRIPT_DIR"
    LOCAL=1
else
    SOURCE="$REPO"
    LOCAL=0
fi

fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

# Cache sudo credentials up front so the package script does not stop halfway.
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo -v || true
fi

PATH="$HOME/.local/bin:$PATH"
export PATH

# `chezmoi init <repo>` clones with git, and the one-line bootstrap needs an
# HTTP client before anything is installed. Fresh Ubuntu Server and WSL images
# do not always ship git, so install the bootstrap prerequisites first.
if ! command -v git >/dev/null 2>&1 ||
    { ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; }; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "==> installing bootstrap prerequisites (git, curl)"
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            if command -v sudo >/dev/null 2>&1; then
                SUDO=sudo
            else
                echo "error: sudo is required to install git" >&2
                exit 1
            fi
        fi
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            git ca-certificates curl
    fi
fi

if ! command -v git >/dev/null 2>&1 && [ "$LOCAL" -eq 0 ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "error: git is required. Install the Xcode Command Line Tools with" >&2
        echo "       'xcode-select --install' and re-run this script." >&2
    else
        echo "error: git is required to clone $REPO; install git and re-run." >&2
    fi
    exit 1
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "==> installing chezmoi"
    if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        brew install chezmoi
    else
        fetch https://get.chezmoi.io | sh -s -- -b "$HOME/.local/bin"
    fi
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "error: chezmoi installation failed; install it manually and re-run." >&2
    exit 1
fi

echo "==> applying dotfiles from $SOURCE"
if [ "$LOCAL" -eq 1 ]; then
    chezmoi init --apply --source "$SOURCE"
else
    chezmoi init --apply "$SOURCE"
fi

echo
echo "==> done. Start a new shell to use fish, or run: exec fish"
