#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Redis on Windows.
    NOTE: Redis has no official native Windows build. This script installs
    the community-maintained Windows port via Chocolatey (redis-64).
    For production-parity, consider running Redis via Docker or WSL instead:
        docker run -d -p 6379:6379 redis:alpine
    winget ID: Redis.Redis  |  choco: redis-64
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Redis"
$WingetId = "Redis.Redis"
$ChocoId  = "redis-64"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        Stop-Service Redis -ErrorAction SilentlyContinue
        if (Test-Choco)      { Uninstall-ViaChoco $ChocoId }
        elseif (Test-Winget) { Uninstall-ViaWinget $WingetId $Tool }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    if (Test-CommandExists "redis-cli") {
        $ver = (redis-cli --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — $ver"
        exit 0
    }
    $svc = Get-Service -Name "Redis*" -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Success "✅ $Tool service found — $($svc.DisplayName) [$($svc.Status)]"
        exit 0
    }

    # ─── Install ──────────────────────────────────────────────────────────────
    Write-Warn "⚠️  Installing Windows port of Redis (community build). Consider Docker for production parity."

    $ok = $false

    # Prefer choco for Redis on Windows — the redis-64 package is well-maintained
    if (Test-Choco) {
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok -and (Test-Winget)) {
        $ok = Install-ViaWinget $WingetId $Tool
    }

    if (-not $ok) {
        Write-Warn "Package manager install failed — trying Docker fallback..."
        if (Test-CommandExists "docker") {
            Write-Info "  Pulling Redis Docker image..."
            docker pull redis:alpine
            Write-Success "✅ Redis Docker image pulled (use: docker run -d -p 6379:6379 redis:alpine)"
            exit 0
        }
        Write-Err "❌ $Tool installation failed — no package manager or Docker available"
        exit 1
    }

    Refresh-Path

    $svc = Get-Service -Name "Redis*" -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Automatic
        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        Write-Info "  Redis service started"
    }

    Write-Success "✅ $Tool installed"
    Write-Info "  Connect with: redis-cli ping"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

