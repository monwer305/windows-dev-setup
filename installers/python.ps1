#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Python 3 (latest stable via winget, or via chocolatey).
    winget ID: Python.Python.3  |  choco: python
    Adds Python and Scripts to PATH automatically.
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "Python 3"
$WingetId = "Python.Python.3"
$ChocoId  = "python"

try {
    # ─── Uninstall ────────────────────────────────────────────────────────────
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # ─── Already installed? ───────────────────────────────────────────────────
    # Check both 'python' and 'python3' to cover different install conventions
    $pyCmd = $null
    if (Test-CommandExists "python")  { $pyCmd = "python" }
    elseif (Test-CommandExists "python3") { $pyCmd = "python3" }

    if ($pyCmd) {
        $ver = (& $pyCmd --version 2>&1).ToString().Trim()
        # Reject the Windows Store stub (python.exe that launches the Store)
        if ($ver -notmatch "Python 3") {
            Write-Warn "Found 'python' but it appears to be the Windows Store stub — installing real Python"
        } else {
            Write-Success "✅ $Tool already installed — $ver"
            exit 0
        }
    }

    # ─── Install ──────────────────────────────────────────────────────────────
    $ok = $false

    if (Test-Winget) {
        # --scope machine ensures it ends up on the system PATH
        Write-Info "  Installing $Tool via winget..."
        winget install --id $WingetId --silent --scope machine `
              --accept-package-agreements --accept-source-agreements
        $ok = ($LASTEXITCODE -eq 0)
    }

    if (-not $ok -and (Test-Choco)) {
        $ok = Install-ViaChoco $ChocoId
    }

    if (-not $ok) {
        Write-Err "❌ $Tool installation failed — no package manager available"
        exit 1
    }

    Refresh-Path
    $ver = (python --version 2>&1).ToString().Trim()
    Write-Success "✅ $Tool installed — $ver"

    # Upgrade pip immediately
    Write-Info "  Upgrading pip..."
    python -m pip install --upgrade pip --quiet
    exit 0

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}

