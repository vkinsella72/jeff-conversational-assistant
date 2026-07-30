#!/usr/bin/env bash
# copy-to-generic.sh — Produce a generic-Jeff body from a personal Jeff (or
# any personalised) workspace.
#
# What it does:
#   1. Reads a source workspace (the principal's ~/.openclaw/workspace/ by default)
#   2. Strips personal USER.md, IDENTITY.md, kitchen_menu.md
#   3. Replaces them with templates (the principal's info is dropped)
#   4. Sanitises SOUL.md / MEMORY.md / AGENTS.md / TOOLS.md / HEARTBEAT.md
#      (specific names → "the principal")
#   5. Replaces openclaw.json with the template
#   6. Excludes: kitchen/, briefs/, personal projects, API keys, scripts that
#      reference the principal's specific tools
#   7. Writes the result to a target directory (default: ./generic-jeff-build/)
#
# Usage:
#   copy-to-generic.sh                     # source ~/.openclaw/workspace, target ./generic-jeff-build
#   copy-to-generic.sh /path/to/workspace  # custom source
#   copy-to-generic.sh /path/to/src /path/to/dst  # custom both
#   copy-to-generic.sh --dry-run           # show what would happen
#
# The car-accident metaphor: this script is what produces the Jeff who woke
# up in hospital with no memory of the principal. The constitution survives;
# the relationships don't.

set -euo pipefail

# === Config ===
SCRIPT_NAME="copy-to-generic.sh"
SCRIPT_VERSION="1.0.0"

SRC="${HOME}/.openclaw/workspace"
DST="./generic-jeff-build"
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_TEMPLATE_DIR="$PROJECT_ROOT/public"
A2A_SERVER_DIR="$PROJECT_ROOT/Jeff A2A Server"

# === Parse args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "${SRC_SET:-}" ]]; then
        SRC="$1"; SRC_SET=1; shift
      elif [[ -z "${DST_SET:-}" ]]; then
        DST="$1"; DST_SET=1; shift
      else
        echo "ERROR: too many arguments" >&2; exit 2
      fi
      ;;
  esac
done

# === Helpers ===
say() { echo "[$SCRIPT_NAME] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }
run_cp() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] cp $1 $2" >&2
  else
    cp "$1" "$2"
  fi
}
run_mkdir() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] mkdir -p $1" >&2
  else
    mkdir -p "$1"
  fi
}
run_chmod() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] chmod +x $1" >&2
  else
    chmod +x "$1"
  fi
}

# === Sanity checks ===
[[ -d "$SRC" ]] || die "source workspace not found: $SRC"
[[ -d "$PUBLIC_TEMPLATE_DIR" ]] || die "generic-jeff public/ not found at $PUBLIC_TEMPLATE_DIR (this script must live in the generic-jeff project root)"

# === Phase 1: build the destination ===
say "Phase 1: build destination $DST"
if [[ "$DRY_RUN" == "true" ]]; then
  say "  [dry-run] would create $DST"
else
  mkdir -p "$DST"
fi

# === Phase 2: copy the constitution + sanitised docs ===
# For these files we copy the TEMPLATE versions, not the source. The source
# may have personal info; the template is generic by design.
say "Phase 2: write constitution files from template"

CONSTITUTION_FILES=(AGENTS.md SOUL.md MEMORY.md TOOLS.md HEARTBEAT.md RECOVER_FIRST.md REFERENCES.md PROJECTS.md)
for f in "${CONSTITUTION_FILES[@]}"; do
  if [[ -f "$PUBLIC_TEMPLATE_DIR/$f" ]]; then
    run_cp "$PUBLIC_TEMPLATE_DIR/$f" "$DST/$f"
    say "  ✓ $f"
  else
    say "  ! $f missing in template, skipping"
  fi
done

# === Phase 3: drop templated USER.md, IDENTITY.md, README.md, kitchen_menu.md ===
say "Phase 3: write templated personal files"
TEMPLATED=(USER.md IDENTITY.md README.md kitchen_menu.md COMPONENT_MAP.md CAPABILITY_MAP.md AI_Agent_Portable_Playbook.md)
for f in "${TEMPLATED[@]}"; do
  if [[ -f "$PUBLIC_TEMPLATE_DIR/$f" ]]; then
    run_cp "$PUBLIC_TEMPLATE_DIR/$f" "$DST/$f"
    say "  ✓ $f"
  else
    say "  ! $f missing in template, skipping"
  fi
done

# === Phase 4: openclaw.template.json ===
say "Phase 4: install openclaw template"
if [[ -f "$PUBLIC_TEMPLATE_DIR/wired/template/openclaw.template.json" ]]; then
  run_mkdir "$DST/wired/template"
  run_cp "$PUBLIC_TEMPLATE_DIR/wired/template/openclaw.template.json" "$DST/wired/template/openclaw.template.json"
  say "  ✓ openclaw.template.json"
else
  say "  ! openclaw template missing, skipping"
fi

