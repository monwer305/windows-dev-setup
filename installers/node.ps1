#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Node.js LTS.
    winget ID: OpenJS.NodeJS.LTS  |  choco: nodejs-lts
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Node.js LTS"
$WingetId = "OpenJS.NodeJS.LTS"
$ChocoId  = "nodejs-lts"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "node") {
        $nodeVer = (node --version 2>$null).Trim()
        $npmVer  = (npm --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — Node $nodeVer  npm $npmVer"
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
    $nodeVer = (node --version 2>$null).Trim()
    Write-Success "✅ $Tool installed — Node $nodeVer"

    # Upgrade npm to latest stable
    Write-Info "  Upgrading npm..."
    npm install -g npm --silent
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

