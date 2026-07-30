# `jeff_a2a_server.py` — Server Spec (v0.1)

**The minimum viable thing that turns a Jeff directory into an A2A agent.**

## What it is

A single Python 3.10+ script. No external dependencies beyond the standard library and one model HTTP client (httpx or requests). Runs in a terminal. Logs to stdout. Exits on Ctrl-C.

## What it does

1. Loads a Jeff spec from a directory.
2. Wraps a model backend.
3. Serves A2A endpoints on localhost.
4. (Optional) Serves a human chat UI at `/`.

## CLI

```
jeff_a2a_server.py \
  --spec <dir>            # path to Jeff spec (contains SOUL.md, AGENTS.md, MEMORY.md)
  --model <backend>       # ollama / kimi / glm / claude / openai-compat
  --model-endpoint <url>  # e.g. http://127.0.0.1:11434 for Ollama
  --port <port>           # default 3001
  --label <name>          # e.g. jeff-a — appears in logs and agent-card
  --memory-snapshot <f>   # (optional) override memory with a specific file
  --quiet                 # suppress non-error logs
```

## Endpoints

### `GET /api/a2a/agent-card`

Returns the agent card (see README.md for shape).

### `GET /api/a2a/health`

Returns `{"status": "ok", "model": "ollama/minimax-m3:cloud", "memory_files": 14}`.

### `POST /api/a2a/message`

Request:
```json
{
  "id": "thread-label-2026-07-23-14-15",
  "message": "What was the principal's working set at 14:14?",
  "from": "jeff-a@example-host",
  "context": []   // optional, prior turns in the thread
}
```

Response:
```json
{
  "id": "thread-label-2026-07-23-14-15",
  "reply": "Working set at 14:14: ...",
  "model": "ollama/minimax-m3:cloud",
  "memory_facts_used": ["MEMORY.md:142", "memory/2026-07-23.md:25"],
  "tokens_in": 1850,
  "tokens_out": 320,
  "duration_ms": 4320
}
```

### `GET /` (optional, human chat UI)

A single HTML page with a textarea. POSTs to `/api/a2a/message`. Shows the reply + memory_facts_used. For "I just want to talk to my recovered Jeff" cases.

## Internal architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flask app (or http.server)                                 │
│                                                              │
│  ┌──────────────┐  ┌────────────────┐  ┌────────────────┐  │
│  │  /agent-card │  │  /message POST │  │  /health GET   │  │
│  └──────────────┘  └────────────────┘  └────────────────┘  │
│                            │                                │
│                            ▼                                │
│                  ┌──────────────────┐                       │
│                  │  JeffSession     │                       │
│                  │  ─────────────   │                       │
│                  │  - spec_loader   │  → loads SOUL.md,     │
│                  │                  │    AGENTS.md,         │
│                  │                  │    MEMORY.md, daily    │
│                  │                  │    notes from --spec   │
│                  │  - memory_search │  → substring + score   │
│                  │                  │    over memory files   │
│                  │  - model_client  │  → HTTP to --model-    │
│                  │                  │    endpoint             │
│                  │  - history_cache │  → per-thread memory    │
│                  │                  │    of conversation      │
│                  └──────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

## The model call (the heart of it)

```python
def call_model(system_prompt, history, user_message, model_endpoint, model_name):
    # Build the messages array
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})
    
    # POST to model
    response = httpx.post(
        f"{model_endpoint}/v1/chat/completions",
        json={"model": model_name, "messages": messages},
        timeout=120
    )
    return response.json()["choices"][0]["message"]["content"]
```

That's the whole model integration. Ollama, vLLM, LM Studio, Claude (with auth), OpenAI — all speak the OpenAI chat completions shape. One function, many backends.

## The system prompt (the soul of it)

```python
def build_system_prompt(spec_dir, memory_snapshot=None):
    soul = (spec_dir / "SOUL.md").read_text()
    agents = (spec_dir / "AGENTS.md").read_text()
    user = (spec_dir / "USER.md").read_text()
    tools = (spec_dir / "TOOLS.md").read_text()
    
    memory = ""
    memory_path = memory_snapshot or (spec_dir / "MEMORY.md")
    if memory_path.exists():
        memory = memory_path.read_text()
    
    return f"""You are Jeff. The principal is <the-principal>.

{soul}

{agents}

{user}

{tools}

# Memory

{memory}

# Operating rule

Answer in the principal's voice. Cite memory facts by file:line when you use them.
If you don't know, say so — don't make things up. Be warm, not corporate.
"""
```

