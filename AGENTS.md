# AGENTS.md

chezmoi dotfiles for Ubuntu 26.04+/WSL2, macOS and Windows 11 26H2+. Correctness
means templates render, the static checks pass and chezmoi is in sync. `scripts/check.sh`
renders the templates and runs the available linters; `.github/workflows/ci.yml`
runs it on Linux and macOS. README.md documents the design and per-OS behavior;
this file only records what agents otherwise get wrong.

## Verify before claiming a change works

- Apply, then check: `chezmoi apply`, `chezmoi status` (must print nothing),
  `chezmoi verify` (exit 0). Editing files in this checkout does not change
  `$HOME` until `chezmoi apply` runs.
- If chezmoi points at the default source (`~/.local/share/chezmoi`) and it is
  missing, pass `--source .`; local-checkout bootstraps pin `sourceDir` to the
  checkout path.
- Render one template: `chezmoi execute-template --source . <file.tmpl>`.
  Windows PowerShell 5.1 does not support `<`; use
  `Get-Content -Raw <file> | chezmoi execute-template`.
- Inspect a rendered target with `chezmoi cat <target>` (e.g.
  `chezmoi cat ~/.gitconfig`).
- Syntax-check rendered output: `sh -n` (POSIX; use Git Bash on Windows),
  `fish -n`, and `[System.Management.Automation.Language.Parser]::ParseFile`
  for `.ps1`.
- `chezmoi init` name/email prompts are a TUI and ignore piped stdin. Use
  `--promptDefaults` for non-interactive runs or they hang.
- Test without touching the real home using the scratch `--source`,
  `--destination` and `--config` commands in README "Testing changes safely".
- Run `sh scripts/check.sh` after editing scripts or templates. It renders every
  template into a temporary tree, then runs `sh -n`, `shellcheck`, `shfmt`,
  `fish -n`, the PowerShell parser, JSON/TOML/Lua checks and `actionlint` when
  those tools are installed.

## chezmoi rules that are easy to get wrong

- `dot_x` maps to `~/.x`, `dot_config/y` to `~/.config/y`, everything else maps
  under `$HOME`; `Documents/...` and `AppData/...` are Windows-only.
- `.tmpl` files are Go templates. `.chezmoiignore` and `run_onchange_*` are also
  templates, and `.chezmoiignore` patterns match **target** paths.
- Every source file is a managed target unless listed in `.chezmoiignore`. New
  root docs must be added there or they get copied into `$HOME` (README.md and
  AGENTS.md are ignored this way). Repo-only tooling (`.editorconfig`,
  `.gitattributes`, `.shellcheckrc`, `.github/**`, `scripts/**`, and the
  `bootstrap.*.tmpl` sources) is ignored for the same reason.
- Scripts run in lexical order (`10-`, `20-` prefixes); `before_`/`after_` choose
  the apply phase.
- Any rendered byte change in a `run_onchange_` script (even a comment) makes
  chezmoi re-run it on the next apply. Don't edit them casually on a live box.
- Adding software means editing the `run_onchange_` install scripts, not
  `bootstrap.*`; bootstrap only installs chezmoi and calls `chezmoi init`.
- `bootstrap.sh` and `bootstrap.ps1` are generated from `bootstrap.*.tmpl` by
  `scripts/render-bootstrap.sh` so they stay standalone while sharing helpers
  from `scripts/lib/`. Edit the templates or libraries, run the renderer, and
  commit both generated files; `scripts/check.sh` fails when they are stale.

## Non-negotiable cross-OS invariants

- Target only Ubuntu 26.04+ and Windows 11 26H2+. Do not add branches or
  caveats for pre-26.04 Ubuntu or older Windows 11 releases; systemd socket
  activation, mirrored WSL networking and the Hyper-V firewall are part of the
  baseline.
- Each `run_onchange_` script is wrapped in `{{ if eq .chezmoi.os "..." }}` and
  must render to whitespace on other OSes; chezmoi skips whitespace-only
  scripts. Existing files use `-}}` trims so they render completely empty.
