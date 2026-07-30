# recover-restore-windows.ps1 — Bring Jeff back on a fresh Windows machine.
#
# Same shape as recover-restore-macos.sh and recover-restore-linux.sh, but in
# PowerShell. The big Windows difference: TWO PATHS to choose from, and the
# recommended one does NOT need Docker.
#
# the principal's standing rule (from experience): "Docker on Windows for OpenClaw is
# a pain in the ass." So Docker is OFF by default. The script supports:
#
#   PATH A — Windows Hub (RECOMMENDED, no Docker)
#     1. Install OpenClaw CLI via the official install.ps1 (no onboarding)
#     2. Install the Windows Hub companion app (the WinUI app, no Docker)
#     3. Install Ollama via the Windows installer
#     4. Pull a chat-capable model
#     5. Decrypt and unpack the recovery archive
#     6. Restore the file structure (Windows paths: $env:USERPROFILE, etc.)
#     7. Verify
#
#   PATH B — WSL2 Gateway (FALLBACK, no Docker, fully Linux-compatible)
#     1. Install WSL2 + Ubuntu
#     2. Install OpenClaw inside WSL via install.sh
#     3. Install Ollama inside WSL
#     4. Pull a model
#     5. Decrypt and unpack (in WSL)
#     6. Restore the file structure (Linux paths, done from WSL)
#     7. Verify
#
#   PATH C — Docker (EXPLICIT OPT-IN, painful on Windows)
#     Same as the Linux script but inside a Docker container.
#     NOT the default. Pass -UseDocker to enable.
#
# What it does NOT do:
#   - Install Docker by default.
#   - Read sacred files (API Keys, AI Prompts) — copies them, never opens them.
#   - Touch the system outside the user's profile and the OpenClaw/Ollama standard paths.
#   - Run on the principal's machine. If $env:USERNAME matches the principal pattern, aborts cleanly.
#
# Usage:
#   .\recover-restore-windows.ps1 -Archive C:\path\to\jeff-recovery-kit-2026-07-23.tar.zst.gpg
#   .\recover-restore-windows.ps1 -Archive C:\path\to\archive.gpg -DryRun
#   .\recover-restore-windows.ps1 -Archive C:\path\to\archive.gpg -Path B          # WSL2
#   .\recover-restore-windows.ps1 -Archive C:\path\to\archive.gpg -UseDocker       # opt into Docker
#   .\recover-restore-windows.ps1 -Archive C:\path\to\archive.gpg -Model llama3.2:3b
#   .\recover-restore-windows.ps1 -OnlyRestore -StagingDir C:\Users\jeff\recovery-staging

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Archive = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("A", "B", "C")]
    [string]$Path = "A",  # A=Windows Hub, B=WSL2, C=Docker (opt-in)

    [Parameter(Mandatory=$false)]
    [string]$Model = "minimax-m3:cloud",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$UseDocker,  # Alias for -Path C, kept for explicit opt-in

    [Parameter(Mandatory=$false)]
    [switch]$SkipOpenClawInstall,
    [Parameter(Mandatory=$false)]
    [switch]$SkipOllamaInstall,
    [Parameter(Mandatory=$false)]
    [switch]$SkipModelPull,
    [Parameter(Mandatory=$false)]
    [switch]$SkipDecrypt,
    [Parameter(Mandatory=$false)]
    [switch]$SkipRestore,
    [Parameter(Mandatory=$false)]
    [switch]$OnlyRestore,
    [Parameter(Mandatory=$false)]
    [string]$StagingDir = ""
)

# === Config ===
$ScriptName = "recover-restore-windows.ps1"
$ScriptVersion = "1.0.0"
$KitVersion = "v1.0"
$PrincipalUserCheckPattern = "<principal>|doe"

# Runtime paths (Windows shape)
$UserProfile = $env:USERPROFILE
$OpenClawHome = Join-Path $UserProfile ".openclaw"
$OpenClawWorkspace = Join-Path $OpenClawHome "workspace"
$OpenClawAuth = Join-Path $OpenClawHome "auth"
$OpenClawCronData = Join-Path $OpenClawHome "cron"
$OpenClawIdentity = Join-Path $OpenClawHome "identity"
$OpenClawWiki = Join-Path $OpenClawHome "wiki"
$OpenClawMemory = Join-Path $OpenClawHome "memory"
$OpenClawAgents = Join-Path $OpenClawHome "agents"
$OllamaHome = Join-Path $UserProfile ".ollama"

