#Requires -Version 5.1
<#
.SYNOPSIS
    Health check — verifies every managed tool and prints a status table.
    Can be run standalone at any time: .\checks\verify.ps1
#>

$ErrorActionPreference = "Continue"

# Refresh PATH from registry so tools installed in this session (or after terminal launch) are found
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

function Write-Success { param([string]$m) Write-Host $m -ForegroundColor Green  }
function Write-Err     { param([string]$m) Write-Host $m -ForegroundColor Red    }
function Write-Info    { param([string]$m) Write-Host $m -ForegroundColor Cyan   }

# ─── Helpers ──────────────────────────────────────────────────────────────────
# NOTE: parameter named $CmdArgs (not $Args) — $args is a PS automatic variable;
#       splatting @Args would always splat the empty automatic variable instead.
function Get-Version {
    param([string]$Command, [string[]]$CmdArgs, [switch]$UseStderr)
    try {
        if ($UseStderr) {
            $v = (& $Command @CmdArgs 2>&1) | Select-Object -First 1
        } else {
            $v = (& $Command @CmdArgs 2>$null) | Select-Object -First 1
        }
        if ($v) { return $v.ToString().Trim() }
        return $null
    } catch { return $null }
}

function Test-CommandExists {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

# Resolve a command that might not be on PATH by probing candidate paths
function Resolve-Exe {
    param([string[]]$Candidates)
    foreach ($p in $Candidates) {
        # Expand wildcards (e.g. MySQL Server 8*)
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Info ""
Write-Info "=========================================="
Write-Info "  Dev Environment Health Check"
Write-Info "=========================================="
Write-Info ""

$Passed = 0
$Failed = 0

# ─── Per-tool checks ──────────────────────────────────────────────────────────
$Checks = @(
    @{
        Name  = "wsl"
        Check = {
            wsl -l -q 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                # WSL outputs UTF-16LE; strip null bytes that cause spaced display in PS 5.1
                $v = (wsl --version 2>$null | Select-Object -First 1)
                if ($v) { return ($v.ToString() -replace "`0","").Trim() } else { return "installed (WSL 1)" }
            }
            return $null
        }
    },
    @{
        Name  = "docker"
        Check = {
            if (Test-CommandExists "docker") { return Get-Version "docker" @("--version") }
            # Docker Desktop installs to one of these locations
            $exe = Resolve-Exe @(
                "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
                "$env:LOCALAPPDATA\Programs\Docker\Docker\resources\bin\docker.exe",
                "$env:ProgramFiles\Docker\resources\bin\docker.exe"
            )
            if ($exe) {
                $v = (& $exe --version 2>$null).ToString().Trim()
                if ($v) { return $v } else { return "Docker (found at $exe)" }
            }
            return $null
        }
    },
    @{
        Name  = "minikube"
        Check = {
            if (Test-CommandExists "minikube") {
                # Parse "minikube version: vX.Y.Z" from multi-line output
                $out = minikube version 2>$null
                $line = $out | Where-Object { $_ -match "minikube version:" } | Select-Object -First 1
                if ($line) { return $line.ToString().Trim() }
                return ($out | Select-Object -First 1).ToString().Trim()
            }
            $exe = Resolve-Exe @("$env:ProgramFiles\Kubernetes\Minikube\minikube.exe")
            if ($exe) { return "minikube (found at $exe)" }
            return $null
        }
    },
    @{
        Name  = "kubectl"
        Check = {
            if (Test-CommandExists "kubectl") {
                $v = kubectl version --client 2>$null | Select-String "Client Version" | Select-Object -First 1
                if ($v) { return $v.ToString().Trim() }
                return Get-Version "kubectl" @("version", "--client")
            }
            $exe = Resolve-Exe @(
                "$env:ProgramFiles\Kubernetes\kubectl.exe",
                "$env:USERPROFILE\.kube\kubectl.exe",
                "$env:ProgramData\chocolatey\bin\kubectl.exe"
            )
            if ($exe) {
                $v = (& $exe version --client 2>$null | Select-String "Client Version" | Select-Object -First 1)
                if ($v) { return $v.ToString().Trim() } else { return "kubectl (found at $exe)" }
            }
            return $null
        }
    },
    @{
        Name  = "helm"
        Check = {
            if (Test-CommandExists "helm") {
                # helm version outputs "version.BuildInfo{Version:\"vX.Y.Z\",...}"
                $raw = helm version 2>$null | Select-Object -First 1
                if ($raw -match 'Version:"(v[\d.]+)"') { return "helm $($Matches[1])" }
                if ($raw) { return $raw.ToString().Trim() }
            }
            $exe = Resolve-Exe @("$env:ProgramFiles\Helm\helm.exe", "$env:ProgramData\chocolatey\bin\helm.exe")
            if ($exe) { return "helm (found at $exe)" }
            return $null
        }
    },
    @{
        Name  = "python"
        Check = {
            foreach ($cmd in @("python", "python3")) {
                if (Test-CommandExists $cmd) {
                    $v = (& $cmd --version 2>&1).ToString().Trim()
                    if ($v -match "Python 3") { return $v }
                }
            }
            return $null
        }
    },
    @{
        Name  = "nginx"
        Check = {
            if (Test-CommandExists "nginx") {
                return (nginx -v 2>&1 | Select-Object -First 1).ToString().Trim()
            }
            # Probe common install locations (winget shim, choco, manual)
            $exe = Resolve-Exe @(
                "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nginx.exe",
                "$env:ProgramFiles\nginx\nginx.exe",
                "$env:ProgramData\nginx\nginx.exe",
                "C:\nginx\nginx.exe",
                "$env:ProgramData\chocolatey\lib\nginx\tools\nginx-*\nginx.exe",
                "$env:ProgramData\chocolatey\bin\nginx.exe"
            )
            if ($exe) {
                $v = (& $exe -v 2>&1 | Select-Object -First 1).ToString().Trim()
                if ($v) { return $v } else { return "nginx (found at $exe)" }
            }
            $svc = Get-Service -Name "nginx" -ErrorAction SilentlyContinue
            if ($svc) { return "nginx service [$($svc.Status)]" }
            return $null
        }
    },
    @{
        Name  = "mysql"
        Check = {
            if (Test-CommandExists "mysql") { return Get-Version "mysql" @("--version") }
            # Probe MySQL bin directory (version number in path)
            $exe = Resolve-Exe @(
                "$env:ProgramFiles\MySQL\MySQL Server *\bin\mysql.exe",
                "$env:ProgramData\chocolatey\bin\mysql.exe"
            )
            if ($exe) {
                $v = (& $exe --version 2>$null).ToString().Trim()
                if ($v) { return $v } else { return "mysql (found at $exe)" }
            }
            $svc = Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue
            if ($svc) { return "MySQL service [$($svc.Status)]" }
            return $null
        }
    },
    @{
        Name  = "git"
        Check = {
            if (Test-CommandExists "git") { return Get-Version "git" @("--version") }
            return $null
        }
    },
    @{
        Name  = "node"
        Check = {
            if (Test-CommandExists "node") {
                $nv   = Get-Version "node" @("--version")
                $npmv = Get-Version "npm"  @("--version")
                return "Node $nv  npm $npmv"
            }
            $exe = Resolve-Exe @(
                "$env:ProgramFiles\nodejs\node.exe",
                "$env:ProgramData\chocolatey\bin\node.exe",
                "$env:APPDATA\nvm\v*\node.exe"
            )
            if ($exe) {
                $nv = (& $exe --version 2>$null).ToString().Trim()
                $npmExe = Join-Path (Split-Path $exe) "npm.cmd"
                if (Test-Path $npmExe) {
                    $npmv = (& $npmExe --version 2>$null).ToString().Trim()
                    return "Node $nv  npm $npmv"
                }
                if ($nv) { return "Node $nv" } else { return "node (found at $exe)" }
            }
            return $null
        }
    },
    @{
        Name  = "postman"
        Check = {
            $locations = @(
                "$env:LOCALAPPDATA\Postman\Postman.exe",           # winget default
                "$env:LOCALAPPDATA\Programs\Postman\Postman.exe",  # older installs
                "$env:ProgramFiles\Postman\Postman.exe"
            )
            foreach ($loc in $locations) {
                if (Test-Path $loc) { return "Postman (found at $loc)" }
            }
            # Squirrel versioned subfolder under either base path
            foreach ($base in @("$env:LOCALAPPDATA\Postman", "$env:LOCALAPPDATA\Programs\Postman")) {
                $found = Get-Item "$base\app-*\Postman.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { return "Postman (found at $($found.FullName))" }
            }
            return $null
        }
    },
    @{
        Name  = "dbeaver"
        Check = {
            $locations = @(
                "$env:LOCALAPPDATA\DBeaver\dbeaver.exe",           # winget default (current user)
                "$env:ProgramFiles\DBeaver\dbeaver.exe",
                "$env:ProgramFiles\dbeaver-ce\dbeaver.exe",
                "$env:LOCALAPPDATA\Programs\DBeaver\dbeaver.exe"
            )
            foreach ($loc in $locations) {
                if (Test-Path $loc) { return "DBeaver (found at $loc)" }
            }
            if (Test-CommandExists "dbeaver") { return Get-Version "dbeaver" @("-version") }
            return $null
        }
    }
)

# ─── Run checks ───────────────────────────────────────────────────────────────
$ColW = 12
foreach ($c in $Checks) {
    try {
        $ver = & $c.Check
    } catch {
        $ver = $null
    }

    if ($ver) {
        $Passed++
        Write-Success ("  {0} {1,-$ColW} {2}" -f ([char]0x2705), $c.Name, $ver)
    } else {
        $Failed++
        Write-Err ("  {0} {1,-$ColW} NOT FOUND" -f ([char]0x274C), $c.Name)
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
$Total = $Passed + $Failed
Write-Info ""
Write-Info "------------------------------------------"
if ($Failed -eq 0) {
    Write-Success "  $Passed/$Total tools installed successfully"
} else {
    Write-Info    "  $Passed/$Total tools installed successfully"
    Write-Err     "  $Failed/$Total tools NOT FOUND"
}
Write-Info "=========================================="
Write-Info ""










