# State and pinned slots — `pin(key)` rendering in the system prompt

Cross-run state for an agent is stored via the `pin({ key, content, scope? })` system tool. The persisted entries live in the `package_persistence` table, but **how the agent reads them back at the next run depends on the platform version**. This document covers the runtime behavior, the recommended prompt pattern, and three anti-patterns that cost ~30 min of debug each if missed.

---

## Storage vs prompt rendering

`pin(key, content)` accepts any key matching `^[a-z0-9_]+$` (max 64 chars) and stores the entry verbatim. The platform always writes successfully — the question is how it surfaces back at the next run.

**Without the `## Pinned Slots` patch** (`apps/api` < commit `ebaa95c7` on `bugs-evos-oli`) — original behaviour:
- Only `key="checkpoint"` is rendered, in section `## Checkpoint` of the system prompt.
- Any other key is **stored but never rendered** in the prompt — the slot is reachable only via `GET /api/agents/.../persistence` (admin/debug), never by the agent at the next run.
- Consequence: an agent that writes `pin(key="sync_state", ...)` cannot read it back next run → silently re-processes everything (the bug pattern that triggered the patch).

**With the `## Pinned Slots` patch** (commit `ebaa95c7`) — behaviour aligned with the docstring:
- `key="checkpoint"` still renders in `## Checkpoint` (unchanged).
- Any other key renders in a new `## Pinned Slots` section, with each slot as a `### <key>` subheading. Plain string contents render as-is; structured contents are wrapped in a fenced JSON block. Keys are sorted alphabetically for deterministic output.

---

## Recommended pattern for cross-run state

**Reading**: from the **system prompt**, NOT via a tool call.

In `prompt.md`:

```md
## 1. Read persistent state — FROM YOUR SYSTEM PROMPT, NOT VIA A TOOL

State is stored via `pin(key="<your-key>", ...)`. At run start, the value
is **automatically injected** into your system prompt:
- `key="checkpoint"` → section `## Checkpoint`
- `key="<custom>"` (with platform patch ebaa95c7) → section `## Pinned Slots > <custom>`

**DO NOT call any tool to read it** — not `recall_memory`, not `note`, not
`run_history`. The content is already in your context. If the section is
absent: this is the first run → start with the default value.
```

**Writing**: at the end of the run.

```ts
// Single carry-over slot (always works, all platform versions)
await pin({ key: "checkpoint", content: { processed_ids: [...], last_sync: "..." }, scope: "shared" });

// Multiple named slots (requires platform patch ebaa95c7)
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

`key="checkpoint"` is special: it always renders in `## Checkpoint` (its own dedicated section), separately from `## Pinned Slots`. Use it as the **principal cross-run carry-over slot**. Any other key (`persona`, `goals`, `last_<thing>`, `sync_state`, etc.) renders in `## Pinned Slots > <key>` once the platform patch is applied.

The PINNED_KEY_PATTERN is `^[a-z0-9_]+$` (max 64 chars) — kebab-case (`sync-state`) is rejected, use snake_case (`sync_state`).

---

## Common Errors entries (cross-reference for `SKILL.md`)

| Error | Cause | Fix |
|-------|-------|-----|
| Agent re-processes the same data on every run even though `pin(key=...)` was called and persisted | Without platform patch `ebaa95c7`, only `key="checkpoint"` is rendered in the prompt. Any other key is stored but never read. | With patch: any key is rendered in `## Pinned Slots`. Without patch: rename to `key="checkpoint"` and bundle multiple slots into one JSON object under that key. |
| Agent calls `recall_memory` or `run_history` to read a `pin` and gets `[]` | `recall_memory` searches the archive (notes), not pinned slots. `run_history` returns past-run metadata, not the current pin state. No native tool reads pins. | The pin auto-injects into `## Checkpoint` (key="checkpoint") or `## Pinned Slots > <key>` (others, with patch). Update the prompt: "read from the section, not via a tool call". |
| `Invalid pinned slot key "foo-bar"` from `pin` | Pattern `^[a-z0-9_]+$` rejects hyphens | Use snake_case: `foo_bar` |

---

## Related platform patches

This document assumes the platform patches on branch `bugs-evos-oli` of `appstrate/appstrate` (or upstream once merged):

- **`ebaa95c7`** — `feat(prompt): render named pinned slots in '## Pinned Slots' section` — enables the multi-slot pattern. Without this patch, only `key="checkpoint"` is visible at the next run.
- **`2f450027`** — `fix(prompt): only mention ./documents/ in Workspace bullet when uploads exist` — removes a related false signal in the same `## System` section (no impact on pin rendering, but in the same prompt-builder file).

If you're targeting a stock Appstrate install (no patches), use `key="checkpoint"` exclusively and bundle all your state into one JSON object under that key. The "multi named slots" pattern only works with `ebaa95c7` applied.
