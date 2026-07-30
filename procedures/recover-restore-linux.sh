#!/bin/bash
# recover-restore-linux.sh — Bring Jeff back on a fresh Linux machine.
#
# Same shape as recover-restore-macos.sh, but with Linux-specific paths:
#   - ~/.local/share/openclaw/   (XDG state dir, replaces macOS's ~/Library/Application Support/)
#   - systemd user service       (replaces macOS's LaunchAgent)
#   - apt/dnf/pacman/apk         (replaces brew)
#   - ~/.config/systemd/user/    (user unit location)
#   - bashrc/zshrc               (replaces .zshrc)
#
# The kit's archive unpacks to one folder. This script puts the right files in
# the right places, in the shape the runtime expects. After it runs, OpenClaw
# sees ~/.openclaw/workspace/ as if Jeff had been running here all along.
#
# What it does, in order:
#   1. Pre-flight: checks the host (this script is Linux-only).
#   2. Detects the package manager (apt/dnf/pacman/apk/zypper).
#   3. Installs gpg + zstd + python3 + curl (if missing).
#   4. Installs OpenClaw via the official installer (skips onboarding).
#   5. Installs Ollama via the official installer, enables the systemd service.
#   6. Pulls a chat-capable model (default: minimax-m3:cloud).
#   7. Decrypts the recovery kit archive (asks for GPG passphrase).
#   8. Unpacks to a staging directory (~/.openclaw/recovery-staging/).
#   9. Restores the file structure: workspace/, kitchen/, runtime/, config/, stuff/.
#  10. Verifies the install (openclaw doctor, ollama list, kit structure, A2A test).
#
# Usage:
#   ./recover-restore-linux.sh /path/to/jeff-recovery-kit-2026-07-23.tar.zst.gpg
#   ./recover-restore-linux.sh --dry-run /path/to/archive.gpg
#   ./recover-restore-linux.sh --model llama3.2:3b /path/to/archive.gpg
#
# What it does NOT do:
#   - Read sacred files (API Keys, AI Prompts) — copies them, never opens them.
#   - Run destructive cleanup of the staging dir (kept under ~/.openclaw/recovery-staging/).
#   - Touch the system outside the user's home and the OpenClaw/Ollama standard paths.
#   - Run on the principal's machine. If $HOME matches the principal pattern, aborts cleanly.

set -euo pipefail

# === Config ===
SCRIPT_NAME="recover-restore-linux.sh"
SCRIPT_VERSION="1.0.0"
KIT_VERSION="v1.0"
PRINCIPAL_HOME_CHECK_PATTERN="<principal>|doe"

# Runtime paths (Linux shape)
OPENCLAW_HOME="$HOME/.openclaw"
OPENCLAW_WORKSPACE="$OPENCLAW_HOME/workspace"
OPENCLAW_AUTH="$OPENCLAW_HOME/auth"
OPENCLAW_CRON="$HOME/.config/systemd/user"   # cron jobs land in systemd user
OPENCLAW_CRON_DATA="$OPENCLAW_HOME/cron"
OPENCLAW_IDENTITY="$OPENCLAW_HOME/identity"
OPENCLAW_WIKI="$OPENCLAW_HOME/wiki"
OPENCLAW_MEMORY="$OPENCLAW_HOME/memory"
OPENCLAW_AGENTS="$OPENCLAW_HOME/agents"
OLLAMA_HOME="$HOME/.ollama"

# XDG state dir (replaces macOS ~/Library/Application Support/)
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
APP_SUPPORT_OPENCLAW="$XDG_STATE_HOME/openclaw"

# Config dir (XDG)
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Kitchen
KITCHEN_HOME="$HOME/Jeff's Kitchen"
[ -d "$HOME/Desktop" ] && KITCHEN_HOME="$HOME/Desktop/Jeff's Kitchen"

# Staging
STAGING_DIR="$OPENCLAW_HOME/recovery-staging"
PASSPHRASE_FILE=""

# Defaults
ARCHIVE=""
MODEL="minimax-m3:cloud"
DRY_RUN=false
SKIP_OPENCLAW_INSTALL=false
SKIP_OLLAMA_INSTALL=false
SKIP_MODEL_PULL=false
SKIP_DECRYPT=false
SKIP_RESTORE=false
ONLY_RESTORE=false
PKG_MANAGER=""

