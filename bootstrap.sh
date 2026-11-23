#!/bin/sh
# One-command bootstrap for Ubuntu Server, WSL2 and macOS.
#
# Usage (from a local checkout):
#   ./bootstrap.sh
#
# Usage (fresh machine, one line):
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.sh)"
#
# Options:
#   --repo URL   clone URL (default: https://github.com/best-cloud/dotfiles.git)
#   --ref REF    branch or tag to apply when cloning (CHEZMOI_REF)
#   -h, --help   show this help
#
# Environment:
#   CHEZMOI_REPO override the repository URL
#   CHEZMOI_REF  branch or tag to apply when cloning
#
# Generated from bootstrap.sh.tmpl by scripts/render-bootstrap.sh. Edit the
# template or scripts/lib/*.sh instead of this file.
set -eu

# Shared POSIX shell helpers.
#
# This file is included verbatim by the chezmoi templates and by the generated
# bootstrap script. Keep it free of top-level side effects and safe to source
# under `set -eu`.

# WSL appends the Windows PATH, so a bare `command -v` can resolve a Windows
# shim under /mnt. Those are slow from Linux and mishandle Linux paths, so only
# count native executables.
native_cmd() {
    case "$(command -v "$1" 2>/dev/null || true)" in
    '' | /mnt/* | *.exe) return 1 ;;
    *) return 0 ;;
    esac
}

can_root() {
    [ "$(id -u)" -eq 0 ] || native_cmd sudo
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Download a URL to stdout.
#
# Requires native_cmd from shell.sh. Kept separate because only the bootstrap
# needs to stream a script; the package installers download to a file.

fetch() {
    if native_cmd curl; then
        curl -fsSL "$1"
    elif native_cmd wget; then
        wget -qO- "$1"
    else
        echo "error: curl or wget is required" >&2
        return 1
    fi
}

# Point Ubuntu's apt sources at the Tsinghua TUNA mirror (deb822).
#
# The repository targets the current Ubuntu LTS (26.04+), which uses
# /etc/apt/sources.list.d/ubuntu.sources. The rewrite is idempotent: the source
# file is replaced only when its content differs, the original is backed up
# once, and third-party repositories in other files are untouched.
#
# https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
#
# Requires native_cmd/can_root/as_root from shell.sh.

configure_ubuntu_mirror() {
    [ -r /etc/os-release ] || return 0
    native_cmd apt-get || return 0
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = ubuntu ] || return 0

    case "$(uname -m)" in
    x86_64 | amd64) _mirror_url=https://mirrors.tuna.tsinghua.edu.cn/ubuntu ;;
    aarch64 | arm64) _mirror_url=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports ;;
    *)
        echo "warning: no TUNA mirror mapping for $(uname -m); keeping apt sources" >&2
        return 0
        ;;
    esac

    _mirror_codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    if [ -z "$_mirror_codename" ]; then
        echo "warning: could not determine the Ubuntu codename; keeping apt sources" >&2
        return 0
    fi

    if ! can_root; then
        echo "warning: sudo is required to update apt sources; skipping" >&2
        return 0
    fi

    _mirror_sources=/etc/apt/sources.list.d/ubuntu.sources
    _mirror_tmp=$(mktemp) || return 0
    trap 'rm -f "$_mirror_tmp"' EXIT
    cat >"$_mirror_tmp" <<EOF
# Managed by chezmoi: TUNA mirror, https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
Types: deb
URIs: $_mirror_url
Suites: $_mirror_codename $_mirror_codename-updates $_mirror_codename-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $_mirror_url
Suites: $_mirror_codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    if [ -f "$_mirror_sources" ] && cmp -s "$_mirror_tmp" "$_mirror_sources"; then
        rm -f "$_mirror_tmp"
        trap - EXIT
        return 0
    fi

    if [ -f "$_mirror_sources" ] && [ ! -f "$_mirror_sources.orig" ]; then
        as_root cp -a "$_mirror_sources" "$_mirror_sources.orig"
    fi

    as_root mkdir -p /etc/apt/sources.list.d
    as_root install -m 0644 "$_mirror_tmp" "$_mirror_sources"
    rm -f "$_mirror_tmp"
    trap - EXIT
    echo "==> apt sources now use $_mirror_url"
}

# WSL only: enable systemd in /etc/wsl.conf.
#
# The Ollama installer and other services expect a service manager. Merge the
# [boot] section instead of replacing the file, so [automount], [interop],
# [user] and other settings survive. systemd starts only after `wsl --shutdown`
# on Windows and a new session, so the rest of the bootstrap still runs without
# it.
#
# Requires can_root/as_root from shell.sh.

configure_wsl_systemd() {
    [ -r /proc/version ] || return 0
    grep -qi microsoft /proc/version || return 0

    if ! can_root; then
        echo "warning: sudo is required to enable systemd in /etc/wsl.conf; skipping" >&2
        return 0
    fi

    _wsl_conf=/etc/wsl.conf
    _wsl_tmp=$(mktemp) || return 0
    trap 'rm -f "$_wsl_tmp"' EXIT

    if [ -f "$_wsl_conf" ]; then
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
        }' "$_wsl_conf" >"$_wsl_tmp"
    else
        printf '[boot]\nsystemd=true\n' >"$_wsl_tmp"
    fi

    if [ -f "$_wsl_conf" ] && cmp -s "$_wsl_tmp" "$_wsl_conf"; then
        rm -f "$_wsl_tmp"
        trap - EXIT
        return 0
    fi

    if [ -f "$_wsl_conf" ] && [ ! -f "$_wsl_conf.orig" ]; then
        as_root cp -a "$_wsl_conf" "$_wsl_conf.orig"
    fi

    as_root install -m 0644 "$_wsl_tmp" "$_wsl_conf"
    rm -f "$_wsl_tmp"
    trap - EXIT
    echo "==> enabled systemd in /etc/wsl.conf (run 'wsl --shutdown' on Windows to apply)"
}

# Bootstrap helpers shared by the generated bootstrap.sh.
#
# Requires native_cmd/can_root/as_root from shell.sh and fetch from fetch.sh.

# True when running inside a WSL2 distribution.
running_in_wsl() {
    [ -r /proc/version ] && grep -qi microsoft /proc/version
}

# The package names, systemd socket activation and WSL assumptions target
# Ubuntu 26.04+. A warning is friendlier than a half-applied older release and
# still lets an advanced user continue on purpose.
check_supported_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "${ID:-}" = ubuntu ] && [ -n "${VERSION_ID:-}" ]; then
            if [ "$(printf '%s\n26.04\n' "$VERSION_ID" | sort -V | head -n 1)" != "26.04" ]; then
                echo "warning: this repository targets Ubuntu 26.04+ (found $VERSION_ID); continuing" >&2
            fi
        fi
    fi
}

# Install the tools that the one-line bootstrap needs before chezmoi exists.
install_bootstrap_prerequisites() {
    if native_cmd git && { native_cmd curl || native_cmd wget; }; then
        return 0
    fi

    if native_cmd apt-get; then
        echo "==> installing bootstrap prerequisites (git, curl)"
        if ! can_root; then
            echo "error: sudo is required to install git" >&2
            exit 1
        fi
        as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y ||
            echo "warning: apt-get update failed; using cached package indexes" >&2
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            git ca-certificates curl
    fi
}

install_chezmoi() {
    if native_cmd chezmoi; then
        return 0
    fi

    echo "==> installing chezmoi"
    if [ "$(uname -s)" = Darwin ] && native_cmd brew; then
        brew install chezmoi
    else
        fetch https://get.chezmoi.io | sh -s -- -b "$HOME/.local/bin"
    fi
}

REPO_FLAG=0
if [ -n "${CHEZMOI_REPO:-}" ]; then
    REPO_FLAG=1
fi
REPO="${CHEZMOI_REPO:-https://github.com/best-cloud/dotfiles.git}"
REF="${CHEZMOI_REF:-}"

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [--repo URL] [--ref REF]

  --repo URL   Git URL to clone (default: https://github.com/best-cloud/dotfiles.git)
  --ref REF    Branch or tag to apply when cloning
  -h, --help   Show this help

Environment variables CHEZMOI_REPO and CHEZMOI_REF provide the same defaults.
With a local checkout, the checkout itself is the source and --ref is ignored.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --repo)
        [ "$#" -ge 2 ] || die "--repo requires a URL"
        REPO=$2
        REPO_FLAG=1
        shift
        ;;
    --repo=*)
        REPO=${1#*=}
        REPO_FLAG=1
        ;;
    --ref)
        [ "$#" -ge 2 ] || die "--ref requires a branch or tag"
        REF=$2
        shift
        ;;
    --ref=*)
        REF=${1#*=}
        ;;
    *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
    shift
done

[ -n "$REPO" ] || die "the repository URL cannot be empty"

# Do not let a caller's CDPATH make `cd` print or pick another directory.
unset CDPATH

script_dir=$(dirname -- "$0")
if ! SCRIPT_DIR=$(cd -- "$script_dir" 2>/dev/null && pwd); then
    SCRIPT_DIR=$(pwd)
fi

# An explicit --repo/CHEZMOI_REPO wins; otherwise use the local checkout if
# there is one, and finally fall back to the repository URL.
if [ "$REPO_FLAG" -eq 0 ] && [ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]; then
    SOURCE="$SCRIPT_DIR"
    LOCAL=1
else
    SOURCE="$REPO"
    LOCAL=0
fi

if [ "$LOCAL" -eq 1 ] && [ -n "$REF" ]; then
    echo "warning: --ref applies to cloned sources; ignoring it for the local checkout at $SOURCE" >&2
    REF=
fi

check_supported_os

# Cache sudo credentials up front so the apt phase does not stop halfway. Only
# do this on apt-based hosts: prompting for sudo on macOS is unnecessary.
if native_cmd apt-get && [ "$(id -u)" -ne 0 ] && native_cmd sudo; then
    sudo -v || true
fi

PATH="$HOME/.local/bin:$PATH"
export PATH

configure_wsl_systemd
configure_ubuntu_mirror
install_bootstrap_prerequisites

if ! native_cmd git && [ "$LOCAL" -eq 0 ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "error: git is required. Install the Xcode Command Line Tools with" >&2
        echo "       'xcode-select --install' and re-run this script." >&2
    else
        echo "error: git is required to clone $REPO; install git and re-run." >&2
    fi
    exit 1
fi

install_chezmoi

if ! native_cmd chezmoi; then
    echo "error: chezmoi installation failed; install it manually and re-run." >&2
    exit 1
fi

echo "==> applying dotfiles from $SOURCE${REF:+ ($REF)}"
if [ "$LOCAL" -eq 1 ]; then
    chezmoi init --apply --source "$SOURCE"
elif [ -n "$REF" ]; then
    chezmoi init --apply "$SOURCE" --branch "$REF"
else
    chezmoi init --apply "$SOURCE"
fi

echo
if running_in_wsl; then
    echo "==> done. Run 'wsl --shutdown' from Windows, reopen Ubuntu, and start a new shell (or run: exec fish)."
else
    echo "==> done. Start a new shell to use fish, or run: exec fish"
fi
