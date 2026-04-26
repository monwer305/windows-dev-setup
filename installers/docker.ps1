#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Docker Desktop for Windows.
    winget ID: Docker.DockerDesktop  |  choco: docker-desktop
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool      = "Docker Desktop"
$WingetId  = "Docker.DockerDesktop"
$ChocoId   = "docker-desktop"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget) { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstall initiated"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "docker") {
        $ver = (docker --version 2>$null).Trim()
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
        Write-Err "❌ ${Tool} — no package manager available (run winget-bootstrap.ps1 first)"
        exit 1
    }

    Refresh-Path
    Write-Success "✅ $Tool installed"
    Write-Warn "⚠️  Docker Desktop requires a logout/restart and virtualization enabled in BIOS."
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}


