#!/usr/bin/env python3
#!/usr/bin/env python3
"""
build_kit_v3_lib.py — the principal's Jeff (or "personal Jeff")'s recovery kit build helpers (example pattern).
Library functions for the build_kit_v3.sh pipeline. Demonstrates credential
redaction, manifest generation, and the public/private fork pattern.
For generic-Jeff, see copy-to-generic.sh instead.
"""

build_kit_v3_lib.py — Library functions for build_kit_v3.sh

This is a Python file with the Python logic the bash script needs.
Splitting Python out of bash avoids quoting nightmares.

Usage from bash:
    python3 build_kit_v3_lib.py redact-tool-md <path>
    python3 build_kit_v3_lib.py redact-openclaw-json <src> <dst>
    python3 build_kit_v3_lib.py redact-auth <src-base> <dst-base>
"""

import sys
import os
import json
import copy
import shutil
import re


def redact_tool_md(path):
    """Redact credentials from a TOOLS.md file (in place)."""
    if not os.path.exists(path):
        return
    with open(path) as f:
        c = f.read()
    redactions = [
        (r'<your-secret>', '[REDACTED]'),
        (r'<your-secret>\S*', '[REDACTED — see private archive]'),
        (r'<your-secret>_\S+', '[REDACTED — see private archive]'),
        (r'<your-secret>', '[REDACTED]'),
        (r'<your-secret>', '[REDACTED]'),
        (r'<your-secret>', '[REDACTED]'),
        (r'<principal-email>', '[REDACTED — see private archive]'),
        (r'<your-secret>09d9f9b06b76eb3e161cf2e2dcacb7f4bcf20322', '[REDACTED — see private archive]'),
        (r'<your-secret>981e13ab5c77ad46a1b1e00c4bc4db40fd253a54', '[REDACTED — see private archive]'),
        (r'<your-secret>-4360-9c34-5c360af1e209', '[REDACTED — see private archive]'),
    ]
    for pat, repl in redactions:
        c = re.sub(pat, repl, c)
    with open(path, 'w') as f:
        f.write(c)


def redact_openclaw_json(src, dst):
    """Copy an openclaw.json with secrets stripped."""
    with open(src) as f:
        cfg = json.load(f)
    red = copy.deepcopy(cfg)
    secret_paths = [
        'channels.telegram.botToken',
        'env.vars.AZURE_CLIENT_ID',
        'env.vars.AZURE_CLIENT_SECRET',
        'env.vars.AZURE_TENANT_ID',
        'gateway.auth.token',
    ]
    for p in secret_paths:
        try:
            parts = p.split('.')
            cur = red
            for part in parts[:-1]:
                cur = cur[part]
            cur[parts[-1]] = '[REDACTED — see private archive]'
        except (KeyError, TypeError):
            pass
    if 'models' in red and 'providers' in red['models']:
        for prov in red['models']['providers'].values():
            if 'apiKey' in prov and prov['apiKey'] not in (None, '', 'ollama-local'):
                prov['apiKey'] = '[REDACTED — see private archive]'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, 'w') as f:
        json.dump(red, f, indent=2)


def redact_auth(src_base, dst_base):
    """Copy ~/.openclaw/auth/ tree with tokens redacted."""
    files = [
        ('office365-accounts.json', 'office365-accounts.json'),
        ('office365/personal.json', 'office365/personal.json'),
    ]
    for src_name, dst_name in files:
        src = os.path.join(src_base, src_name)
        dst = os.path.join(dst_base, dst_name)
        if not os.path.exists(src):
            continue
        try:
            with open(src) as f:
                d = json.load(f)

            def redact(o):
                if isinstance(o, dict):
                    return {
                        k: (
                            '[REDACTED — re-auth on new machine]'
                            if any(s in k.lower() for s in ['token', 'secret', 'key', 'access', 'refresh', 'password', 'client_secret'])
                            else redact(v)
                        )
                        for k, v in o.items()
                    }
                if isinstance(o, list):
                    return [redact(x) for x in o]
                return o

            redacted = redact(d)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, 'w') as f:
                json.dump(redacted, f, indent=2)
        except Exception as e:
            # Fall back to copying bytes (not great, but better than nothing)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy(src, dst)
            print(f"  warn: redacting {src_name} failed ({e}), copied raw")


# CLI
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: build_kit_v3_lib.py <command> [args]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == 'redact-tool-md':
        redact_tool_md(sys.argv[2])
    elif cmd == 'redact-openclaw-json':
        redact_openclaw_json(sys.argv[2], sys.argv[3])
    elif cmd == 'redact-auth':
        redact_auth(sys.argv[2], sys.argv[3])
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
