# Managed by chezmoi. Windows PowerShell 5.1 uses a different profile path than
# PowerShell 7, so load the PowerShell 7 profile instead of duplicating it.

# Documents can be redirected (for example to OneDrive), so check both the
# shell folder and the path chezmoi manages under the user profile.
$candidates = @()
$documents = [Environment]::GetFolderPath('MyDocuments')
if ($documents) {
    $candidates += Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
}
$candidates += Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'

foreach ($profilePath in ($candidates | Select-Object -Unique)) {
    if (Test-Path $profilePath) {
        . $profilePath
        break
    }
}
