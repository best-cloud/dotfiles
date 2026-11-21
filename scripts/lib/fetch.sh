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
