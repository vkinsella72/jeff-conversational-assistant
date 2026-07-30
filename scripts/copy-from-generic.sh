#!/usr/bin/env bash
# copy-from-generic.sh — Drop a generic-Jeff body into a principal's workspace.
#
# What it does:
#   1. Reads a source generic-Jeff folder (the archive, or ./generic-jeff-build/)
#   2. Wipes (or backs up) the destination workspace
#   3. Copies the generic body in
#   4. The principal rehydrates personal context from their own recovery kit
#      (this script does NOT do that — it just installs the generic substrate)
#
# Usage:
#   copy-from-generic.sh                              # src=./generic-jeff-build, dst=~/.openclaw/workspace
#   copy-from-generic.sh /path/to/generic-jeff        # custom source
#   copy-from-generic.sh /path/to/src /path/to/dst    # custom both
#   copy-from-generic.sh --dry-run                    # show what would happen
#   copy-from-generic.sh --backup                     # back up existing dst before overwriting
#
# The car-accident metaphor: this is the script that wakes Jeff up in hospital.
# He opens his eyes, says "hello", has the constitution, doesn't have the memories.

set -euo pipefail

SCRIPT_NAME="copy-from-generic.sh"
SCRIPT_VERSION="1.0.0"

SRC="./generic-jeff-build"
DST="${HOME}/.openclaw/workspace"
DRY_RUN=false
BACKUP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --backup) BACKUP=true; shift ;;
    -h|--help)
      sed -n '2,18p' "$0"
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

say() { echo "[$SCRIPT_NAME] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] $*" >&2
  else
    eval "$@"
  fi
}

[[ -d "$SRC" ]] || die "source generic-Jeff folder not found: $SRC"

# Refuse to overwrite a workspace that already has content,
# unless --backup is passed (which moves the old content aside first).
if [[ -d "$DST" ]] && [[ -n "$(ls -A "$DST" 2>/dev/null)" ]] && [[ "$BACKUP" != "true" ]]; then
  echo "WARN: $DST already has content." >&2
  echo "  Refusing to clobber without --backup or explicit --force." >&2
  die "use --backup to back up the existing workspace first"
fi

# Optional: back up existing dst
if [[ -d "$DST" && "$BACKUP" == "true" ]]; then
  BACKUP_PATH="${DST}.backup.$(date +%Y%m%d-%H%M%S)"
  say "Backing up existing $DST → $BACKUP_PATH"
  run "mv '$DST' '$BACKUP_PATH'"
fi

# Make sure dst exists
say "Ensuring $DST exists"
run "mkdir -p '$DST'"

# Copy the generic body in
say "Copying $SRC → $DST"
run "cp -R '$SRC/.' '$DST/'"

# Set executable bits on the scripts
say "Setting executable bits on scripts"
for f in "$DST"/scripts/*.sh "$DST"/scripts/examples/*.sh "$DST"/scripts/examples-kit/*.sh; do
  [[ -f "$f" ]] || continue
  run "chmod +x '$f'"
done

# Make sure A2A server is at the right path for the MCP config
if [[ -f "$DST/scripts/jeff_a2a_server.py" ]]; then
  say "A2A server present at $DST/scripts/jeff_a2a_server.py"
else
  say "WARN: A2A server not found at $DST/scripts/jeff_a2a_server.py"
  say "      The MCP config expects: ~/.openclaw/workspace/scripts/jeff_a2a_server.py"
fi

# Final check
echo "" >&2
say "Done. Generic-Jeff body installed at: $DST"
say "  Files: $(find "$DST" -type f 2>/dev/null | wc -l)"
if [[ "$DRY_RUN" == "true" ]]; then
  say "(dry-run — nothing was actually written)"
fi
say ""
say "Next steps:"
say "  1. Edit $DST/USER.md with the principal's profile"
say "  2. Install openclaw.json from $DST/wired/template/openclaw.template.json"
say "  3. Start the gateway: openclaw gateway start"
say "  4. Jeff wakes up, says hello."