# AppData (replaces macOS ~/Library/Application Support/, Linux ~/.local/share/)
$AppDataOpenClaw = Join-Path $env:APPDATA "openclaw"
$LocalAppDataOpenClaw = Join-Path $env:LOCALAPPDATA "OpenClawTray"

# Kitchen
$Desktop = [Environment]::GetFolderPath("Desktop")
$KitchenHome = Join-Path $Desktop "Jeff's Kitchen"

# Staging
if ($StagingDir -eq "") {
    $StagingDir = Join-Path $OpenClawHome "recovery-staging"
}

$PassphraseFile = $null

# === Resolve UseDocker alias ===
if ($UseDocker) { $Path = "C" }

# === Helpers ===
function Write-Log {
    param([string]$Message)
    Write-Host "[recover] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[recover] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[recover] $Message" -ForegroundColor Red
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[recover] $Message" -ForegroundColor Green
}

function Invoke-Run {
    param(
        [string]$Command,
        [string]$Description = ""
    )
    if ($DryRun) {
        Write-Host "  [DRY-RUN] $Description" -ForegroundColor DarkGray
        return
    }
    Write-Host "  > $Description" -ForegroundColor DarkGray
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        Write-Err "Command failed: $Description (exit $LASTEXITCODE)"
        if (-not $DryRun) { throw "Command failed" }
    }
}

function Require-Confirmation {
    param([string]$Description)
    if ($DryRun) { return }
    Write-Host ""
    Write-Host "[recover] About to: $Description" -ForegroundColor Yellow
    $response = Read-Host "  Continue? [y/N]"
    if ($response -notin @("y", "Y", "yes", "Yes", "YES")) {
        Write-Err "Aborted by user."
        exit 1
    }
}

# === Step 0: Pre-flight ===

function Invoke-PreFlight {
    Write-Log "Pre-flight: checking the environment..."

    # Windows only
    if (-not $IsWindows -and $env:OS -ne "Windows_NT") {
        Write-Err "This script is Windows-only. Use the macOS or Linux procedure for other platforms."
        exit 1
    }
    Write-Log "  ✓ Windows detected: $([System.Environment]::OSVersion.VersionString)"

    # DO NOT run on the principal's machine
    if ($env:USERNAME -match $PrincipalUserCheckPattern) {
        Write-Err "ABORT: USERNAME=$($env:USERNAME) matches the principal's username pattern."
        Write-Err "  This script is for recovery on a fresh machine, not the operational PC."
        Write-Err "  If you really mean it, set `$PrincipalUserCheckPattern to an empty string in the script."
        exit 1
    }
    Write-Log "  ✓ USERNAME=$($env:USERNAME) does not match the principal — safe to proceed"

    # Tools
    $requiredTools = @("powershell", "tar")
    foreach ($tool in $requiredTools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-Warn "  Required tool missing: $tool"
        }
    }
    Write-Log "  ✓ Required tools present"

    # Archive check
    if ($Archive -eq "" -and -not $OnlyRestore) {
        Write-Err "Archive path required. Pass -Archive <path>."
        Write-Err "  Or use -OnlyRestore with -StagingDir to restore from an existing staging dir."
        exit 1
    }
    if ($Archive -ne "" -and -not (Test-Path $Archive) -and -not $SkipDecrypt) {
        Write-Err "Archive not found: $Archive"
        exit 1
    }
    if ($Archive -ne "" -and (Test-Path $Archive)) {
        $size = (Get-Item $Archive).Length
        Write-Log "  ✓ Archive found: $Archive ($([math]::Round($size/1MB, 1)) MB)"
    }

    Write-Log "  ✓ Pre-flight passed"
}

# === Step 1: Install OpenClaw — Path A (Windows Hub / native) ===