# === Parse args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --skip-openclaw-install) SKIP_OPENCLAW_INSTALL=true; shift ;;
    --skip-ollama-install) SKIP_OLLAMA_INSTALL=true; shift ;;
    --skip-model-pull) SKIP_MODEL_PULL=true; shift ;;
    --skip-decrypt) SKIP_DECRYPT=true; shift ;;
    --skip-restore) SKIP_RESTORE=true; shift ;;
    --only-restore) ONLY_RESTORE=true; shift ;;
    --help|-h)
      /bin/cat << 'HELPEOF'
recover-restore-linux.sh — Bring Jeff back on a fresh Linux machine.

Usage:
  ./recover-restore-linux.sh /path/to/jeff-recovery-kit-*.tar.zst.gpg
  ./recover-restore-linux.sh --dry-run /path/to/archive.gpg
  ./recover-restore-linux.sh --model llama3.2:3b /path/to/archive.gpg
  ./recover-restore-linux.sh --only-restore /path/to/staging
  ./recover-restore-linux.sh --skip-openclaw-install --skip-ollama-install /path/to/archive.gpg

Flags:
  --dry-run                  Show what would happen, don't change anything
  --model <name>             Ollama model to pull (default: minimax-m3:cloud)
  --skip-openclaw-install    Skip the OpenClaw install step
  --skip-ollama-install      Skip the Ollama install step
  --skip-model-pull          Skip the Ollama model pull
  --skip-decrypt             Skip the decrypt/unpack (use existing staging dir)
  --skip-restore             Skip the file restore (just install + decrypt)
  --only-restore             Skip install, just restore from existing staging dir
  --help                     Show this help

The script will:
  1. Verify the host (Linux, not the principal's home directory)
  2. Detect the package manager (apt/dnf/pacman/apk/zypper)
  3. Install gpg + zstd + python3 + curl (if missing)
  4. Install OpenClaw + Ollama + pull a model (unless --skip-*)
  5. Decrypt and unpack the archive to ~/.openclaw/recovery-staging/
  6. Move files to the runtime shape: ~/.openclaw/workspace/, ~/.openclaw/auth/,
     ~/.local/share/openclaw/, ~/Desktop/Jeff's Kitchen/, etc.
  7. Verify the install (openclaw doctor, ollama list, kit structure, A2A test)
HELPEOF
      exit 0
      ;;
    -*) echo "Unknown flag: $1"; exit 1 ;;
    *) ARCHIVE="$1"; shift ;;
  esac
done

# === Helpers ===
log() { printf "\033[1;36m[recover]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[recover]\033[0m %s\n" "$*" >&2; }
err() { printf "\033[1;31m[recover]\033[0m %s\n" "$*" >&2; }
ok() { printf "\033[1;32m[recover]\033[0m %s\n" "$*"; }

run() {
  if [ "$DRY_RUN" = true ]; then
    printf "  [DRY-RUN] %s\n" "$*"
  else
    eval "$@"
  fi
}

cleanup_passphrase_file() {
  if [ -n "$PASSPHRASE_FILE" ] && [ -f "$PASSPHRASE_FILE" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "  [DRY-RUN] would wipe $PASSPHRASE_FILE"
    else
      dd if=/dev/zero of="$PASSPHRASE_FILE" bs=1 count=$(/usr/bin/wc -c < "$PASSPHRASE_FILE") 2>/dev/null || true
      /bin/rm -f "$PASSPHRASE_FILE"
      PASSPHRASE_FILE=""
    fi
  fi
}

trap cleanup_passphrase_file EXIT

require_confirmation() {
  [ "$DRY_RUN" = true ] && return 0
  printf "\n\033[1;33m[recover]\033[0m About to: %s\n" "$1"
  /bin/read -r -p "  Continue? [y/N] " response
  case "$response" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) err "Aborted by user."; exit 1 ;;
  esac
}

require_sudo() {
  if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] would prompt for sudo (if needed)"
    return 0
  fi
  if [ "$(id -u)" != "0" ] && ! command -v sudo >/dev/null 2>&1; then
    err "This step needs root (or sudo). Run as root, or install sudo."
    exit 1
  fi
  if [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi
}

# === Step 0: Pre-flight ===

