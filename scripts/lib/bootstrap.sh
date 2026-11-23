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
