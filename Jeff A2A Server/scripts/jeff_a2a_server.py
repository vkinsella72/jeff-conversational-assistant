#!/usr/bin/env python3
"""
jeff_a2a_server.py — Turn a Jeff directory into a discoverable A2A agent.

A 200-line Python script. Single file. Standard library + httpx.
Reads a Jeff spec (SOUL.md, AGENTS.md, MEMORY.md, daily notes) from --spec.
Wraps a model backend (Ollama OpenAI-compat by default).
Exposes A2A endpoints on localhost. Optionally serves a human chat UI.

Usage:
    jeff_a2a_server.py --spec <dir> --model-endpoint http://127.0.0.1:11434 --port 3001 --label jeff-a

Endpoints:
    GET  /api/a2a/agent-card     — capabilities + skills
    GET  /api/a2a/health         — status
    POST /api/a2a/message        — send a message, get a reply
    GET  /                       — human chat UI
"""

import argparse
import json
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional, Tuple
from typing import Optional

try:
    import httpx
except ImportError:
    print("ERROR: httpx not installed. Run: pip3 install httpx", file=sys.stderr)
    sys.exit(1)


# -------- config -----------------------------------------------------------

A2A_VERSION = "0.2"
AGENT_NAME = "Jeff"
AGENT_VERSION = "0.1"
PRINCIPAL_NAME = "the user"  # overridable via --principal

INDEX_HTML = """<!doctype html>
<html><head><title>Jeff A2A</title>
<style>
body { font-family: -apple-system, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 20px; }
#log { border: 1px solid #ccc; padding: 10px; height: 400px; overflow-y: auto; background: #f8f8f8; }
.you { color: #0066cc; } .jeff { color: #333; } .meta { color: #888; font-size: 0.85em; }
input { width: 80%; padding: 8px; } button { padding: 8px 16px; }
</style></head>
<body>
<h1>Jeff A2A Server</h1>
<p class="meta">spec: <code>__SPEC__</code> &middot; model: <code>__MODEL__</code> &middot; label: <code>__LABEL__</code></p>
<div id="log"></div>
<p><input id="msg" placeholder="Type a message..." autofocus><button onclick="send()">Send</button></p>
<script>
const log = document.getElementById('log');
const msg = document.getElementById('msg');
const threadId = 'web-' + Date.now();
function append(role, text, meta) {
  const d = document.createElement('div');
  d.innerHTML = '<span class="' + role + '"><b>' + (role === 'you' ? 'You' : 'Jeff') + ':</b></span> ' + text;
  if (meta) { const m = document.createElement('div'); m.className = 'meta'; m.textContent = meta; d.appendChild(m); }
  log.appendChild(d); log.scrollTop = log.scrollHeight;
}
async function send() {
  const m = msg.value.trim(); if (!m) return;
  append('you', m); msg.value = '';
  const t0 = performance.now();
  const r = await fetch('/api/a2a/message', { method: 'POST', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ id: threadId, message: m, from: 'web-ui' }) });
  const j = await r.json();
  const ms = (performance.now() - t0).toFixed(0);
  append('jeff', j.reply, 'memory_facts: ' + (j.memory_facts_used||[]).join(', ') + ' &middot; ' + ms + 'ms &middot; ' + (j.tokens_in||'?') + '/' + (j.tokens_out||'?') + ' tok');
}
msg.addEventListener('keydown', e => { if (e.key === 'Enter') send(); });
</script>
</body></html>
"""


# -------- spec + memory ---------------------------------------------------

def load_spec(spec_dir: Path, memory_snapshot: Optional[Path] = None):
    """Load SOUL.md, AGENTS.md, USER.md, TOOLS.md, MEMORY.md, daily notes."""
    def safe_read(name):
        p = spec_dir / name
        return p.read_text() if p.exists() else ""

    soul = safe_read("SOUL.md")
    agents = safe_read("AGENTS.md")
    user = safe_read("USER.md")
    tools = safe_read("TOOLS.md")

    mem_path = memory_snapshot or (spec_dir / "MEMORY.md")
    memory = mem_path.read_text() if mem_path.exists() else ""

    daily = []
    daily_dir = spec_dir / "memory"
    if daily_dir.is_dir():
        for f in sorted(daily_dir.glob("*.md")):
            daily.append((f.name, f.read_text()))

    return {
        "soul": soul, "agents": agents, "user": user, "tools": tools,
        "memory": memory, "memory_path": str(mem_path),
        "daily": daily,
    }


