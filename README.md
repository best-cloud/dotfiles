# dotfiles

chezmoi-managed dotfiles for **Ubuntu 26.04+** (including WSL2), **macOS** and
**Windows 11 26H2+**.

Design principles:

- **Developer experience first** — the shell, prompt, editor, terminal and
  Git/SSH tooling are configured together so a fresh machine feels familiar
  immediately: `fd`/`bat` under their upstream names, a Catppuccin theme
  everywhere, `fzf` history search, SSH connection reuse, Git LFS and delta,
  and one `chezmoi apply` to repair the whole setup.
- **Package manager first** — apt on Ubuntu/WSL, Homebrew on macOS, winget on
  Windows. Upstream installers are only a fallback for tools a distro does not
  package.
- **One file where one file is enough** — a single fish config, a single
  Starship config, a single Git config, a single Neovim config. Templates are
  used only where values or OS differences require them.
- **One primary terminal per desktop** — Windows Terminal on Windows
  (PowerShell 7 by default, plus WSL2 Ubuntu) and Ghostty on macOS. WezTerm
  remains available for WSL-only sessions. Ubuntu Server and WSL render in the
  client terminal.
- **fish first** on Ubuntu and macOS: installed, configured, and set as the
  login shell.
- **Emacs everywhere** — Emacs plus Spacemacs (`~/.emacs.d`) on all platforms.
- **One command per machine** to restore everything.

## One-command restore

This repository is configured for `github.com/best-cloud/dotfiles`. If you
fork it, update the URLs in `bootstrap.sh.tmpl`, `bootstrap.ps1.tmpl`, and here,
then regenerate the entry points with `scripts/render-bootstrap.sh`.

### Ubuntu Server, WSL2, macOS

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.sh)"
```

From a local checkout:

```sh
./bootstrap.sh
```

### Windows 11 (PowerShell)

```powershell
irm https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.ps1 | iex
```

From a local checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

Both bootstraps install chezmoi if needed, then run `chezmoi init --apply`.
chezmoi itself comes from Homebrew or winget where available, and from its
official installer on Linux (apt does not package it). Both bootstraps install
Git first when it is missing (plus `curl` on minimal Linux images), because the
first `chezmoi init` clones this repository with git. On first run you are
prompted once for your name and email (used by Git) and whether to install the
optional apps; those answers are stored in `~/.config/chezmoi/chezmoi.toml`.

The Unix bootstrap also accepts `--repo URL` and `--ref REF` (or the
`CHEZMOI_REPO` / `CHEZMOI_REF` environment variables), and the Windows
bootstrap accepts `-Repo` and `-Ref`. Use `--ref` to install a branch or tag
other than the default branch from a clone; when no repo override is given and
a local checkout exists, the checkout itself is the source and `--ref` is
ignored. `--help` prints the Unix usage.
The bootstrap warns, but continues, when the host predates Ubuntu 26.04 or
Windows 11. It also avoids prompting for sudo on macOS, where no apt phase
exists.

The generated config also records `sourceDir`. Without that, a bootstrap from a
local checkout would leave later `chezmoi apply`/`chezmoi status` calls looking
in the default source (`~/.local/share/chezmoi`), which does not exist.

`bootstrap.sh` asks for your sudo password once up front so the apt phase does
not stop halfway through.

On WSL2, `bootstrap.sh` also enables systemd by merging `systemd=true` into the
`[boot]` section of `/etc/wsl.conf`; the rest of the file (`[automount]`,
`[interop]`, `[user]`, …) is preserved and the edit is skipped when it is already
correct. WSL reads this file only when the distribution starts, so run
`wsl --shutdown` from Windows and reopen Ubuntu afterwards. If Ollama was
installed during the same bootstrap, enable its service after the restart with
`sudo systemctl enable --now ollama` (the installer writes the unit but cannot
enable it while systemd is not running).

### Repository URL

The bootstraps use `https://github.com/best-cloud/dotfiles.git`. If you fork
or rename the repository, update `REPO` in `bootstrap.sh.tmpl`, `$Repo` in
`bootstrap.ps1.tmpl`, and the URLs above, then run
`scripts/render-bootstrap.sh`.

For a private repository, make sure the fresh machine can authenticate to
GitHub (SSH key or `gh auth login`), or pass an SSH URL through
`CHEZMOI_REPO`.

## What gets installed

| | Ubuntu / WSL2 (apt) | macOS (Homebrew) | Windows 11 (winget) |
|---|---|---|---|
| Shell / prompt | fish, starship | fish, starship | PowerShell 7, Starship |
| Core CLI | git, git-lfs, curl, wget, build-essential, unzip, zip, bsdextrautils (col) | git, git-lfs, wget | Git, Git LFS |
| Modern CLI | ripgrep, fd-find, bat, eza, fzf, zoxide, jq, tree, htop, btop, tmux | ripgrep, fd, bat, eza, fzf, zoxide, jq, tree, htop, btop, tmux | ripgrep, fd, bat, eza, fzf, zoxide, jq |
| Editors / multiplexers | neovim, emacs, zellij | neovim, emacs, zellij | Neovim, Emacs, Zellij |
| Dev tools | gh, direnv, uv, AWS CLI, AWS CDK, lazygit, delta, mosh | gh, direnv, uv, AWS CLI, AWS CDK, lazygit, delta, mosh, WeChat DevTools, Postman | gh, direnv, uv, AWS CLI, AWS CDK, lazygit, delta, WeChat DevTools, Postman (mosh via WSL) |
| Containers | podman | podman | — |
| Node.js | fnm (upstream installer) + Node.js LTS | fnm (Homebrew) + Node.js LTS | fnm (winget) + Node.js LTS |
| AI / Python tooling | opencode, ruff, ollama | opencode, ruff, ollama | OpenCode, Ruff (ollama via WSL) |
| Formatters / linters | prettier, shfmt, shellcheck | prettier, shfmt, shellcheck | Prettier, shfmt, ShellCheck |
| Optional daily-use apps | see below (CLI tools) | see below | see below |
| Terminal | — (client terminal) | Ghostty | Windows Terminal, WezTerm |
| Remote access | openssh-server (Ubuntu Server 22, WSL 2222), mosh, wslu (WSL only) | mosh | Windows OpenSSH Server (22), firewall for 22 + WSL 2222/mosh |
| WSL2 / Ubuntu | — (native) | — | Microsoft.WSL + latest Ubuntu LTS |
| Terminal font | — (client terminal) | JetBrainsMono Nerd Font | JetBrainsMono Nerd Font |
| Editor config | Spacemacs in `~/.emacs.d` | Spacemacs in `~/.emacs.d` | Spacemacs in `%USERPROFILE%\.emacs.d` |

Node.js is always installed by fnm, and prettier and AWS CDK by npm, even where
the table's package-manager column is apt, Homebrew or winget. On Windows, the
OpenSSH Server is a Windows capability rather than a winget package.

The Linux install script always checks apt first. If the release does not
package a tool, it falls back to the upstream installer: `starship`, `uv` and
`fnm` use their install scripts, zellij uses the GitHub release binary, `ruff`
uses `uv tool install`, and prettier uses npm. Ollama and OpenCode are not
packaged by apt at all, so they use their upstream installers. `eza`,
`lazygit` and `git-delta` are installed from apt when the release provides
them; otherwise the script prints a warning and continues, and the shell/Git
config still works without them (`core.pager` falls back to `less`). apt
installs are retried one package at a time when a batch fails, so one
unavailable package does not block the rest of the list.

