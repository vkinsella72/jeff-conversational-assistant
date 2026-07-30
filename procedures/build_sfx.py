#!/usr/bin/env python3
"""
build_sfx.py — Build the three SFX archives from the staged generic body.

This is the load-bearing script. Lives in procedures/ as the durable
reference. The actual build runs from /tmp/build-sfx.py (transient copy)
because Python f-string escaping around the embedded bash + PowerShell
preambles requires careful placeholder substitution that's easier to do
in a transient file than in a long-lived one.

The procedure documentation is in
`procedures/building_sfx_archives.md`. Read that first.

Usage:
    python3 /tmp/build-sfx.py         # transient copy
    rm /tmp/build_sfx.py
"""

import base64
import os
import subprocess

SFX_ROOT = os.path.expanduser(
    "~/Desktop/Jeff's Kitchen/Projects/generic-jeff/installers"
)
BODY_DIR = "/tmp/jeff-final-audit"
MARKER = "__GENERIC_JEFF_SFX_PAYLOAD_END_OF_INSTALLER__"

D = chr(36)  # $ placeholder for f-string safety


def build_bash_sfx(installer_path: str, sfx_path: str) -> None:
    """Prepend the bash preamble to an installer + append the payload."""
    preamble = f"""#!/usr/bin/env bash
# Generic-Jeff SFX installer - self-extracts the payload and runs the installer.

__say() {{ echo "[generic-jeff-sfx] $*" >&2; }}
__die() {{ echo "ERROR: $*" >&2; exit 1; }}
__ok()  {{ echo "[generic-jeff-sfx] + $*" >&2; }}

if [[ -z "${{SFX_PAYLOAD_DIR:-}}" ]]; then
  __say "Self-extracting archive detected, extracting payload..."
  __SCRIPT_PATH="${{BASH_SOURCE[0]:-$0}}"
  __SFX_TMP="$(mktemp -d)"
  awk -v marker="{MARKER}" '
    $0 == marker {{ found=1; next }}
    found {{ print }}
  ' "${{__SCRIPT_PATH}}" | base64 -d | tar -xzf - -C "${{__SFX_TMP}}"
  if [[ ! -d "${{__SFX_TMP}}/payload" ]]; then
    __die "payload extraction failed - marker not found or archive corrupt"
  fi
  __ok "payload extracted to ${{__SFX_TMP}}/payload"
  export SFX_PAYLOAD_DIR="${{__SFX_TMP}}/payload"
  exec "${{__SCRIPT_PATH}}" "$@"
fi

"""

    payload = open("/tmp/jeff-rebuild/payload.tar.gz", "rb").read()
    b64 = base64.b64encode(payload).decode()

    installer = open(installer_path).read()
    if installer.startswith("#!/usr/bin/env bash\n"):
        installer = installer[len("#!/usr/bin/env bash\n"):]

    sfx = preamble + installer + "\nexit 0\n" + MARKER + "\n" + b64
    with open(sfx_path, "w") as f:
        f.write(sfx)
    os.chmod(sfx_path, 0o755)
    print("built:", sfx_path, "(", os.path.getsize(sfx_path), "bytes)")


