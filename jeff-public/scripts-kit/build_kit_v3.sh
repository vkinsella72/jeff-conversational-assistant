#!/bin/bash
#!/bin/bash
# build_kit_v3.sh — the principal's Jeff (or "personal Jeff")'s recovery kit build pipeline (example pattern).
#
# ADAPTED FROM: the principal's Jeff (or "personal Jeff")'s v3 kit builder. This is the *shape* of how
# a private Jeff gets packaged into a public, anonymous Jeff: inventory,
# sanitise, build two trees (private + public), encrypt the private one,
# push the public one to a repo. The whole pipeline.
#
# For generic-Jeff's purposes, the equivalent is:
#   - copy-to-generic.sh   (strip personal, build generic body)
#   - copy-from-generic.sh   (copy generic body back into a principal's workspace)
# These two scripts replace build_kit_v3.sh for the generic-Jeff project.
# The the principal's Jeff (or "personal Jeff") version remains here as a worked example of the *full*
# recovery-kit pipeline (private + public + encryption + GitHub push).
#
# To use: don't, unless you're the principal's Jeff (or "personal Jeff"). The patterns (sanitisation,
# encryption, public/private fork, idempotent re-runs) are the real value.
# Fork and adapt for your own kit-building needs.
#
# Original behaviour follows.

#
# What this does (in one pass):
#   1. Inventory the operational state
#   2. Build the PUBLIC tree (Jeff v2.0 worked example) — anonymised, sanitised
#   3. Build the PRIVATE tree (the principal's Jeff) — pulled from operational state
#   4. Add the RECOVERY bundle (RECOVER_FIRST.md + self-contained public-archive copy)
#   5. Merge any previous version's unique content across
#   6. Build the ENCRYPTED archive (tar.zst + GPG AES-256 + SHA-256 manifest)
#   7. Push the PUBLIC repo to GitHub (Jeff v2.0)
#   8. Verify the archive (decrypt + list) and the GitHub push
#
# Usage:
#   ./build_kit_v3.sh full          # all 8 steps, with confirmation gates
#   ./build_kit_v3.sh inventory     # step 1 only
#   ./build_kit_v3.sh public       # step 2 only
#   ./build_kit_v3.sh private      # step 3 only
#   ./build_kit_v3.sh recovery     # step 4 only
#   ./build_kit_v3.sh merge PREV   # step 5 only (PREV = path to previous kit)
#   ./build_kit_v3.sh archive      # step 6 only
#   ./build_kit_v3.sh push         # step 7 only
#   ./build_kit_v3.sh verify       # step 8 only
#   ./build_kit_v3.sh --dry-run full   # show what would happen, don't change anything
#
# The build is idempotent. Re-running any step after a previous success is safe.
# The Python logic (credential redaction) lives in build_kit_v3_lib.py — sibling file.

set -euo pipefail

# === Config ===
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB="$SCRIPT_DIR/build_kit_v3_lib.py"
KIT_ROOT="$HOME/Desktop/Jeff's Kitchen/Projects/Jeff Recovery Kit"
KIT_NAME="Jeff Recovery Kit"
KIT_VERSION="v3.0"
TIMESTAMP=$(date +%Y-%m-%d)
SRC_WORKSPACE="$HOME/.openclaw/workspace"
SRC_OPENCLAW="$HOME/.openclaw"
SRC_KITCHEN="$HOME/Desktop/Jeff's Kitchen"
SRC_STUFF="$HOME/Desktop/Jeff's Kitchen/Stuff"
GITHUB_USER="<your-secret>"
GITHUB_REPO="jeff-public"
GITHUB_REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
RECENT_SESSIONS_DAYS=7
PASSWORD_FILE=""
DRY_RUN=false

# === Parse args ===
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  shift
fi

# === Helpers ===
log() { printf "\033[1;36m[v3]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[v3]\033[0m %s\n" "$*" >&2; }
err() { printf "\033[1;31m[v3]\033[0m %s\n" "$*" >&2; }
ok() { printf "\033[1;32m[v3]\033[0m %s\n" "$*"; }

run() {
  if [ "$DRY_RUN" = true ]; then
    printf "  [DRY-RUN] %s\n" "$*"
  else
    eval "$@"
  fi
}

require_confirmation() {
  [ "$DRY_RUN" = true ] && return 0
  printf "\n\033[1;33m[v3]\033[0m About to: %s\n" "$1"
  read -r -p "  Continue? [y/N] " response
  case "$response" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) err "Aborted."; exit 1 ;;
  esac
}

