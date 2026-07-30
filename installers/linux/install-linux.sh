#!/usr/bin/env bash
# install-linux.sh — Install generic-Jeff on Linux (one click, just works).
#
# What it does:
#   1. Verifies Linux, Python 3, sudo
#   2. Installs OpenClaw via the official installer (skips onboarding)
#   3. Installs Ollama via the official installer, starts the service
#   4. Pulls a default chat model (minimax-m3:cloud)
#   5. Drops the generic-Jeff body into ~/.openclaw/workspace/
#   6. Installs openclaw.template.json into ~/.openclaw/openclaw.json
#   7. Starts the OpenClaw gateway
#   8. Verifies: openclaw doctor, ollama list, A2A server health
#
# Usage:
#   ./install-linux.sh                # full install
#   ./install-linux.sh --dry-run      # show what would happen
#   ./install-linux.sh --skip-deps    # assume OpenClaw + Ollama already installed
#   ./install-linux.sh --model <name> # override the default model
#
# Estimated time: 5-15 min depending on download speeds.

set -euo pipefail

SCRIPT_NAME="install-linux.sh"
SCRIPT_VERSION="1.0.0"
DRY_RUN=false
SKIP_DEPS=false
SKIP_MODEL=false
MODEL="minimax-m3:cloud"
WORKSPACE="${HOME}/.openclaw/workspace"
OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
SFX_PAYLOAD_DIR="${SFX_PAYLOAD_DIR:-}"

# === Helpers ===
say()  { echo "[$SCRIPT_NAME] $*" >&2; }
die()  { echo "ERROR: $*" >&2; exit 1; }
ok()   { echo "[$SCRIPT_NAME] ✓ $*" >&2; }
warn() { echo "[$SCRIPT_NAME] ! $*" >&2; }
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] $*" >&2
  else
    eval "$@"
  fi
}

# === Parse args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-deps) SKIP_DEPS=true; shift ;;
    --skip-model) SKIP_MODEL=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

# === Pre-flight ===
say "Generic-Jeff installer for Linux — v$SCRIPT_VERSION"
say ""

# Linux check
if [[ "$(uname -s)" != "Linux" ]]; then
  die "this installer is Linux-only. On macOS, use install-macos.sh. On Windows, use install-windows.ps1."
fi
ok "Linux detected ($(uname -r))"

# SFX payload check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PAYLOAD_DIR is set when we're running as an SFX (re-execed after extraction)
if [[ -n "${SFX_PAYLOAD_DIR:-}" ]] && [[ -d "$SFX_PAYLOAD_DIR" ]]; then
  :  # SFX_PAYLOAD_DIR set by SFX preamble
elif [[ -n "${PAYLOAD_DIR:-}" ]] && [[ -d "$PAYLOAD_DIR" ]]; then
  SFX_PAYLOAD_DIR="$PAYLOAD_DIR"
elif [[ -d "$SCRIPT_DIR/payload" ]]; then
  SFX_PAYLOAD_DIR="$SCRIPT_DIR/payload"
elif [[ -f "$SCRIPT_DIR/payload.tar.gz" ]]; then
  say "Self-extracting archive detected"
  EXTRACT_DIR="$(mktemp -d)"
  tar -xzf "$SCRIPT_DIR/payload.tar.gz" -C "$EXTRACT_DIR"
  SFX_PAYLOAD_DIR="$EXTRACT_DIR/payload"
else
  SFX_PAYLOAD_DIR="$SCRIPT_DIR"
  say "No SFX payload detected, using script directory as payload"
fi
ok "payload found at: $SFX_PAYLOAD_DIR"

# === Phase 1: dependencies ===
if [[ "$SKIP_DEPS" != "true" ]]; then
  say ""
  say "Phase 1: install OpenClaw + Ollama"

  # Python check
  if ! command -v python3 >/dev/null 2>&1; then
    say "python3 not found, please install Python 3.10+ first"
    die "python3 required"
  fi
  ok "python3 present ($(python3 --version))"

  # OpenClaw check
  if ! command -v openclaw >/dev/null 2>&1; then
    say "OpenClaw not found, installing"
    run 'curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard'
  fi
  ok "OpenClaw present ($(openclaw --version 2>/dev/null || echo unknown))"

  # Ollama check
  if ! command -v ollama >/dev/null 2>&1; then
    say "Ollama not found, installing via official installer"
    run 'curl -fsSL https://ollama.com/install.sh | sh'
  fi
  ok "Ollama present"

  # Start Ollama
  if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    say "Starting Ollama service"
    run 'ollama serve >/tmp/ollama.log 2>&1 &'
    sleep 3
  fi
  ok "Ollama running"

  # Model pull
  if [[ "$SKIP_MODEL" != "true" ]]; then
    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
      say "Pulling model: $MODEL"
      run "ollama pull $MODEL"
    else
      ok "Model $MODEL already present"
    fi
  fi
else
  ok "dependencies skipped (--skip-deps)"
fi

