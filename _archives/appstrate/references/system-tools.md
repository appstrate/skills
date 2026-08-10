# Appstrate System Tools

System tools are platform-provided tools that agents can use at runtime. They are NOT available by default — each tool must be declared in `dependencies.tools` in the manifest to be activated.

## Discovery

List available tools in the org:
```bash
appstrate api GET /api/packages/tools
```

Activate tools for an existing agent via API:
```bash
appstrate api PUT /api/agents/@scope/name/tools \
  -H 'Content-Type: application/json' \
  -d '{"toolIds": ["@appstrate/output", "@appstrate/set-state"]}'
```

Or declare in manifest (preferred — activated at import):
```json
"dependencies": {
  "tools": {
    "@appstrate/output": "^1.0.0",
    "@appstrate/set-state": "^1.0.0"
  }
}
```

## Tool Reference

### `@appstrate/output` — Return structured data

Returns data as the run result. Each call is deep-merged into the final output, validated against the output schema (AJV) after the run completes.

**When to use**: Agent has an `output` schema defined in its manifest and needs to return structured JSON results.

**Without this tool**: Run completes with `result: {}` even on success — the agent has no way to submit structured data.

**In prompt.md**: Instruct the agent to call the `output` tool with a `data` parameter matching the output schema. Multiple calls are merged.

```markdown
Use the `output` tool to return results:
output({ "summary": "...", "itemCount": 42 })
```

### `@appstrate/report` — Generate a markdown report

Produces a markdown report included in the run result alongside structured output.

**When to use**: Agent should produce a human-readable narrative (summary, analysis, formatted results) in addition to or instead of structured data.

**In prompt.md**: Instruct the agent to call `report` with markdown content.

### `@appstrate/set-state` — Persist state between runs

Saves state that is injected as `## Previous State` on the next run. Overwrites previous state entirely.

**When to use**: Recurring/scheduled agents that need to track progress — sync cursors, timestamps, pagination tokens.

**In prompt.md**:
```markdown
Check `## Previous State` for `lastSyncTimestamp`.
- First run: process all items from last 7 days.
- Subsequent runs: only items after `lastSyncTimestamp`.
Call `set-state` with `{ "lastSyncTimestamp": "<now>" }` before finishing.
```

> **Note (post-ADR-011/012/013)** — modern agents should prefer `pin({ key, content, scope })` instead of `set-state`. `pin` writes to the unified `package_persistence` store with explicit scoping (`shared` / `member` / `end_user`) and renders into the system prompt as `## Checkpoint` (for `key="checkpoint"`) or `## Pinned Slots > <key>` (for any other key, requires platform patch — see `references/state-and-checkpoint.md`). Anti-pattern reminder: do NOT call `recall_memory` to read a pin — it searches the archive (notes), not pinned slots. Read pins from the prompt sections, never via tool call.

### `@appstrate/add-memory` — Long-term learning

Saves a discovery or learning as a long-term memory. Memories are injected into future runs and persist across versions.

**When to use**: Agent should learn patterns, preferences, or API quirks across runs (e.g., "this endpoint returns dates in UTC", "user prefers bullet points").

**In prompt.md**: Instruct the agent to call `add-memory` when it discovers something worth remembering.

### `@appstrate/log` — Real-time progress messages

Sends progress messages visible to the user in real time (via SSE).

**When to use**: Long-running agents where the user benefits from seeing intermediate progress (e.g., "Processing page 3/10...").

**In prompt.md**: Instruct the agent to call `log` at key milestones.

## MCP-injected tools (sidecar surface)

Three MCP tools are auto-injected by the sidecar into every agent run — the agent always sees them in its tool list, no manifest declaration needed:

- **`provider_call({ providerId, method, target, headers?, body?, ... })`** — credentialed proxy. The sidecar resolves the provider's stored credentials and forwards the request to the upstream URL. Returns the upstream response verbatim. The credential is **never** visible to the agent. The `providerId` enum is sourced from your agent's `dependencies.providers[]`.
  > **Responses ≥ 32 KB**: the body is spilled to a `BlobStore` and returned as an MCP `resource_link` block instead of inline `text`. To resolve from a custom tool, use `ctx.readResource(uri)` (the 4th `execute` arg, runtime-pi >= 1.0.0-beta.7) — without it `result.content[0].text` will silently come back empty for non-trivial responses. Full pattern + 5 gotchas: see `references/large-responses.md`.
- **`run_history({ limit?, fields? })`** — recent past-run metadata (status, duration, optional `checkpoint` and `result`). Useful for trend analysis, auditing, or recovering from a failed run.
- **`recall_memory({ q?, limit? })`** — search the agent's archive (rows written via the `note(content)` system tool). **Does NOT search pinned slots written by `pin(key, content)`** — those are auto-injected into the prompt, not retrievable via tool call. See `references/state-and-checkpoint.md`.

These tools are documented to the LLM at runtime via the prompt builder; no skill-side action needed beyond declaring `dependencies.providers[]` for `provider_call`.

## Decision Guide

| Agent type | Recommended tools |
|------------|------------------|
| One-shot with structured output | `output` |
| One-shot with report | `report` (+ `output` if also needs structured data) |
| Recurring/scheduled (sync, digest) | `output` + `set-state` |
| Learning agent (improves over time) | `output` + `add-memory` |
| Long-running (> 30s) | Add `log` to any of the above |