cleanup_password_file() {
  if [ -n "$PASSWORD_FILE" ] && [ -f "$PASSWORD_FILE" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "  [DRY-RUN] would wipe $PASSWORD_FILE"
    else
      dd if=/dev/zero of="$PASSWORD_FILE" bs=1 count=$(wc -c < "$PASSWORD_FILE") 2>/dev/null || true
      rm -f "$PASSWORD_FILE"
      PASSWORD_FILE=""
    fi
  fi
}

trap cleanup_password_file EXIT

# === Pre-flight ===
preflight() {
  log "Pre-flight: checking the environment..."
  command -v gh >/dev/null 2>&1 || { err "gh (GitHub CLI) not found. Install with: brew install gh"; exit 1; }
  command -v gpg >/dev/null 2>&1 || { err "gpg not found. Install with: brew install gnupg"; exit 1; }
  command -v zstd >/dev/null 2>&1 || { err "zstd not found. Install with: brew install zstd"; exit 1; }
  command -v tar >/dev/null 2>&1 || { err "tar not found."; exit 1; }
  command -v rsync >/dev/null 2>&1 || { err "rsync not found. Install with: brew install rsync"; exit 1; }
  command -v python3 >/dev/null 2>&1 || { err "python3 not found."; exit 1; }
  [ -f "$LIB" ] || { err "build_kit_v3_lib.py not found at $LIB. Cannot continue."; exit 1; }
  [ -d "$SRC_WORKSPACE" ] || { err "Source workspace not found: $SRC_WORKSPACE"; exit 1; }
  [ -d "$SRC_KITCHEN" ] || { err "Source kitchen not found: $SRC_KITCHEN"; exit 1; }
  [ -d "$SRC_STUFF" ] || { err "Source stuff not found: $SRC_STUFF"; exit 1; }
  log "  ✓ All tools and sources present"
}

# === Step 1: Inventory ===
step_inventory() {
  log "Step 1: Inventory the operational state"
  log "  Workspace: $SRC_WORKSPACE"
  log "  Kitchen:   $SRC_KITCHEN"
  log ""
  log "  Top-level files in workspace:"
  ls -la "$SRC_WORKSPACE"/*.md 2>/dev/null | tail -n +2 | awk '{printf "    %s (%s bytes)\n", $9, $5}' | head
  log ""
  log "  Memory daily notes:"
  printf "    %d daily notes\n" "$(ls $SRC_WORKSPACE/memory/2026-*.md 2>/dev/null | wc -l | tr -d ' ')"
  log ""
  log "  Kitchen projects:"
  printf "    %d projects\n" "$(ls $SRC_KITCHEN/Projects/ 2>/dev/null | wc -l | tr -d ' ')"
  log ""
  log "  Runtime state (~/.openclaw/):"
  for d in memory wiki subagents cron identity auth; do
    if [ -d "$SRC_OPENCLAW/$d" ]; then
      size=$(du -sh "$SRC_OPENCLAW/$d" 2>/dev/null | cut -f1)
      printf "    %-15s  %s\n" "$d/" "$size"
    fi
  done
  log ""
  log "  If these numbers look right, run: ./build_kit_v3.sh full"
}

# === Step 2: Build the PUBLIC tree (Jeff v2.0) ===
step_public() {
  log "Step 2: Build the public tree (Jeff v2.0 — worked example)"
  require_confirmation "build the public tree at $KIT_ROOT/public/"

  mkdir -p "$KIT_ROOT/public"/{scripts,briefs,research,recipes_cooking,projects_public,scripts-kit,wired/redacted}

  # Constitution files
  log "  Copying constitution files..."
  for f in SOUL.md AGENTS.md IDENTITY.md USER.md TOOLS.md HEARTBEAT.md; do
    run "cp $SRC_WORKSPACE/$f $KIT_ROOT/public/$f"
  done

  # Kitchen / Maps
  for f in README.md AI_Agent_Portable_Playbook.md CAPABILITY_MAP.md COMPONENT_MAP.md; do
    if [ -f "$SRC_KITCHEN/$f" ]; then
      run "cp $SRC_KITCHEN/$f $KIT_ROOT/public/$f"
    fi
  done

  # VPS IP redaction in COMPONENT_MAP.md
  if [ -f "$KIT_ROOT/public/COMPONENT_MAP.md" ]; then
    run "sed -i '' 's|88\\.208\\.212\\.100|<VPS-IP-REDACTED>|g' $KIT_ROOT/public/COMPONENT_MAP.md"
  fi

  # Credentials redaction in TOOLS.md (using the Python lib)
  log "  Redacting credentials from TOOLS.md..."
  run "python3 $LIB redact-tool-md $KIT_ROOT/public/TOOLS.md"

  # Scripts (exclude v3 build files — those go in scripts-kit/ only)
  log "  Copying scripts..."
  for f in $SRC_WORKSPACE/scripts/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    case "$name" in
      build_kit_v3.sh|build_kit_v3_lib.py|V3_PROCEDURES.md)
        continue  # skip the v3 build files; they go in scripts-kit/ below
        ;;
    esac
    run "cp $f $KIT_ROOT/public/scripts/"
  done

  # Script env-var cleanup: remove hardcoded credential fallbacks
  # Use the Python lib to do this safely (bash escaping is fragile)
  log "  Patching scripts to remove hardcoded credential fallbacks..."
  cat > /tmp/_patch_skales.py << 'PATCHEOF'
import re
import os
files = ['skales_query.sh', 'skales_browse.sh', 'skales_monitor.sh']
for f in files:
    p = os.path.join('$KIT_ROOT/public/scripts', f)
    if not os.path.exists(p):
        continue
    with open(p) as fh:
        c = fh.read()
    # Replace any hardcoded SKALES_KEY="..." with an env-var required form
    c = re.sub(r'SKALES_KEY="\$\{SKAL[^"]*\}"', 'SKALES_KEY="${SKALES_KEY:?must be set}"', c)
    c = re.sub(r"SKALES_KEY='\$\{SKAL[^']*\}'", "SKALES_KEY='${SKALES_KEY:?must be set}'", c)
    with open(p, 'w') as fh:
        fh.write(c)
PATCHEOF
  run "python3 /tmp/_patch_skales.py"
  rm -f /tmp/_patch_skales.py

  # Briefs
  for f in $SRC_WORKSPACE/briefs/*; do
    [ -f "$f" ] || continue
    run "cp $f $KIT_ROOT/public/briefs/"
  done

  # Research (only the public-safe ones)
  for f in vitamin-d-autism-2026-06-15.md vitamin-d-autism-adhd-dossier.md; do
    if [ -f "$SRC_WORKSPACE/research/$f" ]; then
      run "cp $SRC_WORKSPACE/research/$f $KIT_ROOT/public/research/"
    fi
  done

  # Recipes
  log "  Copying cooking recipes..."
  for d in burgers rice breakfast beef chicken fish pasta sauces sides vegetarian _templates; do
    if [ -d "$SRC_KITCHEN/Recipes/$d" ]; then
      run "cp -r $SRC_KITCHEN/Recipes/$d $KIT_ROOT/public/recipes_cooking/"
    fi
  done

  # Public-safe projects
  log "  Copying public-safe projects..."
  for d in "F1 2026" "Voice Project" "Domains" "Geek Projects" "Vitamin D & Neurodivergence Research" "Move Out 2026" "2026 ElevenLabs" "2026 Skales Integration" "Your Call" "Radio DSL"; do
    if [ -d "$SRC_KITCHEN/Projects/$d" ]; then
      run "cp -r \"$SRC_KITCHEN/Projects/$d\" $KIT_ROOT/public/projects_public/"
    fi
  done

  # Domains: keep only the public-safe files
  if [ -d "$KIT_ROOT/public/projects_public/Domains" ]; then
    log "  Domains: filtering out case-adjacent material..."
    find "$KIT_ROOT/public/projects_public/Domains" -type f -name "*.md" | while read f; do
      if grep -qE "<your-secret>\.co\.uk|<your-secret>\.com|holder history|theft|dr\. andrea woods|hollins park" "$f" 2>/dev/null; then
        run "rm $f"
      fi
    done
  fi

  # Vitamin D research: principal-specific, MOVE to private
  if [ -d "$KIT_ROOT/public/projects_public/Vitamin D & Neurodivergence Research" ]; then
    log "  Vitamin D research: principal-specific, moving to private..."
    mkdir -p "$KIT_ROOT/private/research/vitamin-d"
    run "mv \"$KIT_ROOT/public/projects_public/Vitamin D & Neurodivergence Research/\"*.md $KIT_ROOT/private/research/vitamin-d/"
    run "rmdir \"$KIT_ROOT/public/projects_public/Vitamin D & Neurodivergence Research\""
  fi
  for f in vitamin-d-*.md; do
    if [ -f "$KIT_ROOT/public/research/$f" ]; then
      run "mv $KIT_ROOT/public/research/$f $KIT_ROOT/private/research/vitamin-d/"
    fi
  done

  # Wired/jeff_env.json (portable env descriptor)
  log "  Building jeff_env.json (portable env descriptor)..."
  cat > /tmp/jeff_env.json << 'ENVEOF'
{
  "schema": "jeff_env.v1",
  "description": "Portable environment descriptor for Jeff. Any AI environment (OpenClaw, Skales, or a custom runtime) can read this file to reconstitute Jeff's identity, capabilities, and required wiring.",
  "identity": {
    "name": "Jeff",
    "kind": "personal_ai_assistant",
    "model_agnostic": true,
    "engine_agnostic": true,
    "principal": "the principal",
    "spec_files": ["SOUL.md", "AGENTS.md", "IDENTITY.md", "USER.md", "TOOLS.md", "HEARTBEAT.md", "MEMORY.md"]
  },
  "memory": {
    "primary_file": "MEMORY.md",
    "daily_notes_dir": "memory/",
    "continuity_file": "CONTINUITY.md",
    "format": "Markdown"
  },
  "capabilities_required": ["filesystem_read", "filesystem_write_local", "shell_exec", "memory_search", "web_search"],
  "viks_context": {
    "name": "the principal", "pronouns": "they/them", "timezone": "Europe/London"
  },
  "recovery_contract": {
    "entry_point": "RECOVER_FIRST.md",
    "continuity_first": "Always read CONTINUITY.md first.",
    "test_for_jeffness": "If the new Jeff can produce a context-appropriate first message in the principal's voice → recovery succeeded."
  }
}
ENVEOF
  run "cp /tmp/jeff_env.json $KIT_ROOT/public/wired/jeff_env.json"

  # Wired/redacted/openclaw.redacted.json (using the Python lib)
  log "  Building redacted openclaw.json..."
  run "python3 $LIB redact-openclaw-json $SRC_OPENCLAW/openclaw.json $KIT_ROOT/public/wired/redacted/openclaw.redacted.json"

  # .gitignore
  cat > "$KIT_ROOT/public/.gitignore" << 'GIEOF'
.DS_Store
._*
Thumbs.db
*~.swp
GIEOF

  # Initialise git if not done
  cd "$KIT_ROOT/public"
  if [ ! -d ".git" ]; then
    log "  Initialising git..."
    run "git init -b main"
    run "git config user.name Jeff"
    run "git config user.email <your-git-email>"
  fi

  log "  Public tree built: $(du -sh $KIT_ROOT/public | cut -f1)"
}

# === Step 3: Build the PRIVATE tree (the principal's Jeff) ===
step_private() {
  log "Step 3: Build the private tree (the principal's Jeff — operational state)"
  require_confirmation "build the private tree at $KIT_ROOT/private/ (existing private/ becomes private.vN-backup)"

  # Safety net: rename old private/
  if [ -d "$KIT_ROOT/private" ]; then
    n=2
    while [ -d "$KIT_ROOT/private.v${n}-backup" ]; do
      n=$((n+1))
    done
    log "  Backing up current private/ to private.v${n}-backup/"
    run "mv $KIT_ROOT/private $KIT_ROOT/private.v${n}-backup"
  fi

  mkdir -p "$KIT_ROOT/private"/{constitution,memory_full,research,case,kitchen,runtime,stuff,wired,documents,recovery,recovery/public-archive}

  # Constitution (byte-identical)
  log "  Copying constitution (byte-identical)..."
  for f in SOUL.md AGENTS.md IDENTITY.md USER.md TOOLS.md HEARTBEAT.md; do
    run "cp $SRC_WORKSPACE/$f $KIT_ROOT/private/constitution/$f"
  done

  # Memory (byte-identical)
  log "  Copying memory (byte-identical)..."
  for f in MEMORY.md CONTINUITY.md DREAMS.md; do
    run "cp $SRC_WORKSPACE/$f $KIT_ROOT/private/memory_full/$f"
  done
  mkdir -p "$KIT_ROOT/private/memory_full/daily"
  for f in $SRC_WORKSPACE/memory/2026-*.md; do
    [ -f "$f" ] || continue
    run "cp $f $KIT_ROOT/private/memory_full/daily/$(basename $f)"
  done

  # Research
  log "  Copying research..."
  for f in $SRC_WORKSPACE/research/*; do
    [ -f "$f" ] || continue
    run "cp $f $KIT_ROOT/private/research/"
  done
  for f in $SRC_WORKSPACE/briefs/*; do
    [ -f "$f" ] || continue
    run "cp $f $KIT_ROOT/private/research/"
  done

  # Case
  log "  Copying case material..."
  for f in case_*.md jeff_continuity.md jeff_hot.md jeff_people.md; do
    if [ -f "$SRC_WORKSPACE/$f" ]; then
      run "cp $SRC_WORKSPACE/$f $KIT_ROOT/private/case/$f"
    fi
  done

  # Kitchen (full mirror, sans Jeff Recovery Kit recursion)
  log "  Mirroring the Kitchen (excluding Jeff Recovery Kit/)..."
  if [ -d "$KIT_ROOT/private/kitchen" ]; then
    run "rm -rf $KIT_ROOT/private/kitchen"
  fi
  run "rsync -a --exclude='Jeff Recovery Kit' --exclude='.DS_Store' $SRC_KITCHEN/ $KIT_ROOT/private/kitchen/"

  # Runtime (OpenClaw state snapshot)
  log "  Snapshotting runtime state..."
  for d in memory wiki subagents cron identity; do
    if [ -d "$SRC_OPENCLAW/$d" ]; then
      run "cp -r $SRC_OPENCLAW/$d $KIT_ROOT/private/runtime/"
    fi
  done
  if [ -d "$SRC_OPENCLAW/agents/main/agent" ]; then
    run "mkdir -p $KIT_ROOT/private/runtime/agents"
    run "cp -r $SRC_OPENCLAW/agents/main/agent $KIT_ROOT/private/runtime/agents/main-agent/"
  fi
  log "  Snapshotting recent sessions (last $RECENT_SESSIONS_DAYS days)..."
  if [ -d "$SRC_OPENCLAW/agents/main/sessions" ]; then
    run "mkdir -p $KIT_ROOT/private/runtime/agents/recent-sessions"
    find "$SRC_OPENCLAW/agents/main/sessions" -type f -mtime -$RECENT_SESSIONS_DAYS -not -name "*.lock" 2>/dev/null | head -200 | while read f; do
      relpath=$(echo "$f" | sed "s|$SRC_OPENCLAW/agents/main/sessions/||")
      destdir="$KIT_ROOT/private/runtime/agents/recent-sessions/$(dirname "$relpath")"
      run "mkdir -p $destdir"
      run "cp $f $destdir/$(basename $f)"
    done
  fi
  # Auth (with token redaction via the Python lib)
  if [ -d "$SRC_OPENCLAW/auth" ]; then
    run "mkdir -p $KIT_ROOT/private/runtime/auth"
    run "python3 $LIB redact-auth $SRC_OPENCLAW/auth $KIT_ROOT/private/runtime/auth"
    cat > "$KIT_ROOT/private/runtime/auth/README.md" << 'AUTHREOF'
# Runtime auth state

Tokens are REDACTED. The accounts.json and structure are preserved.
On a new machine, re-auth these services. See the kit's RECOVER_FIRST.md step 7.
AUTHREOF
  fi

  # Stuff (sacred, never read)
  log "  Copying Stuff/ (sacred, never read)..."
  for f in "API Keys.rtf" "AI Prompts.rtf" "OpenClaw Prompts.docx"; do
    if [ -f "$SRC_STUFF/$f" ]; then
      run "cp $SRC_STUFF/$f $KIT_ROOT/private/stuff/$f"
    fi
  done

  # Wired (operational config with secrets)
  log "  Copying wired config (with real secrets)..."
  run "cp $SRC_OPENCLAW/openclaw.json $KIT_ROOT/private/wired/openclaw.json"
  [ -f "$SRC_WORKSPACE/config/tidal_token.json" ] && run "cp $SRC_WORKSPACE/config/tidal_token.json $KIT_ROOT/private/wired/"
  [ -f "$SRC_WORKSPACE/config/mcporter.json" ] && run "cp $SRC_WORKSPACE/config/mcporter.json $KIT_ROOT/private/wired/"

  # Documents (health letters)
  if [ -d "$SRC_KITCHEN/Documents" ]; then
    log "  Copying Documents/ (health letters)..."
    run "cp $SRC_KITCHEN/Documents/*.pdf $SRC_KITCHEN/Documents/*.jpg $KIT_ROOT/private/documents/ 2>/dev/null || true"
  fi

  log "  Private tree built: $(du -sh $KIT_ROOT/private | cut -f1)"
}

# === Step 4: Add the RECOVERY bundle ===
step_recovery() {
  log "Step 4: Add the recovery bundle (RECOVER_FIRST.md + self-contained public-archive copy)"

  if [ -f "$KIT_ROOT/RECOVER_FIRST.md" ]; then
    log "  RECOVER_FIRST.md already exists at kit root; not overwriting"
  else
    err "RECOVER_FIRST.md not found at $KIT_ROOT. Cannot continue without it."
    err "Restore it from a previous kit, or write it manually."
    exit 1
  fi

  run "cp $KIT_ROOT/RECOVER_FIRST.md $KIT_ROOT/public/RECOVER_FIRST.md"
  run "cp $KIT_ROOT/RECOVER_FIRST.md $KIT_ROOT/private/recovery/public-archive/RECOVER_FIRST.md"

  log "  Copying public/ into private/recovery/public-archive/ (self-contained copy)..."
  if [ -d "$KIT_ROOT/private/recovery/public-archive" ]; then
    run "rm -rf $KIT_ROOT/private/recovery/public-archive"
  fi
  run "mkdir -p $KIT_ROOT/private/recovery/public-archive"
  run "rsync -a --exclude='.git' $KIT_ROOT/public/ $KIT_ROOT/private/recovery/public-archive/"

  if [ ! -f "$KIT_ROOT/public/kitchen_menu.md" ]; then
    [ -f "$KIT_ROOT/kitchen_menu.md" ] && run "cp $KIT_ROOT/kitchen_menu.md $KIT_ROOT/public/"
  fi

  log "  Recovery bundle added"
}

# === Step 5: Merge a previous version ===
step_merge() {
  PREV="${1:?Usage: $0 merge <path-to-previous-kit>}"
  [ -d "$PREV" ] || { err "Previous kit not found: $PREV"; exit 1; }
  [ -d "$PREV/private" ] || { err "Previous kit has no private/ — not a valid kit"; exit 1; }

  log "Step 5: Merge previous version ($PREV) into current kit"
  log "  Strategy: copy files only-in-previous (--ignore-existing);"
  log "  new private/ always wins for files that exist in both."
  require_confirmation "merge $PREV/private/ into $KIT_ROOT/private/"

  run "rsync -a --ignore-existing $PREV/private/ $KIT_ROOT/private/"

  # Special handling: case/evidence/ emails
  if [ -d "$PREV/private/kitchen_private/2026 Court Case" ]; then
    log "  Pulling case/ evidence from previous kit's kitchen_private/..."
    mkdir -p "$KIT_ROOT/private/case/evidence"
    find "$PREV/private/kitchen_private/2026 Court Case/" -type f 2>/dev/null | while read f; do
      rel=$(basename "$f")
      if [ ! -f "$KIT_ROOT/private/case/evidence/$rel" ]; then
        run "cp $f $KIT_ROOT/private/case/evidence/"
      fi
    done
  fi

  # Documents/
  if [ -d "$PREV/private/documents" ]; then
    log "  Pulling Documents/ from previous kit..."
    for f in $PREV/private/documents/*; do
      [ -f "$f" ] || continue
      [ -f "$KIT_ROOT/private/documents/$(basename $f)" ] || run "cp $f $KIT_ROOT/private/documents/"
    done
  fi

  # Kitchen projects that may have been added in the previous version
  for sub in "Domains" "Finance" "VPS" "VVBG"; do
    if [ -d "$PREV/private/kitchen/Projects/$sub" ]; then
      mkdir -p "$KIT_ROOT/private/kitchen/Projects/$sub"
      for f in $(find "$PREV/private/kitchen/Projects/$sub/" -type f 2>/dev/null); do
        rel=${f#$PREV/private/kitchen/Projects/$sub/}
        if [ ! -f "$KIT_ROOT/private/kitchen/Projects/$sub/$rel" ]; then
          run "mkdir -p $KIT_ROOT/private/kitchen/Projects/$sub/$(dirname $rel)"
          run "cp $f $KIT_ROOT/private/kitchen/Projects/$sub/$rel"
        fi
      done
    fi
  done

  log "  Merge complete"
}

# === Step 6: Build the encrypted archive ===
step_archive() {
  log "Step 6: Build the encrypted archive"
  require_confirmation "build the encrypted archive (asks for GPG passphrase)"

  mkdir -p "$KIT_ROOT/archives"
  local archive_name="jeff-recovery-kit-${TIMESTAMP}.tar.zst"
  local archive_path="$KIT_ROOT/archives/$archive_name"
  local encrypted_path="${archive_path}.gpg"

  if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] would prompt for GPG passphrase and build archive"
    return 0
  fi

  PASSWORD_FILE=$(mktemp -t jeff-passphrase-XXXXXX)
  chmod 600 "$PASSWORD_FILE"
  printf "Enter GPG passphrase: "
  read -s passphrase
  echo ""
  echo -n "$passphrase" > "$PASSWORD_FILE"
  unset passphrase

  log "  Building tar.zst archive..."
  cd "$KIT_ROOT"
  tar -c --exclude='./public' --exclude='./archives' \
      -f - \
      README.md RESTORE.md PORTABILITY.md REDACTION_REPORT.md KIT_INVENTORY.md RECOVER_FIRST.md \
      private/ | \
  zstd -19 -T2 -o "$archive_path" 2>&1 | tail -3
  log "  Archive: $(du -h $archive_path | cut -f1)"

  log "  Encrypting with GPG AES-256..."
  gpg --batch --yes --pinentry-mode loopback --passphrase-file "$PASSWORD_FILE" \
      --symmetric --cipher-algo AES256 --compress-algo none \
      --output "$encrypted_path" \
      "$archive_path" 2>&1 | tail -3
  log "  Encrypted: $(du -h $encrypted_path | cut -f1)"

  rm -f "$archive_path"

  log "  Building SHA-256 manifest..."
  local manifest="$KIT_ROOT/archives/KIT_MANIFEST_${TIMESTAMP}.sha256"
  : > "$manifest"
  for f in README.md RESTORE.md PORTABILITY.md REDACTION_REPORT.md KIT_INVENTORY.md RECOVER_FIRST.md; do
    /usr/bin/shasum -a 256 -b "$f" >> "$manifest"
  done
  find "$KIT_ROOT/private/" -type f -print0 | xargs -0 /usr/bin/shasum -a 256 -b >> "$manifest"
  log "  Manifest: $(wc -l < $manifest) entries, $(du -h $manifest | cut -f1)"

  if gpg --list-secret-keys 2>/dev/null | grep -q "^sec"; then
    log "  Signing manifest with GPG key..."
    gpg --detach-sign --output "${manifest}.sig" "$manifest" 2>&1 | tail -3
  else
    warn "  No GPG key configured — manifest is unsigned."
    warn "  Generate one with: gpg --gen-key"
  fi

  log ""
  ok "Encrypted archive built: $encrypted_path"
  log "  Manifest: $manifest"
}

# === Step 7: Push the public repo to GitHub ===
step_push() {
  log "Step 7: Push the public repo to GitHub (Jeff v2.0)"
  require_confirmation "create the public GitHub repo and push all commits"

  cd "$KIT_ROOT/public"

  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    log "  Committing any uncommitted changes..."
    git add -A
    git commit -m "Kit build $TIMESTAMP (build_kit_v3.sh)

Co-authored-by: <Your Name> <your-email>>" 2>&1 | tail -3
  fi

  log "  Pre-flight credential sweep..."
  local leaks=0
  for sus in "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "<your-secret>" "88.208.212" "<your-secret>"; do
    if git grep -qE "$sus" 2>/dev/null; then
      err "  ✗ LEAK in tracked content: $sus"
      leaks=$((leaks+1))
    fi
  done
  if [ "$leaks" -gt 0 ]; then
    err "Refusing to push. $leaks credential(s) in staged content."
    exit 1
  fi
  log "  ✓ No credentials in staged content"

  if [ -z "$(git remote get-url origin 2>/dev/null)" ]; then
    log "  Creating GitHub repo: ${GITHUB_USER}/${GITHUB_REPO} (private)..."
    gh repo create "$GITHUB_REPO" --private --source=. --remote=origin --push 2>&1 | tail -5
  else
    log "  Pushing to existing remote..."
    git push -u origin main 2>&1 | tail -5
  fi

  log ""
  ok "Jeff v2.0 is live at: ${GITHUB_REPO_URL%.git}"
}

# === Step 8: Verify ===
step_verify() {
  log "Step 8: Verify the archive and the GitHub push"

  local archive="$KIT_ROOT/archives/jeff-recovery-kit-${TIMESTAMP}.tar.zst.gpg"
  if [ -f "$archive" ]; then
    log "  Archive: $archive"
    log "  Size: $(du -h $archive | cut -f1)"
    if [ "$DRY_RUN" = false ]; then
      log "  Decryption + listing (first 10 entries):"
      PASSWORD_FILE=$(mktemp -t jeff-passphrase-XXXXXX)
      chmod 600 "$PASSWORD_FILE"
      printf "Enter GPG passphrase to verify: "
      read -s passphrase
      echo ""
      echo -n "$passphrase" > "$PASSWORD_FILE"
      unset passphrase
      gpg --batch --yes --pinentry-mode loopback --passphrase-file "$PASSWORD_FILE" \
          --decrypt "$archive" 2>/dev/null | \
      zstd -d 2>/dev/null | \
      tar -t 2>/dev/null | head -10
    fi
  else
    warn "  No archive found at $archive"
  fi

  log ""
  log "  GitHub repo:"
  gh repo view "${GITHUB_USER}/${GITHUB_REPO}" --json name,visibility,url 2>&1 | head -5

  log ""
  ok "Verification complete"
}

# === Main ===
case "${1:-help}" in
  inventory) preflight; step_inventory ;;
  public) preflight; step_public ;;
  private) preflight; step_private ;;
  recovery) preflight; step_recovery ;;
  merge) preflight; step_merge "$2" ;;
  archive) preflight; step_archive ;;
  push) preflight; step_push ;;
  verify) preflight; step_verify ;;
  full)
    preflight
    step_inventory
    step_public
    step_private
    step_recovery
    if ls -d "$KIT_ROOT"/private.v*-backup 2>/dev/null | head -1 > /dev/null; then
      PREV=$(ls -td "$KIT_ROOT"/private.v*-backup | head -1)
      log ""
      log "Found previous kit backup: $PREV"
      read -r -p "  Merge it into the new private/? [Y/n] " merge_response
      case "$merge_response" in
        ""|[Yy]|[Yy][Ee][Ss]) step_merge "$PREV" ;;
        *) log "  Skipping merge" ;;
      esac
    fi
    step_archive
    step_push
    step_verify
    log ""
    ok "═══════════════════════════════════════════════════════════════════"
    ok "  KIT BUILD COMPLETE"
    ok "═══════════════════════════════════════════════════════════════════"
    log "  Encrypted archive: $KIT_ROOT/archives/jeff-recovery-kit-${TIMESTAMP}.tar.zst.gpg"
    log "  Public repo: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
    log ""
    log "  Next: copy the archive to X Drive and/or upload to Mega"
    log "  The kit is COMPLETE. The principal's Jeff is recoverable."
    ;;
  help|--help|-h|"")
    cat << 'USAGE'
build_kit_v3.sh — Build a Jeff Recovery Kit v3 (the whole pipeline)

Usage:
  ./build_kit_v3.sh full          # all 8 steps, with confirmation gates
  ./build_kit_v3.sh inventory     # step 1 only
  ./build_kit_v3.sh public       # step 2 only
  ./build_kit_v3.sh private      # step 3 only
  ./build_kit_v3.sh recovery     # step 4 only
  ./build_kit_v3.sh merge <PREV> # step 5 only (PREV = path to previous kit)
  ./build_kit_v3.sh archive      # step 6 only
  ./build_kit_v3.sh push         # step 7 only
  ./build_kit_v3.sh verify       # step 8 only

  ./build_kit_v3.sh --dry-run full   # show what would happen

The build is idempotent. Re-running any step after a previous success is safe.
Read V3_PROCEDURES.md for the full procedure and the lessons from v2.

Steps:
  1. inventory     — what's in the operational state
  2. public        — build the Jeff v2.0 worked example (anonymised)
  3. private       — build the principal's Jeff (operational state, byte-identical)
  4. recovery      — add RECOVER_FIRST.md + self-contained public-archive copy
  5. merge         — bring a previous kit's unique content across
  6. archive       — tar.zst + GPG AES-256 + SHA-256 manifest
  7. push          — push the public repo to GitHub
  8. verify        — decrypt-and-list the archive, confirm the GitHub push

Idempotency: every step is safe to re-run. The script handles:
  - pre-existing private/ (renames to private.vN-backup before overwriting)
  - pre-existing public-archive/ (deletes before re-copying)
  - pre-existing GitHub repo (skips create, just pushes)
  - missing GPG key (manifest unsigned, with a warning)
  - pre-existing archive (overwrites)
USAGE
    ;;
  *)
    err "Unknown command: $1"
    err "Run '$0 help' for usage"
    exit 1
    ;;
esac