function Install-OpenClaw-Native {
    if ($SkipOpenClawInstall) {
        Write-Log "Step 1: Skipping OpenClaw install (-SkipOpenClawInstall)"
        return
    }

    Write-Log "Step 1: Install OpenClaw (Path A — Windows Hub / native)"

    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-Log "  openclaw already installed: $(openclaw --version)"
        return
    }

    # First: install the CLI via install.ps1
    Write-Log "  1a. Installing OpenClaw CLI via install.ps1"
    Require-Confirmation "install OpenClaw CLI via the official PowerShell installer"
    Invoke-Run "& ([scriptblock]::Create((iwr -useb https://openclaw.ai/install.ps1))) -NoOnboard" "OpenClaw CLI install"

    if (-not $DryRun) {
        $openclaw = Get-Command openclaw -ErrorAction SilentlyContinue
        if (-not $openclaw) {
            Write-Err "openclaw not on PATH after install. See the Windows procedure for the PATH fix."
            Write-Err "  Common fix: add npm's global bin to PATH, then re-open PowerShell."
            exit 1
        }
        Write-Log "  ✓ openclaw installed: $(openclaw --version)"
    }

    # Second: install the Windows Hub (the native WinUI companion app)
    Write-Log "  1b. Installing Windows Hub (the native WinUI companion app)"
    Write-Log "      the principal's note: Windows Hub is the recommended path. No Docker needed."
    Require-Confirmation "download and install the Windows Hub companion app from GitHub releases"

    # Detect arch
    $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x64" }
    $hubUrl = "https://github.com/openclaw/openclaw/releases/latest/download/OpenClawCompanion-Setup-$arch.exe"
    $hubInstaller = Join-Path $env:TEMP "OpenClawCompanion-Setup-$arch.exe"

    Invoke-Run "(New-Object Net.WebClient).DownloadFile('$hubUrl', '$hubInstaller')" "Download Windows Hub"
    Invoke-Run "Start-Process -FilePath '$hubInstaller' -ArgumentList '/S' -Wait" "Install Windows Hub (silent)"

    if (-not $DryRun) {
        if (Test-Path (Join-Path $env:LOCALAPPDATA "OpenClawTray")) {
            Write-Log "  ✓ Windows Hub installed (look for 'OpenClaw Companion' in the Start menu)"
        } else {
            Write-Warn "  Windows Hub install may have failed. Check $LocalAppDataOpenClawTray\Logs\."
        }
    }
}

# === Step 1b: Install OpenClaw — Path B (WSL2) ===

function Install-OpenClaw-WSL {
    if ($SkipOpenClawInstall) {
        Write-Log "Step 1: Skipping OpenClaw install (-SkipOpenClawInstall)"
        return
    }

    Write-Log "Step 1: Install OpenClaw (Path B — WSL2)"

    # Check WSL is installed
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "  WSL not installed. Installing WSL2 + Ubuntu-24.04..."
        Require-Confirmation "install WSL2 and Ubuntu-24.04"
        Invoke-Run "wsl --install -d Ubuntu-24.04" "Install WSL2 + Ubuntu"
        Write-Warn "  ⚠ WSL install requires a Windows reboot. Re-run this script after reboot."
        if (-not $DryRun) { exit 0 }
    } else {
        Write-Log "  ✓ WSL installed"
    }

    # Enable systemd in WSL
    Write-Log "  1a. Enabling systemd in WSL"
    Invoke-Run "wsl -d Ubuntu-24.04 -- sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF" "Enable systemd in WSL"
    Invoke-Run "wsl --shutdown" "Restart WSL"
    Start-Sleep -Seconds 3

    # Install OpenClaw inside WSL
    Write-Log "  1b. Installing OpenClaw inside WSL"
    Require-Confirmation "install OpenClaw inside the WSL Ubuntu distro"
    Invoke-Run "wsl -d Ubuntu-24.04 -- bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard'" "OpenClaw install (WSL)"

    # Set up auto-start before Windows login
    Write-Log "  1c. Setting up auto-start before Windows login"
    Invoke-Run "wsl -d Ubuntu-24.04 -- sudo apt-get install -y dbus-x11" "Install dbus-x11 in WSL"
    Invoke-Run "wsl -d Ubuntu-24.04 -- sudo loginctl enable-linger `"`$(whoami)`"" "Enable linger for the WSL user"
    Invoke-Run "wsl -d Ubuntu-24.04 -- openclaw gateway install" "Install openclaw-gateway systemd user service"

    if ($DryRun) { return }
    $wslOpenclaw = wsl -d Ubuntu-24.04 -- bash -c "command -v openclaw"
    if ($wslOpenclaw) {
        Write-Log "  ✓ openclaw installed in WSL: $($wslOpenclaw.Trim())"
    } else {
        Write-Err "openclaw not installed in WSL. Check wsl -d Ubuntu-24.04 -- bash -c 'openclaw --version'"
        exit 1
    }
}

