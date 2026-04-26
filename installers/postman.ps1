#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Postman — API testing and development platform.
    winget ID: Postman.Postman  |  choco: postman
    Postman installs per-user under %LOCALAPPDATA%\Programs\Postman.
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Postman"
$WingetId = "Postman.Postman"
$ChocoId  = "postman"

# Postman doesn't put itself on PATH — check well-known install locations
function Test-PostmanInstalled {
    $locations = @(
        "$env:LOCALAPPDATA\Programs\Postman\Postman.exe",
        "$env:APPDATA\Postman\app-*\Postman.exe",
        "$env:ProgramFiles\Postman\Postman.exe"
    )
    foreach ($loc in $locations) {
        if (Get-Item $loc -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstall initiated"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-PostmanInstalled) {
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
    Write-Info "  Launch from Start Menu > Postman"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