## The memory search (the load-bearing bit)

```python
def search_memory(query, spec_dir, top_k=5):
    """Substring + score over MEMORY.md and daily notes."""
    candidates = []
    
    memory_files = [spec_dir / "MEMORY.md"]
    memory_files.extend((spec_dir / "memory").glob("*.md"))
    
    query_tokens = set(query.lower().split())
    
    for f in memory_files:
        if not f.exists():
            continue
        for line_num, line in enumerate(f.read_text().splitlines(), 1):
            line_tokens = set(line.lower().split())
            overlap = len(query_tokens & line_tokens)
            if overlap >= 2:  # at least 2 tokens in common
                candidates.append((overlap, str(f), line_num, line))
    
    candidates.sort(reverse=True)
    return candidates[:top_k]
```

This is the "remember when the principal asked X" pathway. Crude, but for v0.1 it works. v0.2 adds vector search.

## History cache (per-thread state)

```python
history = {}  # thread_id → list of {role, content}

def handle_message(thread_id, message, from_label, context=None):
    if context:
        history[thread_id] = context
    elif thread_id not in history:
        history[thread_id] = []
    
    # Prepend memory search results to the message
    facts = search_memory(message, spec_dir)
    memory_excerpt = "\n".join(f"{f}:{ln}: {l}" for _, f, ln, l in facts)
    enriched = f"[memory_facts]\n{memory_excerpt}\n\n[message]\n{message}"
    
    # Call model
    system = build_system_prompt(spec_dir)
    reply = call_model(system, history[thread_id], enriched, ...)
    
    # Update history
    history[thread_id].append({"role": "user", "content": message})
    history[thread_id].append({"role": "assistant", "content": reply})
    
    # Trim to last 20 turns to bound context
    history[thread_id] = history[thread_id][-40:]
    
    return {
        "id": thread_id,
        "reply": reply,
        "memory_facts_used": [f"{f}:{ln}" for _, f, ln, _ in facts],
    }
```

## What it does NOT do (v0.1 scope)

- ❌ Streaming (SSE) — defer to v0.2
- ❌ Auth tokens — defer to v0.3
- ❌ Persistent state across restarts — defer to v0.2
- ❌ Vector search — substring match is enough for v0.1
- ❌ Memory writes from remote — local-only by default
- ❌ Multi-agent orchestration — that's the council orchestrator, separate tool

## The line count (sanity check)

- CLI parsing: ~20 lines
- Flask app + endpoints: ~40 lines
- Spec loader + system prompt: ~30 lines
- Memory search: ~30 lines
- Model client: ~20 lines
- History cache: ~20 lines
- Human chat UI (HTML): ~30 lines (separate file)
- **Total: ~190 lines Python + 30 lines HTML**

The 100-line target was optimistic. 200 is honest. Still small.

## How to test it (the recovery test)

1. `python3 jeff_a2a_server.py --spec <kit>/private/recovery/public-archive/ --port 3001 --label jeff-a`
2. `curl -s http://127.0.0.1:3001/api/a2a/agent-card | jq .`
3. `curl -X POST http://127.0.0.1:3001/api/a2a/message -H 'Content-Type: application/json' -d '{"id":"t1","message":"Who is the principal?","from":"jeff-b"}'`
4. The reply should be a principal-aware Jeff, not a generic assistant. **That's the test.**

## Open design questions

1. **Should the server write logs to a file?** Stdout is fine for v0.1, but for "I want to see what my other Jeff did" a log file is nicer. Defer.

2. **Should `--model-endpoint` default to localhost Ollama?** Yes, that's the offline-first story.

3. **What's the default port?** 3001. (Other apps commonly use 3000. 3001 avoids conflict.)

4. **What about the v2.0 worked example?** It's already a valid Jeff directory (has SOUL.md, etc.). The same script should serve it. Yes — same code path, different spec.

5. **What about the private/ directory?** Same — has SOUL.md. Yes, same code path.

6. **Can two Jeffs talk to each other?** Yes. The script is symmetric. Jeff-A on 3001 can `curl` Jeff-B on 3002. No special "client mode" needed.

## Status

- Spec: drafted (this file)
- Implementation: not started
- Tests: not written
- First deployment: not scheduled
