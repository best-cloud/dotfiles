# Managed by chezmoi: Documents/PowerShell/Microsoft.PowerShell_profile.ps1
# Windows PowerShell 5.1 loads this through the shim in Documents/WindowsPowerShell.

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
$localBin = Join-Path $HOME '.local\bin'
if ($env:Path -notlike "*$localBin*") {
    $env:Path = "$localBin;$env:Path"
}

# winget installs portable CLI shims here (for example OpenCode).
$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
if ((Test-Path $wingetLinks) -and ($env:Path -notlike "*$wingetLinks*")) {
    $env:Path = "$wingetLinks;$env:Path"
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# Use Unix-style locations on Windows too, so the same managed dotfiles
# (Neovim, Starship, …) are found without duplicating configs.
$env:XDG_CONFIG_HOME = Join-Path $HOME '.config'
$env:XDG_DATA_HOME = Join-Path $HOME '.local\share'
$env:XDG_STATE_HOME = Join-Path $HOME '.local\state'
$env:XDG_CACHE_HOME = Join-Path $HOME '.cache'

$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'

# Emacs on Windows uses HOME to locate ~/.emacs.d. Keep it aligned with the
# PowerShell home so terminal and GUI Emacs see the same Spacemacs checkout.
if (-not $env:HOME) {
    $env:HOME = $HOME
}

# Zellij ignores XDG_CONFIG_HOME on Windows, so point it at the shared
# ~/.config/zellij/config.kdl managed by chezmoi.
$env:ZELLIJ_CONFIG_DIR = Join-Path $HOME '.config\zellij'

# Zellij opens cmd.exe for new panes when SHELL is unset. Point it at the
# PowerShell that loaded this profile so panes start in PowerShell instead.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $env:SHELL = 'pwsh'
} else {
    $env:SHELL = 'powershell'
}

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# ---------------------------------------------------------------------------
# zoxide: `z <query>` and interactive `zi`
# ---------------------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ---------------------------------------------------------------------------
# PSReadLine
# ---------------------------------------------------------------------------
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    try {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -BellStyle None
    } catch {
        # Older PSReadLine versions do not support every option above.
    }
}

# ---------------------------------------------------------------------------
# Aliases and abbreviations, kept in sync with dot_config/fish/config.fish.tmpl.
# ---------------------------------------------------------------------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias -Name ls -Value eza -Force
    function ll { eza -lah @args }
    function lt { eza --tree @args }
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Force
}
if (Get-Command git -ErrorAction SilentlyContinue) {
    Set-Alias -Name g -Value git -Force
    # `gl` is a read-only built-in alias for Get-Location; it would shadow the
    # function, so force-remove it first.
    Remove-Item Alias:gl -Force -ErrorAction SilentlyContinue
    function gs { git status -sb @args }
    function gl { git log --oneline --graph --decorate --all @args }
    function gd { git diff @args }
    function gco { git checkout @args }
}
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit -Force
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias -Name vi -Value nvim -Force
}
if (Get-Command emacs -ErrorAction SilentlyContinue) {
    function e { emacs -nw @args }
}
if (Get-Command zellij -ErrorAction SilentlyContinue) {
    Set-Alias -Name zj -Value zellij -Force
    function za { zellij attach -c @args }
    function zls { zellij list-sessions @args }
}
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Set-Alias -Name o -Value opencode -Force
}
