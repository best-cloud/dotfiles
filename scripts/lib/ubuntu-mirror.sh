# Point Ubuntu's apt sources at the Tsinghua TUNA mirror (deb822).
#
# The repository targets the current Ubuntu LTS (26.04+), which uses
# /etc/apt/sources.list.d/ubuntu.sources. The rewrite is idempotent: the source
# file is replaced only when its content differs, the original is backed up
# once, and third-party repositories in other files are untouched.
#
# https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
#
# Requires native_cmd/can_root/as_root from shell.sh.

configure_ubuntu_mirror() {
    [ -r /etc/os-release ] || return 0
    native_cmd apt-get || return 0
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = ubuntu ] || return 0

    case "$(uname -m)" in
    x86_64 | amd64) _mirror_url=https://mirrors.tuna.tsinghua.edu.cn/ubuntu ;;
    aarch64 | arm64) _mirror_url=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports ;;
    *)
        echo "warning: no TUNA mirror mapping for $(uname -m); keeping apt sources" >&2
        return 0
        ;;
    esac

    _mirror_codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    if [ -z "$_mirror_codename" ]; then
        echo "warning: could not determine the Ubuntu codename; keeping apt sources" >&2
        return 0
    fi

    if ! can_root; then
        echo "warning: sudo is required to update apt sources; skipping" >&2
        return 0
    fi

    _mirror_sources=/etc/apt/sources.list.d/ubuntu.sources
    _mirror_tmp=$(mktemp) || return 0
    trap 'rm -f "$_mirror_tmp"' EXIT
    cat >"$_mirror_tmp" <<EOF
# Managed by chezmoi: TUNA mirror, https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
Types: deb
URIs: $_mirror_url
Suites: $_mirror_codename $_mirror_codename-updates $_mirror_codename-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $_mirror_url
Suites: $_mirror_codename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    if [ -f "$_mirror_sources" ] && cmp -s "$_mirror_tmp" "$_mirror_sources"; then
        rm -f "$_mirror_tmp"
        trap - EXIT
        return 0
    fi

    if [ -f "$_mirror_sources" ] && [ ! -f "$_mirror_sources.orig" ]; then
        as_root cp -a "$_mirror_sources" "$_mirror_sources.orig"
    fi

    as_root mkdir -p /etc/apt/sources.list.d
    as_root install -m 0644 "$_mirror_tmp" "$_mirror_sources"
    rm -f "$_mirror_tmp"
    trap - EXIT
    echo "==> apt sources now use $_mirror_url"
}