`wslu` is a WSL-only package: it provides `wslview`, which fish exports as
`BROWSER` so `gh auth login`, AWS SSO and `open`-style tools open links in the
Windows browser instead of failing. Ubuntu Server does not need it, and macOS
and Windows have their own URL handlers, so it is the one conditional package
in the Linux list.

`fd` and `bat` are installed from Ubuntu's `fd-find` and `bat` packages, whose
binaries are named `fdfind` and `batcat`. The Linux script links them into
`~/.local/bin` as `fd` and `bat` so the upstream names work in scripts, fzf,
Emacs and non-fish shells; the fish wrappers remain as a fallback on older
machines.

`git-lfs` is in all three lists and its clean/smudge filters are written
directly in `dot_gitconfig.tmpl` instead of by `git lfs install`. That keeps
`chezmoi apply` from deleting the filters from the managed `.gitconfig`. The
package scripts verify `git-lfs` and fail the run when it is missing, so LFS
repositories never silently check out pointer files.

`git-delta` is the Git pager and `interactive.diffFilter` on every platform,
with the Catppuccin Mocha syntax theme. `core.pager` uses
`delta || less -FRX`, so a machine where the delta install failed still has a
working pager.

`bsdextrautils` is a Linux-only dependency: it provides `col`, which the fish
`MANPAGER` pipeline uses to strip overstrike codes before `bat` renders a man
page. macOS ships `col` with the base system, and fish is not managed on
Windows, so the package has no counterpart in the Homebrew or winget lists.

Podman is installed on Ubuntu and macOS but not on Windows. On macOS it is only
the client; run `podman machine init` once before the first container so it can
start its Linux VM.

OpenCode is not packaged by apt, so the Linux script uses the upstream
installer and puts the launcher in `~/.opencode/bin`, which fish already adds to
`PATH`. macOS installs it from the upstream Homebrew tap
(`anomalyco/tap/opencode-v2`), and Windows installs the official portable
`Anomaly.OpenCode` winget package.

The AWS CLI comes from apt (`awscli`), Homebrew (`awscli`) and winget
(`Amazon.AWSCLI`). AWS CDK is distributed only through npm, so the scripts
install `aws-cdk` globally into `~/.local` (Unix) or `%APPDATA%\npm` (Windows)
after fnm has installed Node.js; both prefixes are on `PATH`.

Ubuntu packages `mosh` but not `ollama` (it ships only the `python3-ollama`
client library), so the Linux script installs Ollama with the upstream installer
at <https://ollama.com/install.sh>. That installer needs root, so it runs through
`sudo` when the script is not already root. In WSL without systemd the binary is
still installed; start the server with `ollama serve`. macOS gets both from
Homebrew (`mosh` and `ollama` formulae). Windows deliberately does not install
Ollama natively; use `ollama` from the WSL2 Ubuntu distribution instead.

mosh is installed on both Ubuntu Server and WSL (the same apt package), and on
macOS. It has no native Windows build or winget package, so on Windows it is
available through the WSL2 Ubuntu distribution; run it as `wsl mosh <host>`.

### SSH and mosh access

Windows 11 runs the built-in OpenSSH Server on the default **port 22**.
`run_onchange_after_35-windows-ssh.ps1.tmpl` installs the
`OpenSSH.Server~~~~0.0.1.0` Windows capability when needed, sets `sshd` to
start automatically, starts it, and creates a `Windows SSH (TCP 22)` inbound
firewall rule on the `Any` profile. It also sets OpenSSH's `DefaultShell`
registry value to PowerShell 7 (`pwsh.exe`), preferring the machine-wide MSI
path and falling back to the discovered winget/MSIX package, so SSH sessions
start in PowerShell 7 rather than `cmd.exe`. It sets the built-in
`OpenSSH Authentication Agent` service to Automatic and starts it, so
`AddKeysToAgent yes` from `~/.ssh/config` needs a passphrase only once. The
capability install and service setup need an elevated PowerShell. Connect to
the Windows host with:

```sh
ssh <windows-user>@<windows-lan-ip>
```

WSL2 Ubuntu separately serves SSH on **port 2222**. The Linux
package list includes `openssh-server` (Ubuntu Server images already have it),
and `run_onchange_after_45-wsl-ssh.sh.tmpl` writes
`/etc/ssh/sshd_config.d/00-chezmoi-wsl.conf` with `Port 2222`. Ubuntu 26.04+
starts SSH from `ssh.socket`, so the script also writes
`/etc/systemd/system/ssh.socket.d/zz-chezmoi-port.conf` and restarts
`ssh.socket` (the `zz-` prefix keeps the override after systemd's generated
`addresses.conf`). This targets Ubuntu 26.04+ and assumes systemd socket
activation; if systemd is not running yet, the script writes both files and
asks for `wsl --shutdown`. The script is a no-op on Ubuntu Server, so a server
keeps its normal SSH port. Port 2222 avoids colliding with the Windows OpenSSH
server, which normally owns port 22.

On the Windows side, `dot_wslconfig` sets `networkingMode=mirrored` so WSL2
shares the Windows host's network interfaces. WSL only reads `.wslconfig` when
the distribution starts, so run `wsl --shutdown` once after the first apply.
That restart also starts systemd, which is when the `ssh.socket` drop-in takes
effect if systemd was not running during the apply. Mirrored networking and the
Hyper-V firewall are part of the supported Windows 11 26H2+ baseline. The same
Windows script creates inbound rules for both the Windows Firewall and the
Hyper-V firewall:

- TCP 2222 for SSH;
- UDP 60000-61000 for mosh.

Both rule sets use the `Any` profile so they also work on networks classified as
Public. Creating them needs an elevated shell; a non-elevated apply warns and
skips them. Once the rules exist, other machines on the LAN can connect with:

```sh
ssh <windows-user>@<windows-lan-ip>            # Windows sshd, port 22
ssh -p 2222 <wsl-user>@<windows-lan-ip>        # WSL2 sshd, port 2222
mosh --ssh='ssh -p 2222' <wsl-user>@<windows-lan-ip>
```

Windows and WSL2 can be reached at the same LAN address because they listen on
different ports. mosh uses the WSL SSH connection on port 2222 and then switches
to its UDP port. Keep Windows on 22 and WSL on 2222; if one side is moved,
update `run_onchange_after_35-windows-ssh.ps1.tmpl`,
`run_onchange_after_45-wsl-ssh.sh.tmpl` and the firewall rules together.

Ubuntu 26.04 packages Starship 1.22.1, but the shipped
`catppuccin-powerline` preset uses `jj_bookmark`, added in Starship 1.27.0.
The script therefore installs the upstream Starship release into
`~/.local/bin` when the packaged version is older. That directory comes first
in `PATH`, so the newer binary shadows `/usr/bin/starship`.

### Node.js, prettier and linters

