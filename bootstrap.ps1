# One-command bootstrap for Windows 11 using winget.
#
# Usage (fresh machine, PowerShell):
#   irm https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.ps1 | iex
#
# Usage (from a local checkout):
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 [-Repo URL] [-Ref REF]
#
# Set -Repo or CHEZMOI_REPO to override the repository URL, and -Ref or
# CHEZMOI_REF to apply a branch or tag from the cloned repository.
#
# Generated from bootstrap.ps1.tmpl by scripts/render-bootstrap.sh. Edit the
# template or scripts/lib/*.ps1 instead of this file.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Repo = $env:CHEZMOI_REPO,
    [string]$Ref = $env:CHEZMOI_REF
)

$ErrorActionPreference = 'Stop'

$repoExplicit = $PSBoundParameters.ContainsKey('Repo') -or [bool]$env:CHEZMOI_REPO
if (-not $Repo) {
    $Repo = 'https://github.com/best-cloud/dotfiles.git'
}

if ([Environment]::OSVersion.Version.Build -lt 22000) {
    Write-Warning 'This repository targets Windows 11 26H2+; older Windows builds may miss required features.'
}

# Add a directory to the current process PATH once.
#
# Comparing whole entries instead of matching a substring keeps paths that
# contain glob characters (for example `[`) from being misdetected.
function Add-PathEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not $Path) {
        return
    }
    $entries = $env:Path -split [IO.Path]::PathSeparator
    if ($entries -notcontains $Path) {
        $env:Path = "$Path$([IO.Path]::PathSeparator)$env:Path"
    }
}

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

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is required. Install "App Installer" from the Microsoft Store and re-run.'
}

# `chezmoi init <repo>` clones with git, and the dotfiles install script runs
# only after the clone. A fresh Windows 11 has no Git, so install it first.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '==> installing Git'
    $null = Install-WingetPackage 'Git.Git'
    Update-SessionPath
    $gitCmd = Join-Path $env:ProgramFiles 'Git\cmd'
    if (Test-Path $gitCmd) {
        Add-PathEntry $gitCmd
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git installation failed. Install Git for Windows and re-run.'
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host '==> installing chezmoi'
    $null = Install-WingetPackage 'twpayne.chezmoi'
    Update-SessionPath
    $wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if (Test-Path $wingetLinks) {
        Add-PathEntry $wingetLinks
    }
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw 'chezmoi installation failed. Install it with: winget install twpayne.chezmoi'
}

# Prefer a local checkout when this script is run from one, unless the repo was
# set explicitly with -Repo/CHEZMOI_REPO.
if (-not $repoExplicit -and $PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '.chezmoi.toml.tmpl'))) {
    if ($Ref) {
        Write-Warning '-Ref applies to cloned sources; ignoring it for the local checkout at $PSScriptRoot'
    }
    Write-Host "==> applying dotfiles from $PSScriptRoot"
    chezmoi init --apply --source $PSScriptRoot
} else {
    $initArgs = @('init', '--apply', $Repo)
    if ($Ref) {
        $initArgs += @('--branch', $Ref)
    }
    $label = if ($Ref) { "$Repo ($Ref)" } else { $Repo }
    Write-Host "==> applying dotfiles from $label"
    chezmoi @initArgs
}

if ($LASTEXITCODE -ne 0) {
    throw "chezmoi init --apply failed with exit code $LASTEXITCODE"
}

Write-Host ''
Write-Host '==> done. Open a new Windows Terminal tab to use the new profile.'
Write-Host '    For the WSL2 setup, run "wsl --shutdown" once and reopen Ubuntu.'