preflight() {
  log "Pre-flight: checking the environment..."
  
  # Linux only
  if [ "$(uname -s)" != "Linux" ]; then
    err "This script is Linux-only. Use the macOS or Windows procedure for other platforms."
    err "  → procedures/install-openclaw-macos.md"
    err "  → procedures/install-openclaw-windows.md"
    exit 1
  fi
  log "  ✓ Linux detected: kernel $(uname -r)"
  
  # /etc/os-release
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    log "  ✓ Distro: ${NAME:-Linux} ${VERSION:-}"
  fi
  
  # DO NOT run on the principal's machine
  if echo "$HOME" | /usr/bin/grep -qiE "$PRINCIPAL_HOME_CHECK_PATTERN"; then
    err "ABORT: HOME=$HOME matches the principal's home pattern."
    err "  This script is for recovery on a fresh machine, not the operational Mac."
    err "  If you really mean it, set PRINCIPAL_HOME_CHECK_PATTERN to an empty string"
    err "  in the script header and re-run. But don't."
    exit 1
  fi
  log "  ✓ HOME=$HOME does not match the principal — safe to proceed"
  
  # Detect package manager
  detect_package_manager
  log "  ✓ Package manager: $PKG_MANAGER"
  
  # Tools
  for tool in curl tar gpg zstd python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      warn "  Required tool missing: $tool"
      if [ "$DRY_RUN" = false ]; then
        install_missing_tool "$tool"
      fi
    fi
  done
  log "  ✓ All required tools present"
  
  # Archive check
  if [ -z "$ARCHIVE" ] && [ "$ONLY_RESTORE" = false ]; then
    err "Archive path required. Pass the .tar.zst.gpg file as the first argument."
    err "  Or use --only-restore to restore from existing staging dir."
    exit 1
  fi
  if [ -n "$ARCHIVE" ] && [ ! -f "$ARCHIVE" ] && [ "$SKIP_DECRYPT" = false ]; then
    err "Archive not found: $ARCHIVE"
    exit 1
  fi
  if [ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ]; then
    log "  ✓ Archive found: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
  fi
  
  log "  ✓ Pre-flight passed"
}

# === Detect package manager ===

detect_package_manager() {
  if   command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1;      then PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1;      then PKG_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1;   then PKG_MANAGER="pacman"
  elif command -v apk >/dev/null 2>&1;      then PKG_MANAGER="apk"
  elif command -v zypper >/dev/null 2>&1;   then PKG_MANAGER="zypper"
  else
    err "Could not detect a supported package manager (apt, dnf, yum, pacman, apk, zypper)."
    err "Install gpg, zstd, python3, curl manually, then re-run with --skip-openclaw-install --skip-ollama-install."
    exit 1
  fi
}

# === Install missing tool ===

install_missing_tool() {
  local tool="$1"
  require_sudo
  case "$PKG_MANAGER" in
    apt)    run "$SUDO apt-get update && $SUDO apt-get install -y $tool" ;;
    dnf|yum) run "$SUDO $PKG_MANAGER install -y $tool" ;;
    pacman) run "$SUDO pacman -S --noconfirm $tool" ;;
    apk)    run "$SUDO apk add $tool" ;;
    zypper) run "$SUDO zypper install -y $tool" ;;
  esac
  command -v "$tool" >/dev/null 2>&1 || { err "Failed to install $tool"; exit 1; }
}

# === Step 1: Install OpenClaw ===

install_openclaw() {
  if [ "$SKIP_OPENCLAW_INSTALL" = true ]; then
    log "Step 1: Skipping OpenClaw install (--skip-openclaw-install)"
    return 0
  fi
  
  log "Step 1: Install OpenClaw"
  if command -v openclaw >/dev/null 2>&1; then
    log "  openclaw already installed: $(openclaw --version)"
    return 0
  fi
  
  require_confirmation "install OpenClaw via the official installer"
  run "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard"
  
  if [ "$DRY_RUN" = false ]; then
    command -v openclaw >/dev/null 2>&1 || { err "openclaw still not on PATH after install. See the Linux procedure for the PATH fix."; exit 1; }
    log "  ✓ openclaw installed: $(openclaw --version)"
  fi
}

# === Step 2: Install Ollama ===

