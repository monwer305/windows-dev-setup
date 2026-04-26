#Requires -Version 5.1
<#
.SYNOPSIS
    Installs MySQL Community Server.
    winget ID: Oracle.MySQL  |  choco: mysql
    After install the MySQL service is set to start automatically.
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "MySQL"
$WingetId = "Oracle.MySQL"
$ChocoId  = "mysql"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        Stop-Service MySQL -ErrorAction SilentlyContinue
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "mysql") {
        $ver = (mysql --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — $ver"
        exit 0
    }
    # Also check if the service exists even when mysql isn't on PATH yet
    $svc = Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Success "✅ $Tool service found — $($svc.DisplayName) [$($svc.Status)]"
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

    # Start and enable the service if it exists
    $svc = Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Automatic
        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        Write-Info "  MySQL service started"
    }

    Write-Success "✅ $Tool installed"
    Write-Warn "⚠️  Default root password is empty — secure with: mysql_secure_installation"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

