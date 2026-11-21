# Upstream installer helpers.
#
# Requires native_cmd/as_root from shell.sh.

as_root_sh() {
    as_root sh "$@"
}

# Download and run a best-effort installer.
#
# Usage: install_from_url NAME URL INTERPRETER [ARG...]
#
# NAME is used in warnings, URL is downloaded to a temporary file, and
# INTERPRETER runs that file with the remaining arguments. Failures are
# warnings so the rest of the package set is still applied.
install_from_url() {
    if [ "$#" -lt 3 ]; then
        echo "error: install_from_url requires NAME URL INTERPRETER" >&2
        return 0
    fi

    _installer_name=$1
    _installer_url=$2
    _installer_interp=$3
    shift 3
    if ! _installer_tmp=$(mktemp); then
        echo "warning: $_installer_name temporary file failed" >&2
        return 0
    fi

    if native_cmd curl; then
        if ! curl -fsSL "$_installer_url" -o "$_installer_tmp"; then
            echo "warning: $_installer_name download failed" >&2
            rm -f "$_installer_tmp"
            return 0
        fi
    elif native_cmd wget; then
        if ! wget -qO "$_installer_tmp" "$_installer_url"; then
            echo "warning: $_installer_name download failed" >&2
            rm -f "$_installer_tmp"
            return 0
        fi
    else
        echo "warning: $_installer_name download needs curl or wget" >&2
        rm -f "$_installer_tmp"
        return 0
    fi

    if "$_installer_interp" "$_installer_tmp" "$@"; then
        :
    else
        echo "warning: $_installer_name installation failed" >&2
    fi
    rm -f "$_installer_tmp"
}
