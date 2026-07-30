<#
.SYNOPSIS
    Install generic-Jeff on Windows (one click, just works).

.DESCRIPTION
    1. Verifies Windows, Python 3, admin
    2. Installs OpenClaw via the official installer
    3. Installs Ollama via the official installer
    4. Pulls a default chat model
    5. Drops the generic-Jeff body into $HOME\.openclaw\workspace\
    6. Installs openclaw.template.json into $HOME\.openclaw\openclaw.json
    7. Starts the OpenClaw gateway
    8. Verifies: openclaw doctor, ollama list, A2A server health

.PARAMETER DryRun
    Show what would happen, don't actually write

.PARAMETER SkipDeps
    Assume OpenClaw + Ollama are already installed

.PARAMETER Model
    Override the default chat model

.EXAMPLE
    .\install-windows.ps1
    .\install-windows.ps1 -DryRun
    .\install-windows.ps1 -SkipDeps -Model llama3.2:3b
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipDeps,
    [string]$Model = "minimax-m3:cloud"
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

function Say($msg) { Write-Host "[install-windows.ps1] $msg" }
function Die($msg) { Write-Error "ERROR: $msg"; exit 1 }
function Ok($msg) { Write-Host "[install-windows.ps1] + $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[install-windows.ps1] ! $msg" -ForegroundColor Yellow }
function Run($cmd) {
    if ($DryRun) { Say "  [dry-run] $cmd" }
    else { Invoke-Expression $cmd }
}

Say "Generic-Jeff installer for Windows — v$ScriptVersion"
Say ""

# Windows check
if ($env:OS -ne "Windows_NT") {
    Die "this installer is Windows-only. On macOS, use install-macos.sh. On Linux, use install-linux.sh."
}
Ok "Windows detected"

# SFX payload check
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadDir = $null
if (Test-Path "$ScriptDir\payload") {
    $PayloadDir = "$ScriptDir\payload"
} elseif (Test-Path "$ScriptDir\payload.zip") {
    Say "Self-extracting archive detected"
    $ExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    Expand-Archive -Path "$ScriptDir\payload.zip" -DestinationPath $ExtractDir -Force
    $PayloadDir = "$ExtractDir\payload"
} else {
    $PayloadDir = $ScriptDir
    Say "No SFX payload detected, using script directory as payload"
}
Ok "payload found at: $PayloadDir"

# === Phase 1: dependencies ===
if (-not $SkipDeps) {
    Say ""
    Say "Phase 1: install OpenClaw + Ollama"

    # Python check
    try { $pyVersion = python --version 2>&1 } catch { Die "python not found, please install Python 3.10+ first" }
    Ok "python present ($pyVersion)"

    # OpenClaw
    try { $ocVersion = openclaw --version 2>&1 } catch {
        Say "OpenClaw not found, installing"
        Run "Invoke-WebRequest -Uri 'https://openclaw.ai/install.ps1' -OutFile '$env:TEMP\openclaw-install.ps1'"
        Run "& '$env:TEMP\openclaw-install.ps1' -NoOnboard"
    }
    Ok "OpenClaw present"

    # Ollama
    try { $ollamaVersion = ollama --version 2>&1 } catch {
        Say "Ollama not found, downloading installer"
        Run "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '$env:TEMP\OllamaSetup.exe'"
        Run "Start-Process -FilePath '$env:TEMP\OllamaSetup.exe' -ArgumentList '/S' -Wait"
    }
    Ok "Ollama present"

    # Wait for Ollama to be ready
    $ollamaReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) { $ollamaReady = $true; break }
        } catch { Start-Sleep -Seconds 2 }
    }
    if ($ollamaReady) { Ok "Ollama running" } else { Warn "Ollama may not be running yet" }

    # Model pull
    try {
        $models = ollama list 2>&1
        if ($models -notmatch $Model) {
            Say "Pulling model: $Model"
            Run "ollama pull $Model"
        } else {
            Ok "Model $Model already present"
        }
    } catch { Warn "could not check models" }
} else {
    Ok "dependencies skipped (-SkipDeps)"
}

# === Phase 2: install generic-Jeff body ===
Say ""
Say "Phase 2: install generic-Jeff body to $env:USERPROFILE\.openclaw\workspace"

$workspace = "$env:USERPROFILE\.openclaw\workspace"

