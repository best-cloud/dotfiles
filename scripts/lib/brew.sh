# Homebrew helpers.
#
# Kept separate from shell.sh so Linux-only scripts do not carry macOS code.

# Install the Homebrew formulae or casks in the remaining arguments that are
# not installed yet. The first argument is "formula" or "cask".
#
# `brew install` aborts the whole batch when one package is unavailable (for
# example a cask that a third-party tap renamed), so a failed batch is retried
# one package at a time. Individual failures stay warnings: the caller verifies
# the tools it truly requires and the rest of the list is still attempted.
brew_install_missing() {
    _brew_kind=$1
    shift
    _brew_missing=
    for _brew_pkg in "$@"; do
        if ! brew list --"$_brew_kind" "$_brew_pkg" >/dev/null 2>&1; then
            _brew_missing="$_brew_missing $_brew_pkg"
        fi
    done
    if [ -z "$_brew_missing" ]; then
        return 0
    fi

    echo "==> brew install --$_brew_kind:$_brew_missing"
    # shellcheck disable=SC2086  # word splitting of the package list is intended
    if brew install --"$_brew_kind" $_brew_missing; then
        return 0
    fi

    echo "warning: batch install failed; retrying each $_brew_kind separately" >&2
    for _brew_pkg in $_brew_missing; do
        brew install --"$_brew_kind" "$_brew_pkg" ||
            echo "warning: $_brew_pkg installation failed" >&2
    done
    return 0
}
