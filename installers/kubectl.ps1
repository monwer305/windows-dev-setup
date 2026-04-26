#Requires -Version 5.1
<#
.SYNOPSIS
    Installs kubectl — Kubernetes command-line tool.
    winget ID: Kubernetes.kubectl  |  choco: kubernetes-cli
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "kubectl"
$WingetId = "Kubernetes.kubectl"
$ChocoId  = "kubernetes-cli"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "kubectl") {
        $ver = (kubectl version --client 2>$null | Select-String "Client Version").ToString().Trim()
        if (-not $ver) { $ver = "installed" }
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

