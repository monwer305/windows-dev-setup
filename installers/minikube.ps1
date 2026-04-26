#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Minikube — local single-node Kubernetes cluster.
    Requires Docker to already be running as the VM driver.
    winget ID: Kubernetes.minikube  |  choco: minikube
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Minikube"
$WingetId = "Kubernetes.minikube"
$ChocoId  = "minikube"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-CommandExists "minikube") {
            Write-Info "Stopping and deleting Minikube cluster..."
            minikube stop  2>$null
            minikube delete 2>$null
        }
        if (Test-Winget)       { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco)    { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "minikube") {
        $ver = (minikube version --short 2>$null).Trim()
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
    Write-Warn "⚠️  Start with: minikube start --driver=docker"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

