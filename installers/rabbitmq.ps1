#Requires -Version 5.1
<#
.SYNOPSIS
    Installs RabbitMQ message broker.
    Erlang/OTP is a required dependency — chocolatey handles it automatically.
    winget ID: RabbitMQ.RabbitMQ  |  choco: rabbitmq
    Management UI available at http://localhost:15672 (guest/guest)
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "RabbitMQ"
$WingetId = "RabbitMQ.RabbitMQ"
$ChocoId  = "rabbitmq"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        Stop-Service RabbitMQ -ErrorAction SilentlyContinue
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    $svc = Get-Service -Name "RabbitMQ*" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Success "✅ $Tool already installed — service: $($svc.DisplayName) [$($svc.Status)]"
        exit 0
    }
    # Also check the CLI tool
    if (Test-CommandExists "rabbitmqctl") {
        Write-Success "✅ $Tool already installed (rabbitmqctl found)"
        exit 0
    }

    # ─── Install ──────────────────────────────────────────────────────────────
    $ok = $false

    if (Test-Winget) {
        # winget install also handles the Erlang dependency on its own
        $ok = Install-ViaWinget $WingetId $Tool
    }

    if (-not $ok -and (Test-Choco)) {
        # choco rabbitmq pulls in erlang as a dependency automatically
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok) {
        Write-Err "❌ $Tool installation failed — no package manager available"
        exit 1
    }

    Refresh-Path

    # Enable the management plugin so the web UI is available
    if (Test-CommandExists "rabbitmq-plugins") {
        Write-Info "  Enabling RabbitMQ management plugin..."
        rabbitmq-plugins enable rabbitmq_management 2>$null
    }

    $svc = Get-Service -Name "RabbitMQ*" -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Automatic
        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        Write-Info "  RabbitMQ service started"
    }

    Write-Success "✅ $Tool installed"
    Write-Info "  Management UI: http://localhost:15672  (user: guest / pass: guest)"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

