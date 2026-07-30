<#
.SYNOPSIS
    Drop a generic-Jeff body into a principal's workspace.

.DESCRIPTION
    Wipes (or backs up) the destination workspace and copies the generic
    body in. Does NOT rehydrate personal context — that's the principal's
    recovery kit, a separate process.

.PARAMETER Source
    Path to the generic-Jeff folder (default: .\generic-jeff-build)

.PARAMETER Destination
    Where to install (default: $HOME\.openclaw\workspace)

.PARAMETER Backup
    Back up the existing destination before overwriting

.PARAMETER DryRun
    Show what would happen

.EXAMPLE
    .\copy-from-generic.ps1
    .\copy-from-generic.ps1 -Source C:\path\to\generic-jeff -Destination C:\Users\Me\.openclaw\workspace -Backup
#>
[CmdletBinding()]
param(
    [string]$Source = ".\generic-jeff-build",
    [string]$Destination = "$HOME\.openclaw\workspace",
    [switch]$Backup,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

function Say($msg) { Write-Host "[copy-from-generic.ps1] $msg" }
function Die($msg) { Write-Error "ERROR: $msg"; exit 1 }
function Run($cmd) {
    if ($DryRun) { Say "  [dry-run] $cmd" }
    else { Invoke-Expression $cmd }
}

if (-not (Test-Path $Source)) { Die "source generic-Jeff folder not found: $Source" }

# Refuse to overwrite a workspace that already has content,
# unless -Backup is passed (which moves the old content aside first).
if ((Test-Path $Destination) -and (Get-ChildItem $Destination -ErrorAction SilentlyContinue | Select-Object -First 1) -and (-not $Backup)) {
    Write-Warning "Destination already has content: $Destination"
    Write-Warning "Refusing to clobber without -Backup"
    Die "use -Backup to back up the existing workspace first"
}

if ((Test-Path $Destination) -and $Backup) {
    $backupPath = "$Destination.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Say "Backing up existing $Destination → $backupPath"
    Run "Rename-Item '$Destination' '$backupPath'"
}

Say "Ensuring $Destination exists"
Run "New-Item -ItemType Directory -Force -Path '$Destination' | Out-Null"

Say "Copying $Source → $Destination"
Run "Copy-Item '$Source\*' '$Destination\' -Recurse -Force"

# Check A2A server
$a2aPath = Join-Path $Destination "scripts\jeff_a2a_server.py"
if (Test-Path $a2aPath) {
    Say "A2A server present at $a2aPath"
} else {
    Say "WARN: A2A server not found at expected path"
}

Write-Host ""
Say "Done. Generic-Jeff body installed at: $Destination"
Say ""
Say "Next steps:"
Say "  1. Edit $Destination\USER.md with the principal's profile"
Say "  2. Install openclaw.json from $Destination\wired\template\openclaw.template.json"
Say "  3. Start the gateway: openclaw gateway start"
Say "  4. Jeff wakes up, says hello."
if ($DryRun) { Say "(dry-run — nothing was actually written)" }