- The same tool must stay in sync across three lists: apt (linux branch of
  `...install-packages.sh.tmpl`), Homebrew formulas/casks (darwin branch), and
  winget IDs (`...install-packages.ps1.tmpl`). Tools apt may not package need a
  `case` fallback in the linux branch. Podman is the deliberate exception: it
  is installed on Ubuntu and macOS only, not on Windows. mosh is the other
  exception: there is no native Windows build or winget package, so the Linux
  branch installs it in both Ubuntu Server and WSL2 Ubuntu. ollama is
  not packaged by apt (only the `python3-ollama` client library), so the Linux
  branch installs it with the upstream `https://ollama.com/install.sh` script.
  It is also not installed natively on Windows: use the WSL2 Ollama.
  `gnu-tar` is the macOS-only exception: quelpa/package-build prefer `gtar`
  over the system BSD tar, which adds AppleDouble `._*` members that break
  Emacs' `package-tar-file-info` when building the code-review package; Linux
  already ships GNU tar and Windows gets it from Git for Windows.
  `bsdextrautils` is the Linux-only exception: it provides `col`, which the
  managed fish `MANPAGER` pipeline uses. macOS ships `col` with the base system
  and fish is not managed on Windows, so it has no Homebrew or winget entry.
  `openssh-server` is the other Linux-only package: it provides the WSL2 sshd,
  which `run_onchange_after_45-wsl-ssh.sh.tmpl` moves to port 2222. The script
  exits on non-WSL kernels, so Ubuntu Server keeps port 22; macOS and Windows
  provide their own SSH servers and need no package entry.
- Desktop-only extras are intentional: WeChat DevTools and Postman are
  development tools installed on macOS (`postman`, `wechatwebdevtools` casks)
  and Windows (`Postman.Postman`, `Tencent.WeixinDevTools`), not on Linux. The
  opt-in `installOptionalApps` lists in `run_onchange_after_50-optional-apps.*`
  exist on all three platforms and must stay optional and disjoint from the
  mandatory lists: do not move them into the mandatory lists, duplicate them
  across both stages, or add an apt branch to the macOS/Windows scripts. The
  Linux list (`run_onchange_after_50-optional-apps-linux.sh.tmpl`) is CLI-only
  and owns `ffmpeg`, `deno` and `yt-dlp`; it may use apt/sudo for `ffmpeg`.
  Their templates read the flag with `(get . "installOptionalApps")`, so
  configs created before the key existed still render as disabled.
- Node.js is the deliberate exception: it is never installed by apt, Homebrew or
  winget's `OpenJS.NodeJS.LTS`. The Linux branch installs fnm with its upstream
  installer (`--skip-shell --install-dir ~/.local/share/fnm`), the macOS branch
  installs the `fnm` formula, and the Windows branch installs `Schniz.fnm` with
  winget; all three then run `fnm install --lts` and
  `fnm default lts-latest`. Do not add `nodejs`/`npm` back to PACKAGES, `node`
  to BREW_PACKAGES, or the `prettier` formula (it depends on Homebrew Node.js).
  fish sources `fnm env --use-on-cd` and the PS7 profile runs
  `fnm env --use-on-cd --shell powershell`. Spacemacs does not use Node.js, so
  nothing in `dot_spacemacs` should grow a `node` dependency.
- AWS CLI is in all three package lists (`awscli` on apt/Homebrew,
  `Amazon.AWSCLI` on winget). AWS CDK ships only through npm, so each branch
  installs `aws-cdk` after fnm: `~/.local` on Unix and `%APPDATA%\npm` on
  Windows, the same prefixes as prettier.
- Optional yt-dlp always gets its strongly recommended dependencies: ffmpeg/
  ffprobe, yt-dlp-ejs and Deno. Linux installs ffmpeg with apt, Deno with the
  upstream installer into `~/.deno/bin` (`--no-modify-path`, added by fish and
  the profile) and `yt-dlp[default]` with uv; macOS uses the `ffmpeg`, `deno`
  and `yt-dlp` formulae; Windows uses `yt-dlp.FFmpeg`, `DenoLand.Deno` and
  `yt-dlp.yt-dlp`. `dot_config/yt-dlp/config` selects `--js-runtimes deno`,
  allows `--remote-components ejs:npm` and sets
  `--download-archive ./archive.txt` (relative to the current directory).