Node.js is never installed by apt, Homebrew or winget. Every platform uses
[fnm](https://github.com/Schniz/fnm): the Linux script installs it with the
upstream installer into `~/.local/share/fnm` (`--skip-shell`, so the installer
does not edit shell rc files), macOS installs `fnm` from Homebrew, and Windows
installs `Schniz.fnm` with winget. Each script then runs `fnm install --lts` and
`fnm default lts-latest`, so the current Node.js LTS is the default version.

fnm downloads Node.js from nodejs.org unless told otherwise, so every platform
points `FNM_NODE_DIST_MIRROR` at the TUNA mirror
(`https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/`), the same one the apt
and ELPA setup targets. The install scripts set it for the first install, and
fish and the PowerShell profile export it so later `fnm install <version>` runs
use it too. To bypass the mirror for one command, set the variable to
`https://nodejs.org/dist/` in that shell.

fish runs `fnm env --use-on-cd`; the PowerShell profile runs the same setup
with `--shell powershell`. That puts the default Node.js and npm on `PATH` and
switches versions automatically in directories with a `.node-version` or
`.nvmrc` file. `fnm install <version>`, `fnm use <version>` and `fnm list` work
as usual. Spacemacs does not use Node.js: nothing in the managed Emacs config
calls `node`, so only the shell and the tools you run yourself need it.

Prettier is installed with npm on every platform, including macOS. It is
deliberately not the Homebrew `prettier` formula, because that formula depends
on Homebrew's Node.js. On Unix the prefix is `~/.local`, which stays on `PATH`
regardless of which fnm version is active; on Windows the conventional
`%APPDATA%\npm` prefix is used and the PowerShell profile adds it to `PATH`.
AWS CDK uses the same prefixes. `shfmt` and `shellcheck` come from apt,
Homebrew and winget; they are the linters used by `scripts/check.sh`.

WSL appends the Windows `PATH`, so the install probes ignore non-native
executables (paths under `/mnt` or ending in `.exe`). Otherwise an inherited
Windows npm `prettier` would make the Linux script think the tool was already
installed and skip the native one, and every later `prettier` call would run a
Windows shim.

### Optional daily-use apps

Every platform can also install a personal set of optional applications. They
are opt-in because not every machine wants them: `chezmoi init` asks once and
defaults to no, and the answer is stored as `installOptionalApps` in
`~/.config/chezmoi/chezmoi.toml`. At the
`Install optional apps ... [y/N]` prompt, enter `y` (or `yes`/`true`) to
install the list, or `n` (or `no`/`false`, or just Enter) to skip it.

- Linux (apt + uv + upstream installers): `ffmpeg`, `deno`, `yt-dlp`.
- macOS (Homebrew formulae and casks): `ffmpeg`, `deno`, `yt-dlp`, plus the
  desktop casks `1password`, `google-chrome`, `flclash`, `notion`,
  `onlyoffice`, `iina`, `wechat`, `neteasemusic`, `openvpn-connect`,
  `windows-app`.
- Windows (winget): `yt-dlp.FFmpeg`, `DenoLand.Deno`, `yt-dlp.yt-dlp`, plus the
  desktop packages `AgileBits.1Password`, `Flow-Launcher.Flow-Launcher`,
  `Google.Chrome.EXE`, `chen08209.FlClash`, `Notion.Notion`,
  `ONLYOFFICE.DesktopEditors`, `Daum.PotPlayer`, `SumatraPDF.SumatraPDF`,
  `Tencent.WeChat.Universal`, `NetEase.CloudMusic`.

`yt-dlp` gets its strongly recommended dependencies on every platform:
`ffmpeg`/`ffprobe`, `yt-dlp-ejs` (bundled by the Homebrew formula and the
official Windows executable, and installed through uv's `default` extra on
Linux) and Deno as the JavaScript runtime. The managed
`~/.config/yt-dlp/config` selects Deno, allows `ejs:npm` remote components and
keeps a per-directory `archive.txt` download archive; XDG config is used on
Windows too because the profile sets `XDG_CONFIG_HOME`.

The macOS `flclash` cask is published in the `chen08209/tap` tap rather than
homebrew-cask, so the optional script taps it and installs it separately from
the other casks. Homebrew 7 refuses to load casks from third-party taps until
they are trusted, so the script runs `brew trust --cask chen08209/tap/flclash`
before the install.

The optional lists are deliberately disjoint from the mandatory package lists:
do not add a package to both stages. The main install scripts own development
tools and shared CLI utilities; the optional scripts own personal applications
(and Linux's optional list stays limited to CLI tools rather than desktop GUI
apps).

To enable it on an existing machine, add `installOptionalApps = true` under
`[data]` in `~/.config/chezmoi/chezmoi.toml` and run `chezmoi apply`; set it to
false to stop managing the list. `run_onchange_after_50-optional-apps.*` only
runs when the value is true. The WeChat DevTools and Postman packages are
development tools and are installed unconditionally on macOS and Windows.

## Ubuntu mirror (TUNA)

Ubuntu and WSL2 use the Tsinghua TUNA mirror
(<https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/>) for apt, including the
security suite. `run_onchange_before_05-ubuntu-mirror.sh.tmpl` rewrites the
deb822 source file before the package script runs, so every `apt-get update`
and install in the bootstrap is fast.

The repo targets the current Ubuntu LTS (26.04+), which uses
`/etc/apt/sources.list.d/ubuntu.sources`; the script creates that file if it is
missing:

- `arm64` uses the `ubuntu-ports` mirror; other architectures keep the
  existing sources.
- The original file is backed up once as `ubuntu.sources.orig`, and
  third-party repositories in other files are untouched.
- No legacy `/etc/apt/sources.list` is written.

The same implementation is shared by `bootstrap.sh` and the `05` script through
`scripts/lib/ubuntu-mirror.sh`, because the bootstrap installs git and curl
before chezmoi can apply anything. The generated bootstrap inlines that helper,
so it stays standalone.
TUNA may lag behind the official security archive by a few minutes; switch the
security suite back to `http://security.ubuntu.com/ubuntu` in the script if a
production machine needs immediate security updates.

## PyPI, Homebrew and npm mirrors

The package managers that apt does not drive use mirrors too:

- **uv / PyPI** — `dot_config/uv/uv.toml` (Unix) and
  `AppData/Roaming/uv/uv.toml` (Windows, because uv ignores XDG there) set
  `https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple` as the default index.
  This covers `uv tool install` (ruff, yt-dlp) and `uv pip`. The Linux branch
  of the package script also exports `UV_DEFAULT_INDEX` for the `ruff` install,
  because `run_onchange_before_` scripts run before the config file is applied.
  Set `UV_DEFAULT_INDEX=https://pypi.org/simple` to bypass the mirror for one
  command.
- **Homebrew** — the macOS branch exports `HOMEBREW_API_DOMAIN`
  (`https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api`) and
  `HOMEBREW_BOTTLE_DOMAIN`
  (`https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles`), and the macOS fish
  block sets them for interactive shells. Formula metadata and bottles
  therefore come from TUNA instead of GitHub.
- **npm** — TUNA no longer mirrors npm, so `prettier` and `aws-cdk` install
  through npmmirror (Alibaba) with
  `npm_config_registry=https://registry.npmmirror.com/`. fish and the PowerShell
  profile export it for interactive use, and the install scripts set it for the
  first apply. It is an environment variable rather than a managed `~/.npmrc`
  so npm's own `allow-scripts` allowlist (which `@opencode/cli` needs) survives;
  override it per command with `--registry=https://registry.npmjs.org/`.
- **Node.js** — covered in [Node.js, prettier and linters](#nodejs-prettier-and-linters).

## Git, SSH and shared developer configs

`dot_gitconfig.tmpl` is the single Git config on every platform. Besides the
usual rebase/prune/auto-setup-remote defaults it configures:

- `delta` as the pager and `interactive.diffFilter`, with a `less` fallback and
  the Catppuccin Mocha syntax theme;
- the LFS clean/smudge/process filters directly, so `git lfs` works in every
  clone without running `git lfs install` (which would be undone by the next
  `chezmoi apply`);
- `core.autocrlf=false` on Unix and `input` on Windows, plus `longpaths=true` on
  Windows, so cross-platform checkouts stay LF;
- `diff.algorithm=histogram`, `colorMoved=zebra`, `merge.conflictstyle=zdiff3`,
  `rerere`, `rebase.autoStash`, `column.ui=auto`, and short aliases such as
  `git undo`, `git wip`, `git root` and `git uncommit`.

`dot_gitignore_global` and `dot_config/git/attributes` are wired through
`core.excludesFile` and `core.attributesFile`. The ignore list covers the usual
OS/editor/Python/Node/infra artifacts (including `cdk.out/` and
`.terraform/`); the attributes file keeps working trees LF and marks common
binary formats.

`dot_ssh/config.tmpl` applies a small, host-independent client policy:

- `AddKeysToAgent yes`, keepalives for NAT/VPN sessions, and hashed known hosts;
- connection reuse (`ControlMaster auto`, `ControlPath ~/.ssh/control-%C`,
  `ControlPersist 10m`) on Unix, where OpenSSH supports it;
- `Host github.com` with `User git`, so `ssh github.com` works without a URL.

Machine-specific hosts, jump hosts and keys belong in `~/.ssh/config.d/*.conf`,
which is included first and is deliberately unmanaged.

### bat, ripgrep, gh and lazygit

These tools otherwise look in a platform-specific directory. The managed fish
and PowerShell environments set one path for all three operating systems, so
each tool has a single config file:

| Tool | Environment variable | Managed file |
|---|---|---|
| bat | `BAT_CONFIG_PATH` | `dot_config/bat/config` (Catppuccin Mocha, line numbers) |
| ripgrep | `RIPGREP_CONFIG_PATH` | `dot_config/ripgrep/config` (smart case, hidden, build-dir ignores) |
| GitHub CLI | `GH_CONFIG_DIR` | `dot_config/gh/config.yml` (SSH protocol, `gh pc/pv/co` aliases) |
| lazygit | `LG_CONFIG_FILE` | `dot_config/lazygit/config.yml` (Catppuccin theme, Nerd Font v3) |

Authentication stays out of the repo: `gh auth login` writes
`~/.config/gh/hosts.yml`, which chezmoi does not manage.

### Editor and login polish

`.editorconfig` is the repository style and the source for
`dot_editorconfig.tmpl`, which is managed as `~/.editorconfig`. Because the
target keeps `root = true`, it applies only when a project does not ship its own
file. It sets UTF-8, LF, a final newline, trimmed trailing whitespace, 4-space
defaults, 2-space JS/TS/JSON/YAML/Lua, tabs for Go and Makefiles, Python 4/100,
and keeps Markdown trailing spaces.

`empty_dot_hushlogin` creates an empty `~/.hushlogin`, which suppresses the
"Last login" banner on macOS and Ubuntu. The shell greeting is already empty.

## Repository layout

```text
.
├── .chezmoi.toml.tmpl                  # machine data + prompts (sourceDir, name, email, optional apps, OS flags)
├── .chezmoiignore                      # OS-specific and repo-only targets
├── .editorconfig                       # repo style; included by dot_editorconfig.tmpl
├── dot_editorconfig.tmpl               # managed ~/.editorconfig
├── .gitattributes                      # line-ending rules
├── .shellcheckrc                       # shellcheck target shell
├── bootstrap.sh.tmpl / bootstrap.ps1.tmpl   # one-command entry point sources
├── bootstrap.sh / bootstrap.ps1             # generated standalone entry points
├── scripts/
│   ├── check.sh                             # render + lint everything locally or in CI
│   ├── render-bootstrap.sh                  # regenerate bootstrap.sh/bootstrap.ps1
│   └── lib/                                 # shared shell/PowerShell fragments
├── .github/
│   ├── dependabot.yml                  # keep Actions current
│   └── workflows/ci.yml                # Linux + macOS + Windows check job
├── dot_gitconfig.tmpl                  # single Git config for all OSes (delta, LFS, aliases)
├── dot_gitignore_global                # global excludes
├── empty_dot_hushlogin                 # empty ~/.hushlogin (suppresses the banner)
├── dot_ssh/config.tmpl                 # SSH keepalive, agent, multiplexing
├── dot_wslconfig                       # Windows-only mirrored WSL networking
├── dot_spacemacs                       # default Spacemacs develop dotfile + TUNA ELPA
├── dot_config/
│   ├── bat/config                      # shared bat config (BAT_CONFIG_PATH)
│   ├── gh/config.yml                   # shared gh config (GH_CONFIG_DIR)
│   ├── git/attributes                  # global Git attributes
│   ├── lazygit/config.yml              # shared lazygit config (LG_CONFIG_FILE)
│   ├── ripgrep/config                  # shared rg config (RIPGREP_CONFIG_PATH)
│   ├── fish/config.fish.tmpl           # single fish config for Ubuntu + macOS
│   ├── starship.toml                   # catppuccin-powerline preset + uv python_binary
│   ├── zellij/config.kdl.tmpl          # shared; Windows uses ZELLIJ_CONFIG_DIR
│   ├── nvim/init.lua                   # plugin-free, works offline
│   ├── yt-dlp/config                   # optional yt-dlp/Deno/archive settings
│   ├── uv/uv.toml                      # TUNA PyPI index for uv (Unix)
│   ├── wezterm/wezterm.lua             # WezTerm (alternative), WSL2 Ubuntu only
│   └── ghostty/config                  # macOS terminal
├── AppData/
│   ├── Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/
│   │   └── LocalState/settings.json    # Windows Terminal, Catppuccin Mocha
│   └── Roaming/uv/uv.toml              # TUNA PyPI index for uv (Windows)
├── Documents/
│   ├── PowerShell/
│   │   └── Microsoft.PowerShell_profile.ps1.tmpl   # PowerShell 7
│   └── WindowsPowerShell/
│       └── Microsoft.PowerShell_profile.ps1        # PS 5.1 shim
├── run_onchange_before_05-ubuntu-mirror.sh.tmpl       # TUNA apt mirror
├── run_onchange_before_10-install-packages.sh.tmpl    # apt + Homebrew
├── run_onchange_before_10-install-packages.ps1.tmpl   # winget
├── run_onchange_after_20-default-shell.sh.tmpl        # chsh to fish
├── run_onchange_after_20-macos-defaults.sh.tmpl       # .DS_Store off NAS/USB
├── run_onchange_after_30-spacemacs.sh.tmpl            # clone Spacemacs (Unix)
├── run_onchange_after_30-spacemacs.ps1.tmpl           # clone Spacemacs (Windows)
├── run_onchange_after_35-windows-ssh.ps1.tmpl         # Windows OpenSSH on 22, pwsh 7
├── run_onchange_after_40-wsl.ps1.tmpl                 # WSL2 + Ubuntu + firewall
├── run_onchange_after_45-wsl-ssh.sh.tmpl              # WSL2 sshd on port 2222
├── run_onchange_after_50-optional-apps.sh.tmpl        # optional macOS apps
├── run_onchange_after_50-optional-apps-linux.sh.tmpl  # optional Linux CLI apps
└── run_onchange_after_50-optional-apps.ps1.tmpl       # optional Windows apps
```

## How the scripts work

The installers are `run_onchange_` scripts: chezmoi hashes the rendered content
and re-runs a script only when it changes. Add a package to a list, run
`chezmoi apply`, and it installs just that package (all scripts are
idempotent).

Individual downloads stay best-effort so one failure does not block the rest of
the list. The tools with no distro package (Node.js from fnm, prettier, AWS CDK)
and `git-lfs` are verified at the end of the package script, though: when one
is still missing the script exits non-zero, `chezmoi apply` reports the error,
and chezmoi re-runs the script on the next apply instead of recording a partial
install as done. A failed apt or Homebrew batch is retried one package at a
time, so a single unavailable package does not hide the rest.

The scripts are templates too. On the wrong OS a script renders to whitespace,
and chezmoi skips whitespace-only scripts entirely. That is why a `.ps1`
script is safe in the same repo as Linux/macOS `.sh` scripts.

Shared POSIX shell and PowerShell helpers live in `scripts/lib/` and are inlined
with chezmoi's `include` function, so each rendered script stays self-contained
while the source has one copy. `bootstrap.sh` and `bootstrap.ps1` are generated
from their `.tmpl` sources by `scripts/render-bootstrap.sh`; that keeps them
standalone at runtime while sharing the same helpers. Edit the templates or the
libraries, then run the renderer and `scripts/check.sh`.

To force every `run_onchange_` script to run again, delete its entry from
chezmoi's state. Script hashes are stored in `entryState` (the old
`--bucket=scriptState` is no longer used by current chezmoi):

```sh
chezmoi state dump   # script entries have "type": "script"
chezmoi state delete --bucket=entryState --key="$HOME/10-install-packages.sh"
chezmoi apply
```

### Static checks

`scripts/check.sh` renders every template into a temporary directory with a
scratch chezmoi config, then validates the output:

- `sh -n`, `shellcheck` and `shfmt` for shell scripts;
- `fish -n` for the fish config;
- the PowerShell parser for `.ps1` files, including the Windows branches of
  `.ps1.tmpl` files (the Go template wrapper is stripped and includes expanded);
- JSON, TOML, YAML and Lua parsing for the configs, `git config` for the
  rendered Git config, `ssh -G -F` for the SSH config, and Emacs `check-parens`
  for `dot_spacemacs`;
- a sync check that fails when `bootstrap.sh` or `bootstrap.ps1` differs from
  its rendered template;
- a line-ending check that fails when the Git index or working tree contains
  CRLF (the repository is LF-only; this is what broke `.shellcheckrc` on a
  Windows checkout).

Missing optional tools are skipped, so the script is useful on a fresh machine.
It looks for `python3` and then `python`, and ignores the broken Microsoft Store
execution aliases; on Windows without a real Python, the JSON check falls back
to `ConvertFrom-Json`. `.github/workflows/ci.yml` runs the checks on Linux,
macOS and Windows (Git Bash) with the tools installed, and runs `actionlint` on
the workflow itself on Linux. Dependabot keeps the Actions current. Run the
checks before committing a change:

```sh
sh scripts/check.sh
```

After editing `bootstrap.sh.tmpl`, `bootstrap.ps1.tmpl`, or anything under
`scripts/lib/`, regenerate the standalone entry points and commit both files:

```sh
./scripts/render-bootstrap.sh
```

### Adding an application

1. Add the package name to the relevant list in
   `run_onchange_before_10-install-packages.sh.tmpl` (apt and Homebrew lists)
   and/or `run_onchange_before_10-install-packages.ps1.tmpl` (winget ID).
   Personal daily-use applications belong in
   `run_onchange_after_50-optional-apps.sh.tmpl` (Homebrew),
   `run_onchange_after_50-optional-apps-linux.sh.tmpl` (Linux CLI tools) or
   `run_onchange_after_50-optional-apps.ps1.tmpl` (winget); those scripts only
   run when `installOptionalApps` is true.
2. Run `chezmoi apply`.
3. Commit and push.

### Adding a dotfile

```sh
chezmoi add ~/.config/some-tool/config.toml
# or, if it needs templating:
chezmoi add --template ~/.config/some-tool/config.toml
```

Single files are preferred. Use `dot_config/tool/config.toml` directly; add
`.tmpl` only if the file needs OS or machine values. Use
`dot_config/tool/config.$(OS).toml`-style separate files only when formats
genuinely differ.

## fish configuration

`dot_config/fish/config.fish.tmpl` is the only managed fish file. It:

- adds `~/.local/bin`, `~/.cargo/bin`, `~/.opencode/bin` and `~/.deno/bin`,
  plus `~/.local/share/fnm` on Linux, to `PATH`;
- loads Homebrew's `shellenv` on macOS only, disables Homebrew analytics and
  env hints, and points Homebrew at the TUNA API/bottle mirrors;
- initializes fnm (`fnm env --use-on-cd`) when it is installed;
- exports `BAT_CONFIG_PATH`, `RIPGREP_CONFIG_PATH`, `GH_CONFIG_DIR`,
  `LG_CONFIG_FILE` and `DO_NOT_TRACK`;
- defines `fd`/`bat` wrappers for Ubuntu's `fdfind`/`batcat` names as a
  fallback for machines that predate the `~/.local/bin` links;
- defines `mkcd` and `reload`;
- initializes Starship, zoxide, fzf and direnv;
- adds guarded abbreviations (`ls` → `eza`, `cat` → `bat`, `vi` → `nvim`,
  `e` → `emacs -nw`, `zj` → zellij, `o` → opencode, `gco`/`gsw`/`grb`/`gaa`/
  `gpush`/`gpull` for Git, …);
- sources `~/.config/fish/local.fish` if it exists for machine-local tweaks.

The PowerShell 7 profile defines the same aliases and abbreviations as the fish
config, so the two shells stay consistent across platforms. It also exports the
same shared config paths, hooks direnv, and maps Ctrl+R/Ctrl+T to fzf history
and file pickers when fzf is installed. The 5.1 shim inherits everything by
dot-sourcing that profile.

`run_onchange_after_20-default-shell.sh.tmpl` adds the fish path to
`/etc/shells` when needed and runs `chsh`. Log out and back in (or run
`exec fish`) when it finishes.

The Starship config is the `catppuccin-powerline` preset, so the prompt uses
Nerd Font glyphs and powerline separators. Install `JetBrainsMono Nerd Font`
on the machine that renders the terminal (the Windows and macOS package scripts
do this automatically); the managed WezTerm and Ghostty configs already select
it. If you only have a bare TTY or a terminal without a Nerd Font, regenerate
the file with a fallback preset instead:

```sh
starship preset no-nerd-font -o dot_config/starship.toml
```

To pick up preset changes after a Starship upgrade:

```sh
starship preset catppuccin-powerline -o dot_config/starship.toml
```

Regenerating drops the one local override in the file: the `[python]` table sets
`python_binary` to
`[['uv', 'run', '--no-python-downloads', '--no-project', 'python'], 'python3', 'python']`
so the prompt shows the interpreter uv resolves for the current directory and
still works where uv is not on `PATH`. Re-add it after regenerating.

## Terminals

### Windows: Windows Terminal

`AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`
is applied to the packaged Windows Terminal settings file. It:

- makes PowerShell 7 the `defaultProfile` (profile GUID
  `{574e775e-4f2a-5b96-ac1e-a2962a402336}`, the `Windows.Terminal.PowershellCore`
  source);
- adds an Ubuntu profile that runs `wsl.exe -d Ubuntu --cd ~`, and disables the
  generated WSL/Azure/Visual Studio profile sources so the profile list stays
  deterministic;
- matches the managed WezTerm font and palette: Catppuccin Mocha, JetBrainsMono
  Nerd Font medium at 12 pt, a deliberately taller 1.5 cell height, 92% acrylic
  opacity, a hidden tab row when only one tab is open, 100k-line scrollback and
  a 160x44 initial window;
- embeds the `Catppuccin Mocha` color scheme and terminal theme copied verbatim
  from <https://github.com/catppuccin/windows-terminal> (`mocha.json` and
  `mochaTheme.json`).

