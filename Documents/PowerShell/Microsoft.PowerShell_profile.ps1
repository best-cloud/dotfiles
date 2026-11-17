# Managed by chezmoi: Documents/PowerShell/Microsoft.PowerShell_profile.ps1
# Windows PowerShell 5.1 loads this through the shim in Documents/WindowsPowerShell.

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
$localBin = Join-Path $HOME '.local\bin'
if ($env:Path -notlike "*$localBin*") {
    $env:Path = "$localBin;$env:Path"
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
# Prefer the modern replacements when they are installed.
# ---------------------------------------------------------------------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue
    Set-Alias -Name ls -Value eza
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -ErrorAction SilentlyContinue
    Set-Alias -Name cat -Value bat
}
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias -Name v -Value nvim
}

# Git abbreviations.
function gs { git status -sb @args }
function gl { git log --oneline --graph --decorate --all @args }
function gd { git diff @args }