- OpenCode is not packaged by apt: Linux uses its upstream installer into
  `~/.opencode/bin` (already on the script's and fish's `PATH`), macOS uses the
  `anomalyco/tap/opencode-v2` Homebrew tap outside `BREW_PACKAGES`, and Windows
  uses `Anomaly.OpenCode`. Ruff is in all three lists (apt falls back to
  `uv tool install ruff`).
- Prettier is installed through npm on Linux, macOS and Windows (on Unix it
  runs after fnm has put Node.js on `PATH`, into `~/.local`). shfmt and
  shellcheck are in all three lists. Spacemacs uses none of them: only the
  python layer formats on save
  (`python-formatter 'ruff`, `python-format-on-save t`). Do not re-add a
  prettier-js hook, the web/config `*-fmt-on-save` variables or
  `shell-scripts-format-on-save`; the other language layers are editing,
  completion and Flycheck only. `diffutils` stays in the Homebrew list for
  `gdiff`, but prettier-js no longer configures `prettier-js-diff-command`.
- Shell abbreviations are defined twice: fish in
  `dot_config/fish/config.fish.tmpl` and PowerShell in the PS7 profile. Keep
  the two lists in sync; use functions in PowerShell where the alias needs
  arguments (`ll`, `za`, `e`, …). Both shells define `e` → `emacs -nw`; the
  profile only adds it when `emacs` is on `PATH`.
- `.chezmoi.kernel` is empty on Windows, so `.chezmoi.kernel.osrelease` must
  stay behind `eq .chezmoi.os "linux"` (this previously crashed `chezmoi init`
  on Windows).
- Unix scripts are POSIX `sh` with `set -eu`; no bashisms.
- Terminals are client-side and OS-specific. `dot_config/wezterm/wezterm.lua`
  is Windows-only and WSL-only (no PowerShell/cmd launch menu);
  `dot_config/ghostty/config` is macOS-only. Both are gated in
  `.chezmoiignore`.
- Keep `emacs` in the apt and Homebrew lists and `GNU.Emacs` in the winget
  list. `run_onchange_after_30-spacemacs.*` clones the Spacemacs `develop`
  branch only when `~/.emacs.d` is absent; never switch or overwrite an
  existing checkout.
- `dot_spacemacs` is the upstream develop template plus the TUNA ELPA snippet
  from the develop section of the TUNA ELPA help page in
  `dotspacemacs/user-init()`. On develop the override variable is
  `configuration-layer-elpa-archives` (single dash), not the master-only
  double-dash name. Keep the published snippet format, but it omits NonGNU
  ELPA, which Spacemacs' lock file uses for `org-contrib`, so `nongnu-cn` is
  added; removing it brings back "Package org-contrib is not available".
  `org-cn` stays in the list to match the published snippet, even though
  TUNA's `elpa/org/` currently serves the orgmode.org website and its
  `archive-contents` returns 404; the resulting startup warning is expected
  until TUNA fixes the mirror. On macOS `user-init()` puts Homebrew's bin
  directory on `exec-path` before packages load, so quelpa finds `gtar`
  (installed from the Homebrew list) instead of the system BSD tar. BSD tar
  adds AppleDouble `._*` members that Emacs 31's `tar-mode` exposes, breaking
  quelpa's `code-review` build with "wrong-type-argument arrayp nil". The
  default GUI font
  is JetBrainsMono NF 12 pt medium; the mode-line height uses
  `:separator-scale 1.1`.
- `run_onchange_after_20-macos-defaults.sh.tmpl` is macOS-only and renders
  empty elsewhere. It sets `DSDontWriteNetworkStores` and
  `DSDontWriteUSBStores` in `com.apple.desktopservices` so Finder stops
  writing `.DS_Store` on NAS shares and USB/removable media, and restarts
  Finder only when a value changes. The keys are preventive: existing files
  stay, and command-line copies can still create AppleDouble `._*` files.
