# AGENTS.md

chezmoi dotfiles for Ubuntu/WSL2, macOS and Windows 11. There is no build, test
suite, lint or CI: correctness means templates render and chezmoi is in sync.
README.md documents the design and per-OS behavior; this file only records what
agents otherwise get wrong.

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

## chezmoi rules that are easy to get wrong

- `dot_x` maps to `~/.x`, `dot_config/y` to `~/.config/y`, everything else maps
  under `$HOME`; `Documents/...` and `AppData/...` are Windows-only.
- `.tmpl` files are Go templates. `.chezmoiignore` and `run_onchange_*` are also
  templates, and `.chezmoiignore` patterns match **target** paths.
- Every source file is a managed target unless listed in `.chezmoiignore`. New
  root docs must be added there or they get copied into `$HOME` (README.md and
  AGENTS.md are ignored this way).
- Scripts run in lexical order (`10-`, `20-` prefixes); `before_`/`after_` choose
  the apply phase.
- Any rendered byte change in a `run_onchange_` script (even a comment) makes
  chezmoi re-run it on the next apply. Don't edit them casually on a live box.
- Adding software means editing the `run_onchange_` install scripts, not
  `bootstrap.*`; bootstrap only installs chezmoi and calls `chezmoi init`.

## Non-negotiable cross-OS invariants

- Each `run_onchange_` script is wrapped in `{{ if eq .chezmoi.os "..." }}` and
  must render to whitespace on other OSes; chezmoi skips whitespace-only
  scripts. Existing files use `-}}` trims so they render completely empty.
- The same tool must stay in sync across three lists: apt (linux branch of
  `...install-packages.sh.tmpl`), Homebrew formulas/casks (darwin branch), and
  winget IDs (`...install-packages.ps1.tmpl`). Tools apt may not package need a
  `case` fallback in the linux branch.
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
  copied verbatim from the develop section of the TUNA ELPA help page in
  `dotspacemacs/user-init()`. On develop the override variable is
  `configuration-layer-elpa-archives` (single dash), not the master-only
  double-dash name. Do not rewrite the published snippet. The default GUI font
  is JetBrainsMono NF 12 pt medium; the mode-line height uses
  `:separator-scale 1.1`.
- The deb822 TUNA apt-mirror logic exists twice: in `bootstrap.sh` (so the
  prerequisites are fast) and in `run_onchange_before_05-ubuntu-mirror.sh.tmpl`
  (so `chezmoi apply` enforces it). Keep the two copies in sync. Only
  `/etc/apt/sources.list.d/ubuntu.sources` is written; the repo targets the
  current Ubuntu LTS, so there is no legacy `sources.list` branch.
- Prefer template data (`.name`, `.email`, `.editor`, `.isWSL`, `.isMacOS`,
  `.isWindows`) over per-OS duplicate files.

## Windows specifics

- Profiles: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (PS7) plus
  the 7-line `Documents/WindowsPowerShell/...` shim for 5.1. Add logic only to
  the PS7 file.
- The profile sets `XDG_*` and `ZELLIJ_CONFIG_DIR` so Neovim, Starship, Zellij
  and WezTerm read `~/.config`. Removing them silently breaks all four. It also
  sets `SHELL` (`pwsh` on 7, `powershell` on 5.1) so Zellij panes do not fall
  back to `cmd.exe`; keep the version check because 5.1 dot-sources this file.
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
- The Nerd Font winget package is a machine-scope MSI and needs elevation;
  winget CLI shims live in `%LOCALAPPDATA%\Microsoft\WinGet\Links`.
- If `Documents` is redirected to OneDrive, both profile targets miss. Check
  `[Environment]::GetFolderPath('MyDocuments')` before assuming.

## Generated content

- `dot_config/starship.toml` is the verbatim `catppuccin-powerline` preset.
  Regenerate with `starship preset catppuccin-powerline -o dot_config/starship.toml`
  instead of hand-editing; the prompt requires the JetBrainsMono NF font.
- The `Catppuccin Mocha` scheme and theme in the Windows Terminal settings are
  copied verbatim from <https://github.com/catppuccin/windows-terminal>
  (`mocha.json` and `mochaTheme.json`). Do not retype or reorder those colors;
  copy the upstream files again when they change.
