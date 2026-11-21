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

# WSL appends the Windows PATH, so a bare `command -v` can resolve a Windows
# shim under /mnt (for example curl.exe or gsudo.exe). Those are slow when
# launched from Linux and use Windows paths, so only count native executables.
native_cmd() {
    _p=$(command -v "$1" 2>/dev/null) || return 1
    case "$_p" in
    /mnt/* | *.exe) return 1 ;;
    esac
    return 0
}

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
    if native_cmd curl; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

# Cache sudo credentials up front so the package script does not stop halfway.
if [ "$(id -u)" -ne 0 ] && native_cmd sudo; then
    sudo -v || true
fi

PATH="$HOME/.local/bin:$PATH"
export PATH

# WSL only: enable systemd in /etc/wsl.conf. The Ollama installer and other
# services expect a service manager. Merge the [boot] section instead of
# replacing the file, so [automount], [interop], [user] and other settings
# survive. systemd starts only after `wsl --shutdown` on Windows and a new
# session, so the rest of this bootstrap still runs without it.
if [ -r /proc/version ] && grep -qi microsoft /proc/version; then
    WSL_SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        if native_cmd sudo; then
            WSL_SUDO=sudo
        else
            echo "warning: sudo is required to enable systemd in /etc/wsl.conf; skipping" >&2
        fi
    fi
    if [ "$(id -u)" -eq 0 ] || [ -n "$WSL_SUDO" ]; then
        conf=/etc/wsl.conf
        new=$(mktemp)
        if [ -f "$conf" ]; then
            awk '
            function flush_boot() {
                if (in_boot && !boot_written) {
                    print "systemd=true"
                    boot_written = 1
                }
            }
            /^[[:space:]]*\[/ {
                flush_boot()
                header = $0
                gsub(/\r/, "", header)
                sub(/[[:space:]]*#.*$/, "", header)
                sub(/^[[:space:]]+/, "", header)
                sub(/[[:space:]]+$/, "", header)
                in_boot = (header == "[boot]")
                if (in_boot) boot_seen = 1
                print
                next
            }
            in_boot && /^[[:space:]]*systemd[[:space:]]*=/ {
                if (!boot_written) {
                    print "systemd=true"
                    boot_written = 1
                }
                next
            }
            { print }
            END {
                flush_boot()
                if (!boot_seen) {
                    print ""
                    print "[boot]"
                    print "systemd=true"
                }
            }' "$conf" >"$new"
        else
            printf '[boot]\nsystemd=true\n' >"$new"
        fi
        if [ -f "$conf" ] && [ "$(cat "$new")" = "$(cat "$conf")" ]; then
            rm -f "$new"
        else
            if [ -f "$conf" ] && [ ! -f "$conf.orig" ]; then
                $WSL_SUDO cp -a "$conf" "$conf.orig"
            fi
            $WSL_SUDO install -m 0644 "$new" "$conf"
            rm -f "$new"
            echo "==> enabled systemd in /etc/wsl.conf (run 'wsl --shutdown' on Windows to apply)"
        fi
    fi
fi

# Point apt at the Tsinghua TUNA mirror before installing prerequisites, so the
# whole bootstrap is fast. Ubuntu 24.04+ (including the current LTS) uses the
# deb822 format. Keep this in sync with
# run_onchange_before_05-ubuntu-mirror.sh.tmpl.
if [ -r /etc/os-release ] && command -v apt-get >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ "${ID:-}" = ubuntu ]; then
        mirror=""
        case "$(uname -m)" in
        x86_64 | amd64) mirror=https://mirrors.tuna.tsinghua.edu.cn/ubuntu ;;
        aarch64 | arm64) mirror=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports ;;
        esac
        codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
        if [ -n "$mirror" ] && [ -n "$codename" ] &&
            { [ "$(id -u)" -eq 0 ] || native_cmd sudo; }; then
            MIRROR_SUDO=""
            if [ "$(id -u)" -ne 0 ]; then
                MIRROR_SUDO=sudo
            fi
            deb822=/etc/apt/sources.list.d/ubuntu.sources
            new=$(mktemp)
            cat >"$new" <<EOF
# Managed by chezmoi: TUNA mirror, https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
Types: deb
URIs: $mirror
Suites: $codename $codename-updates $codename-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $mirror
Suites: $codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
            if [ -f "$deb822" ] && [ "$(cat "$new")" = "$(cat "$deb822")" ]; then
                rm -f "$new"
            else
                if [ -f "$deb822" ] && [ ! -f "$deb822.orig" ]; then
                    $MIRROR_SUDO cp -a "$deb822" "$deb822.orig"
                fi
                $MIRROR_SUDO mkdir -p /etc/apt/sources.list.d
                $MIRROR_SUDO install -m 0644 "$new" "$deb822"
                rm -f "$new"
                echo "==> apt sources now use $mirror"
            fi
        fi
    fi
fi

# `chezmoi init <repo>` clones with git, and the one-line bootstrap needs an
# HTTP client before anything is installed. Fresh Ubuntu Server and WSL images
# do not always ship git, so install the bootstrap prerequisites first.
if ! native_cmd git ||
    { ! native_cmd curl && ! native_cmd wget; }; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "==> installing bootstrap prerequisites (git, curl)"
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            if native_cmd sudo; then
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

if ! native_cmd git && [ "$LOCAL" -eq 0 ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "error: git is required. Install the Xcode Command Line Tools with" >&2
        echo "       'xcode-select --install' and re-run this script." >&2
    else
        echo "error: git is required to clone $REPO; install git and re-run." >&2
    fi
    exit 1
fi

if ! native_cmd chezmoi; then
    echo "==> installing chezmoi"
    if [ "$(uname -s)" = "Darwin" ] && native_cmd brew; then
        brew install chezmoi
    else
        fetch https://get.chezmoi.io | sh -s -- -b "$HOME/.local/bin"
    fi
fi

if ! native_cmd chezmoi; then
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