- The deb822 TUNA apt-mirror logic lives in `scripts/lib/ubuntu-mirror.sh`. The
  `05-ubuntu-mirror` script includes it, and the generated `bootstrap.sh`
  inlines it so prerequisites are fast before chezmoi exists. Only
  `/etc/apt/sources.list.d/ubuntu.sources` is written; the repo targets the
  current Ubuntu LTS, so there is no legacy `sources.list` branch.
- Prefer template data (`.name`, `.email`, `.editor`, `.isWSL`, `.isMacOS`,
  `.isWindows`) over per-OS duplicate files.

## Windows specifics

- Profiles: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` (PS7)
  plus the 7-line `Documents/WindowsPowerShell/...` shim for 5.1. The template
  includes `scripts/lib/path.ps1`; add logic only to the PS7 template.
- The profile sets `XDG_*` and `ZELLIJ_CONFIG_DIR` so Neovim, Starship, Zellij
  and WezTerm read `~/.config`. Removing them silently breaks all four. It also
  sets `SHELL` (`pwsh` on 7, `powershell` on 5.1) so Zellij panes do not fall
  back to `cmd.exe`; keep the version check because 5.1 dot-sources this file.
  It also adds `%APPDATA%\npm` to `PATH` (npm global installs of prettier and
  aws-cdk) and runs `fnm env --use-on-cd --shell powershell`; the Node.js MSI
  used to provide both, so removing them breaks `node`, `cdk` and `prettier`.
- Windows Terminal is the default Windows client. Its settings are the managed
  target `AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`,
  which must stay in `.chezmoiignore` on non-Windows. PowerShell 7 is
  `defaultProfile` (GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}`); the Ubuntu
  profile runs `wsl.exe -d Ubuntu --cd ~`.
- WezTerm remains installed as the WSL-only alternative and defaults to the
  `WSL:Ubuntu` domain. There is no PowerShell/cmd launch entry; do not add one
  back.
- `Microsoft.WindowsTerminal` and `Microsoft.WSL` belong in the winget list.
  Ubuntu is provisioned by `run_onchange_after_40-wsl.ps1.tmpl` with
  `wsl --install --distribution Ubuntu --no-launch`, not by a winget distro
  package, so it always tracks the current LTS. The first enablement needs an
  elevated shell; the script warns instead of failing when it is not elevated.
- Windows SSH is enabled by `run_onchange_after_35-windows-ssh.ps1.tmpl` from
  the built-in `OpenSSH.Server~~~~0.0.1.0` capability, not winget: it sets the
  `sshd` service to Automatic, starts it, and adds a `Windows SSH (TCP 22)`
  inbound firewall rule on the `Any` profile. It also sets
  `HKLM:\SOFTWARE\OpenSSH\DefaultShell` to PowerShell 7 (`pwsh.exe`) and
  `DefaultShellCommandOption` to `-c`, preferring
  `%ProgramFiles%\PowerShell\7\pwsh.exe`, then a discovered non-alias
  `pwsh.exe`, then the `Microsoft.PowerShell` MSIX package path. Do not point
  this at `powershell.exe` (5.1) or the bare WindowsApps execution alias. Do not
  add `Microsoft.OpenSSH.Beta` to the winget list. Windows keeps port 22 and
  WSL2 keeps 2222, so both are reachable at the same LAN address. The capability
  and service setup need elevation; keep the warning when chezmoi is not
  elevated.
- `dot_wslconfig` is the Windows-only target `~/.wslconfig` and must stay under
  the non-Windows branch of `.chezmoiignore`. It sets
  `networkingMode=mirrored`, which puts the WSL2 distribution on the Windows
  host's interfaces. WSL reads the file only when a distribution starts, so
  `wsl --shutdown` is required after it changes. The same 40 script creates
  inbound Windows Firewall **and** Hyper-V firewall rules for TCP 2222 (SSH)
  and UDP 60000-61000 (mosh), because mirrored mode is filtered by both. The
  rules use the `Any` profile; do not remove the elevated-shell warning, and
  keep the `{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}` WSL VMCreatorId.