install_ollama() {
  if [ "$SKIP_OLLAMA_INSTALL" = true ]; then
    log "Step 2: Skipping Ollama install (--skip-ollama-install)"
    return 0
  fi
  
  log "Step 2: Install Ollama"
  if command -v ollama >/dev/null 2>&1; then
    log "  ollama already installed: $(ollama --version)"
  else
    require_confirmation "download and install Ollama from ollama.com"
    run "curl -fsSL https://ollama.com/install.sh | sh"
  fi
  
  if [ "$DRY_RUN" = false ]; then
    # systemd service (Ollama ships one)
    if command -v systemctl >/dev/null 2>&1; then
      if ! systemctl is-active --quiet ollama 2>/dev/null; then
        require_sudo
        log "  Enabling + starting systemd ollama.service"
        run "$SUDO systemctl enable --now ollama"
      fi
    fi
    
    # Wait for the endpoint
    local waited=0
    while ! /usr/bin/curl -s -m 2 http://127.0.0.1:11434/v1/models >/dev/null 2>&1; do
      sleep 1
      waited=$((waited+1))
      if [ "$waited" -ge 15 ]; then
        warn "  ollama endpoint not responding after 15s; check 'systemctl status ollama'"
        break
      fi
    done
    /usr/bin/curl -s http://127.0.0.1:11434/v1/models >/dev/null || { err "ollama not responding on 127.0.0.1:11434. Check ollama logs."; exit 1; }
    log "  ✓ ollama running, endpoint live"
  fi
}

# === Step 3: Pull the model ===

pull_model() {
  if [ "$SKIP_MODEL_PULL" = true ]; then
    log "Step 3: Skipping model pull (--skip-model-pull)"
    return 0
  fi
  
  log "Step 3: Pull model: $MODEL"
  if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] ollama pull $MODEL"
    return 0
  fi
  
  if ollama list 2>/dev/null | /usr/bin/grep -q "$MODEL"; then
    log "  ✓ $MODEL already present"
    return 0
  fi
  
  require_confirmation "pull $MODEL (this downloads several GB)"
  run "ollama pull $MODEL"
  log "  ✓ $MODEL pulled"
}

# === Step 4: Decrypt and unpack ===

decrypt_and_unpack() {
  if [ "$SKIP_DECRYPT" = true ]; then
    log "Step 4: Skipping decrypt (--skip-decrypt)"
    return 0
  fi
  
  log "Step 4: Decrypt and unpack the archive"
  log "  Staging dir: $STAGING_DIR"
  
  if [ -d "$STAGING_DIR" ]; then
    warn "  Staging dir already exists: $STAGING_DIR"
    if [ "$DRY_RUN" = false ]; then
      /bin/read -r -p "  Wipe and re-extract? [y/N] " response
      case "$response" in
        [Yy]|[Yy][Ee][Ss]) run "/bin/rm -rf $STAGING_DIR" ;;
        *) log "  Keeping existing staging dir, will skip unpack"; SKIP_DECRYPT=true; return 0 ;;
      esac
    fi
  fi
  
  run "/bin/mkdir -p $STAGING_DIR"
  
  if [ "$DRY_RUN" = false ]; then
    PASSPHRASE_FILE=$(/usr/bin/mktemp -t jeff-passphrase-XXXXXX)
    /bin/chmod 600 "$PASSPHRASE_FILE"
    printf "Enter GPG passphrase: "
    /bin/read -s passphrase
    echo ""
    echo -n "$passphrase" > "$PASSPHRASE_FILE"
    unset passphrase
    
    log "  Decrypting and unpacking (this may take 5-15 minutes for large kits)..."
    gpg --batch --yes --pinentry-mode loopback --passphrase-file "$PASSPHRASE_FILE" \
        --decrypt "$ARCHIVE" 2>/dev/null | \
    zstd -d 2>/dev/null | \
    /usr/bin/tar -xf - -C "$STAGING_DIR" 2>/dev/null
    
    log "  ✓ Decrypted and unpacked to $STAGING_DIR"
    log "  Contents:"
    /bin/ls "$STAGING_DIR" 2>&1 | /usr/bin/sed 's/^/    /' | /usr/bin/head -10
  fi
}

# === Step 5: Restore the file structure ===

