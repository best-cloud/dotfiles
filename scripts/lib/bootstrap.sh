# Bootstrap helpers shared by the generated bootstrap.sh.
#
# Requires native_cmd/can_root/as_root from shell.sh and fetch from fetch.sh.

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
        as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
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