Windows Terminal reads the file at startup; use Ctrl+Shift+Comma to open the
JSON file, or restart the app, after `chezmoi apply` changes it. The path is
under `%LOCALAPPDATA%` and is unaffected by a redirected `Documents` folder.

### Windows: WezTerm (WSL-only)

`dot_config/wezterm/wezterm.lua` is applied to
`~/.config/wezterm/wezterm.lua`. It sets `WSL:Ubuntu` as the default domain and
defines no PowerShell or cmd launch-menu entry. If `wsl --list --quiet` reports
another name (for example `Ubuntu-24.04`), change `distribution` in the config.

The config uses the WebGpu front end, the high-performance GPU preference, a
120 fps cap and a 100k-line scrollback, sized for a 2K display at 100% scaling.
The window is fully opaque: `win32_system_backdrop` and
`window_background_opacity` are deliberately not set because the Acrylic/Mica
backdrop path has driver compatibility problems with NVIDIA GPUs on Windows.
WezTerm checks `~/.config/wezterm/wezterm.lua` before `~/.wezterm.lua`, so an
old unmanaged `~/.wezterm.lua` is ignored and can be deleted.

### macOS: Ghostty

Homebrew installs the `ghostty` cask, and `dot_config/ghostty/config` is applied
to `~/.config/ghostty/config`. It uses the same JetBrainsMono Nerd Font Medium
and Catppuccin Mocha as WezTerm, with slightly taller cells and matching text
padding, but 14 pt (larger than WezTerm's 12 pt, which is sized for the 2K
Windows screen) and 92% opacity with a blurred background where WezTerm stays
opaque. Window chrome, initial window size and macOS window behavior are left
to Ghostty instead of imitating WezTerm's Windows-oriented decoration. It also
uses fish shell integration. Only the left Option key acts as Alt, and
Alt+Left/Right are unbound so the shell gets them for word-wise movement.
Reload from inside Ghostty with Cmd+Shift+Comma; `ghostty +list-themes` and
`ghostty +list-fonts` show the names available on the machine.

