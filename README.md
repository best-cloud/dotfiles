# dotfiles

chezmoi-managed dotfiles for **Ubuntu Server**, **Ubuntu on WSL2**, **macOS**
and **Windows 11**.

Design principles:

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
fork it, update the URLs in `bootstrap.sh`, `bootstrap.ps1`, and here.

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
prompted once for your name and email (used by Git); those answers are stored
in `~/.config/chezmoi/chezmoi.toml`.

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
or rename the repository, update `REPO` in `bootstrap.sh`, `$Repo` in
`bootstrap.ps1`, and the URLs above.

For a private repository, make sure the fresh machine can authenticate to
GitHub (SSH key or `gh auth login`), or pass an SSH URL through
`CHEZMOI_REPO`.

## What gets installed

| | Ubuntu / WSL2 (apt) | macOS (Homebrew) | Windows 11 (winget) |
|---|---|---|---|
| Shell / prompt | fish, starship | fish, starship | PowerShell 7, Starship |
| Core CLI | git, curl, wget, build-essential, unzip, zip | git, wget | Git |
| Modern CLI | ripgrep, fd-find, bat, eza, fzf, zoxide, jq, tree, htop, btop, tmux | ripgrep, fd, bat, eza, fzf, zoxide, jq, tree, htop, btop, tmux | ripgrep, fd, bat, eza, fzf, zoxide, jq |
| Editors / multiplexers | neovim, emacs, zellij | neovim, emacs, zellij | Neovim, Emacs, Zellij |
| Dev tools | gh, direnv, uv, lazygit, mosh | gh, direnv, uv, lazygit, mosh, WeChat DevTools, Postman | gh, uv, lazygit, WeChat DevTools, Postman (mosh via WSL) |
| Containers | podman | podman | — |
| Node.js | fnm + Node.js LTS (no apt) | fnm + Node.js LTS (no Homebrew) | Node.js LTS (winget) |
| AI / Python tooling | opencode, ruff, ollama | opencode, ruff, ollama | OpenCode, Ruff (ollama via WSL) |
| Formatters | prettier, shfmt | prettier, shfmt | Prettier, shfmt |
| Optional daily-use apps | — | see below | see below |
| Terminal | — (client terminal) | Ghostty | Windows Terminal, WezTerm |
| WSL2 / Ubuntu | — (native) | — | Microsoft.WSL + latest Ubuntu LTS |
| Terminal font | — (client terminal) | JetBrainsMono Nerd Font | JetBrainsMono Nerd Font |
| Editor config | Spacemacs in `~/.emacs.d` | Spacemacs in `~/.emacs.d` | Spacemacs in `%USERPROFILE%\.emacs.d` |

Ubuntu releases do not all package `starship`, `zellij`, `uv` and `ruff`, and
never package `fnm` or `prettier`. The script checks apt first and only then
falls back to the official installer (the GitHub release binary for zellij,
`uv tool install` for ruff, the upstream installer for fnm, npm for prettier).
`eza` and `lazygit` are installed from apt when the release provides them;
otherwise the script prints a warning and continues, and the shell config still
works without them.

Podman is installed on Ubuntu and macOS but not on Windows. On macOS it is only
the client; run `podman machine init` once before the first container so it can
start its Linux VM.

OpenCode is not packaged by apt, so the Linux script uses the upstream
installer and puts the launcher in `~/.opencode/bin`, which fish already adds to
`PATH`. macOS installs it from the upstream Homebrew tap
(`anomalyco/tap/opencode-v2`), and Windows installs the official portable
`Anomaly.OpenCode` winget package.

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

Ubuntu 26.04 packages Starship 1.22.1, but the shipped
`catppuccin-powerline` preset uses `jj_bookmark`, added in Starship 1.27.0.
The script therefore installs the upstream Starship release into
`~/.local/bin` when the packaged version is older. That directory comes first
in `PATH`, so the newer binary shadows `/usr/bin/starship`.

### Node.js, prettier and shfmt