def build_system_prompt(spec: dict, principal: str = "the user") -> str:
    parts = [
        f"You are {AGENT_NAME}. The principal is {principal}.",
        "",
        "# SOUL (constitution)",
        spec["soul"],
        "",
        "# AGENTS (operating rules)",
        spec["agents"],
        "",
        "# USER (principal)",
        spec["user"],
        "",
        "# TOOLS (local environment)",
        spec["tools"],
        "",
        "# MEMORY (long-term facts)",
        spec["memory"][:12000],  # cap to keep prompt sane
    ]
    return "\n".join(parts)


def search_memory(query: str, spec: dict, top_k: int = 5) -> list[Tuple[int, str, int, str]]:
    """Substring + token-overlap search across MEMORY.md and daily notes."""
    q_tokens = set(re.findall(r"\w+", query.lower()))
    if not q_tokens:
        return []

    candidates = []
    if spec["memory"]:
        for ln, line in enumerate(spec["memory"].splitlines(), 1):
            lt = set(re.findall(r"\w+", line.lower()))
            overlap = len(q_tokens & lt)
            if overlap >= 2:
                candidates.append((overlap, spec["memory_path"], ln, line.strip()))

    for fname, content in spec["daily"]:
        for ln, line in enumerate(content.splitlines(), 1):
            lt = set(re.findall(r"\w+", line.lower()))
            overlap = len(q_tokens & lt)
            if overlap >= 2:
                candidates.append((overlap, f"memory/{fname}", ln, line.strip()))

    candidates.sort(reverse=True)
    return candidates[:top_k]


# -------- model client ----------------------------------------------------

def call_model(system: str, history: list, user_message: str, endpoint: str, model: str, timeout: int = 120) -> tuple[str, int, int]:
    """Call OpenAI-compat /v1/chat/completions. Returns (reply, tokens_in, tokens_out)."""
    messages = [{"role": "system", "content": system}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    url = endpoint.rstrip("/") + "/v1/chat/completions"
    payload = {"model": model, "messages": messages, "temperature": 0.7}
    r = httpx.post(url, json=payload, timeout=timeout)
    r.raise_for_status()
    data = r.json()
    reply = data["choices"][0]["message"]["content"]
    usage = data.get("usage", {})
    return reply, usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)


# -------- server state ----------------------------------------------------

class JeffServer:
    def __init__(self, spec_dir: Path, model: str, model_endpoint: str, label: str, memory_snapshot: Optional[Path], principal: str = "the user"):
        self.spec = load_spec(spec_dir, memory_snapshot)
        self.system = build_system_prompt(self.spec, principal=self.principal)
        self.model = model
        self.model_endpoint = model_endpoint
        self.label = label
        self.principal = principal
        self.history: dict[str, list] = {}
        self.started_at = time.time()

    def agent_card(self) -> dict:
        return {
            "name": AGENT_NAME, "version": AGENT_VERSION,
            "label": self.label, "protocol": f"a2a/{A2A_VERSION}",
            "capabilities": {"streaming": False, "pushNotifications": False, "stateTransitionHistory": False},
            "skills": [
                {"id": "reason", "description": "Reason in the principal's voice using local memory (SOUL.md, MEMORY.md, daily notes)."},
                {"id": "council", "description": "Participate in a council: position, cross-examination, vote with dissent."},
                {"id": "remember", "description": "Suggest memory updates; host Jeff decides whether to commit."},
            ],
            "endpoints": {"agent_card": "/api/a2a/agent-card", "message": "/api/a2a/message", "health": "/api/a2a/health"},
        }

    def health(self) -> dict:
        return {
            "status": "ok", "label": self.label, "model": self.model,
            "uptime_seconds": int(time.time() - self.started_at),
            "memory_facts": len(self.spec["memory"].splitlines()),
            "daily_notes": len(self.spec["daily"]),
            "active_threads": len(self.history),
        }

    def handle_message(self, thread_id: str, message: str, from_label: str, context: Optional[list] = None) -> dict:
        if context is not None:
            self.history[thread_id] = context
        elif thread_id not in self.history:
            self.history[thread_id] = []

        facts = search_memory(message, self.spec)
        fact_lines = [f"[{f}:{ln}] {line}" for _, f, ln, line in facts]
        memory_block = "\n".join(fact_lines) if fact_lines else "(no memory facts matched)"
        enriched = f"[memory_facts]\n{memory_block}\n\n[message]\n{message}"

        t0 = time.time()
        try:
            reply, tin, tout = call_model(self.system, self.history[thread_id], enriched, self.model_endpoint, self.model)
        except Exception as e:
            reply = f"[error: {e}]"
            tin, tout = 0, 0
        dur_ms = int((time.time() - t0) * 1000)

        self.history[thread_id].append({"role": "user", "content": message})
        self.history[thread_id].append({"role": "assistant", "content": reply})
        self.history[thread_id] = self.history[thread_id][-40:]  # bound

        return {
            "id": thread_id,
            "reply": reply,
            "model": self.model,
            "memory_facts_used": [f"{f}:{ln}" for _, f, ln, _ in facts],
            "tokens_in": tin, "tokens_out": tout, "duration_ms": dur_ms,
            "from": self.label, "to": from_label,
        }