### macOS: NAS and USB metadata

`run_onchange_after_20-macos-defaults.sh.tmpl` sets the per-user
`com.apple.desktopservices` keys `DSDontWriteNetworkStores` and
`DSDontWriteUSBStores`, so Finder stops writing `.DS_Store` files on network
shares (SMB/AFP/NAS) and removable media (USB drives, SD cards). The script
restarts Finder only when it changes a value; otherwise it is a no-op.

These settings are preventive: existing `.DS_Store` and AppleDouble `._*` files
stay until removed. To clean a mounted volume:

```sh
find /Volumes/<name> \( -name .DS_Store -o -name '._*' \) -delete
```

AppleDouble `._*` files can still be produced by command-line copies to
FAT/exFAT media; use `ditto --norsrc --noextattr` or `rsync --exclude='._*'`
when that matters.

## Windows notes

- Run `bootstrap.ps1` on Windows itself, not inside WSL, so winget apps and the
  PowerShell profile are applied. If your winget policy requires machine-wide
  installs, run it from an elevated PowerShell; user-scope installs work from a
  normal window. The Windows OpenSSH Server capability, service and firewall
  rule also need an elevated window.
- The PowerShell 7 profile template is
  `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`. Windows
  PowerShell 5.1 uses a different path, so
  `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` is a tiny shim
  that dot-sources the PS7 profile. The shim checks both the shell's `Documents`
  folder and `%USERPROFILE%\Documents`, so a OneDrive redirect still works.
