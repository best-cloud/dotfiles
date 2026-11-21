#!/bin/sh
# Static checks for the dotfiles repository.
#
# The Go templates are rendered into a throwaway directory with a scratch
# chezmoi configuration. Each rendered file is then checked with the tools that
# are installed; optional tools are skipped so a fresh machine can still run the
# basic checks. CI installs the tools it wants to require.
set -eu

unset CDPATH
script_dir=$(dirname -- "$0")
if ! ROOT=$(cd -- "$script_dir/.." 2>/dev/null && pwd); then
    ROOT=$(pwd)
fi

need() { command -v "$1" >/dev/null 2>&1; }
have_tomllib() { python3 -c 'import tomllib' >/dev/null 2>&1; }
fail() {
    echo "check failed: $*" >&2
    exit 1
}

need chezmoi || fail "chezmoi is required"
need sh || fail "sh is required"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home"
chezmoi init --apply=false --promptDefaults \
    --source "$ROOT" --destination "$tmp/home" --config "$tmp/chezmoi.toml" >/dev/null

if need python3 && have_tomllib; then
    python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$tmp/chezmoi.toml" ||
        fail "TOML: $tmp/chezmoi.toml"
fi

render_dir="$tmp/render"
mkdir -p "$render_dir"
find "$ROOT" -type f -name '*.tmpl' \
    -not -path "$ROOT/.git/*" -not -path "$ROOT/scripts/*" -print |
    sort >"$tmp/templates"

while IFS= read -r src; do
    rel=${src#"$ROOT"/}
    case "$rel" in
    .chezmoi.toml.tmpl)
        # Uses the prompt functions that are only available during chezmoi init.
        continue
        ;;
    esac
    out="$render_dir/$(printf '%s' "$rel" | sed 's|/|__|g; s|\.tmpl$||')"
    chezmoi execute-template --config "$tmp/chezmoi.toml" --source "$ROOT" <"$src" >"$out"
done <"$tmp/templates"

# .chezmoiignore is a template too, but does not use the .tmpl suffix.
chezmoi execute-template --config "$tmp/chezmoi.toml" --source "$ROOT" \
    <"$ROOT/.chezmoiignore" >"$render_dir/chezmoiignore"

# The bootstrap entry points are generated so they can share helpers while
# remaining standalone at runtime.
for name in bootstrap.sh bootstrap.ps1; do
    if ! cmp -s "$render_dir/$name" "$ROOT/$name"; then
        fail "$name is out of date; run scripts/render-bootstrap.sh"
    fi
done

check_sh() {
    [ -s "$1" ] || return 0
    sh -n "$1" || fail "sh syntax: $1"
    if need shellcheck; then
        shellcheck -x "$1" || fail "shellcheck: $1"
    fi
    if need shfmt; then
        shfmt -ln posix -d -i 4 "$1" || fail "shfmt: $1"
    fi
}

# Library fragments have no shebang, so pass the shell dialect explicitly.
check_sh_lib() {
    [ -s "$1" ] || return 0
    sh -n "$1" || fail "sh syntax: $1"
    if need shellcheck; then
        shellcheck -s sh -x "$1" || fail "shellcheck: $1"
    fi
    if need shfmt; then
        shfmt -ln posix -d -i 4 "$1" || fail "shfmt: $1"
    fi
}

check_fish() {
    [ -s "$1" ] || return 0
    if need fish; then
        fish -n "$1" || fail "fish syntax: $1"
    fi
}

check_ps1() {
    [ -s "$1" ] || return 0
    if need pwsh; then
        # shellcheck disable=SC2016  # single quotes keep the PowerShell $variables intact
        CHECK_FILE=$1 pwsh -NoLogo -NoProfile -NonInteractive -Command '
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($env:CHECK_FILE, [ref]$tokens, [ref]$errors) > $null
            if ($errors.Count -gt 0) {
                $errors | Out-String | Write-Error
                exit 1
            }
        ' || fail "PowerShell syntax: $1"
    fi
}

check_json() {
    if need python3; then
        python3 -m json.tool "$1" >/dev/null || fail "JSON: $1"
    fi
}

check_lua() {
    if need luac; then
        luac -p "$1" || fail "Lua syntax: $1"
    elif need lua; then
        lua -e 'assert(loadfile(arg[1]))' "$1" || fail "Lua syntax: $1"
    fi
}