def build_windows_sfx(installer_path: str, sfx_path: str) -> None:
    """Prepend the PowerShell preamble to an installer + append the payload."""
    # Use a placeholder (XDSX) for the dollar sign so Python f-string
    # escaping doesn't trip. Substitute back at the end.
    PLACEHOLDER = "XDSX"

    preamble_template = '''# === Self-extracting archive preamble ===
# When run as a single-file SFX, this section extracts the payload to a temp dir
# and re-executes the installer with -PayloadDir set.

{DS}ErrorActionPreference = "Stop"
{DS}PayloadMarker = "__GENERIC_JEFF_SFX_PAYLOAD_END_OF_INSTALLER__"

if (-not {DS}PayloadDir) {{
    Write-Host "[install-windows.ps1] Self-extracting archive detected, extracting payload..."
    {DS}ScriptPath = {DS}MyInvocation.MyCommand.Path
    {DS}ExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path {DS}ExtractDir | Out-Null

    {DS}scriptText = Get-Content -Path {DS}ScriptPath -Raw
    {DS}markerIdx = {DS}scriptText.IndexOf({DS}PayloadMarker)
    if ({DS}markerIdx -lt 0) {{
        Write-Error "payload extraction failed - marker not found"
        exit 1
    }}

    {DS}b64Start = {DS}markerIdx + {DS}PayloadMarker.Length + 1
    {DS}b64Text = {DS}scriptText.Substring({DS}b64Start)
    {DS}bytes = [Convert]::FromBase64String({DS}b64Text.Trim())
    {DS}zipPath = Join-Path {DS}ExtractDir "payload.zip"
    [System.IO.File]::WriteAllBytes({DS}zipPath, {DS}bytes)
    Expand-Archive -Path {DS}zipPath -DestinationPath {DS}ExtractDir -Force

    {DS}payloadDir = Join-Path {DS}ExtractDir "payload"
    if (-not (Test-Path {DS}payloadDir)) {{
        Write-Error "payload extraction failed - payload dir not found"
        exit 1
    }}

    Write-Host "[install-windows.ps1] payload extracted to {DS}payloadDir"
    Write-Host ""
    & {DS}ScriptPath -PayloadDir {DS}payloadDir @args
    exit {DS}LASTEXITCODE
}}

'''
    preamble = preamble_template.replace("{DS}", PLACEHOLDER)

    payload = open("/tmp/jeff-rebuild-zip/payload.zip", "rb").read()
    b64 = base64.b64encode(payload).decode()

    installer = open(installer_path).read()
    preamble_real = preamble.replace(PLACEHOLDER, "$")
    sfx = preamble_real + installer + "\nexit 0\n" + MARKER + "\n" + b64

    with open(sfx_path, "w") as f:
        f.write(sfx)

    # Fix any doubled braces (Python f-string escape artifact)
    text = open(sfx_path).read()
    text = text.replace("{{", "{").replace("}}", "}")
    with open(sfx_path, "w") as f:
        f.write(text)

    print("built:", sfx_path, "(", os.path.getsize(sfx_path), "bytes)")


def main():
    # Step 1: Build tar.gz + zip payloads from the staged body
    print("=== Building payloads ===")
    subprocess.run(["rm", "-rf", "/tmp/jeff-rebuild", "/tmp/jeff-rebuild-zip"],
                   check=False)
    os.makedirs("/tmp/jeff-rebuild")
    os.makedirs("/tmp/jeff-rebuild-zip")

    subprocess.run(["cp", "-R", BODY_DIR, "/tmp/jeff-rebuild/payload"], check=True)
    subprocess.run(["tar", "-czf", "/tmp/jeff-rebuild/payload.tar.gz",
                    "-C", "/tmp/jeff-rebuild", "payload"], check=True)

    subprocess.run(["cp", "-R", BODY_DIR, "/tmp/jeff-rebuild-zip/payload"], check=True)
    subprocess.run(["zip", "-r", "/tmp/jeff-rebuild-zip/payload.zip", "payload"],
                   cwd="/tmp/jeff-rebuild-zip", check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Step 2: Build the SFX archives
    print("\n=== Building SFX archives ===")
    for platform, installer_name, sfx_name in [
        ("macos", "install-macos.sh", "generic-jeff-macos.sh"),
        ("linux", "install-linux.sh", "generic-jeff-linux.sh"),
    ]:
        installer_path = os.path.join(SFX_ROOT, platform, installer_name)
        sfx_path = os.path.join(SFX_ROOT, platform, sfx_name)
        build_bash_sfx(installer_path, sfx_path)

    installer_path = os.path.join(SFX_ROOT, "windows", "install-windows.ps1")
    sfx_path = os.path.join(SFX_ROOT, "windows", "generic-jeff-windows.ps1")
    build_windows_sfx(installer_path, sfx_path)

    print("\n=== Done ===")
    print("Verify with: <SFX path> --dry-run --skip-deps")


if __name__ == "__main__":
    main()