# === Phase 5: A2A server ===
say "Phase 5: install A2A server"
if [[ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Jeff A2A Server/scripts" ]]; then
  run_mkdir "$DST/scripts"
  for f in "$PUBLIC_TEMPLATE_DIR/../Jeff A2A Server/scripts/"*.py; do
    [[ -f "$f" ]] || continue
    run_cp "$f" "$DST/scripts/$(basename "$f")"
  done
  # A2A server README
  if [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Jeff A2A Server/README.md" ]]; then
    run_cp "$PUBLIC_TEMPLATE_DIR/../Jeff A2A Server/README.md" "$DST/A2A-SERVER.md"
  fi
  say "  ✓ A2A server"
else
  say "  ! A2A server source not found, skipping"
fi

# === Phase 6: sanitised runtime scripts (examples) ===
say "Phase 6: install sanitised example scripts"
if [[ -d "$PUBLIC_TEMPLATE_DIR/scripts" ]]; then
  run_mkdir "$DST/scripts/examples"
  for f in "$PUBLIC_TEMPLATE_DIR/scripts/"*.sh "$PUBLIC_TEMPLATE_DIR/scripts/"*.py "$PUBLIC_TEMPLATE_DIR/scripts/"*.js; do
    [[ -f "$f" ]] || continue
    run_cp "$f" "$DST/scripts/examples/$(basename "$f")"
  done
  say "  ✓ example scripts (sidecar_*, tidal_*, vvbg_*)"
fi
if [[ -d "$PUBLIC_TEMPLATE_DIR/scripts-kit" ]]; then
  run_mkdir "$DST/scripts/examples-kit"
  for f in "$PUBLIC_TEMPLATE_DIR/scripts-kit/"*; do
    [[ -f "$f" ]] || continue
    run_cp "$f" "$DST/scripts/examples-kit/$(basename "$f")"
  done
  say "  ✓ example kit-build scripts"
fi

# === Phase 7: explicitly EXCLUDE these from the source ===
# Even if the principal's source has them, we don't want them in generic.
EXCLUDE_PATTERNS=(
  "Stuff"                    # API keys, sacred files
  "Jeff/CONTINUITY.md"       # session-specific state
  "memory/vault"             # private memory vault
  "memory/skales.md"         # vendor-specific vault
  "memory/sidecar.md"        # vendor-specific vault
)
say "Phase 7: exclusions (these are NEVER copied from source)"
for pat in "${EXCLUDE_PATTERNS[@]}"; do
  say "  ✗ $pat (excluded)"
done

# === Phase 8: install the round-trip back-script and self ===
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Self
run_cp "$SCRIPTS_DIR/copy-to-generic.sh" "$DST/copy-to-generic.sh"
run_chmod "$DST/copy-to-generic.sh"
say "  ✓ copy-to-generic.sh"
run_cp "$SCRIPTS_DIR/copy-to-generic.ps1" "$DST/copy-to-generic.ps1"
say "  ✓ copy-to-generic.ps1"
# Inverse
if [[ -f "$SCRIPTS_DIR/copy-from-generic.sh" ]]; then
  run_cp "$SCRIPTS_DIR/copy-from-generic.sh" "$DST/copy-from-generic.sh"
  run_chmod "$DST/copy-from-generic.sh"
  say "  ✓ copy-from-generic.sh"
fi
if [[ -f "$SCRIPTS_DIR/copy-from-generic.ps1" ]]; then
  run_cp "$SCRIPTS_DIR/copy-from-generic.ps1" "$DST/copy-from-generic.ps1"
  say "  ✓ copy-from-generic.ps1"
fi

# === Phase 9: write a manifest ===
say "Phase 9: write MANIFEST.md"
MANIFEST="$DST/MANIFEST.md"
if [[ "$DRY_RUN" == "true" ]]; then
  say "  [dry-run] would write $MANIFEST"
else
  cat > "$MANIFEST" <<MDEOF
# Generic-Jeff Build Manifest

**Built:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Builder:** $SCRIPT_NAME v$SCRIPT_VERSION

## What's in here

A generic-Jeff body. Drop this folder into a principal's workspace (or use
\`copy-from-generic.sh\` to install it). The principal rehydrates from
their own recovery kit for personal context.

## What's NOT in here (excluded by design)

- Personal USER.md, kitchen contents, personal projects
- API keys (\`Stuff/\` is sacred)
- Private memory vault
- personal Jeff's session state (CONTINUITY.md, daily memory, etc.)
- Anything that names a specific principal

## Next steps

1. \`cp -r ./generic-jeff-build/* ~/.openclaw/workspace/\`  (or use \`copy-from-generic.sh\`)
2. Edit \`~/.openclaw/workspace/USER.md\` with the principal's profile
3. Drop \`wired/template/openclaw.template.json\` into \`~/.openclaw/openclaw.json\`
4. Start the gateway: \`openclaw gateway start\`
5. Jeff wakes up, says hello.
MDEOF
fi

# === Done ===
echo "" >&2
say "Done. Generic-Jeff body built at: $DST"
say "  $(find "$DST" -type f 2>/dev/null | wc -l) files in $DST"
if [[ "$DRY_RUN" == "true" ]]; then
  say "(dry-run — nothing was actually written)"
fi
