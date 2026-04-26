#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Windows Subsystem for Linux (WSL 2).
    Windows 10: enables features via DISM and downloads the WSL2 kernel update.
    Windows 11: uses the single "wsl --install" command.
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool = "WSL"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        Write-Info "Disabling WSL Windows features..."
        Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction SilentlyContinue
        Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue
        Write-Success "✅ $Tool disabled (restart required to complete removal)"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    # wsl -l -q lists installed distros; exit 0 means WSL is present and working
    $wslList = wsl -l -q 2>$null
    if ($LASTEXITCODE -eq 0) {
        $ver = (wsl --version 2>$null | Select-Object -First 1)
        if (-not $ver) { $ver = "WSL installed" }
        Write-Success "✅ $Tool already installed — $($ver.Trim())"
        exit 0
    }

    # ─── Windows 11 path: single command ─────────────────────────────────────
    if ($WindowsVersion -eq "Windows 11") {
        Write-Info "Installing WSL (Windows 11 path: wsl --install)..."
        wsl --install --no-launch
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ $Tool installed"
            Write-Warn "⚠️  A restart is required to finish WSL setup."
            exit 0
        }
        Write-Warn "wsl --install returned $LASTEXITCODE — may already be enabled or need restart"
        exit 0
    }

    # ─── Windows 10 path: DISM + WSL2 kernel update ──────────────────────────
    Write-Info "Enabling WSL features (Windows 10 path)..."

    # Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    # Enable Virtual Machine Platform (required for WSL 2)
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # Download and install the WSL2 Linux kernel update package
    Write-Info "Downloading WSL2 kernel update..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $KernelPath = Join-Path $env:TEMP "wsl_update_x64.msi"
    Invoke-WebRequest `
        -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" `
        -OutFile $KernelPath -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i `"$KernelPath`" /quiet /norestart" -Wait

    # Make WSL 2 the default version for new distros
    wsl --set-default-version 2

    Write-Success "✅ $Tool features enabled"
    Write-Warn "⚠️  A system restart is required."
    Write-Warn "   After restart, install Ubuntu with: wsl --install -d Ubuntu"
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