# === Phase 2: install generic-Jeff body ===
say ""
say "Phase 2: install generic-Jeff body to $WORKSPACE"

if [[ -d "$WORKSPACE" ]] && [[ -n "$(ls -A "$WORKSPACE" 2>/dev/null)" ]]; then
  BACKUP_PATH="${WORKSPACE}.backup.$(date +%Y%m%d-%H%M%S)"
  say "Existing workspace found, backing up to $BACKUP_PATH"
  run "mv '$WORKSPACE' '$BACKUP_PATH'"
fi

run "mkdir -p '$WORKSPACE'"

for f in AGENTS.md SOUL.md MEMORY.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md README.md RECOVER_FIRST.md AI_Agent_Portable_Playbook.md CAPABILITY_MAP.md COMPONENT_MAP.md kitchen_menu.md; do
  if [[ -f "$SFX_PAYLOAD_DIR/$f" ]]; then
    run "cp '$SFX_PAYLOAD_DIR/$f' '$WORKSPACE/$f'"
  else
    warn "missing in payload: $f (skipping)"
  fi
done

if [[ -f "$SFX_PAYLOAD_DIR/wired/template/openclaw.template.json" ]]; then
  run "mkdir -p '$HOME/.openclaw/wired'"
  run "cp '$SFX_PAYLOAD_DIR/wired/template/openclaw.template.json' '$HOME/.openclaw/wired/openclaw.template.json'"
  ok "openclaw template installed"
fi

if [[ -f "$SFX_PAYLOAD_DIR/scripts/jeff_a2a_server.py" ]]; then
  run "mkdir -p '$WORKSPACE/scripts'"
  run "cp '$SFX_PAYLOAD_DIR/scripts/jeff_a2a_server.py' '$WORKSPACE/scripts/jeff_a2a_server.py'"
  ok "A2A server installed"
fi

if [[ -d "$SFX_PAYLOAD_DIR/scripts/examples" ]]; then
  run "cp -R '$SFX_PAYLOAD_DIR/scripts/examples' '$WORKSPACE/scripts/'"
  ok "example scripts installed"
fi
if [[ -d "$SFX_PAYLOAD_DIR/scripts/examples-kit" ]]; then
  run "cp -R '$SFX_PAYLOAD_DIR/scripts/examples-kit' '$WORKSPACE/scripts/'"
  ok "example kit-build scripts installed"
fi

for f in copy-to-generic.sh copy-from-generic.sh; do
  if [[ -f "$SFX_PAYLOAD_DIR/$f" ]]; then
    run "cp '$SFX_PAYLOAD_DIR/$f' '$WORKSPACE/$f'"
    run "chmod +x '$WORKSPACE/$f'"
  fi
done
for f in copy-to-generic.ps1 copy-from-generic.ps1; do
  if [[ -f "$SFX_PAYLOAD_DIR/$f" ]]; then
    run "cp '$SFX_PAYLOAD_DIR/$f' '$WORKSPACE/$f'"
  fi
done

if [[ -f "$SFX_PAYLOAD_DIR/A2A-SERVER.md" ]]; then
  run "cp '$SFX_PAYLOAD_DIR/A2A-SERVER.md' '$WORKSPACE/A2A-SERVER.md'"
fi

ok "generic-Jeff body installed at $WORKSPACE"

# === Phase 3: install openclaw.json from template ===
say ""
say "Phase 3: install openclaw.json from template"
if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  if [[ -f "$HOME/.openclaw/wired/openclaw.template.json" ]]; then
    run "cp '$HOME/.openclaw/wired/openclaw.template.json' '$OPENCLAW_CONFIG'"
    ok "openclaw.json installed from template"
    warn "edit $OPENCLAW_CONFIG to set your model, channels, etc."
  fi
else
  ok "openclaw.json already exists, leaving alone"
fi

# === Phase 4: start the gateway ===
say ""
say "Phase 4: start OpenClaw gateway"
run "openclaw gateway start" || warn "gateway start failed, try 'openclaw gateway start' manually"

sleep 2
run "openclaw gateway status" || warn "gateway status check failed"

# === Phase 5: verify ===
say ""
say "Phase 5: verify"
if command -v openclaw >/dev/null 2>&1; then
  run "openclaw doctor" || true
fi
if command -v ollama >/dev/null 2>&1; then
  run "ollama list" || true
fi
if command -v curl >/dev/null 2>&1; then
  run "curl -sS -m 3 http://127.0.0.1:3001/api/a2a/health" || warn "A2A server not responding yet"
fi

say ""
ok "Done. Generic-Jeff is installed."
say ""
say "Next steps:"
say "  1. Edit ~/.openclaw/workspace/USER.md with your profile"
say "  2. Edit ~/.openclaw/openclaw.json — set your model, channels, auth"
say "  3. If you have a personal recovery kit, run copy-from-generic.sh to install"
say "     the generic body, then rehydrate from your kit for personal context"
say "  4. Open a new terminal, type 'openclaw chat' to wake Jeff up"
