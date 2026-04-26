#Requires -Version 5.1
<#
.SYNOPSIS
    Installs nginx for Windows.
    winget IDs: freenginx.nginx (primary), nginxinc.nginx (fallback)
    choco: nginx (fallback when winget unavailable)
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool        = "nginx"
$WingetId    = "freenginx.nginx"
$WingetIdAlt = "nginxinc.nginx"
$ChocoId     = "nginx"

function Get-NginxVersion {
    # Refresh PATH so WinGet-installed nginx shim is visible
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (Test-CommandExists "nginx") {
        $v = nginx -v 2>&1
        return $v.ToString().Trim()
    }
    foreach ($p in @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramData\chocolatey\lib\nginx\tools",
        "$env:ProgramFiles\nginx",
        "C:\nginx"
    )) {
        $exe = Join-Path $p "nginx.exe"
        if (Test-Path $exe) {
            $v = & $exe -v 2>&1
            return $v.ToString().Trim()
        }
    }
    return $null
}

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        Stop-Service nginx -ErrorAction SilentlyContinue
        if (Test-Winget) {
            winget uninstall --id $WingetId --silent 2>$null
            winget uninstall --id $WingetIdAlt --silent 2>$null
        }
        if (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    $existingVer = Get-NginxVersion
    if ($existingVer) {
        Write-Success "✅ $Tool already installed — $existingVer"
        exit 0
    }

    # ─── Install ──────────────────────────────────────────────────────────────
    $ok = $false

    if (Test-Winget) {
        $ok = Install-ViaWinget $WingetId $Tool
        if (-not $ok) { $ok = Install-ViaWinget $WingetIdAlt $Tool }
    }

    if (-not $ok -and (Test-Choco)) {
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok) {
        Write-Err "❌ $Tool installation failed — no package manager available"
        exit 1
    }

    Refresh-Path

    # Verify the binary is actually present after install
    $postVer = Get-NginxVersion
    if (-not $postVer) {
        Write-Warn "⚠️  Package manager reported success but nginx binary not found."
        Write-Warn "   Try installing manually: https://nginx.org/en/docs/windows.html"
        exit 1
    }

    Write-Success "✅ $Tool installed — $postVer"
    Write-Info "  Run nginx with: nginx"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

