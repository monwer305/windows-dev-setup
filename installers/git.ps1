#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Git for Windows.
    winget ID: Git.Git  |  choco: git
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Git"
$WingetId = "Git.Git"
$ChocoId  = "git"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "git") {
        $ver = (git --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — $ver"
        exit 0
    }

    # ─── Install ──────────────────────────────────────────────────────────────
    $ok = $false

    if (Test-Winget) {
        $ok = Install-ViaWinget $WingetId $Tool
    }

    if (-not $ok -and (Test-Choco)) {
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok) {
        Write-Err "❌ $Tool installation failed — no package manager available"
        exit 1
    }

    Refresh-Path
    $ver = (git --version 2>$null).Trim()
    Write-Success "✅ $Tool installed — $ver"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

