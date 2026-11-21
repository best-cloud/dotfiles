# Homebrew helpers.
#
# Kept separate from shell.sh so Linux-only scripts do not carry macOS code.

# Install the Homebrew formulae or casks in the remaining arguments that are
# not installed yet. The first argument is "formula" or "cask".
brew_install_missing() {
    _brew_kind=$1
    shift
    _brew_missing=
    for _brew_pkg in "$@"; do
        if ! brew list --"$_brew_kind" "$_brew_pkg" >/dev/null 2>&1; then
            _brew_missing="$_brew_missing $_brew_pkg"
        fi
    done
    if [ -n "$_brew_missing" ]; then
        echo "==> brew install --$_brew_kind:$_brew_missing"
        # shellcheck disable=SC2086  # word splitting of the package list is intended
        brew install --"$_brew_kind" $_brew_missing
    fi
}