if ((Test-Path $workspace) -and (Get-ChildItem $workspace -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $backupPath = "$workspace.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Say "Existing workspace found, backing up to $backupPath"
    Run "Rename-Item '$workspace' '$backupPath'"
}

Run "New-Item -ItemType Directory -Force -Path '$workspace' | Out-Null"

$constitution = @("AGENTS.md", "SOUL.md", "MEMORY.md", "USER.md", "IDENTITY.md", "TOOLS.md",
                  "HEARTBEAT.md", "README.md", "RECOVER_FIRST.md", "AI_Agent_Portable_Playbook.md",
                  "CAPABILITY_MAP.md", "COMPONENT_MAP.md", "kitchen_menu.md")
foreach ($f in $constitution) {
    $src = Join-Path $PayloadDir $f
    if (Test-Path $src) {
        Run "Copy-Item '$src' '$workspace\$f' -Force"
    } else {
        Warn "missing in payload: $f (skipping)"
    }
}

$templateJson = Join-Path $PayloadDir "wired\template\openclaw.template.json"
if (Test-Path $templateJson) {
    Run "New-Item -ItemType Directory -Force -Path '$env:USERPROFILE\.openclaw\wired' | Out-Null"
    Run "Copy-Item '$templateJson' '$env:USERPROFILE\.openclaw\wired\openclaw.template.json' -Force"
    Ok "openclaw template installed"
}

$a2aServer = Join-Path $PayloadDir "scripts\jeff_a2a_server.py"
if (Test-Path $a2aServer) {
    Run "New-Item -ItemType Directory -Force -Path '$workspace\scripts' | Out-Null"
    Run "Copy-Item '$a2aServer' '$workspace\scripts\jeff_a2a_server.py' -Force"
    Ok "A2A server installed"
}

$examplesDir = Join-Path $PayloadDir "scripts\examples"
if (Test-Path $examplesDir) {
    Run "Copy-Item '$examplesDir' '$workspace\scripts\examples' -Recurse -Force"
    Ok "example scripts installed"
}
$examplesKitDir = Join-Path $PayloadDir "scripts\examples-kit"
if (Test-Path $examplesKitDir) {
    Run "Copy-Item '$examplesKitDir' '$workspace\scripts\examples-kit' -Recurse -Force"
    Ok "example kit-build scripts installed"
}

foreach ($f in @("copy-to-generic.sh", "copy-from-generic.sh", "copy-to-generic.ps1", "copy-from-generic.ps1")) {
    $src = Join-Path $PayloadDir $f
    if (Test-Path $src) { Run "Copy-Item '$src' '$workspace\$f' -Force" }
}

$a2aReadme = Join-Path $PayloadDir "A2A-SERVER.md"
if (Test-Path $a2aReadme) { Run "Copy-Item '$a2aReadme' '$workspace\A2A-SERVER.md' -Force" }

Ok "generic-Jeff body installed at $workspace"

# === Phase 3: install openclaw.json from template ===
Say ""
Say "Phase 3: install openclaw.json from template"
$ocConfig = "$env:USERPROFILE\.openclaw\openclaw.json"
if (-not (Test-Path $ocConfig)) {
    $srcTemplate = "$env:USERPROFILE\.openclaw\wired\openclaw.template.json"
    if (Test-Path $srcTemplate) {
        Run "Copy-Item '$srcTemplate' '$ocConfig' -Force"
        Ok "openclaw.json installed from template"
        Warn "edit $ocConfig to set your model, channels, etc."
    }
} else {
    Ok "openclaw.json already exists, leaving alone"
}

# === Phase 4: start the gateway ===
Say ""
Say "Phase 4: start OpenClaw gateway"
Run "openclaw gateway start" | Out-Null
if ($LASTEXITCODE -ne 0) { Warn "gateway start returned non-zero, check 'openclaw gateway start' manually" }

Start-Sleep -Seconds 2
Run "openclaw gateway status" | Out-Null

# === Phase 5: verify ===
Say ""
Say "Phase 5: verify"
Run "openclaw doctor" | Out-Null
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/api/a2a/health" -UseBasicParsing -TimeoutSec 3
    Ok "A2A server responding"
} catch { Warn "A2A server not responding yet (may need a moment)" }

Say ""
Ok "Done. Generic-Jeff is installed."
Say ""
Say "Next steps:"
Say "  1. Edit $workspace\USER.md with your profile"
Say "  2. Edit $ocConfig — set your model, channels, auth"
Say "  3. If you have a personal recovery kit, run copy-from-generic.ps1 to install"
Say "     the generic body, then rehydrate from your kit for personal context"
Say "  4. Open a new PowerShell, type 'openclaw chat' to wake Jeff up"