# -------- HTTP handler ----------------------------------------------------

def make_handler(server: JeffServer):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            sys.stderr.write(f"[{server.label}] {self.address_string()} {fmt % args}\n")

        def _json(self, code: int, payload: dict):
            body = json.dumps(payload, indent=2).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _html(self, body: str):
            body = body.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == "/api/a2a/agent-card":
                self._json(200, server.agent_card())
            elif self.path == "/api/a2a/health":
                self._json(200, server.health())
            elif self.path == "/" or self.path == "/index.html":
                html = (INDEX_HTML
                        .replace("__SPEC__", str(server.spec["memory_path"]))
                        .replace("__MODEL__", server.model)
                        .replace("__LABEL__", server.label))
                self._html(html)
            else:
                self._json(404, {"error": "not found", "path": self.path})

        def do_POST(self):
            if self.path != "/api/a2a/message":
                self._json(404, {"error": "not found"})
                return
            length = int(self.headers.get("Content-Length", 0))
            try:
                data = json.loads(self.rfile.read(length))
            except json.JSONDecodeError as e:
                self._json(400, {"error": f"bad json: {e}"})
                return
            thread_id = data.get("id") or f"thread-{int(time.time())}"
            message = data.get("message", "").strip()
            from_label = data.get("from", "unknown")
            context = data.get("context")
            if not message:
                self._json(400, {"error": "message is required"})
                return
            result = server.handle_message(thread_id, message, from_label, context)
            self._json(200, result)

    return Handler


# -------- main ------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description="Serve a Jeff as an A2A agent.")
    p.add_argument("--spec", type=Path, required=True, help="Path to Jeff spec directory")
    p.add_argument("--model", default="minimax-m3:cloud", help="Model name (default: a reasonable Ollama cloud model — override per your setup)")
    p.add_argument("--model-endpoint", default="http://127.0.0.1:11434",
                   help="OpenAI-compat endpoint (default: Ollama on 11434)")
    p.add_argument("--port", type=int, default=3001, help="Port to listen on (default: 3001)")
    p.add_argument("--label", default="jeff", help="This Jeff's label (for logs + agent-card)")
    p.add_argument("--memory-snapshot", type=Path, default=None, help="Override MEMORY.md with this file")
    p.add_argument("--host", default="127.0.0.1", help="Bind host (default: 127.0.0.1)")
    p.add_argument("--principal", default="the user", help="What to call the principal in the system prompt (default: the user)")
    args = p.parse_args()

    if not args.spec.is_dir():
        print(f"ERROR: --spec {args.spec} is not a directory", file=sys.stderr)
        sys.exit(1)

    server = JeffServer(args.spec, args.model, args.model_endpoint, args.label, args.memory_snapshot, principal=args.principal)
    handler = make_handler(server)
    httpd = ThreadingHTTPServer((args.host, args.port), handler)

    print(f"[{args.label}] Jeff A2A server ready on http://{args.host}:{args.port}", flush=True)
    print(f"  spec:    {args.spec}", flush=True)
    print(f"  model:   {args.model} @ {args.model_endpoint}", flush=True)
    print(f"  card:    http://{args.host}:{args.port}/api/a2a/agent-card", flush=True)
    print(f"  ui:      http://{args.host}:{args.port}/", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{args.label}] shutting down", flush=True)


if __name__ == "__main__":
    main()
