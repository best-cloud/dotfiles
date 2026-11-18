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
- **fish first** on Ubuntu and macOS: installed, configured, and set as the
  login shell.
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
| Editors / multiplexers | neovim, zellij | neovim, zellij | Neovim, Zellij |
| Dev tools | gh, direnv, uv, lazygit | gh, direnv, uv, lazygit | gh, uv, lazygit |
| Terminal | — | — | Windows Terminal |
| Terminal font | — (client terminal) | JetBrainsMono Nerd Font | JetBrainsMono Nerd Font |

Ubuntu releases do not all package `starship`, `zellij` and `uv`. The script
checks apt first and only then falls back to the official installer (or the
GitHub release binary for zellij). `eza` and `lazygit` are installed from apt
when the release provides them; otherwise the script prints a warning and
continues, and the shell config still works without them.

Ubuntu 26.04 packages Starship 1.22.1, but the shipped
`catppuccin-powerline` preset uses `jj_bookmark`, added in Starship 1.27.0.
The script therefore installs the upstream Starship release into
`~/.local/bin` when the packaged version is older. That directory comes first
in `PATH`, so the newer binary shadows `/usr/bin/starship`.

## Repository layout

```text
.
├── .chezmoi.toml.tmpl                  # machine data + prompts (sourceDir, name, email, isWSL)
├── .chezmoiignore                      # OS-specific targets
├── bootstrap.sh / bootstrap.ps1        # one-command entry points
├── dot_gitconfig.tmpl                  # single Git config for all OSes
├── dot_gitignore_global
├── dot_config/
│   ├── fish/config.fish.tmpl           # single fish config for Ubuntu + macOS
│   ├── starship.toml                   # catppuccin-powerline preset, all OSes
│   ├── zellij/config.kdl               # shared; Windows uses ZELLIJ_CONFIG_DIR
│   └── nvim/init.lua                   # plugin-free, works offline
├── Documents/
│   ├── PowerShell/
│   │   └── Microsoft.PowerShell_profile.ps1        # PowerShell 7
│   └── WindowsPowerShell/
│       └── Microsoft.PowerShell_profile.ps1        # PS 5.1 shim
├── run_onchange_before_10-install-packages.sh.tmpl   # apt + Homebrew
├── run_onchange_before_10-install-packages.ps1.tmpl  # winget
└── run_onchange_after_20-default-shell.sh.tmpl       # chsh to fish
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

- adds `~/.local/bin` and `~/.cargo/bin` to `PATH`;
- loads Homebrew's `shellenv` on macOS only;
- defines `fd`/`bat` wrappers for Ubuntu's `fdfind`/`batcat` names;
- initializes Starship, zoxide, fzf and direnv;
- adds guarded abbreviations (`ls` → `eza`, `cat` → `bat`, `zj` → zellij, …);
- sources `~/.config/fish/local.fish` if it exists for machine-local tweaks.

`run_onchange_after_20-default-shell.sh.tmpl` adds the fish path to
`/etc/shells` when needed and runs `chsh`. Log out and back in (or run
`exec fish`) when it finishes.

The Starship config is the `catppuccin-powerline` preset, so the prompt uses
Nerd Font glyphs and powerline separators. Install `JetBrainsMono Nerd Font`
on the machine that renders the terminal (Windows and macOS runtimes do this
automatically) and select it in the terminal profile. If you only have a bare
TTY or a terminal without a Nerd Font, regenerate the file with a fallback
preset instead:

```sh
starship preset no-nerd-font -o dot_config/starship.toml
```

To pick up preset changes after a Starship upgrade:

```sh
starship preset catppuccin-powerline -o dot_config/starship.toml
```

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
  Neovim, Starship and Zellij use the same managed config files as
  Linux/macOS instead of duplicating them in `%LOCALAPPDATA%`. Zellij ignores
  `XDG_CONFIG_HOME` on Windows, so the profile also sets `ZELLIJ_CONFIG_DIR`.
- PowerShell 7 is installed first by the winget script. The script itself is
  compatible with Windows PowerShell 5.1 in case chezmoi starts under it.
- The Nerd Font ships as a machine-scope MSI, so install it from an elevated
  window. Afterwards select `JetBrainsMono NF` as the font face in Windows
  Terminal (Settings → Profiles → Defaults → Appearance).
- WSL2 needs no extra Windows-side config. Run `bootstrap.sh` inside the WSL
  distro as well; the two sides are independent chezmoi installations.

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
