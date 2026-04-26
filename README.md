# windows-dev-setup

> One-command Windows dev environment bootstrapper. Pick a profile, run one script, walk away.

Idempotent PowerShell scripts that install a full developer toolchain on Windows 10 or 11. Choose from three pre-built profiles — microservices, frontend, or data science — or define your own. Every run ends with a colour-coded health check confirming exactly what is installed and at what version.

```powershell
# Install the Python microservices stack (default)
.\setup.ps1

# Or pick a different profile
.\setup.ps1 -Profile frontend
.\setup.ps1 -Profile data-science

# Preview without touching anything
.\setup.ps1 -DryRun
```

---

## Profiles

| Profile | Tools installed | Post-install |
|---|---|---|
| **microservices** | WSL, Docker, Minikube, kubectl, Helm, Python, Nginx, MySQL, Git, Node, Postman, DBeaver | `docker pull mysql:8.0` |
| **frontend** | Git, Node, Docker | `npm install -g vercel pnpm typescript` |
| **data-science** | Git, Python, Docker, MySQL, DBeaver |`docker pull mysql:8.0` |

---

## How it works

```
setup.ps1
  │
  ├── 0. winget-bootstrap.ps1      # ensure winget is available; fall back to Chocolatey
  │
  ├── 1–N. installers/<tool>.ps1   # one file per tool, run in dependency order
  │         ├── already installed? → skip (idempotent)
  │         ├── winget available?  → install via winget
  │         └── else               → install via Chocolatey
  │
  ├── post_install commands        # pip install, docker pull, etc.
  │
  └── checks/verify.ps1            # health check — prints ✅/❌ for every tool
```

Each installer is self-contained and can be run standalone:

```powershell
.\installers\docker.ps1            # install only Docker
.\installers\docker.ps1 -Uninstall # remove it
```

### Windows 10 vs 11

The script auto-detects your OS version. You can override it:

```powershell
.\setup.ps1 -Windows 10
.\setup.ps1 -Windows 11
```

| Area | Windows 10 | Windows 11 |
|---|---|---|
| winget | Downloaded via `winget-bootstrap.ps1` if absent | Pre-installed |
| WSL | DISM feature enable + WSL2 kernel MSI download | `wsl --install` |

---

## Health check

Run at any time, independently of setup:

```powershell
.\checks\verify.ps1
```

```
==========================================
  Dev Environment Health Check
==========================================

  ✅ wsl          WSL version: 2.6.3.0
  ✅ docker       Docker version 27.4.0, build bde2b89
  ✅ minikube     minikube version: v1.34.0
  ✅ kubectl      Client Version: v1.30.5
  ✅ helm         helm v3.16.2
  ✅ python       Python 3.12.1
  ✅ mysql        Ver 8.4.8 for Win64 on x86_64
  ✅ git          git version 2.54.0.windows.1
  ✅ node         Node v24.15.0  npm 11.13.0
  ✅ postman      Postman (found)
  ✅ dbeaver      DBeaver (found)

------------------------------------------
  11/11 tools installed successfully
==========================================
```

The check probes both `PATH` and well-known install locations, so tools installed by winget or Chocolatey (which don't always update `PATH` in the current session) are still detected correctly.

---

## Extending

### Add a new profile

Create `profiles/<name>.json`:

```json
{
  "name": "Human-readable name",
  "description": "What this profile is for",
  "tools": ["git", "node", "docker"],
  "post_install": [
    "npm install -g some-global-package"
  ],
  "notes": {
    "git": "Why git is included"
  }
}
```

Then run it: `.\setup.ps1 -Profile <name>`

### Add a new tool

Copy `installers/docker.ps1` to `installers/<toolname>.ps1`, swap in the winget ID and Chocolatey name, and add the tool name to the relevant profile's `tools` array.

```powershell
#Requires -Version 5.1
param([switch]$Uninstall)
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\common.ps1"

$Tool     = "My Tool"
$WingetId = "Vendor.Package"
$ChocoId  = "choco-package"

try {
    if ($Uninstall) {
        if (Test-Winget) { Uninstall-ViaWinget $WingetId $Tool }
        elseif (Test-Choco) { Uninstall-ViaChoco $ChocoId }
        Write-Success "✅ $Tool uninstalled"; exit 0
    }

    if (Test-CommandExists "mytool") {
        $ver = (mytool --version 2>$null).Trim()
        Write-Success "✅ $Tool already installed — $ver"; exit 0
    }

    $ok = $false
    if (Test-Winget)                { $ok = Install-ViaWinget $WingetId $Tool }
    if (-not $ok -and (Test-Choco)) { $ok = Install-ViaChoco $ChocoId }

    if ($ok) { Refresh-Path; Write-Success "✅ $Tool installed"; exit 0 }
    Write-Err "❌ $Tool installation failed"; exit 1
} catch {
    Write-Err "❌ $Tool installation failed: $_"; exit 1
}
```

---

## Requirements

- Windows 10 (build 1903+) or Windows 11
- PowerShell 5.1 (ships with Windows — no upgrade needed)
- Administrator privileges (needed for DISM, MSI installs, and most package managers)

---

## Repository layout

```
windows-dev-setup/
├── setup.ps1                   # master orchestrator
├── profiles/
│   ├── microservices.json      # Python microservices stack (14 tools)
│   ├── frontend.json           # Node / React / Docker
│   └── data-science.json       # Python / JupyterLab / MySQL
├── installers/
│   ├── common.ps1              # shared helpers (dot-sourced by every installer)
│   ├── winget-bootstrap.ps1    # ensure winget or Chocolatey is available
│   └── <tool>.ps1              # one file per managed tool
└── checks/
    └── verify.ps1              # standalone health check
```
