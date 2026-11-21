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