check_toml() {
    if need python3 && have_tomllib; then
        python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$1" ||
            fail "TOML: $1"
    fi
}

for file in "$render_dir"/*; do
    case "$file" in
    *.sh) check_sh "$file" ;;
    *.fish) check_fish "$file" ;;
    *.ps1) check_ps1 "$file" ;;
    *.json) check_json "$file" ;;
    *.lua) check_lua "$file" ;;
    esac
done

# Non-template files that are checked in directly.
check_sh "$ROOT/bootstrap.sh"
check_sh "$ROOT/scripts/check.sh"
check_sh "$ROOT/scripts/render-bootstrap.sh"
check_sh_lib "$ROOT/scripts/lib/shell.sh"
check_sh_lib "$ROOT/scripts/lib/fetch.sh"
check_sh_lib "$ROOT/scripts/lib/installers.sh"
check_sh_lib "$ROOT/scripts/lib/brew.sh"
check_sh_lib "$ROOT/scripts/lib/ubuntu-mirror.sh"
check_sh_lib "$ROOT/scripts/lib/wsl.sh"
check_sh_lib "$ROOT/scripts/lib/bootstrap.sh"
check_ps1 "$ROOT/bootstrap.ps1"
check_ps1 "$ROOT/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
check_ps1 "$ROOT/scripts/lib/path.ps1"
check_ps1 "$ROOT/scripts/lib/winget.ps1"
check_json "$ROOT/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
check_lua "$ROOT/dot_config/nvim/init.lua"
check_lua "$ROOT/dot_config/wezterm/wezterm.lua"
check_toml "$ROOT/dot_config/starship.toml"

# The rendered Git config is valid when git can parse it.
if need git; then
    git config --file "$render_dir/dot_gitconfig" --list >/dev/null ||
        fail "git config: $render_dir/dot_gitconfig"
fi

# Some templates render empty on this OS. Their single Go template wrapper is
# stripped so the body is still checked: this covers the Windows PowerShell
# branches and the macOS-only shell scripts on every platform. Include actions
# are expanded first, because those bodies are not rendered by chezmoi here.
expand_template_body() {
    _body_src=$1
    _body_out=$2
    while IFS= read -r _body_line; do
        case "$_body_line" in
        *'{{ include "'*)
            _body_include=$(printf '%s' "$_body_line" |
                sed -n 's/.*{{ include "\([^"]*\)".*/\1/p')
            cat "$ROOT/$_body_include"
            ;;
        *) printf '%s\n' "$_body_line" ;;
        esac
    done <"$_body_src" | sed -e '1{/^{{/d;}' -e '${/{{ end/d;}' >"$_body_out"
}

mkdir -p "$tmp/bodies"
while IFS= read -r src; do
    rel=${src#"$ROOT"/}
    case "$rel" in
    *.ps1.tmpl | run_onchange_after_20-macos-defaults.sh.tmpl | run_onchange_after_50-optional-apps.sh.tmpl) ;;
    *) continue ;;
    esac
    out="$tmp/bodies/$(printf '%s' "$rel" | sed 's|/|__|g; s|\.tmpl$||')"
    expand_template_body "$src" "$out"
    case "$out" in
    *.sh) check_sh "$out" ;;
    *.ps1) check_ps1 "$out" ;;
    esac
done <"$tmp/templates"

if need actionlint; then
    actionlint "$ROOT/.github/workflows/ci.yml" || fail "actionlint: ci.yml"
fi

# On Linux, scripts for the other operating systems must render to whitespace
# only; chezmoi skips whitespace-only scripts.
if [ "$(uname -s)" = Linux ]; then
    for name in \
        run_onchange_after_20-macos-defaults.sh \
        run_onchange_after_30-spacemacs.ps1 \
        run_onchange_after_40-wsl.ps1 \
        run_onchange_after_50-optional-apps.sh \
        run_onchange_after_50-optional-apps.ps1 \
        run_onchange_before_10-install-packages.ps1; do
        if [ -f "$render_dir/$name" ] &&
            [ -n "$(tr -d '[:space:]' <"$render_dir/$name")" ]; then
            fail "rendered non-empty on Linux: $name"
        fi
    done
fi

echo "all checks passed"
