#Requires -Version 5.1
# Shared helpers — dot-source this file in every installer:
#   . "$PSScriptRoot\common.ps1"

# ─── Color output ─────────────────────────────────────────────────────────────
function Write-Info    { param([string]$m) Write-Host $m -ForegroundColor Cyan    }
function Write-Success { param([string]$m) Write-Host $m -ForegroundColor Green   }
function Write-Warn    { param([string]$m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err     { param([string]$m) Write-Host $m -ForegroundColor Red     }

# ─── Package manager detection ────────────────────────────────────────────────
function Test-Winget {
    try {
        $null = winget --version 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Test-Choco {
    return ($null -ne (Get-Command choco -ErrorAction SilentlyContinue))
}

function Test-CommandExists {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

# ─── Install helpers ──────────────────────────────────────────────────────────
function Install-ViaWinget {
    param([string]$Id, [string]$DisplayName)
    Write-Info "  Installing $DisplayName via winget..."
    winget install --id $Id --silent --accept-package-agreements --accept-source-agreements
    return ($LASTEXITCODE -eq 0)
}

function Install-ViaChoco {
    param([string]$PackageName)
    Write-Info "  Installing $PackageName via Chocolatey..."
    choco install $PackageName -y --no-progress
    return ($LASTEXITCODE -eq 0)
}

# ─── Uninstall helpers ────────────────────────────────────────────────────────
function Uninstall-ViaWinget {
    param([string]$Id, [string]$DisplayName)
    Write-Info "  Uninstalling $DisplayName via winget..."
    winget uninstall --id $Id --silent
    return ($LASTEXITCODE -eq 0)
}

function Uninstall-ViaChoco {
    param([string]$PackageName)
    Write-Info "  Uninstalling $PackageName via Chocolatey..."
    choco uninstall $PackageName -y
    return ($LASTEXITCODE -eq 0)
}

# ─── Refresh PATH from registry (needed after installs) ──────────────────────
function Refresh-Path {
    $m = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $u = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$m;$u"
}

# ─── Windows version — read env var set by setup.ps1, or auto-detect ─────────
$WindowsVersion = $env:DEV_SETUP_WINDOWS_VERSION
if (-not $WindowsVersion) {
    try {
        $caption = (Get-WmiObject Win32_OperatingSystem).Caption
        $WindowsVersion = if ($caption -match "Windows 11") { "Windows 11" } else { "Windows 10" }
    } catch {
        $WindowsVersion = "Windows 10"
    }
}

