# Managed by chezmoi. Windows PowerShell 5.1 uses a different profile path than
# PowerShell 7, so load the PowerShell 7 profile instead of duplicating it.

$pwshProfile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
if (Test-Path $pwshProfile) {
    . $pwshProfile
}