- The profile sets `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` and
  `XDG_CACHE_HOME` to Unix-style locations under your home directory. This lets
  Neovim, Starship, Zellij and WezTerm use the same managed config files as
  Linux/macOS instead of duplicating them in `%LOCALAPPDATA%`. Zellij ignores
  `XDG_CONFIG_HOME` on Windows, so the profile also sets `ZELLIJ_CONFIG_DIR`.
- The profile also points `BAT_CONFIG_PATH`, `RIPGREP_CONFIG_PATH`,
  `GH_CONFIG_DIR` and `LG_CONFIG_FILE` at the shared `~/.config` files, exports
  `DO_NOT_TRACK` and `POWERSHELL_TELEMETRY_OPTOUT`, hooks direnv when it is
  installed, and maps Ctrl+R/Ctrl+T to fzf history/file pickers. It forces UTF-8
  for redirected output and native-command pipelines so PowerShell 5.1 does not
  write UTF-16 files.
- The profile sets `SHELL` to `pwsh` under PowerShell 7 and to `powershell`
  under Windows PowerShell 5.1, so Zellij panes start in PowerShell instead of
  falling back to `cmd.exe`. The 5.1 shim dot-sources the PS7 profile, and the
  version check keeps each shell pointing at itself.
- PowerShell 7 is installed first by the winget script. The script itself is
  compatible with Windows PowerShell 5.1 in case chezmoi starts under it.
- The Nerd Font ships as a machine-scope MSI, so install it from an elevated
  window. The managed Windows Terminal and WezTerm configs both select
  `JetBrainsMono Nerd Font`.