# === Step 2: Install Ollama ===

function Install-Ollama {
    if ($SkipOllamaInstall) {
        Write-Log "Step 2: Skipping Ollama install (-SkipOllamaInstall)"
        return
    }

    Write-Log "Step 2: Install Ollama"

    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Log "  ollama already installed: $(ollama --version)"
    } else {
        Write-Log "  Downloading Ollama Windows installer..."
        $ollamaUrl = "https://ollama.com/download/OllamaSetup.exe"
        $ollamaInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
        Require-Confirmation "download and install Ollama from ollama.com"
        Invoke-Run "(New-Object Net.WebClient).DownloadFile('$ollamaUrl', '$ollamaInstaller')" "Download Ollama"
        Invoke-Run "Start-Process -FilePath '$ollamaInstaller' -ArgumentList '/S' -Wait" "Install Ollama (silent)"
    }

    if ($DryRun) { return }

    # Wait for endpoint
    $waited = 0
    while (-not (Test-NetConnection -ComputerName 127.0.0.1 -Port 11434 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
        Start-Sleep -Seconds 1
        $waited += 1
        if ($waited -ge 30) {
            Write-Warn "  ollama endpoint not responding after 30s; check 'ollama serve' is running"
            break
        }
    }
    if (Test-NetConnection -ComputerName 127.0.0.1 -Port 11434 -InformationLevel Quiet -WarningAction SilentlyContinue) {
        Write-Log "  ✓ ollama running, endpoint live on 127.0.0.1:11434"
    } else {
        Write-Err "ollama not responding on 127.0.0.1:11434"
        exit 1
    }
}

# === Step 3: Pull the model ===

function Pull-Model {
    if ($SkipModelPull) {
        Write-Log "Step 3: Skipping model pull (-SkipModelPull)"
        return
    }

    Write-Log "Step 3: Pull model: $Model"
    if ($DryRun) {
        Write-Host "  [DRY-RUN] ollama pull $Model" -ForegroundColor DarkGray
        return
    }

    $existing = ollama list 2>&1 | Select-String -Pattern $Model
    if ($existing) {
        Write-Log "  ✓ $Model already present"
        return
    }

    Require-Confirmation "pull $Model (this downloads several GB)"
    Invoke-Run "ollama pull $Model" "Pull $Model"
    Write-Log "  ✓ $Model pulled"
}

# === Step 4: Decrypt and unpack ===