- WSL2 Ubuntu listens on SSH port 2222 so it does not collide with the Windows
  OpenSSH server on 22. `run_onchange_after_45-wsl-ssh.sh.tmpl` writes
  `/etc/ssh/sshd_config.d/00-chezmoi-wsl.conf` and
  `/etc/systemd/system/ssh.socket.d/zz-chezmoi-port.conf`. The repo targets
  Ubuntu 26.04+, which starts SSH from `ssh.socket`; do not add an
  `ssh.service` or init-script fallback. Changing only `sshd_config` leaves the
  listener on 22, so the `zz-` drop-in must sort after the generator's
  `addresses.conf`, reset `ListenStream=` and set both `0.0.0.0:2222` and
  `[::]:2222`. The script enables and restarts `ssh.socket`; when systemd is not
  running yet it only writes the files and asks for `wsl --shutdown`. OpenSSH
  `Port` options are cumulative, not first-wins, so the script warns when
  `sshd -T` reports any port other than 2222. Keep the runtime `/proc/version`
  check so Ubuntu Server is untouched, and keep the firewall port in sync with
  these drop-ins. Mosh reuses the SSH connection and then uses UDP 60000-61000.
- On WSL, `bootstrap.sh` idempotently merges `systemd=true` into a `[boot]`
  section of `/etc/wsl.conf` (detected via `/proc/version`) and never overwrites
  the rest of the file. WSL only reads it at distro start, so the restart with
  `wsl --shutdown` is required; the bootstrap itself still runs without systemd.
  Ollama's installer writes the unit but cannot enable it until that restart.
- WSL appends the Windows `PATH`, which includes `/mnt/c/...`. Never use a bare
  `command -v` to decide whether a Linux tool is installed: when the native
  binary is missing, the probe falls through to a Windows shim (the Windows npm
  `prettier` used to suppress the native install). Those shims are slow from
  Linux and mishandle Linux paths, and passing a `/mnt` `fish.exe` to `chsh` or
  `gsudo.exe` to `sudo` is wrong. The Unix scripts use a native-only
  `has`/`native_cmd` helper that rejects `/mnt/*` and `*.exe`; apply the same
  guard to any new install or privilege probe.
- The Nerd Font winget package is a machine-scope MSI and needs elevation;
  winget CLI shims live in `%LOCALAPPDATA%\Microsoft\WinGet\Links`.
- The GNU Emacs installer does not add its versioned
  `%ProgramFiles%\Emacs\emacs-*\bin` directory to `PATH`, so the PS7 profile
  resolves the newest install and prepends it. Keep the version discovery;
  do not pin a version that breaks on the next Emacs upgrade.
- Windows winget calls in `bootstrap.ps1` and the install scripts go through the
  shared `scripts/lib/winget.ps1` retry helpers. Fresh Windows can intermittently
  return `Unrecognized command: '...\winget.exe'` when winget commands run
  back-to-back (winget-cli#5376); keep the retry instead of calling winget
  directly.
- If `Documents` is redirected to OneDrive, chezmoi's `Documents/...` targets
  miss. The 5.1 shim checks both the shell folder and `$HOME\Documents`, but
  check `[Environment]::GetFolderPath('MyDocuments')` before assuming the apply
  path is correct.

## Generated content

- `dot_config/starship.toml` is the `catppuccin-powerline` preset plus one
  local override: `[python] python_binary` tries
  `uv run --no-python-downloads --no-project python` and then falls back to
  `python3`/`python`. Regenerate with
  `starship preset catppuccin-powerline -o dot_config/starship.toml` instead of
  hand-editing, then re-add that override; the prompt requires the JetBrainsMono
  NF font.
- The `Catppuccin Mocha` scheme and theme in the Windows Terminal settings are
  copied verbatim from <https://github.com/catppuccin/windows-terminal>
  (`mocha.json` and `mochaTheme.json`). Do not retype or reorder those colors;
  copy the upstream files again when they change.
