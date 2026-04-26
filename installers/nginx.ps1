#Requires -Version 5.1
<#
.SYNOPSIS
    Installs nginx for Windows.
    Uses Chocolatey as primary (most reliable on Windows).
    winget fallback: nginx.nginx
    Installs as a Windows service via the NSSM wrapper bundled in the choco package.
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "nginx"
$WingetId = "nginx.nginx"
$ChocoId  = "nginx"

# Common install paths to probe for the nginx binary
$NginxPaths = @(
    "$env:ProgramData\chocolatey\lib\nginx\tools",
    "$env:ProgramFiles\nginx",
    "C:\nginx"
)

function Get-NginxVersion {
    if (Test-CommandExists "nginx") {
        $v = nginx -v 2>&1
        return $v.ToString().Trim()
    }
    foreach ($p in $NginxPaths) {
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
        if (Test-Choco)     { Uninstall-ViaChoco $ChocoId }
        elseif (Test-Winget) { Uninstall-ViaWinget $WingetId $Tool }
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

    # Prefer Chocolatey for nginx — its package includes service wrappers
    if (Test-Choco) {
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok -and (Test-Winget)) {
        $ok = Install-ViaWinget $WingetId $Tool
    }

    if (-not $ok) {
        Write-Err "❌ $Tool installation failed — no package manager available"
        exit 1
    }

    Refresh-Path
    Write-Success "✅ $Tool installed"
    Write-Info "  Start nginx with: Start-Service nginx   (or: nginx)"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

