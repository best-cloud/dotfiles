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
