# Shared winget helpers.
#
# Included verbatim by the install/optional-apps templates and by the generated
# bootstrap.ps1. Keep this file free of top-level side effects.

# winget can intermittently fail with "Unrecognized command:
# '...\winget.exe'" when commands are called back-to-back on a fresh Windows
# install. The next attempt normally succeeds (winget-cli#5376). Exit code
# -1978335230 is winget's "invalid command line" result for that race.
function Test-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        winget list --id $Id --exact --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        if ($LASTEXITCODE -ne -1978335230) {
            return $false
        }
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 3
        }
    }
    return $false
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        winget install --id $Id --exact --source winget `
            --accept-package-agreements --accept-source-agreements `
            --silent --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        if ($attempt -lt 3) {
            Write-Warning "winget install $Id failed (exit $LASTEXITCODE); retrying in 3 seconds..."
            Start-Sleep -Seconds 3
        }
    }
    return $false
}
