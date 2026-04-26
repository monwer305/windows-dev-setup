#Requires -Version 5.1
<#
.SYNOPSIS
    Dev environment bootstrapper for Windows 10/11.
.DESCRIPTION
    Installs or uninstalls developer tools based on a named profile.
    Runs winget-bootstrap first, then installs tools in dependency order,
    then runs a health-check summary.
.PARAMETER Profile
    Which profile to load: microservices | frontend | data-science
.PARAMETER Windows
    Override automatic Windows version detection: 10 | 11
.PARAMETER DryRun
    Preview what would run without making any changes.
.PARAMETER Uninstall
    Remove every tool listed in the profile instead of installing.
.EXAMPLE
    .\setup.ps1 -Profile microservices
    .\setup.ps1 -Profile frontend -DryRun
    .\setup.ps1 -Profile microservices -Uninstall
    .\setup.ps1 -Profile microservices -Windows 10
#>
param(
    [string]$Profile  = "microservices",
    [string]$Windows  = "",
    [switch]$DryRun,
    [switch]$Uninstall
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"
$ScriptDir = $PSScriptRoot
$LogFile   = Join-Path $ScriptDir "setup.log"
$StartTime = Get-Date

# ─── Logging ──────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ("[{0}] [{1}] {2}" -f $ts, $Level, $Message) |
        Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# ─── Color helpers ────────────────────────────────────────────────────────────
function Write-Info    { param([string]$m) Write-Host $m -ForegroundColor Cyan    }
function Write-Success { param([string]$m) Write-Host $m -ForegroundColor Green   }
function Write-Warn    { param([string]$m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err     { param([string]$m) Write-Host $m -ForegroundColor Red     }

# ─── Windows version detection ────────────────────────────────────────────────
function Resolve-WindowsVersion {
    param([string]$Override = "")
    if ($Override -eq "10") { return "Windows 10" }
    if ($Override -eq "11") { return "Windows 11" }
    try {
        $caption = (Get-WmiObject Win32_OperatingSystem).Caption
        if ($caption -match "Windows 11") { return "Windows 11" }
        return "Windows 10"
    } catch {
        Write-Warn "Could not detect Windows version — defaulting to Windows 10"
        return "Windows 10"
    }
}

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Info "=================================================="
Write-Info "   Dev Environment Bootstrapper"
Write-Info "=================================================="
Write-Log "Setup started. Profile=$Profile DryRun=$DryRun Uninstall=$Uninstall"

$WindowsVersion = Resolve-WindowsVersion -Override $Windows
$env:DEV_SETUP_WINDOWS_VERSION = $WindowsVersion   # child scripts read this env var

Write-Info "OS      : $WindowsVersion"
Write-Info "Profile : $Profile"
if ($DryRun)         { Write-Warn "Mode    : DRY RUN — no changes will be made" }
elseif ($Uninstall)  { Write-Warn "Mode    : UNINSTALL" }
else                 { Write-Info "Mode    : Install" }
Write-Info ""
Write-Log "Windows=$WindowsVersion"

# ─── Load profile ─────────────────────────────────────────────────────────────
$ProfilePath = Join-Path $ScriptDir "profiles\$Profile.json"
if (-not (Test-Path $ProfilePath)) {
    Write-Err "Profile '$Profile' not found: $ProfilePath"
    Write-Log "ERROR: Profile not found: $ProfilePath" "ERROR"
    exit 1
}

try {
    $ProfileData = Get-Content $ProfilePath -Raw | ConvertFrom-Json
} catch {
    Write-Err "Failed to parse profile JSON: $_"
    exit 1
}

$Tools = @($ProfileData.tools)
$Total = $Tools.Count
Write-Info "Profile  : $($ProfileData.name)"
Write-Info "Tools    : $Total to process"
Write-Info ""

# Results: ordered dict  tool -> status string
$Results = [ordered]@{}

# ─── Step 0: Ensure winget is available ───────────────────────────────────────
$BootstrapScript = Join-Path $ScriptDir "installers\winget-bootstrap.ps1"
Write-Info "─── Step 0: Bootstrapping package manager ───"
Write-Log "Running winget-bootstrap"

if ($DryRun) {
    Write-Info "[DRY RUN] Would run: winget-bootstrap.ps1"
} else {
    & $BootstrapScript
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "winget bootstrap reported issues — proceeding anyway"
    }
}
Write-Info ""

# ─── Steps 1–N: Install tools in profile order ────────────────────────────────
$StepNum = 0
foreach ($Tool in $Tools) {
    $StepNum++
    $InstallerPath = Join-Path $ScriptDir "installers\$Tool.ps1"
    $StepLabel = "Installing $Tool... ($StepNum/$Total)"

    if (-not (Test-Path $InstallerPath)) {
        Write-Warn "─── $StepLabel — no installer found, skipping ───"
        Write-Log "SKIP: $Tool — no installer" "WARN"
        $Results[$Tool] = "SKIPPED (no installer)"
        continue
    }

    Write-Info "─── $StepLabel ───"
    Write-Log "START: $Tool"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would run: $InstallerPath"
        $Results[$Tool] = "DRY RUN"
        Write-Info ""
        continue
    }

    try {
        $LASTEXITCODE = 0   # reset so stale codes from previous tools don't bleed in
        if ($Uninstall) {
            & $InstallerPath -Uninstall
        } else {
            & $InstallerPath
        }

        $Code = $LASTEXITCODE
        if ($Code -eq 0) {
            $Results[$Tool] = "OK"
            Write-Log "OK: $Tool"
        } else {
            $Results[$Tool] = "FAILED (exit $Code)"
            Write-Log "FAILED: $Tool exit=$Code" "ERROR"
        }
    } catch {
        $Results[$Tool] = "FAILED ($_)"
        Write-Log "EXCEPTION: $Tool — $_" "ERROR"
        Write-Err "Unhandled exception in $Tool installer: $_"
    }
    Write-Info ""
}

# ─── Post-install commands ────────────────────────────────────────────────────
if (-not $DryRun -and -not $Uninstall) {
    $PostInstall = @($ProfileData.post_install)
    if ($PostInstall.Count -gt 0) {
        Write-Info "─── Running post-install commands ───"
        Write-Log "Running post-install commands"
        foreach ($Cmd in $PostInstall) {
            Write-Info "  > $Cmd"
            Write-Log "POST: $Cmd"
            try {
                Invoke-Expression $Cmd 2>&1 | Out-Default
            } catch {
                Write-Warn "  Post-install command failed: $Cmd"
                Write-Warn "  Error: $_"
                Write-Log "POST FAILED: $Cmd — $_" "WARN"
            }
        }
        Write-Info ""
    }
}

# ─── Health check ─────────────────────────────────────────────────────────────
$VerifyScript = Join-Path $ScriptDir "checks\verify.ps1"
if ((Test-Path $VerifyScript) -and -not $DryRun) {
    Write-Info "─── Health Check ───"
    & $VerifyScript
    Write-Info ""
}

# ─── Summary table ────────────────────────────────────────────────────────────
Write-Info "=================================================="
Write-Info "   Summary"
Write-Info "=================================================="

$OkCount   = 0
$FailCount = 0
$SkipCount = 0

foreach ($Entry in $Results.GetEnumerator()) {
    $s = $Entry.Value
    if ($s -eq "OK") {
        $color = "Green";  $OkCount++
    } elseif ($s -like "SKIPPED*") {
        $color = "Yellow"; $SkipCount++
    } elseif ($s -eq "DRY RUN") {
        $color = "Cyan"
    } else {
        $color = "Red";    $FailCount++
    }
    Write-Host ("  {0,-20} {1}" -f $Entry.Key, $s) -ForegroundColor $color
}

Write-Info ""
$Duration = ((Get-Date) - $StartTime).ToString("hh\:mm\:ss")
Write-Success "  Installed : $OkCount"
Write-Warn    "  Skipped   : $SkipCount"
if ($FailCount -gt 0) {
    Write-Err "  Failed    : $FailCount"
} else {
    Write-Success "  Failed    : 0"
}
Write-Info "  Duration  : $Duration"
Write-Info "  Log       : $LogFile"
Write-Log "Done. OK=$OkCount SKIPPED=$SkipCount FAILED=$FailCount Duration=$Duration"


