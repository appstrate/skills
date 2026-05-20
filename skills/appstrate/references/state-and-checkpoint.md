# State and pinned slots — `pin(key)` rendering in the system prompt

Cross-run state for an agent is stored via the `pin({ key, content, scope? })` system tool. The persisted entries live in the `package_persistence` table and are surfaced to the next run as **sections in the system prompt** — no tool call needed to read them back. This document covers the rendering rules, the recommended prompt pattern, and a handful of gotchas that each cost ~30 min of debug if missed.

---

## Storage vs prompt rendering

`pin(key, content)` accepts any key matching `^[a-z0-9_]+$` (max 64 chars) and stores the entry verbatim. The platform always writes successfully — and on current upstream `main` (since [PR #362](https://github.com/appstrate/appstrate/pull/362), merged ~2026-05-08), the rendering rules are:

- `key="checkpoint"` renders in section `## Checkpoint` of the system prompt (dedicated, single slot).
- Any other key renders in `## Pinned Slots`, with each slot as a `### <key>` subheading. Plain string contents render as-is; structured contents are wrapped in a fenced JSON block. Keys are sorted alphabetically for deterministic output.

> **Pre-2026-05-08 installs**: only `key="checkpoint"` was rendered. Any other key was stored but never surfaced — the slot was reachable only via `GET /api/agents/.../persistence` (admin/debug). Agents that wrote `pin(key="sync_state", ...)` couldn't read it back next run, silently re-processing everything. Fix: update the install, or fall back to a single `key="checkpoint"` slot bundling all your state as a JSON object.

---

## Recommended pattern for cross-run state

**Reading**: from the **system prompt**, NOT via a tool call.

In `prompt.md`:

```md
## 1. Read persistent state — FROM YOUR SYSTEM PROMPT, NOT VIA A TOOL

State is stored via `pin(key="<your-key>", ...)`. At run start, the value
is **automatically injected** into your system prompt:
- `key="checkpoint"` → section `## Checkpoint`
- `key="<custom>"` → section `## Pinned Slots > <custom>`

**DO NOT call any tool to read it** — not `recall_memory`, not `note`, not
`run_history`. The content is already in your context. If the section is
absent: this is the first run → start with the default value.
```

**Writing**: at the end of the run.

```ts
// Single carry-over slot
await pin({ key: "checkpoint", content: { processed_ids: [...], last_sync: "..." }, scope: "shared" });

// Multiple named slots
await pin({ key: "persona", content: "You are a friendly assistant.", scope: "shared" });
await pin({ key: "goals", content: ["maximize accuracy", "respect user time"], scope: "shared" });
await pin({ key: "last_processed_id", content: 142828058, scope: "shared" });
```

---

## Five gotchas

### 1. `recall_memory` does NOT read pinned slots — anti-pattern

The MCP tool `recall_memory({ q?, limit? })` searches the **archive** (entries written via `note(content)`, `pinned=false`, `key=null`). It silently returns `[]` when no notes match — including when you wrote a `pin({ key: "sync_state", ... })` and expected it back. The agent will conclude "first run, no state" even though the slot is in the DB.

The correct read path is **the system prompt itself** (`## Checkpoint` for the `checkpoint` slot, `## Pinned Slots > <key>` for others). No tool call required.

### 2. `scope: "shared"` recommended for app-wide state

By default, `pin` scopes to the current actor (member or end_user). For an agent whose state should be visible regardless of the trigger (cron, end-user, dashboard user), pass `scope: "shared"` explicitly. Otherwise:

- A scheduled cron run writes to `scope: "shared"` automatically (system actor).
- A dashboard user run writes to their member scope.
- An end-user impersonated run writes to that end-user's scope.

These three buckets are isolated by design (cross-actor reads would leak state). If you want one bucket for the whole app, always pass `scope: "shared"`.

### 3. No native MCP tool to list pins by key from the agent

There's no `list_pins({ key? })` MCP tool. The agent's only read paths are the prompt sections and (indirectly) `recall_memory` for archive notes. If you genuinely need to enumerate slots from inside a run, you can't — design around it (use a single `checkpoint` slot with structured content instead of N independent slots).

The admin endpoint `GET /api/agents/{scope}/{name}/persistence` lists all stored slots, but it's not callable from the runtime — only from the dashboard/CLI/admin SDK.

### 4. `/persistence` response shape is `{ pinned: [...], memories: [...] }`

The admin endpoint returns `{ pinned: [{id, key, content, runId, ...}], memories: [{id, content, runId, ...}] }`. **NOT** the standard `{ data: [...] }` envelope. Easy to miss when scripting against the API — `jq '.data'` will silently return `null`.

### 5. The reserved key `"checkpoint"`

`key="checkpoint"` is special: it always renders in `## Checkpoint` (its own dedicated section), separately from `## Pinned Slots`. Use it as the **principal cross-run carry-over slot**. Any other key (`persona`, `goals`, `last_<thing>`, `sync_state`, etc.) renders in `## Pinned Slots > <key>`.

The PINNED_KEY_PATTERN is `^[a-z0-9_]+$` (max 64 chars) — kebab-case (`sync-state`) is rejected, use snake_case (`sync_state`).

---

## Common Errors entries (cross-reference for `SKILL.md`)

| Error | Cause | Fix |
|-------|-------|-----|
| Agent re-processes the same data on every run even though `pin(key=...)` was called and persisted | Pre-2026-05-08 install: only `key="checkpoint"` rendered in the prompt. Any other key stored but never surfaced. | Update the install (PR #362 merged). Without the fix: rename to `key="checkpoint"` and bundle multiple slots into one JSON object. |
| Agent calls `recall_memory` or `run_history` to read a `pin` and gets `[]` | `recall_memory` searches the archive (notes), not pinned slots. `run_history` returns past-run metadata, not the current pin state. No native tool reads pins. | The pin auto-injects into `## Checkpoint` (key="checkpoint") or `## Pinned Slots > <key>` (others). Update the prompt: "read from the section, not via a tool call". |
| `Invalid pinned slot key "foo-bar"` from `pin` | Pattern `^[a-z0-9_]+$` rejects hyphens | Use snake_case: `foo_bar` |