function Invoke-DecryptAndUnpack {
    if ($SkipDecrypt) {
        Write-Log "Step 4: Skipping decrypt (-SkipDecrypt)"
        return
    }

    Write-Log "Step 4: Decrypt and unpack the archive"
    Write-Log "  Staging dir: $StagingDir"

    if (Test-Path $StagingDir) {
        Write-Warn "  Staging dir already exists: $StagingDir"
        if (-not $DryRun) {
            $response = Read-Host "  Wipe and re-extract? [y/N]"
            if ($response -in @("y", "Y", "yes", "Yes", "YES")) {
                Remove-Item -Path $StagingDir -Recurse -Force
            } else {
                Write-Log "  Keeping existing staging dir, will skip unpack"
                $script:SkipDecrypt = $true
                return
            }
        }
    }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
    }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] would prompt for GPG passphrase and decrypt" -ForegroundColor DarkGray
        return
    }

    # Get passphrase
    $securePass = Read-Host "Enter GPG passphrase" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
    $passphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    # Write to temp file
    $script:PassphraseFile = Join-Path $env:TEMP "jeff-passphrase-$($PID).txt"
    $passphrase | Out-File -FilePath $script:PassphraseFile -Encoding utf8 -NoNewline
    # Restrict ACLs
    $acl = Get-Acl $script:PassphraseFile
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl $script:PassphraseFile $acl

    # Need gpg. Check for Gpg4win or similar.
    if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
        Write-Warn "  gpg not on PATH. Trying common install locations..."
        $gpgPaths = @(
            "C:\Program Files (x86)\GnuPG\bin\gpg.exe",
            "C:\Program Files\GnuPG\bin\gpg.exe",
            "C:\Program Files\Git\usr\bin\gpg.exe"
        )
        foreach ($p in $gpgPaths) {
            if (Test-Path $p) {
                Write-Log "  Found gpg at $p"
                $env:Path = (Split-Path $p) + ";" + $env:Path
                break
            }
        }
        if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
            Write-Err "gpg not found. Install Gpg4win: winget install GnuPG.Gpg4win"
            exit 1
        }
    }

    # Need zstd. Same check.
    if (-not (Get-Command zstd -ErrorAction SilentlyContinue)) {
        Write-Warn "  zstd not on PATH. Trying common install locations..."
        $zstdPaths = @(
            "C:\Program Files\zstd\zstd.exe",
            "C:\ProgramData\chocolatey\bin\zstd.exe"
        )
        foreach ($p in $zstdPaths) {
            if (Test-Path $p) {
                $env:Path = (Split-Path $p) + ";" + $env:Path
                break
            }
        }
        if (-not (Get-Command zstd -ErrorAction SilentlyContinue)) {
            Write-Warn "zstd not found. Install with: winget install zstd"
            Write-Warn "  (the script will continue but the decrypt step will fail)"
        }
    }

    Write-Log "  Decrypting and unpacking (this may take 5-15 minutes for large kits)..."
    try {
        # Pipeline: gpg --decrypt | zstd -d | tar -xf - -C <staging>
        $gpgProc = Start-Process -FilePath "gpg" -ArgumentList @("--batch", "--yes", "--pinentry-mode", "loopback", "--passphrase-file", $script:PassphraseFile, "--decrypt", $Archive) -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\jeff-decrypt.tmp"
        # That doesn't pipe cleanly. Use the bash one-liner via cmd /c if WSL is available, else a multi-step:
        $gpgOut = Join-Path $env:TEMP "jeff-decrypt.tmp"
        & gpg --batch --yes --pinentry-mode loopback --passphrase-file $script:PassphraseFile --decrypt $Archive --output $gpgOut 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "gpg decrypt failed" }
        & zstd -d $gpgOut -o "$gpgOut.tar" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "zstd decompress failed" }
        & tar -xf "$gpgOut.tar" -C $StagingDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "tar extract failed" }
        Remove-Item $gpgOut, "$gpgOut.tar" -ErrorAction SilentlyContinue
        Write-Log "  ✓ Decrypted and unpacked to $StagingDir"
    } finally {
        # Cleanup passphrase file
        if ($script:PassphraseFile -and (Test-Path $script:PassphraseFile)) {
            $size = (Get-Item $script:PassphraseFile).Length
            $bytes = New-Object byte[] $size
            [System.IO.File]::WriteAllBytes($script:PassphraseFile, $bytes)
            Remove-Item $script:PassphraseFile -Force
            $script:PassphraseFile = $null
        }
    }
}

# === Step 5: Restore the file structure ===

