<#
.SYNOPSIS
    Produce a generic-Jeff body from a personal Jeff (or any personalised) workspace.

.DESCRIPTION
    Strips personal USER.md, IDENTITY.md, kitchen contents. Replaces
    openclaw.json with the template. Excludes API keys, private memory,
    session state. The result is what you'd hand to anyone.

.PARAMETER Source
    Path to the principal's workspace (default: $HOME\.openclaw\workspace)

.PARAMETER Destination
    Where to write the generic-Jeff body (default: .\generic-jeff-build)

.PARAMETER PublicTemplateDir
    Where the generic-jeff public/ folder lives (default: script's parent\public)

.PARAMETER DryRun
    Show what would happen, don't actually write

.EXAMPLE
    .\copy-to-generic.ps1
    .\copy-to-generic.ps1 -DryRun
    .\copy-to-generic.ps1 -Source C:\Users\Me\.openclaw\workspace -Destination .\out
#>
[CmdletBinding()]
param(
    [string]$Source = "$HOME\.openclaw\workspace",
    [string]$Destination = ".\generic-jeff-build",
    [string]$PublicTemplateDir = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

if (-not $PublicTemplateDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $PublicTemplateDir = Join-Path $ScriptDir "public"
}

function Say($msg) { Write-Host "[copy-to-generic.ps1] $msg" }
function Die($msg) { Write-Error "ERROR: $msg"; exit 1 }
function Run($cmd) {
    if ($DryRun) { Say "  [dry-run] $cmd" }
    else { Invoke-Expression $cmd }
}

# Sanity checks
if (-not (Test-Path $Source)) { Die "source workspace not found: $Source" }
if (-not (Test-Path $PublicTemplateDir)) { Die "generic-jeff public/ not found at $PublicTemplateDir" }

Say "Phase 1: build destination $Destination"
Run "New-Item -ItemType Directory -Force -Path '$Destination' | Out-Null"

# Constitution + sanitised docs (always from template)
$constitution = @("AGENTS.md", "SOUL.md", "MEMORY.md", "TOOLS.md", "HEARTBEAT.md", "RECOVER_FIRST.md", "REFERENCES.md", "PROJECTS.md")
Say "Phase 2: write constitution files from template"
foreach ($f in $constitution) {
    $src = Join-Path $PublicTemplateDir $f
    if (Test-Path $src) {
        Run "Copy-Item '$src' '$Destination\$f' -Force"
        Say "  + $f"
    } else {
        Say "  ! $f missing in template, skipping"
    }
}

# Templated personal files
$templated = @("USER.md", "IDENTITY.md", "README.md", "kitchen_menu.md", "COMPONENT_MAP.md", "CAPABILITY_MAP.md", "AI_Agent_Portable_Playbook.md")
Say "Phase 3: write templated personal files"
foreach ($f in $templated) {
    $src = Join-Path $PublicTemplateDir $f
    if (Test-Path $src) {
        Run "Copy-Item '$src' '$Destination\$f' -Force"
        Say "  + $f"
    }
}

# openclaw template
Say "Phase 4: install openclaw template"
$templateJson = Join-Path $PublicTemplateDir "wired\template\openclaw.template.json"
if (Test-Path $templateJson) {
    Run "New-Item -ItemType Directory -Force -Path '$Destination\wired\template' | Out-Null"
    Run "Copy-Item '$templateJson' '$Destination\wired\template\openclaw.template.json' -Force"
    Say "  + openclaw.template.json"
}

# A2A server
Say "Phase 5: install A2A server"
$a2aScripts = Join-Path $PublicTemplateDir "..\Jeff A2A Server\scripts"
if (Test-Path $a2aScripts) {
    Run "New-Item -ItemType Directory -Force -Path '$Destination\scripts' | Out-Null"
    Get-ChildItem -Path $a2aScripts -Filter "*.py" | ForEach-Object {
        Run "Copy-Item '$($_.FullName)' '$Destination\scripts\$($_.Name)' -Force"
    }
    $a2aReadme = Join-Path $PublicTemplateDir "..\Jeff A2A Server\README.md"
    if (Test-Path $a2aReadme) {
        Run "Copy-Item '$a2aReadme' '$Destination\A2A-SERVER.md' -Force"
    }
    Say "  + A2A server"
}

# Example scripts
Say "Phase 6: install sanitised example scripts"
$exScripts = Join-Path $PublicTemplateDir "scripts"
if (Test-Path $exScripts) {
    Run "New-Item -ItemType Directory -Force -Path '$Destination\scripts\examples' | Out-Null"
    Get-ChildItem -Path $exScripts -File | ForEach-Object {
        Run "Copy-Item '$($_.FullName)' '$Destination\scripts\examples\$($_.Name)' -Force"
    }
}
$exScriptsKit = Join-Path $PublicTemplateDir "scripts-kit"
if (Test-Path $exScriptsKit) {
    Run "New-Item -ItemType Directory -Force -Path '$Destination\scripts\examples-kit' | Out-Null"
    Get-ChildItem -Path $exScriptsKit -File | ForEach-Object {
        Run "Copy-Item '$($_.FullName)' '$Destination\scripts\examples-kit\$($_.Name)' -Force"
    }
}

# Install self and the round-trip inverse
$psScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Self
Run "Copy-Item '$psScriptsDir\copy-to-generic.ps1' '$Destination\copy-to-generic.ps1' -Force"
Say "  + copy-to-generic.ps1"
# Inverse
$backScript = Join-Path $psScriptsDir "copy-from-generic.ps1"
if (Test-Path $backScript) {
    Run "Copy-Item '$backScript' '$Destination\copy-from-generic.ps1' -Force"
    Say "  + copy-from-generic.ps1"
}

# Manifest
Say "Phase 8: write MANIFEST.md"
$manifest = @"
# Generic-Jeff Build Manifest

Built: $(Get-Date -Format "u")
Source: $Source
Builder: copy-to-generic.ps1 v$ScriptVersion

## Next steps

1. Copy this folder into a principal's workspace, or use copy-from-generic.ps1
2. Edit USER.md with the principal's profile
3. Install openclaw.json from wired\template\openclaw.template.json
4. Start the gateway: openclaw gateway start
5. Jeff wakes up, says hello.
"@
Run "Set-Content -Path '$Destination\MANIFEST.md' -Value @'`$manifest`'@"

Write-Host ""
Say "Done. Generic-Jeff body built at: $Destination"
if ($DryRun) { Say "(dry-run — nothing was actually written)" }