Node.js is never installed by apt or Homebrew. The Linux script installs
[fnm](https://github.com/Schniz/fnm) with its upstream installer into
`~/.local/share/fnm` (`--skip-shell`, so the installer does not edit shell rc
files), and the macOS script installs `fnm` itself from Homebrew. Both then run
`fnm install --lts` and `fnm default lts-latest`, so the current Node.js LTS is
the default version.

fish runs `fnm env --use-on-cd`, which puts the default Node.js and npm on
`PATH` and switches versions automatically in directories with a
`.node-version` or `.nvmrc` file. `fnm install <version>`, `fnm use <version>`
and `fnm list` work as usual. Spacemacs does not use Node.js: nothing in the
managed Emacs config calls `node`, so only the shell and the tools you run
yourself need it.

Windows is the exception: it keeps `OpenJS.NodeJS.LTS` from winget, because fnm
is not part of the Windows setup.

Prettier is installed with `npm install -g --prefix "$HOME/.local" prettier` on
every platform, including macOS. It is deliberately not the Homebrew `prettier`
formula, because that formula depends on Homebrew's Node.js. Installing it into
`~/.local` keeps `prettier` on `PATH` regardless of which fnm version is active.
`shfmt` comes from apt, Homebrew and winget.

### Optional daily-use apps

Windows and macOS can also install a personal set of daily-use applications.
They are opt-in because not every machine wants them: `chezmoi init` asks once
and defaults to no, and the answer is stored as `installOptionalApps` in
`~/.config/chezmoi/chezmoi.toml`. At the prompt, enter `y` (or `yes`/`true`) to
install the list, or `n` (or `no`/`false`, or just Enter) to skip it.

- macOS (Homebrew casks): `1password`, `google-chrome`, `flclash`, `notion`,
  `onlyoffice`, `iina`, `wechat`, `neteasemusic`, `openvpn-connect`,
  `windows-app`.
- Windows (winget): `AgileBits.1Password`, `Flow-Launcher.Flow-Launcher`,
  `Google.Chrome.EXE`, `chen08209.FlClash`, `Notion.Notion`,
  `ONLYOFFICE.DesktopEditors`, `Daum.PotPlayer`, `SumatraPDF.SumatraPDF`,
  `Tencent.WeChat.Universal`, `NetEase.CloudMusic`.

The macOS `flclash` cask is published in the `chen08209/tap` tap rather than
homebrew-cask, so the optional script taps it and installs it separately from
the other casks.

The optional lists are deliberately disjoint from the mandatory package lists:
do not add a package to both stages. The main install scripts own development
tools and shared CLI utilities; the optional scripts own personal applications.

To enable it on an existing machine, add `installOptionalApps = true` under
`[data]` in `~/.config/chezmoi/chezmoi.toml` and run `chezmoi apply`; set it to
false to stop managing the list. `run_onchange_after_50-optional-apps.*` only
runs when the value is true. These lists are desktop-only by design: Linux
installs no personal applications. The WeChat DevTools and Postman packages are
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

The same logic runs early in `bootstrap.sh`, because the bootstrap installs
git and curl before chezmoi can apply anything. Keep the two copies in sync.
TUNA may lag behind the official security archive by a few minutes; switch the
security suite back to `http://security.ubuntu.com/ubuntu` in the script if a
production machine needs immediate security updates.

## Repository layout

```text
.
├── .chezmoi.toml.tmpl                  # machine data + prompts (sourceDir, name, email, isWSL)
├── .chezmoiignore                      # OS-specific targets
├── bootstrap.sh / bootstrap.ps1        # one-command entry points
├── dot_gitconfig.tmpl                  # single Git config for all OSes
├── dot_gitignore_global
├── dot_spacemacs                       # default Spacemacs develop dotfile + TUNA ELPA
├── dot_config/
│   ├── fish/config.fish.tmpl           # single fish config for Ubuntu + macOS
│   ├── starship.toml                   # catppuccin-powerline preset, all OSes
│   ├── zellij/config.kdl               # shared; Windows uses ZELLIJ_CONFIG_DIR
│   ├── nvim/init.lua                   # plugin-free, works offline
│   ├── wezterm/wezterm.lua             # WezTerm (alternative), WSL2 Ubuntu only
│   └── ghostty/config                  # macOS terminal
├── AppData/
│   └── Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/
│       └── LocalState/settings.json    # Windows Terminal, Catppuccin Mocha
├── Documents/
│   ├── PowerShell/
│   │   └── Microsoft.PowerShell_profile.ps1        # PowerShell 7
│   └── WindowsPowerShell/
│       └── Microsoft.PowerShell_profile.ps1        # PS 5.1 shim
├── run_onchange_before_05-ubuntu-mirror.sh.tmpl       # TUNA apt mirror
├── run_onchange_before_10-install-packages.sh.tmpl    # apt + Homebrew
├── run_onchange_before_10-install-packages.ps1.tmpl   # winget
├── run_onchange_after_20-default-shell.sh.tmpl        # chsh to fish
├── run_onchange_after_30-spacemacs.sh.tmpl            # clone Spacemacs (Unix)
├── run_onchange_after_30-spacemacs.ps1.tmpl           # clone Spacemacs (Windows)
├── run_onchange_after_40-wsl.ps1.tmpl                 # WSL2 + Ubuntu
├── run_onchange_after_50-optional-apps.sh.tmpl        # optional macOS apps
└── run_onchange_after_50-optional-apps.ps1.tmpl       # optional Windows apps
```

## How the scripts work

The installers are `run_onchange_` scripts: chezmoi hashes the rendered content
and re-runs a script only when it changes. Add a package to a list, run
`chezmoi apply`, and it installs just that package (all scripts are
idempotent).

The scripts are templates too. On the wrong OS a script renders to whitespace,
and chezmoi skips whitespace-only scripts entirely. That is why a `.ps1`
script is safe in the same repo as Linux/macOS `.sh` scripts.

To force every `run_onchange_` script to run again, delete its entry from
chezmoi's state. Script hashes are stored in `entryState` (the old
`--bucket=scriptState` is no longer used by current chezmoi):

