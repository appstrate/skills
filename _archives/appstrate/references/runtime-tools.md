# Appstrate Runtime Tools + Sidecar MCP Surface

Two distinct families of tools reach an agent at runtime. Neither is a package dependency anymore — there is no `dependencies.tools` and there are no `@appstrate/output`-style tool packages.

1. **Runtime tools** — five platform built-ins (`output`, `log`, `note`, `pin`, `report`), opt-in per agent via the top-level `runtime_tools` array. Hosted as MCP tools by the sidecar (and as Pi extensions on the CLI `appstrate run` path).
2. **Sidecar MCP tools** — `run_history`, `recall_memory`, and per-integration tools (`{ns}__api_call`, `{ns}__{tool}`, `{ns}__api_upload`). Advertised to the model via MCP `tools/list`.

The agent discovers every tool through `tools/list` — **the prompt never lists tools** (see `prompt-writing.md`). Each tool is self-documented by its MCP `description` + input schema.

## Runtime tools — `runtime_tools`

Nothing is injected by default. Declare what the agent needs in the manifest:

```json
"runtime_tools": ["output", "report"]
```

Closed enum: `["output", "log", "note", "pin", "report"]`. A value outside this set is rejected at validation.

> **`output` is required iff the agent declares a non-empty `output.schema`.** The validator (`agentManifestSchema` superRefine) rejects a manifest that declares an output schema but omits `"output"` from `runtime_tools`. An agent with no output schema may legitimately finish without ever calling `output` (a side-effect-only run is a valid success).

### `output({ data })`
Returns the run's structured result. `data` is validated (AJV) against `output.schema`. Call at most once (last write wins). Read back via `result.output.<field>` (NOT `result.<field>` — see `manifest-schema.md` §Output schema).

### `report({ content })`
Appends markdown to the run report. When selected, its MCP description is **"MANDATORY — call at least once before finishing"** (a behavioural contract once loaded, not an install-time gate). Use for the human-readable narrative.

### `log({ level, message })`
Real-time progress to the user via SSE. `level ∈ "info" | "warn" | "error"`.

### `note({ content, scope? })`
Long-term memory archive (`content` ≤ 2000 chars, `scope ∈ "actor" | "shared"`, default `actor`). Written here, read back via the `recall_memory` MCP tool. Not rendered in the prompt.

### `pin({ key, content, scope? })`
Named pinned slot. `key` matches `^[a-z0-9_]+$` (≤ 64). The reserved key `"checkpoint"` is the carry-over slot rendered as `## Checkpoint`; any other key renders under `## Pinned Slots > <key>`. Last write wins per `(scope, key)`. See `state-and-checkpoint.md`.

> **Anti-pattern**: do NOT call `recall_memory` to read a pin — it searches the `note` archive, not pinned slots. Pins are auto-injected into the prompt (data-only sections); read them there.

## Sidecar MCP tools

### First-party (not namespaced)
- **`run_history({ limit?, fields? })`** — recent past-run metadata. `limit` 1–50 (default 10), `fields ⊆ ["checkpoint","result"]`. Returns `{ object, data, hasMore }`.
- **`recall_memory({ q?, limit? })`** — substring search over the `note` archive. The argument is **`q`** (not `query`), `limit` 1–50.

### Per-integration (namespaced `{ns}__`)
For each integration the agent depends on, the sidecar exposes:
- **`{ns}__api_call({ target, method?, headers?, body?, responseMode?, substituteBody? })`** — credential-injecting proxy. **Replaces the old global `provider_call`** (no compat alias). The integration + auth are implicit in the tool name — there is no `providerId` argument. `target` must match the auth's `authorized_uris` (or be non-private when `allow_all_uris`). `body` is `string | { fromBytes, encoding:"base64" } | { multipart:[…] }`. The credential is injected server-side and never visible to the agent.
  - One opted-in auth → `api_call`; multiple → `api_call__{authKey}`.
  - `substituteBody: true` substitutes `{{placeholders}}` inside a string body server-side (distinct from the manifest's `{$credential.…}` delivery syntax — see `create-integration.md`).
  - Responses ≥ **32 KB** (or non-text) spill to a blob and come back as an MCP `resource_link` (URI `appstrate://api-response/{runId}/{ulid}`). Resolve via `ctx.readResource(uri)`; they are also auto-spilled to the workspace. Full pattern + gotchas: `large-responses.md`.
  - Result `_meta["dev.appstrate/upstream"] = { status, headers, finalUrl? }` (`status: 0` = preflight, no upstream contact).
- **`{ns}__api_upload(...)`** — chunked/resumable upload, exposed only when the integration's auth declares `upload_protocols`. Executed agent-side.
- **`{ns}__{tool}`** — any tool advertised by the integration's MCP server (`source.kind: local | remote`), forwarded verbatim and gated by the agent's `integrations_configuration.<id>.tools` allowlist.

## Decision guide

| Agent need | Use |
|---|---|
| Return structured JSON | `output` (required if `output.schema` declared) |
| Human-readable narrative | `report` |
| Live progress to the user | `log` |
| Carry state to the next run | `pin({ key:"checkpoint", … })` |
| Learn across runs | `note` (write) + `recall_memory` (read) |
| Call an external API | `{ns}__api_call` (declare the integration; see `create-integration.md`) |
| Use a packaged MCP server's tools | `{ns}__{tool}` (depend on the integration with `source.kind: local|remote`) |