- Windows Terminal is the default Windows client and opens PowerShell 7; its
  managed settings live under
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState`.
  It copies on select, strips formatting, trims pasted whitespace, uses compact
  tabs and a 1.5 cell height (manually tuned; WezTerm keeps its own 1.1 line
  height). WezTerm stays installed for WSL-only sessions and opens WSL2
  directly.
- `run_onchange_after_35-windows-ssh.ps1.tmpl` enables the built-in Windows
  OpenSSH Server on port 22: it installs the `OpenSSH.Server` capability, sets
  the `sshd` service to Automatic and starts it, adds a `Windows SSH (TCP 22)`
  inbound firewall rule for the `Any` profile, and points `DefaultShell` at
  PowerShell 7 (`pwsh.exe`). It needs an elevated shell. WSL2 stays on 2222, so
  both are reachable at the same LAN address.
- `run_onchange_after_40-wsl.ps1.tmpl` sets WSL2 as the default version and
  registers the `Ubuntu` distribution when it is missing. The first
  `wsl --install` that enables the optional Windows features needs an elevated
  shell and sometimes a reboot; the script prints the exact command and exits
  cleanly when it is not elevated. Launch Ubuntu once after it is registered to
  create the Linux user.
- The managed `~/.wslconfig` keeps `networkingMode=mirrored` and
  `firewall=true`, and puts `autoMemoryReclaim=gradual` (return idle RAM to
  Windows), `sparseVhd=true` and `hostAddressLoopback=true` under
  `[experimental]`, where this WSL build still expects them. DNS tunneling and
  automatic proxy forwarding are deliberately omitted because this machine's
  VPN lives on the router, not on Windows. The same script creates the Windows
  Firewall and Hyper-V firewall rules for SSH on TCP 2222 and mosh on UDP
  60000-61000. Run `wsl --shutdown` after the first apply so WSL picks up the
  new settings; create the rules from an elevated shell.
- Run `bootstrap.sh` inside the WSL distro as well; the two sides are
  independent chezmoi installations.

## Emacs and Spacemacs

Emacs is installed on every platform (`emacs` from apt or Homebrew, `GNU.Emacs`
from winget). `run_onchange_after_30-spacemacs.*` clones the Spacemacs
`develop` branch into `~/.emacs.d` on the first apply; an existing checkout is
never switched or overwritten because Spacemacs updates itself (`SPC f e U`).

`dot_spacemacs` is the upstream develop `.spacemacs` template plus the TUNA
ELPA snippet from the develop section of
<https://mirrors.tuna.tsinghua.edu.cn/help/elpa/>. It sets
`configuration-layer-elpa-archives` to the `melpa-cn`, `org-cn` and `gnu-cn`
mirrors, plus `nongnu-cn` because Spacemacs' lock file also uses NonGNU ELPA
and the org layer needs `org-contrib` from it. `org-cn` is kept to match the
published snippet even though TUNA's org mirror currently serves the
orgmode.org website and its `archive-contents` returns 404; the startup warning
is harmless until the mirror is fixed. macOS also installs `gnu-tar`
(Homebrew's `gtar`) because quelpa prefers it over the system BSD tar. The GUI
default font is JetBrainsMono NF at 12 pt medium weight, and
the mode-line theme uses `:separator-scale 1.1` to match the managed WezTerm
profile. The first Emacs start downloads Spacemacs packages through the mirror,
so it needs network access once. Edit the repo copy rather than `~/.spacemacs`;
values Emacs appends at the end of the file are reverted by the next
`chezmoi apply`.

The enabled layers cover editing and navigation (`auto-completion`,
`better-defaults`, `git`, `helm`, `multiple-cursors`, `syntax-checking`,
`treemacs`, `version-control`) and the common languages `python`, `javascript`,
`typescript`, `html` (which also handles CSS/SCSS/Less), `yaml`, `json`,
`markdown`, `org` and `shell-scripts`. Python is the only language that formats
on save:

- `syntax-checking` runs Flycheck, which prefers its built-in `python-ruff`
  checker when `ruff` is on `PATH` (Flycheck 39+).
- The Python layer is configured with `python-formatter 'ruff` and
  `python-format-on-save t`. Spacemacs uses the `ruff-format` package for both
  the on-save hook and `SPC m =` on the current buffer.
- The other languages have no on-save formatter and no formatter wiring in
  `dotspacemacs/user-config`. `prettier`, `shfmt` and `shellcheck` are still
  installed by the package scripts, but only as CLI tools; Spacemacs does not
  call them.
- `dotspacemacs/user-init` adds the Homebrew directories to `exec-path` before
  packages load, so quelpa uses `gtar` instead of macOS' BSD tar; BSD tar adds
  AppleDouble `._*` members that break the `code-review` build.
- `dotspacemacs/user-config` adds `~/.local/bin`, the Homebrew directories on
  macOS and the WinGet/npm directories on Windows to `exec-path`, so GUI Emacs
  finds `ruff` and `opencode`.

On Windows the script also sets the user-scope `HOME` variable to
`%USERPROFILE%` when no `HOME` is defined. Emacs otherwise uses
`%APPDATA%\Roaming` as `~`, which would miss `~/.emacs.d` and the managed
dotfiles. The PowerShell profile mirrors that value into the current session;
open a new shell (or sign out) after the first apply so GUI Emacs picks it up.

The GNU Emacs installer does not add its versioned
`C:\Program Files\Emacs\emacs-*\bin` directory to `PATH`. The PowerShell profile
resolves the newest installed version and prepends its `bin` directory, so
terminal sessions get `emacs`, `emacsclient` and `etags` without pinning a
version that breaks on the next Emacs upgrade. The `e` abbreviation opens
`emacs -nw`, matching fish.

## Machine-specific values

The template data lives in `.chezmoi.toml.tmpl`:

```toml
[data]
    name = "..."
    email = "..."
    editor = "nvim"
    installOptionalApps = false
    isWSL = true
    isMacOS = false
    isWindows = false
```

Use them in any template, for example:

```fish
{{ if .isWSL }}set -gx BROWSER wslview{{ end }}
```

For values that must differ per machine, add a `promptStringOnce` entry and use
it in the relevant template. Avoid separate dotfiles when one conditional line
will do.

## Testing changes safely

Render everything into a scratch directory without running scripts or touching
your home directory:

```sh
mkdir -p /tmp/chezmoi-test
chezmoi init --apply=false --promptDefaults \
  --source . \
  --destination /tmp/chezmoi-test/home \
  --config /tmp/chezmoi-test/chezmoi.toml

chezmoi apply --dry-run --verbose \
  --source . \
  --destination /tmp/chezmoi-test/home \
  --config /tmp/chezmoi-test/chezmoi.toml
```

Render one template:

```sh
chezmoi execute-template --source . < dot_config/fish/config.fish.tmpl > /tmp/config.fish
fish -n /tmp/config.fish     # syntax check
```

Windows PowerShell 5.1 does not support `<` redirection, so use
`Get-Content -Raw dot_config/fish/config.fish.tmpl | chezmoi execute-template --source .`.
`sh scripts/check.sh` renders and checks every template in one step.

To render the other operating systems' branches from one machine, override the
template data that the scripts read:

```sh
chezmoi execute-template \
  --override-data '{"chezmoi":{"os":"linux"},"isWSL":true,"isMacOS":false,"isWindows":false}' \
  --source . < run_onchange_before_10-install-packages.sh.tmpl | sh -n
```

Use `"os":"darwin"` with `isMacOS` or `"os":"windows"` with `isWindows` for the
other branches. CI does this by running the checks on all three runners.

Check what chezmoi manages and would change:

```sh
chezmoi status
chezmoi diff
chezmoi managed
chezmoi verify
```

## Troubleshooting

- **`chsh` asks for a password / fails** — rerun `chezmoi apply`. On a minimal
  server, make sure sudo is configured for your user.
- **A winget package in the list fails** — IDs occasionally change. Run
  `winget search <name>`, update the list, and rerun `chezmoi apply`.
- **winget prints `Unrecognized command: '...\winget.exe'` on a fresh
  Windows machine** — a known winget race when commands run back-to-back. The
  scripts retry automatically; if it still fails, run `winget source update`
  and rerun `chezmoi apply`.
- **Optional apps did not install** — check that `installOptionalApps = true`
  is under `[data]` in `~/.config/chezmoi/chezmoi.toml`; the
  `50-optional-apps` scripts render empty and are skipped when it is false.
- **fish is not the default shell after WSL setup** — close the terminal and
  reopen it. WSL reads the login shell from `/etc/passwd`, which `chsh`
  updates.
- **Homebrew is missing on a fresh Mac** — the macOS script installs it
  automatically; you may be prompted to install the Xcode Command Line Tools.
- **`scripts/check.sh` reports CRLF line endings** — the repository is LF-only.
  Commit or stash local edits, then normalize the checkout:
  `git add --renormalize . && git checkout -- .`. `core.autocrlf=true` alone is
  not enough: `.gitattributes` sets `eol=lf` for every text file, which is what
  keeps the POSIX scripts and `.shellcheckrc` working on Windows.