```sh
chezmoi state dump   # script entries have "type": "script"
chezmoi state delete --bucket=entryState --key="$HOME/10-install-packages.sh"
chezmoi apply
```

### Adding an application

1. Add the package name to the relevant list in
   `run_onchange_before_10-install-packages.sh.tmpl` (apt and Homebrew lists)
   and/or `run_onchange_before_10-install-packages.ps1.tmpl` (winget ID).
   Personal daily-use applications belong in
   `run_onchange_after_50-optional-apps.sh.tmpl` (Homebrew) or
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

- adds `~/.local/bin`, `~/.cargo/bin` and (on Linux) `~/.local/share/fnm` to
  `PATH`;
- loads Homebrew's `shellenv` on macOS only;
- initializes fnm (`fnm env --use-on-cd`) when it is installed;
- defines `fd`/`bat` wrappers for Ubuntu's `fdfind`/`batcat` names;
- initializes Starship, zoxide, fzf and direnv;
- adds guarded abbreviations (`ls` → `eza`, `cat` → `bat`, `vi` → `nvim`,
  `e` → `emacs -nw`, `zj` → zellij, `o` → opencode, …);
- sources `~/.config/fish/local.fish` if it exists for machine-local tweaks.

The PowerShell 7 profile defines the same aliases and abbreviations, so both
shells behave the same way on Windows, except for `e` → `emacs -nw`: Windows
uses the Emacs GUI only, so the profile has no `e`. The 5.1 shim inherits
everything else by dot-sourcing that profile.

`run_onchange_after_20-default-shell.sh.tmpl` adds the fish path to
`/etc/shells` when needed and runs `chsh`. Log out and back in (or run
`exec fish`) when it finishes.

The Starship config is the `catppuccin-powerline` preset, so the prompt uses
Nerd Font glyphs and powerline separators. Install `JetBrainsMono Nerd Font`
on the machine that renders the terminal (Windows and macOS runtimes do this
automatically); the managed WezTerm and Ghostty configs already select it. If
you only have a bare TTY or a terminal without a Nerd Font, regenerate the file
with a fallback preset instead:

```sh
starship preset no-nerd-font -o dot_config/starship.toml
```

To pick up preset changes after a Starship upgrade:

```sh
starship preset catppuccin-powerline -o dot_config/starship.toml
```

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
- matches the managed WezTerm font and sizing: Catppuccin Mocha, JetBrainsMono
  Nerd Font medium at 12 pt, 1.1 cell height, 92% acrylic opacity, a hidden tab
  row when only one tab is open, 100k-line scrollback and a 160x44 initial
  window;
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

