# One-command bootstrap for Windows 11 using winget.
#
# Usage (fresh machine, PowerShell):
#   irm https://raw.githubusercontent.com/best-cloud/dotfiles/main/bootstrap.ps1 | iex
#
# Usage (from a local checkout):
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
#
# Set -Repo to override the repository URL.
[CmdletBinding()]
param(
    [string]$Repo = 'https://github.com/best-cloud/dotfiles.git'
)

$ErrorActionPreference = 'Stop'

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
    winget install --id Git.Git --exact --source winget `
        --accept-package-agreements --accept-source-agreements `
        --silent --disable-interactivity
    Update-SessionPath
    $gitCmd = Join-Path $env:ProgramFiles 'Git\cmd'
    if (Test-Path $gitCmd) {
        $env:Path = "$gitCmd;$env:Path"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git installation failed. Install Git for Windows and re-run.'
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host '==> installing chezmoi'
    winget install --id twpayne.chezmoi --exact --source winget `
        --accept-package-agreements --accept-source-agreements `
        --silent --disable-interactivity
    Update-SessionPath
    $wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if (Test-Path $wingetLinks) {
        $env:Path = "$wingetLinks;$env:Path"
    }
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw 'chezmoi installation failed. Install it with: winget install twpayne.chezmoi'
}

# Prefer a local checkout when this script is run from one.
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '.chezmoi.toml.tmpl'))) {
    Write-Host "==> applying dotfiles from $PSScriptRoot"
    chezmoi init --apply --source $PSScriptRoot
} else {
    Write-Host "==> applying dotfiles from $Repo"
    chezmoi init --apply $Repo
}

if ($LASTEXITCODE -ne 0) {
    throw "chezmoi init --apply failed with exit code $LASTEXITCODE"
}

Write-Host ''
Write-Host '==> done. Open a new Windows Terminal tab to use the new profile.'
