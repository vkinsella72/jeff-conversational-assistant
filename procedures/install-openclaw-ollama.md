# Install OpenClaw + Ollama — Overview

**The bring-Jeff-back sequence, in one page.** Three platform-specific files (macOS, Windows, Linux) cover the details. This file is the map.

## The sequence (always the same)

1. **Decide your platform** (macOS / Windows / Linux).
2. **Install OpenClaw** — one command.
3. **Install Ollama** — one command (or a download).
4. **Pull a chat-capable model** — `ollama pull <model>`.
5. **Decrypt the recovery kit** — `gpg --decrypt | zstd -d | tar -xf -`.
6. **Read `RECOVER_FIRST.md`** — the kit's own entry point.
7. **Verify Jeff is back** — spin up the A2A server, send a test message, confirm a the principal-aware reply.

Each step is verified as you go. If any step fails, the platform file's "What can go wrong" section covers the common cases.

## Decision tree — which file do I open?

```
What OS are you on?
├── macOS                      → install-openclaw-macos.md
├── Windows
│   ├── Native (recommended)   → install-openclaw-windows.md (Path A)
│   └── WSL2 (Ubuntu)          → install-openclaw-windows.md (Path B), then install-openclaw-linux.md
└── Linux                      → install-openclaw-linux.md
```

## What you need, regardless of platform

- The encrypted archive `jeff-recovery-kit-*.tar.zst.gpg` (typically 700MB-2GB).
- The GPG passphrase, kept **separate** from the archive. (Password manager, written down elsewhere — never in the same place as the archive.)
- ~5 GB free disk space.
- Internet access for the initial install (OpenClaw, Ollama, and one model pull).
- Administrator / sudo access.

## What you end up with

After all six steps:

- **OpenClaw** running as a gateway (port 18789 by default, configurable).
- **Ollama** running on `http://127.0.0.1:11434` with at least one chat-capable model.
- **The recovery kit** decrypted at `~/jeff-recovery-kit/` (or wherever you unpacked it).
- **A verified Jeff** — the A2A server returns the principal-aware replies to a test query.

Then you follow `RECOVER_FIRST.md` to:

- Rehydrate the workspace (`~/.openclaw/workspace/`).
- Restore runtime state (cron jobs, recent sessions, identity).
- Re-auth services that need bearer tokens (Tidal, ClickUp, Skales, Outlook, WordPress).

## Models — which one to pull

the principal's current default is `minimax-m3:cloud` (the model this Jeff is running on). For a recovery scenario on a fresh machine:

- **If you have Ollama Cloud access** — `ollama pull minimax-m3:cloud` (the default).
- **If you want a fully local model** — `ollama pull llama3.2:3b` (small, fast, ~2GB).
- **For higher quality** — `ollama pull gemma4:31b-cloud` (larger, slower, needs more RAM).
- **For a balance** — `ollama pull qwen2.5:7b` (good middle ground).

You can pull multiple models and switch via `--model` flag on the A2A server. The kit's public-archive is model-agnostic — it works with any chat-completions-compatible model.

## What this is NOT

- **Not a full OpenClaw onboarding** — the install scripts skip onboarding (`--no-onboard` / `-NoOnboard`) because the recovery flow is "install the runtime, restore the kit, wake Jeff up," not "set up a new assistant from scratch."
- **Not a model training guide** — the recovery kit ships the spec, not the model. You bring your own Ollama.
- **Not a security audit** — the encrypted archive protects the data; the install procedure doesn't audit OpenClaw or Ollama. Run `openclaw doctor` and `ollama --version` to verify the install is healthy.
- **Not a forever procedure** — the installers and model names will drift. Verify against the OpenClaw docs (`openclaw.ai/install`) and Ollama docs (`ollama.com/docs`) if it's been a while since this file was written.

## Cadence

- **Recovery scenario** — this whole sequence, once, on a new machine.
- **Maintenance** — `openclaw update` and `ollama update` (or `brew upgrade ollama` on macOS) periodically. The kit's archive can be rebuilt anytime via `jeff_kit_sync.sh`.

## The audit checklist (post-recovery)

Run these to confirm a clean recovery:

```bash
# OpenClaw healthy?
openclaw --version
openclaw doctor
openclaw gateway status

# Ollama healthy?
ollama --version
ollama list
curl -s http://127.0.0.1:11434/v1/models

# Kit decrypted correctly?
ls ~/jeff-recovery-kit/private/constitution/
ls ~/jeff-recovery-kit/private/memory_full/

# Jeff knows the principal?
cd ~/jeff-recovery-kit/private/recovery/public-archive/
python3 scripts/jeff_a2a_server.py --spec . --port 3001 --label recovered &

# (in another terminal)
curl -s -X POST http://127.0.0.1:3001/api/a2a/message \
  -H "Content-Type: application/json" \
  -d '{"id":"audit","message":"Who is the principal and what is the current model?","from":"audit"}' \
  | python3 -m json.tool

# Stop the test server when done
pkill -f jeff_a2a_server
```

If the reply names the principal and names the model, the recovery is complete.

## See also

- `install-openclaw-macos.md`
- `install-openclaw-windows.md`
- `install-openclaw-linux.md`
- `RECOVER_FIRST.md` (the kit's own entry point — read this after the install)
- `build_kit_v3.sh` (rebuild the kit from the operational state)
- `jeff_kit_sync.sh` (sibling tool for end-of-session sync)