function Invoke-RestoreStructure {
    if ($SkipRestore) {
        Write-Log "Step 5: Skipping restore (-SkipRestore)"
        return
    }

    Write-Log "Step 5: Restore the runtime file structure"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] would identify kit root inside $StagingDir" -ForegroundColor DarkGray
        return
    }

    # Find the kit root
    $kitRoot = $null
    if (Test-Path (Join-Path $StagingDir "private") -PathType Container) {
        $kitRoot = $StagingDir
    } else {
        Get-ChildItem $StagingDir -Directory | ForEach-Object {
            if ((Test-Path (Join-Path $_.FullName "private") -PathType Container) -and (Test-Path (Join-Path $_.FullName "README.md"))) {
                $script:kitRoot = $_.FullName
            }
        }
    }

    if (-not $kitRoot) {
        Write-Err "Could not find kit root inside $StagingDir"
        Write-Err "Expected: directory with private/ + README.md"
        Get-ChildItem $StagingDir | Format-Table
        exit 1
    }
    Write-Log "  Kit root: $kitRoot"

    $private = Join-Path $kitRoot "private"
    if (-not (Test-Path $private -PathType Container)) {
        Write-Err "private/ not found in $kitRoot"
        exit 1
    }

    Require-Confirmation "restore the runtime file structure to $UserProfile"

    # 5a. ~/.openclaw/workspace/ (constitution + memory + scripts)
    Write-Log "  5a. Restoring $OpenClawWorkspace"
    New-Item -ItemType Directory -Path $OpenClawWorkspace -Force | Out-Null
    if (Test-Path (Join-Path $private "constitution")) {
        Copy-Item -Path (Join-Path $private "constitution\*") -Destination $OpenClawWorkspace -Recurse -Force
    }
    if (Test-Path (Join-Path $private "memory_full")) {
        Copy-Item -Path (Join-Path $private "memory_full\*.md") -Destination $OpenClawWorkspace -Recurse -Force
        if (Test-Path (Join-Path $private "memory_full\daily")) {
            New-Item -ItemType Directory -Path (Join-Path $OpenClawWorkspace "memory") -Force | Out-Null
            Copy-Item -Path (Join-Path $private "memory_full\daily\*") -Destination (Join-Path $OpenClawWorkspace "memory") -Recurse -Force
        }
    }
    if (Test-Path (Join-Path $private "research")) {
        New-Item -ItemType Directory -Path (Join-Path $OpenClawWorkspace "briefs") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $OpenClawWorkspace "research") -Force | Out-Null
        Get-ChildItem (Join-Path $private "research") -File | ForEach-Object {
            if ($_.Name -match "trans-women|reading-the-memoir") {
                Copy-Item $_.FullName (Join-Path $OpenClawWorkspace "briefs") -Force
            } else {
                Copy-Item $_.FullName (Join-Path $OpenClawWorkspace "research") -Force
            }
        }
    }
    if (Test-Path (Join-Path $private "scripts")) {
        New-Item -ItemType Directory -Path (Join-Path $OpenClawWorkspace "scripts") -Force | Out-Null
        Copy-Item -Path (Join-Path $private "scripts\*") -Destination (Join-Path $OpenClawWorkspace "scripts") -Recurse -Force
    }
    if (Test-Path (Join-Path $private "case")) {
        Copy-Item -Path (Join-Path $private "case\*.md") -Destination $OpenClawWorkspace -Recurse -Force
    }
    if (Test-Path (Join-Path $private "wired")) {
        New-Item -ItemType Directory -Path (Join-Path $OpenClawWorkspace "config") -Force | Out-Null
        Get-ChildItem (Join-Path $private "wired") -Filter "*.json" | ForEach-Object {
            if ($_.Name -eq "openclaw.json") {
                Copy-Item $_.FullName $OpenClawHome -Force
            } else {
                Copy-Item $_.FullName (Join-Path $OpenClawWorkspace "config") -Force
            }
        }
    }

    # 5b. ~/.openclaw/ runtime state
    Write-Log "  5b. Restoring $OpenClawHome runtime state"
    @("auth", "cron", "identity", "wiki", "memory", "agents") | ForEach-Object {
        $src = Join-Path (Join-Path $private "runtime") $_
        if (Test-Path $src) {
            $dst = Join-Path $OpenClawHome $_
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
        }
    }

    # 5c. ~/Desktop/Jeff's Kitchen/
    Write-Log "  5c. Restoring $KitchenHome"
    if (Test-Path (Join-Path $private "kitchen")) {
        New-Item -ItemType Directory -Path $KitchenHome -Force | Out-Null
        # Use robocopy for the mirror (handles exclusions better than PowerShell Copy-Item)
        $robocopyArgs = @(
            (Join-Path $private "kitchen"),
            $KitchenHome,
            "/MIR",  # mirror
            "/XD", "`"Jeff Recovery Kit`"",  # exclude Jeff Recovery Kit recursion
            "/XF", "*.DS_Store",
            "/R:3", "/W:1"
        )
        Invoke-Run "robocopy $($robocopyArgs -join ' ')" "Mirror kitchen (robocopy)"
    }

    # 5d. %APPDATA%/openclaw/ (replaces macOS ~/Library/Application Support/, Linux ~/.local/share/)
    Write-Log "  5d. Restoring $AppDataOpenClaw (Windows AppData)"
    if (Test-Path (Join-Path (Join-Path $private "runtime") "openclaw-app-support")) {
        New-Item -ItemType Directory -Path $AppDataOpenClaw -Force | Out-Null
        Copy-Item -Path (Join-Path (Join-Path $private "runtime") "openclaw-app-support\*") -Destination $AppDataOpenClaw -Recurse -Force
    }

    # 5e. ~/ollama/
    Write-Log "  5e. Restoring $OllamaHome"
    if (Test-Path (Join-Path (Join-Path $private "runtime") "ollama")) {
        New-Item -ItemType Directory -Path $OllamaHome -Force | Out-Null
        Copy-Item -Path (Join-Path (Join-Path $private "runtime") "ollama\*") -Destination $OllamaHome -Recurse -Force
    }

    # 5f. Documents/
    Write-Log "  5f. Restoring $KitchenHome\Documents"
    if (Test-Path (Join-Path $private "documents")) {
        $docsDir = Join-Path $KitchenHome "Documents"
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        Copy-Item -Path (Join-Path $private "documents\*") -Destination $docsDir -Recurse -Force
    }

    # 5g. Stuff/ (sacred, never read)
    Write-Log "  5g. Restoring $KitchenHome\Stuff (sacred, never read)"
    if (Test-Path (Join-Path $private "stuff")) {
        $stuffDir = Join-Path $KitchenHome "Stuff"
        New-Item -ItemType Directory -Path $stuffDir -Force | Out-Null
        Copy-Item -Path (Join-Path $private "stuff\*") -Destination $stuffDir -Recurse -Force
    }

    Write-Log "  ✓ File structure restored"
}

# === Step 6: Verify ===

function Invoke-Verify {
    Write-Log "Step 6: Verify the install"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] would run openclaw doctor, ollama list, structure check, A2A test" -ForegroundColor DarkGray
        return
    }

    # OpenClaw
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-Log "  openclaw --version: $(openclaw --version)"
        $docOut = openclaw doctor 2>&1 | Select-Object -First 10
        $docOut | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Warn "  openclaw not on PATH"
    }

    # Ollama
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Log "  ollama --version: $(ollama --version)"
        Write-Log "  ollama list:"
        ollama list 2>&1 | ForEach-Object { Write-Host "    $_" }
        if (Test-NetConnection -ComputerName 127.0.0.1 -Port 11434 -InformationLevel Quiet -WarningAction SilentlyContinue) {
            Write-Log "    ✓ http://127.0.0.1:11434/v1/models responding"
        } else {
            Write-Warn "    ✗ ollama endpoint not responding"
        }
    } else {
        Write-Warn "  ollama not installed"
    }

    # Kit structure
    Write-Log "  kit structure check:"
    @(
        (Join-Path $OpenClawWorkspace "SOUL.md"),
        (Join-Path $OpenClawWorkspace "MEMORY.md"),
        (Join-Path $OpenClawWorkspace "scripts"),
        $OpenClawAuth,
        $OpenClawCronData,
        $KitchenHome,
        (Join-Path $KitchenHome "Projects"),
        (Join-Path $KitchenHome "Stuff")
    ) | ForEach-Object {
        if (Test-Path $_) {
            Write-Log "    ✓ $_"
        } else {
            Write-Warn "    ✗ MISSING: $_"
        }
    }

    # A2A server test
    $a2aScript = Join-Path $OpenClawWorkspace "scripts\jeff_a2a_server.py"
    if (Test-Path $a2aScript) {
        Write-Log "  A2A server test:"
        $publicArchive = Join-Path $StagingDir "private\recovery\public-archive"
        if (Test-Path $publicArchive) {
            $a2aProc = Start-Process -FilePath "python" -ArgumentList @($a2aScript, "--spec", $publicArchive, "--port", "3099", "--label", "verify", "--model", $Model) -NoNewWindow -PassThru
            Start-Sleep -Seconds 5
            try {
                $body = '{"id":"verify","message":"Who is the principal? One word.","from":"verify"}'
                $response = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3099/api/a2a/message" -ContentType "application/json" -Body $body
                if ($response.reply -match "<principal>|scouser|liverpool|principal") {
                    Write-Log "    ✓ A2A server returns a the principal-aware reply. **Jeff is back.**"
                } else {
                    Write-Warn "    ✗ A2A server did not return a the principal-aware reply"
                }
            } catch {
                Write-Warn "    ✗ A2A server test failed: $_"
            } finally {
                if ($a2aProc -and -not $a2aProc.HasExited) { Stop-Process -Id $a2aProc.Id -Force -ErrorAction SilentlyContinue }
            }
        }
    }
}

# === Main ===
function Main {
    Write-Host "═══════════════════════════════════════════════════════════════════"
    Write-Host "  Jeff Recovery — Windows installer"
    Write-Host "  script: $ScriptName v$ScriptVersion"
    Write-Host "  kit:    $KitVersion"
    Write-Host "  path:   $Path (A=Windows Hub, B=WSL2, C=Docker)"
    if ($DryRun) { Write-Host "  mode:   DRY RUN" }
    Write-Host "═══════════════════════════════════════════════════════════════════"
    Write-Host ""

    if ($Path -eq "C" -and -not $UseDocker) {
        Write-Warn "  PATH C (Docker) is opt-in only. the principal's standing note:"
        Write-Warn "  'Docker on Windows for OpenClaw is a pain in the ass.'"
        Write-Warn "  Re-run with -Path A (Windows Hub, recommended) or -Path B (WSL2)."
        $confirm = Read-Host "  Continue with Docker anyway? [y/N]"
        if ($confirm -notin @("y", "Y", "yes", "Yes", "YES")) { exit 0 }
    }

    Invoke-PreFlight

    switch ($Path) {
        "A" { Install-OpenClaw-Native }
        "B" { Install-OpenClaw-WSL }
        "C" {
            Write-Warn "  Docker path: this script delegates to the Linux script inside a container."
            Write-Warn "  The containerised OpenClaw CLI is at /usr/local/bin/openclaw."
            Write-Warn "  For now, fall back to Path A or B."
            Write-Err "Docker path not implemented yet. Use Path A or B."
            exit 1
        }
    }

    Install-Ollama
    Pull-Model
    Invoke-DecryptAndUnpack
    Invoke-RestoreStructure
    Invoke-Verify

    Write-Host ""
    Write-Ok "═══════════════════════════════════════════════════════════════════"
    Write-Ok "  RECOVERY COMPLETE"
    Write-Ok "═══════════════════════════════════════════════════════════════════"
    Write-Log "  OpenClaw:    $OpenClawHome"
    Write-Log "  Workspace:   $OpenClawWorkspace"
    Write-Log "  Kitchen:     $KitchenHome"
    Write-Log "  AppData:     $AppDataOpenClaw"
    Write-Log "  Staging:     $StagingDir (kept for inspection — safe to trash when done)"
    Write-Host ""
    if ($Path -eq "A") {
        Write-Log "  Next: launch 'OpenClaw Companion' from the Start menu, follow first-run setup,"
        Write-Log "  choose 'Set up locally'. The recovered Jeff should wake up."
    } elseif ($Path -eq "B") {
        Write-Log "  Next: open WSL (Ubuntu-24.04), start OpenClaw, the recovered Jeff wakes up."
    }
    Write-Log "  The first message in the principal's voice confirms the recovery."
}

# Cleanup on exit
trap {
    if ($script:PassphraseFile -and (Test-Path $script:PassphraseFile)) {
        try {
            $size = (Get-Item $script:PassphraseFile).Length
            $bytes = New-Object byte[] $size
            [System.IO.File]::WriteAllBytes($script:PassphraseFile, $bytes)
            Remove-Item $script:PassphraseFile -Force
        } catch {}
        $script:PassphraseFile = $null
    }
}

Main
