#Requires -Version 5.1
<#
.SYNOPSIS
    Installs DBeaver Community Edition — universal GUI database client.
    Supports MySQL, PostgreSQL, SQLite, and many others.
    winget ID: dbeaver.dbeaver  |  choco: dbeaver
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "DBeaver"
$WingetId = "dbeaver.dbeaver"
$ChocoId  = "dbeaver"

function Test-DBeaVerInstalled {
    $locations = @(
        "$env:ProgramFiles\DBeaver\dbeaver.exe",
        "$env:LOCALAPPDATA\Programs\DBeaver\dbeaver.exe",
        "$env:ProgramFiles\dbeaver-ce\dbeaver.exe"
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) { return $true }
    }
    if (Test-CommandExists "dbeaver") { return $true }
    return $false
}

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-DBeaVerInstalled) {
        Write-Success "✅ $Tool already installed"
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

    Write-Success "✅ $Tool installed"
    Write-Info "  Launch from Start Menu > DBeaver"
    Write-Info "  Connect to MySQL: New Connection > MySQL > host: localhost"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

