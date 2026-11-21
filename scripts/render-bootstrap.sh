#!/bin/sh
# Render the generated bootstrap entry points from their templates.
#
# bootstrap.sh and bootstrap.ps1 must stay standalone because they run before
# chezmoi and before the source checkout exists. They are generated here so the
# shared shell/PowerShell helpers live in one place.
set -eu

unset CDPATH
script_dir=$(dirname -- "$0")
if ! ROOT=$(cd -- "$script_dir/.." 2>/dev/null && pwd); then
    ROOT=$(pwd)
fi

command -v chezmoi >/dev/null 2>&1 ||
    {
        echo "error: chezmoi is required" >&2
        exit 1
    }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
: >"$tmp/chezmoi.toml"

for name in bootstrap.sh bootstrap.ps1; do
    chezmoi execute-template --config "$tmp/chezmoi.toml" --source "$ROOT" \
        <"$ROOT/$name.tmpl" >"$tmp/$name"
    if ! cmp -s "$tmp/$name" "$ROOT/$name"; then
        cat "$tmp/$name" >"$ROOT/$name"
        echo "rendered $name"
    fi
done

chmod 755 "$ROOT/bootstrap.sh"
chmod 644 "$ROOT/bootstrap.ps1"
