# Dev Environment Bootstrapper

PowerShell 5.1+ compatible dev environment setup for Windows 10 and Windows 11.

## Usage

```powershell
# Install the microservices stack (default)
.\setup.ps1

# Install a specific profile
.\setup.ps1 -Profile frontend
.\setup.ps1 -Profile data-science

# Preview what would be installed — no changes made
.\setup.ps1 -Profile microservices -DryRun

# Override Windows version detection
.\setup.ps1 -Profile microservices -Windows 10

# Uninstall everything in a profile
.\setup.ps1 -Profile microservices -Uninstall

# Run the health check at any time
.\checks\verify.ps1
```

## Project Structure

```
dev-setup/
├── setup.ps1               # Master orchestrator
├── setup.log               # Auto-generated run log (timestamped)
├── profiles/
│   ├── microservices.json  # Python microservices stack
│   ├── frontend.json       # Frontend (Node/Docker/Git)
│   └── data-science.json   # Data science (Python/Jupyter/MySQL)
├── installers/
│   ├── common.ps1          # Shared helpers (dot-sourced by each installer)
│   ├── winget-bootstrap.ps1
│   ├── wsl.ps1
│   ├── docker.ps1
│   ├── minikube.ps1
│   ├── kubectl.ps1
│   ├── helm.ps1
│   ├── mysql.ps1
│   ├── python.ps1
│   ├── nginx.ps1
│   ├── git.ps1
│   ├── node.ps1
│   ├── postman.ps1
│   ├── redis.ps1
│   ├── rabbitmq.ps1
│   └── dbeaver.ps1
├── checks/
│   └── verify.ps1
└── CLAUDE.md
```

## Adding a New Profile

1. Create `profiles/<name>.json` following this schema:

```json
{
  "name": "Human-readable name",
  "description": "What this profile is for",
  "tools": ["git", "node", "docker"],
  "post_install": [
    "npm install -g some-global-package"
  ],
  "notes": {
    "git": "Why git is included",
    "node": "Why node is included"
  }
}
```

2. Tool names in `tools` must match the filename of an installer in `installers/`
   (e.g. `"node"` → `installers/node.ps1`).

3. Run it: `.\setup.ps1 -Profile <name>`

## Adding a New Installer

Copy this template to `installers/<toolname>.ps1`:

```powershell
#Requires -Version 5.1
param([switch]$Uninstall)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"   # loads color helpers, Test-Winget, Install-ViaWinget, etc.

$Tool     = "My Tool"
$WingetId = "Vendor.Package"   # winget package ID
$ChocoId  = "choco-package"    # chocolatey package name

try {
    if ($Uninstall) {
        if (Test-Winget)    { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"
        exit 0
    }

    # Idempotency check — skip if already installed
    if (Test-CommandExists "mytool") {
        $ver = (mytool --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — $ver"
        exit 0
    }

    $ok = $false
    if (Test-Winget)                   { $ok = Install-ViaWinget $WingetId $Tool }
    if (-not $ok -and (Test-Choco))    { $ok = Install-ViaChoco $ChocoId }

    if ($ok) {
        Refresh-Path
        Write-Success "✅ $Tool installed"
        exit 0
    }

    Write-Err "❌ $Tool installation failed"
    exit 1

} catch {
    Write-Err "❌ $Tool installation failed: $_"
    exit 1
}
```

Then add the tool name to the relevant profile's `tools` array and optionally to
`checks/verify.ps1`.

## Dependency Order

The microservices profile installs tools in this order, which respects runtime
dependencies:

| # | Tool | Depends On |
|---|------|------------|
| 1 | WSL | — (Windows feature) |
| 2 | Docker | WSL (backend VM) |
| 3 | Minikube | Docker (VM driver) |
| 4 | kubectl | Minikube (cluster target) |
| 5 | Helm | kubectl (K8s API) |
| 6 | Python | — |
| 7 | Nginx | — |
| 8 | MySQL | — |
| 9 | Redis | — |
| 10 | RabbitMQ | Erlang/OTP (auto-installed) |
| 11 | Git | — |
| 12 | Node | — |
| 13 | Postman | — |
| 14 | DBeaver | — |

## Windows 10 vs Windows 11 Differences

| Area | Windows 10 | Windows 11 |
|------|-----------|-----------|
| winget | May not be pre-installed — `winget-bootstrap.ps1` downloads the App Installer MSIX | Pre-installed with OS |
| WSL | Requires DISM to enable features + manual WSL2 kernel update download | Single `wsl --install` command |
| Docker | Requires manual Hyper-V/VT-x check | Same, but VT-x more reliably enabled by default |

The `$env:DEV_SETUP_WINDOWS_VERSION` environment variable is set by `setup.ps1`
and read by all child scripts so each can take the appropriate path.

## Package Manager Preference

```
winget  →  first attempt (ships with Windows, no admin needed for most packages)
choco   →  fallback (requires admin, installed automatically if winget fails)
```

`winget-bootstrap.ps1` runs before every install session. It installs
Chocolatey automatically when winget cannot be obtained.

## Helpers Available in common.ps1

| Function | Description |
|----------|-------------|
| `Write-Info` / `Write-Success` / `Write-Warn` / `Write-Err` | Color-coded output |
| `Test-Winget` | Returns `$true` if winget is usable |
| `Test-Choco` | Returns `$true` if choco is on PATH |
| `Test-CommandExists "name"` | Returns `$true` if command exists on PATH |
| `Install-ViaWinget $id $name` | Installs a package and returns success bool |
| `Install-ViaChoco $name` | Installs via choco and returns success bool |
| `Uninstall-ViaWinget $id $name` | Uninstalls via winget |
| `Uninstall-ViaChoco $name` | Uninstalls via choco |
| `Refresh-Path` | Reloads PATH from registry into current session |
| `$WindowsVersion` | Auto-detected `"Windows 10"` or `"Windows 11"` |

## Output Colours

| Colour | Meaning |
|--------|---------|
| Cyan | Informational / in-progress |
| Green | Success |
| Yellow | Warning / skipped |
| Red | Failure |
