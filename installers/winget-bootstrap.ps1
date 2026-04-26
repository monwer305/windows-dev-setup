#Requires -Version 5.1
<#
.SYNOPSIS
    Ensures winget is available before any other installer runs.
    On Windows 10, winget may not be pre-installed — this script installs
    the App Installer MSIX bundle from Microsoft, then falls back to
    installing Chocolatey if that fails.
#>

$ErrorActionPreference = "Continue"

function Write-Info    { param([string]$m) Write-Host $m -ForegroundColor Cyan    }
function Write-Success { param([string]$m) Write-Host $m -ForegroundColor Green   }
function Write-Warn    { param([string]$m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err     { param([string]$m) Write-Host $m -ForegroundColor Red     }

$WindowsVersion = $env:DEV_SETUP_WINDOWS_VERSION

Write-Info "Checking package manager availability..."

# ─── Test whether winget is functional ───────────────────────────────────────
function Test-WingetAvailable {
    try {
        $null = winget --version 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

# ─── Test whether Chocolatey is available ────────────────────────────────────
function Test-ChocoAvailable {
    return ($null -ne (Get-Command choco -ErrorAction SilentlyContinue))
}

# ─── Already good? ────────────────────────────────────────────────────────────
if (Test-WingetAvailable) {
    $ver = (winget --version 2>$null).Trim()
    Write-Success "✅ winget is available ($ver)"
    exit 0
}

Write-Warn "winget not found. Attempting to install..."

# On Windows 11 winget ships with the OS — if it's missing, prompt to repair.
if ($WindowsVersion -eq "Windows 11") {
    Write-Warn "Windows 11 detected but winget is missing."
    Write-Warn "Try: Start > Microsoft Store > App Installer > Update"
}

# ─── Method 1: Install via the official App Installer MSIX bundle ─────────────
try {
    Write-Info "Downloading App Installer (winget) from Microsoft..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $MsixPath = Join-Path $env:TEMP "AppInstaller.msixbundle"

    # aka.ms/getwinget redirects to the latest stable MSIX bundle
    Invoke-WebRequest -Uri "https://aka.ms/getwinget" `
                      -OutFile $MsixPath `
                      -UseBasicParsing

    Write-Info "Installing App Installer package..."
    Add-AppxPackage -Path $MsixPath -ErrorAction Stop

    if (Test-WingetAvailable) {
        $ver = (winget --version 2>$null).Trim()
        Write-Success "✅ winget installed successfully ($ver)"
        exit 0
    }
    throw "winget still not found after App Installer installation"

} catch {
    Write-Warn "App Installer method failed: $_"
    Write-Warn "Falling back to Chocolatey..."
}

# ─── Method 2: Install Chocolatey as fallback package manager ─────────────────
try {
    if (Test-ChocoAvailable) {
        $ver = (choco --version 2>$null).Trim()
        Write-Success "✅ Chocolatey already available ($ver)"
        exit 0
    }

    Write-Info "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $InstallScript = (New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'
    )
    Invoke-Expression $InstallScript

    # Refresh PATH so choco is found in this session
    $m = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $u = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$m;$u"

    if (Test-ChocoAvailable) {
        $ver = (choco --version 2>$null).Trim()
        Write-Success "✅ Chocolatey installed as package manager fallback ($ver)"
        # Flag so installers know to skip winget attempts
        $env:DEV_SETUP_USE_CHOCO = "true"
        exit 0
    }

    throw "Chocolatey installation completed but 'choco' is not on PATH"

} catch {
    Write-Err "❌ Could not install winget or Chocolatey."
    Write-Err "   Error: $_"
    Write-Err "   Please install winget manually: https://aka.ms/getwinget"
    exit 1
}