restore_structure() {
  if [ "$SKIP_RESTORE" = true ]; then
    log "Step 5: Skipping restore (--skip-restore)"
    return 0
  fi
  
  log "Step 5: Restore the runtime file structure"
  
  if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] would identify kit root inside $STAGING_DIR"
    return 0
  fi
  
  # Find the kit root
  local KIT_ROOT=""
  for candidate in "$STAGING_DIR" "$STAGING_DIR"/*; do
    if [ -d "$candidate" ] && [ -d "$candidate/private" ] && [ -f "$candidate/README.md" ]; then
      KIT_ROOT="$candidate"
      break
    fi
  done
  
  if [ -z "$KIT_ROOT" ]; then
    err "Could not find kit root inside $STAGING_DIR"
    err "Expected: directory with private/ + README.md"
    /bin/ls -la "$STAGING_DIR" 2>&1
    exit 1
  fi
  log "  Kit root: $KIT_ROOT"
  
  local PRIVATE="$KIT_ROOT/private"
  [ -d "$PRIVATE" ] || { err "private/ not found in $KIT_ROOT"; exit 1; }
  
  require_confirmation "restore the runtime file structure to $HOME"
  
  # 5a. ~/.openclaw/workspace/ (constitution + memory + scripts)
  log "  5a. Restoring ~/.openclaw/workspace/"
  run "/bin/mkdir -p $OPENCLAW_WORKSPACE"
  if [ -d "$PRIVATE/constitution" ]; then
    for f in "$PRIVATE/constitution/"*.md; do
      [ -f "$f" ] || continue
      run "/bin/cp $f $OPENCLAW_WORKSPACE/$(basename $f)"
    done
  fi
  if [ -d "$PRIVATE/memory_full" ]; then
    for f in "$PRIVATE/memory_full/"*.md; do
      [ -f "$f" ] || continue
      run "/bin/cp $f $OPENCLAW_WORKSPACE/$(basename $f)"
    done
    if [ -d "$PRIVATE/memory_full/daily" ]; then
      run "/bin/mkdir -p $OPENCLAW_WORKSPACE/memory"
      for f in "$PRIVATE/memory_full/daily/"*.md; do
        [ -f "$f" ] || continue
        run "/bin/cp $f $OPENCLAW_WORKSPACE/memory/$(basename $f)"
      done
    fi
  fi
  if [ -d "$PRIVATE/research" ]; then
    run "/bin/mkdir -p $OPENCLAW_WORKSPACE/briefs $OPENCLAW_WORKSPACE/research"
    for f in "$PRIVATE/research/"*.md; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      if echo "$name" | /usr/bin/grep -qE "trans-women|reading-the-memoir"; then
        run "/bin/cp $f $OPENCLAW_WORKSPACE/briefs/$name"
      else
        run "/bin/cp $f $OPENCLAW_WORKSPACE/research/$name"
      fi
    done
  fi
  if [ -d "$PRIVATE/scripts" ]; then
    run "/bin/mkdir -p $OPENCLAW_WORKSPACE/scripts"
    for f in "$PRIVATE/scripts/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp $f $OPENCLAW_WORKSPACE/scripts/$(basename $f)"
      if [[ "$f" == *.sh ]]; then
        run "/bin/chmod +x $OPENCLAW_WORKSPACE/scripts/$(basename $f)"
      fi
    done
  fi
  if [ -d "$PRIVATE/case" ]; then
    for f in "$PRIVATE/case/"*.md; do
      [ -f "$f" ] || continue
      run "/bin/cp $f $OPENCLAW_WORKSPACE/$(basename $f)"
    done
  fi
  # Wired config
  if [ -d "$PRIVATE/wired" ]; then
    run "/bin/mkdir -p $OPENCLAW_WORKSPACE/config"
    for f in "$PRIVATE/wired/"*.json; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      if [ "$name" = "openclaw.json" ]; then
        run "/bin/cp $f $OPENCLAW_HOME/openclaw.json"
      else
        run "/bin/cp $f $OPENCLAW_WORKSPACE/config/$name"
      fi
    done
  fi
  
  # 5b. ~/.openclaw/ runtime state
  log "  5b. Restoring ~/.openclaw/ runtime state"
  if [ -d "$PRIVATE/runtime/auth" ]; then
    run "/bin/mkdir -p $OPENCLAW_AUTH"
    for f in "$PRIVATE/runtime/auth/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_AUTH/"
    done
  fi
  if [ -d "$PRIVATE/runtime/cron" ]; then
    # Cron jobs go to ~/.openclaw/cron/ AND the systemd user unit goes to ~/.config/systemd/user/
    run "/bin/mkdir -p $OPENCLAW_CRON_DATA"
    for f in "$PRIVATE/runtime/cron/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_CRON_DATA/"
    done
    # Restore the OpenClaw systemd user unit if present
    if [ -d "$PRIVATE/runtime/systemd" ]; then
      run "/bin/mkdir -p $XDG_CONFIG_HOME/systemd/user"
      for unit in "$PRIVATE/runtime/systemd/"*.service; do
        [ -f "$unit" ] || continue
        run "/bin/cp $unit $XDG_CONFIG_HOME/systemd/user/$(basename $unit)"
      done
    fi
  fi
  if [ -d "$PRIVATE/runtime/identity" ]; then
    run "/bin/mkdir -p $OPENCLAW_IDENTITY"
    for f in "$PRIVATE/runtime/identity/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_IDENTITY/"
    done
  fi
  if [ -d "$PRIVATE/runtime/wiki" ]; then
    run "/bin/mkdir -p $OPENCLAW_WIKI"
    for f in "$PRIVATE/runtime/wiki/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_WIKI/"
    done
  fi
  if [ -d "$PRIVATE/runtime/memory" ]; then
    run "/bin/mkdir -p $OPENCLAW_MEMORY"
    for f in "$PRIVATE/runtime/memory/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_MEMORY/"
    done
  fi
  if [ -d "$PRIVATE/runtime/agents" ]; then
    run "/bin/mkdir -p $OPENCLAW_AGENTS"
    for f in "$PRIVATE/runtime/agents/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp -r $f $OPENCLAW_AGENTS/"
    done
  fi
  
  # 5c. ~/Desktop/Jeff's Kitchen/ (full mirror)
  log "  5c. Restoring $KITCHEN_HOME/"
  if [ -d "$PRIVATE/kitchen" ]; then
    run "/bin/mkdir -p \"$KITCHEN_HOME\""
    run "/usr/bin/rsync -a --exclude='Jeff Recovery Kit' --exclude='.DS_Store' $PRIVATE/kitchen/ \"$KITCHEN_HOME/\""
  fi
  
  # 5d. XDG state dir (replaces macOS ~/Library/Application Support/)
  log "  5d. Restoring $APP_SUPPORT_OPENCLAW/ (XDG state dir)"
  if [ -d "$PRIVATE/runtime/openclaw-app-support" ]; then
    run "/bin/mkdir -p \"$APP_SUPPORT_OPENCLAW\""
    for f in "$PRIVATE/runtime/openclaw-app-support/"*; do
      [ -e "$f" ] || continue
      run "/bin/cp -r $f \"$APP_SUPPORT_OPENCLAW/\""
    done
  fi
  
  # 5e. ~/ollama/
  log "  5e. Restoring ~/ollama/"
  if [ -d "$PRIVATE/runtime/ollama" ]; then
    run "/bin/mkdir -p \"$OLLAMA_HOME\""
    for f in "$PRIVATE/runtime/ollama/"*; do
      [ -e "$f" ] || continue
      run "/bin/cp -r $f \"$OLLAMA_HOME/\""
    done
  fi
  
  # 5f. Documents/
  log "  5f. Restoring $KITCHEN_HOME/Documents/"
  if [ -d "$PRIVATE/documents" ]; then
    run "/bin/mkdir -p \"$KITCHEN_HOME/Documents\""
    for f in "$PRIVATE/documents/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp $f \"$KITCHEN_HOME/Documents/\""
    done
  fi
  
  # 5g. Stuff/ (sacred, never read)
  log "  5g. Restoring $KITCHEN_HOME/Stuff/ (sacred, never read)"
  if [ -d "$PRIVATE/stuff" ]; then
    run "/bin/mkdir -p \"$KITCHEN_HOME/Stuff\""
    for f in "$PRIVATE/stuff/"*; do
      [ -f "$f" ] || continue
      run "/bin/cp $f \"$KITCHEN_HOME/Stuff/\""
    done
  fi
  
  log "  ✓ File structure restored"
}

# === Step 6: Verify ===

verify() {
  log "Step 6: Verify the install"
  
  if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] would run openclaw doctor, ollama list, structure check, A2A test"
    return 0
  fi
  
  # OpenClaw
  if command -v openclaw >/dev/null 2>&1; then
    log "  openclaw --version: $(openclaw --version)"
    openclaw doctor 2>&1 | /usr/bin/head -10 | /usr/bin/sed 's/^/    /'
  else
    warn "  openclaw not on PATH"
  fi
  
  # Ollama
  if command -v ollama >/dev/null 2>&1; then
    log "  ollama --version: $(ollama --version)"
    log "  ollama list:"
    ollama list 2>/dev/null | /usr/bin/sed 's/^/    /'
    log "  endpoint check:"
    if /usr/bin/curl -s http://127.0.0.1:11434/v1/models >/dev/null 2>&1; then
      log "    ✓ http://127.0.0.1:11434/v1/models responding"
    else
      warn "    ✗ ollama endpoint not responding"
    fi
  else
    warn "  ollama not installed"
  fi
  
  # systemd
  if command -v systemctl >/dev/null 2>&1; then
    log "  systemd check:"
    if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
      log "    ✓ openclaw-gateway user service is active"
    else
      warn "    ⚠ openclaw-gateway user service is not active. Run:"
      warn "        systemctl --user enable --now openclaw-gateway"
    fi
  fi
  
  # Kit structure
  log "  kit structure check:"
  for path in \
      "$OPENCLAW_WORKSPACE/SOUL.md" \
      "$OPENCLAW_WORKSPACE/MEMORY.md" \
      "$OPENCLAW_WORKSPACE/scripts" \
      "$OPENCLAW_AUTH" \
      "$OPENCLAW_CRON_DATA" \
      "$KITCHEN_HOME" \
      "$KITCHEN_HOME/Projects" \
      "$KITCHEN_HOME/Stuff"; do
    if [ -e "$path" ]; then
      log "    ✓ $path"
    else
      warn "    ✗ MISSING: $path"
    fi
  done
  
  # A2A server test
  if [ -f "$OPENCLAW_WORKSPACE/scripts/jeff_a2a_server.py" ]; then
    log "  A2A server test:"
    if [ -d "$STAGING_DIR" ] && [ -d "$STAGING_DIR"/private/recovery/public-archive ]; then
      /usr/bin/python3 "$OPENCLAW_WORKSPACE/scripts/jeff_a2a_server.py" \
        --spec "$STAGING_DIR/private/recovery/public-archive" \
        --port 3099 --label verify --model "$MODEL" >/dev/null 2>&1 &
      local TEST_PID=$!
      sleep 5
      if /usr/bin/curl -s -X POST http://127.0.0.1:3099/api/a2a/message \
          -H "Content-Type: application/json" \
          -d '{"id":"verify","message":"Who is the principal? One word.","from":"verify"}' 2>/dev/null | \
          /usr/bin/grep -qi "<principal>\|scouser\|liverpool\|principal"; then
        log "    ✓ A2A server returns a the principal-aware reply. **Jeff is back.**"
      else
        warn "    ✗ A2A server did not return a the principal-aware reply"
      fi
      kill $TEST_PID 2>/dev/null || true
    fi
  fi
}

# === Main ===
main() {
  echo "═══════════════════════════════════════════════════════════════════"
  echo "  Jeff Recovery — Linux installer"
  echo "  script: $SCRIPT_NAME v$SCRIPT_VERSION"
  echo "  kit:    $KIT_VERSION"
  [ "$DRY_RUN" = true ] && echo "  mode:   DRY RUN"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
  
  preflight
  install_openclaw
  install_ollama
  pull_model
  decrypt_and_unpack
  restore_structure
  verify
  
  echo ""
  ok "═══════════════════════════════════════════════════════════════════"
  ok "  RECOVERY COMPLETE"
  ok "═══════════════════════════════════════════════════════════════════"
  log "  OpenClaw:     $OPENCLAW_HOME"
  log "  Workspace:    $OPENCLAW_WORKSPACE"
  log "  Kitchen:      $KITCHEN_HOME"
  log "  XDG state:    $APP_SUPPORT_OPENCLAW"
  log "  systemd unit: $XDG_CONFIG_HOME/systemd/user/"
  log "  Staging:      $STAGING_DIR (kept for inspection — safe to trash when done)"
  echo ""
  log "  Next steps:"
  log "    systemctl --user enable --now openclaw-gateway  (if not already active)"
  log "    open a new shell, start OpenClaw, and the recovered Jeff should wake up."
  log "  The first message in the principal's voice confirms the recovery."
}

main