## Windows notes

- Run `bootstrap.ps1` on Windows itself, not inside WSL, so winget apps and the
  PowerShell profile are applied. If your winget policy requires machine-wide
  installs, run it from an elevated PowerShell; user-scope installs work from a
  normal window.
- The main profile is `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
  for PowerShell 7. Windows PowerShell 5.1 uses a different path, so
  `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` is a tiny shim
  that dot-sources the PS7 profile. If your `Documents` folder is redirected to
  OneDrive, edit both paths in the repo (or ignore them and keep local copies).
- The profile sets `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` and
  `XDG_CACHE_HOME` to Unix-style locations under your home directory. This lets
  Neovim, Starship, Zellij and WezTerm use the same managed config files as
  Linux/macOS instead of duplicating them in `%LOCALAPPDATA%`. Zellij ignores
  `XDG_CONFIG_HOME` on Windows, so the profile also sets `ZELLIJ_CONFIG_DIR`.
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
  WezTerm stays installed for WSL-only sessions and opens WSL2 directly.
- `run_onchange_after_40-wsl.ps1.tmpl` sets WSL2 as the default version and
  registers the `Ubuntu` distribution when it is missing. The first
  `wsl --install` that enables the optional Windows features needs an elevated
  shell and sometimes a reboot; the script prints the exact command and exits
  cleanly when it is not elevated. Launch Ubuntu once after it is registered to
  create the Linux user.
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
and the org layer needs `org-contrib` from it. The GUI default
font is JetBrainsMono NF at 12 pt medium weight, and
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
  `dotspacemacs/user-config`. `prettier` and `shfmt` are still installed by the
  package scripts, but only as CLI tools; Spacemacs does not call them.
- `dotspacemacs/user-config` adds `~/.local/bin`, the Homebrew directories on
  macOS and the WinGet/npm directories on Windows to `exec-path`, so GUI Emacs
  finds `ruff` and `opencode`.

On Windows the script also sets the user-scope `HOME` variable to
`%USERPROFILE%` when no `HOME` is defined. Emacs otherwise uses
`%APPDATA%\Roaming` as `~`, which would miss `~/.emacs.d` and the managed
dotfiles. The PowerShell profile mirrors that value into the current session;
open a new shell (or sign out) after the first apply so GUI Emacs picks it up.

## Machine-specific values

The template data lives in `.chezmoi.toml.tmpl`:

```toml
[data]
    name = "..."
    email = "..."
    editor = "nvim"
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
chezmoi execute-template < dot_config/fish/config.fish.tmpl > /tmp/config.fish
fish -n /tmp/config.fish     # syntax check
```

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
- **Nothing re-runs after editing a script** — only rendered content changes
  trigger `run_onchange_`. Delete the script's `entryState` key as shown above
  to force a run.
- **Starship reports `Unknown key: jj_bookmark`** — the managed preset requires
  Starship >= 1.27.0. The install script upgrades Ubuntu's packaged 1.22.1 into
  `~/.local/bin`; if the warning persists, check that `command -v starship`
  resolves to `~/.local/bin/starship` and re-run `chezmoi apply`.
- **`node`/`npm` are missing or the wrong version** — Node.js comes from fnm.
  Run `fnm list`, `fnm install --lts` and `fnm default lts-latest`, then open a
  new shell (`fnm env --use-on-cd` is sourced by fish). If a machine previously
  installed Node.js with apt or Homebrew, remove it (`sudo apt-get remove
  nodejs npm` or `brew uninstall node prettier`) so the fnm version wins.
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
- **Spacemacs did not clone** — check `chezmoi apply` output. A pre-existing
  `~/.emacs.d` that is not a git checkout is intentionally left alone, and the
  clone needs git plus network access. An existing checkout on another branch
  triggers a warning instead of an automatic switch; run
  `git -C ~/.emacs.d checkout develop` to move it. Delete the script's
  `entryState` key to retry after fixing either.
- **Emacs on Windows ignores `~/.emacs.d`** — Emacs uses `%APPDATA%\Roaming`
  unless `HOME` is set. The Spacemacs script sets user-scope `HOME` when it is
  missing; open a new shell or sign out so GUI Emacs sees it.
