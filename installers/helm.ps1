#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Helm — Kubernetes package manager.
    winget ID: Helm.Helm  |  choco: kubernetes-helm
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Helm"
$WingetId = "Helm.Helm"
$ChocoId  = "kubernetes-helm"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "helm") {
        $ver = (helm version --short 2>$null).Trim()
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
    Write-Success "✅ $Tool installed"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