- **`chezmoi` asks whether to overwrite `.gitconfig`** — a package installer
  (typically Git LFS for Windows) edited it after the last apply. The managed
  config already contains the LFS clean/smudge/process filters, so accepting
  chezmoi's version is safe; use `chezmoi apply --force` or answer yes.
- **`direnv` throws on Windows PowerShell 5.1** — the hook requires PowerShell
  7.2+, so the profile only loads it there. If the error persists, the 5.1
  profile is stale; run `chezmoi apply` and open a new PowerShell window.
- **Nothing re-runs after editing a script** — only rendered content changes
  trigger `run_onchange_`. Delete the script's `entryState` key as shown above
  to force a run.
- **Starship reports `Unknown key: jj_bookmark`** — the managed preset requires
  Starship >= 1.27.0. The install script upgrades Ubuntu's packaged 1.22.1 into
  `~/.local/bin`; if the warning persists, check that `command -v starship`
  resolves to `~/.local/bin/starship` and re-run `chezmoi apply`.
- **`node`/`npm` are missing or the wrong version** — Node.js comes from fnm on
  every platform. When the fnm download does not succeed, `chezmoi apply` ends
  with `still missing after this run: node` and the install script is re-run on
  the next apply. fnm already uses the TUNA mirror (`FNM_NODE_DIST_MIRROR`, see
  above); if the mirror is also unreachable, fix the network or run
  `fnm list`, `fnm install --lts` and `fnm default lts-latest` by hand, then
  open a new shell (`fnm env --use-on-cd` is sourced by fish and by the
  PowerShell profile). If a machine previously installed Node.js with apt,
  Homebrew or winget, remove it (`sudo apt-get remove nodejs npm`,
  `brew uninstall node prettier`, or `winget uninstall OpenJS.NodeJS.LTS`) so
  the fnm version wins.
- **`yt-dlp` warns that no JavaScript runtime is available** — the optional
  apps install Deno, and `~/.config/yt-dlp/config` sets `--js-runtimes deno`.
  Check `deno --version`; on Linux the official installer puts it in
  `~/.deno/bin`, which fish adds to `PATH`.
- **Git output is plain or `git diff` errors about `delta`** — the managed
  `core.pager` is `delta || less -FRX`, so a missing delta falls back to less.
  Install it (`sudo apt-get install git-delta`, `brew install git-delta` or
  `winget install dandavison.delta`) and re-run `chezmoi apply`. If delta runs
  but the Catppuccin theme is unknown, upgrade delta; the config still works
  with delta's bundled default theme.
- **LFS repositories check out pointer files** — `git lfs version` must succeed.
  The filters are already in `~/.gitconfig`; do not run `git lfs install`
  (chezmoi would restore the managed file and remove its edits). On Windows the
  installer writes `C:\Program Files\Git LFS`, which is added to the persisted
  `PATH`; open a new shell if `git lfs` is not found there yet.
- **`ssh` complains about a `ControlPath` socket** — stale multiplexing sockets
  are safe to remove: `rm -f ~/.ssh/control-*`. Multiplexing is only enabled on
  Unix; Windows OpenSSH does not support it.
- **`bat` says the Catppuccin theme is unknown** — the theme ships with bat
  0.24+. Ubuntu 26.04, Homebrew and the winget package are new enough; if an
  older binary is first on `PATH`, upgrade it or remove the `--theme` line from
  `~/.config/bat/config`.
- **`gh`, `lazygit` or `rg` ignores the managed config** — they read
  `GH_CONFIG_DIR`, `LG_CONFIG_FILE` and `RIPGREP_CONFIG_PATH`, which fish and
  the PowerShell profile export. Start a new shell after applying, and check
  `echo $env:GH_CONFIG_DIR` (PowerShell) or `echo $GH_CONFIG_DIR` (fish).
- **A command resolves to `/mnt/c/...`** — WSL appends the Windows `PATH`, so
  `prettier`, `zellij`, `emacs` and similar tools can fall through to a Windows
  shim when no native binary exists. The install scripts ignore `/mnt` and
  `*.exe` when probing, so re-run `chezmoi apply` to install the native package
  instead of invoking the Windows executable.
- **apt still downloads from archive.ubuntu.com** — the 05 script only runs on
  Ubuntu. Check `/etc/os-release` (`ID=ubuntu`) and run `chezmoi apply`. The
  original source file is preserved as `*.orig`.
- **WezTerm opens PowerShell or cannot find the WSL distro** — the distro name
  in `dot_config/wezterm/wezterm.lua` must match `wsl --list --quiet`; update
  `distribution` and reload the config.
- **Windows Terminal still shows old settings or duplicate Ubuntu profiles** —
  restart Windows Terminal after `chezmoi apply`. If the distro is not named
  `Ubuntu`, update the `Ubuntu` profile commandline in
  `AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`.
- **WSL/Ubuntu was not installed** — the first `wsl --install` needs an elevated
  PowerShell and possibly a reboot. Run `wsl --install --no-distribution`, reboot
  if asked, then re-run `chezmoi apply` (delete the
  `40-wsl.ps1` `entryState` key to force it).
- **Cannot reach the Windows host over SSH** — the OpenSSH Server capability
  and `sshd` setup need an elevated apply. Check `Get-Service sshd`,
  `Get-WindowsCapability -Online -Name OpenSSH.Server*`, and
  `Get-NetFirewallRule -DisplayName 'Windows SSH (TCP 22)'`. If the service
  failed to start because WSL was holding port 22, run `wsl --shutdown` and
  restart the service. After connecting, `$PSVersionTable.PSVersion` should
  report 7.x; if it reports 5.1, check `Get-ItemProperty HKLM:\SOFTWARE\OpenSSH`
  for the `DefaultShell` value.
- **Cannot reach WSL2 over SSH or mosh from another machine** — check that
  `~/.wslconfig` contains `networkingMode=mirrored`, run `wsl --shutdown`, and
  reopen Ubuntu. Confirm the rules exist (`Get-NetFirewallRule -DisplayName
  'WSL2 *'` and `Get-NetFirewallHyperVRule -Name 'WSL2-*'`). If an earlier
  non-elevated apply skipped them, delete the `40-wsl.ps1` `entryState` key (see
  above) and re-run `chezmoi apply` from an elevated shell. Inside Ubuntu,
  `sudo sshd -T | grep -i '^port'` should report 2222, `sudo ss -lntp | grep
  2222` should show the listener, and `systemctl status ssh.socket` should be
  active. The mosh UDP range 60000-61000 must not be blocked by a network
  firewall between the client and Windows.
- **WSL sshd fails with `Address already in use`** — another WSL distribution,
  a leftover `sshd`, or a manually re-ported Windows sshd already holds port
  2222. Check with `Get-NetTCPConnection -LocalPort 2222 -State Listen` in
  PowerShell, then move the other listener or change the WSL port in
  `run_onchange_after_45-wsl-ssh.sh.tmpl` and the firewall rules.
- **Spacemacs did not clone** — check `chezmoi apply` output. A pre-existing
  `~/.emacs.d` that is not a git checkout is intentionally left alone, and the
  clone needs git plus network access. An existing checkout on another branch
  triggers a warning instead of an automatic switch; run
  `git -C ~/.emacs.d checkout develop` to move it. Delete the script's
  `entryState` key to retry after fixing either.
- **Emacs on Windows ignores `~/.emacs.d`** — Emacs uses `%APPDATA%\Roaming`
  unless `HOME` is set. The Spacemacs script sets user-scope `HOME` when it is
  missing; open a new shell or sign out so GUI Emacs sees it.
