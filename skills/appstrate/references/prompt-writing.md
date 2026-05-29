# Writing Effective prompt.md Files

The prompt is plain Markdown that the platform wraps with auto-injected sections (identity, container, data-only inputs, a Communication contract). Under AFPS 0.x the prompt does **two** things differently from the 1.x era:

1. **It never lists tools.** The agent discovers every tool through MCP `tools/list`; each is self-documented by its `description` + `inputSchema`. A list in the prompt would go stale and contradict the live list.
2. **All communication is routed through tool calls.** Any free text the agent emits outside a tool call is **never delivered to the user** — there is no chat channel. Results, status, questions, errors must all leave the run as a tool call.

## Table of Contents

- [Container Environment](#container-environment)
- [The Communication Contract](#the-communication-contract)
- [Never list tools in the prompt](#never-list-tools-in-the-prompt)
- [External APIs go through integration tools](#external-apis-go-through-integration-tools)
- [Auto-Injected Sections](#auto-injected-sections)
- [Placeholder Semantics](#placeholder-semantics)
- [Recommended Structure](#recommended-structure)
- [Memory](#memory)
- [Incremental Processing](#incremental-processing)
- [Common Mistakes](#common-mistakes)

## Container Environment

- **Runtimes**: Bun (primary) + Python3/pip
- **Working dir**: `/workspace`
- **Uploads**: `./documents/<filename>` (relative to cwd), only when the manifest field is wired as a file field (see `manifest-schema.md` §"File / upload fields"). If the system prompt has no `## Documents` section, the file wasn't injected — fix the manifest, don't search for the file.
- **Ephemeral**: destroyed after execution. Persist via `pin`/`note` and `output` only.
- **Network**: direct outbound HTTP/HTTPS for public endpoints. Authenticated external calls go through the integration's `{ns}__api_call` / `{ns}__{tool}` tools — never raw curl with a token (the agent never sees credentials).

## The Communication Contract

The platform auto-injects a `### Communication` section into every system prompt. Its rule:

> **Free text emitted outside a tool call is discarded.** To communicate anything — a result, a status update, a question, an error — call the appropriate tool.

| What the agent wants to do | Tool to use |
|---|---|
| Return the structured result | `output({ data })` (required if `output.schema` is declared) |
| Tell the user what happened (narrative) | `report({ content })` |
| Stream live progress | `log({ level, message })` |
| Make an external API call | `{ns}__api_call(...)` / `{ns}__{tool}(...)` |
| Carry state to the next run | `pin({ key, content })` |
| Record a learning for later runs | `note({ content })` |

You do **not** re-state this contract in `prompt.md` — it is injected. But write the prompt's instructions in terms of tool calls ("call `output` with …", "call `report` to summarize"), never "respond with…" or "print…", which would produce text that is silently dropped.

## Never list tools in the prompt

The `### Tools` / tool-doc sections that older prompts hand-wrote are gone. The agent enumerates tools via MCP `tools/list` at run start, and each tool carries its own `description` + `inputSchema`. Consequences for `prompt.md`:

- **Do not enumerate available tools.** A hard-coded list drifts from the live set (`runtime_tools` opt-ins, the per-integration `{ns}__*` tools, first-party `run_history`/`recall_memory`) and the agent will trust the live list over your prose.
- **Do not write usage prose for a tool** (arg names, examples, "the X tool takes a Y"). That belongs in the tool's MCP `description`/schema, or — for an integration — in its `INTEGRATION.md` (injected as `### API Documentation`).
- **Do** describe the *task* and the *order of operations* ("fetch the open issues, then summarize, then call `output`"). Reference tools by name where it clarifies a step; don't document their signatures.

## External APIs go through integration tools

There is no sidecar proxy URL, no `X-Provider`/`X-Target` headers, no `$SIDECAR_URL/proxy` for the agent to construct. Authenticated upstream access is mediated by the integration's MCP tools:

- **`{ns}__api_call({ target, method?, headers?, body?, responseMode?, substituteBody? })`** — credential-injecting REST proxy for a `source.kind: none` integration (and any integration opting into the `api_call` capability). The integration + auth are **implicit in the tool name** (no `providerId` argument). The credential is injected **server-side** and is never visible to the agent.
- **`{ns}__{tool}(...)`** — a tool advertised by the integration's own MCP server (`source.kind: local | remote`), gated by the agent's `integrations_configuration.<id>.tools` allowlist.

The agent learns the exact tool names, targets, and arguments from `tools/list` and the integration's `INTEGRATION.md` — not from the prompt. Full surface: `runtime-tools.md`. Large responses (≥ 32 KB) spill to a `resource_link`: `large-responses.md`.

## Auto-Injected Sections

The platform prepends these automatically (data-only — values, not tool usage). Do NOT repeat them, and do NOT document the tools that feed them:

1. `## System` + `### Environment` — identity, container, timeout
2. `### Communication` — the contract above
3. `### Skills` — referenced skills, extracted at `.pi/skills/`
4. `## User Input` — `input` field values
5. `## Documents` — uploaded file paths (only if a file field was wired + provided)
6. `## Configuration` — `config` values
7. `## Checkpoint` — content of `pin({ key: "checkpoint", … })` from the previous run, fenced
8. `## Pinned Slots` — content of every other `pin({ key: "<custom>", … })`, one `### <key>` subsection each
9. `## Memory` — **pinned** memos only; the full `note` archive is read on demand via the `recall_memory` MCP tool, not injected
10. `## Integration: {id}` + `### API Documentation` — per dependent integration; the `### API Documentation` body is the integration's `INTEGRATION.md`
11. `## Output Format` — the expected JSON + validation rules (derived from `output.schema`)

> **State / pin pattern** — read cross-run state from `## Checkpoint` / `## Pinned Slots`, NEVER via `recall_memory` (which only searches the `note` archive, `key=null`). Tell the LLM explicitly: *"Read state from `## Checkpoint` and `## Pinned Slots`. Do NOT call `recall_memory` to look for state — that tool searches archive notes, not pinned slots."* Full pattern + gotchas: `state-and-checkpoint.md`.

## Placeholder Semantics

Two unrelated substitution mechanisms exist. The agent only ever touches the second one.

### `{$credential.<field>}` — manifest-side, the agent NEVER sees it

In an **integration manifest's** `delivery.value`, the platform substitutes `{$credential.<field>}` (and `{$outputs.<name>}`) with the connected credential **server-side**, before the upstream call. This lives entirely in the integration package; the agent does not read, write, or substitute it, and never sees the resolved secret. (Grammar: Arazzo runtime expressions, regex `/\{\$credential\.([A-Za-z0-9_]+)\}/`.) See `create-integration.md`.

### `substituteBody: true` + `{{var}}` — an `api_call` argument

When the agent calls `{ns}__api_call` with a **string body** and `substituteBody: true`, the sidecar replaces `{{var}}` in that body with the connected credential's `var`, server-side. The agent keeps the `{{...}}` placeholders **literal** — it never substitutes real values or masks itself.

```jsonc
// ✅ correct — placeholders stay literal, sidecar substitutes
{ "body": "grant_type=password&username={{email}}&password={{password}}", "substituteBody": true }

// ❌ wrong — agent self-substituted with masks → upstream gets the literal mask → 401/502
{ "body": "grant_type=password&username=<USERNAME>&password=<PASSWORD>", "substituteBody": true }
```

If a body also contains agent-computed markers (`<FRESH_DEVICE_ID>`, a token from a prior response), those the agent **does** replace with values it computes — distinct from the `{{...}}` placeholders it must leave alone. The cleanest home for any such instruction is the integration's `INTEGRATION.md`, not the agent prompt.

> The old 1.x prose about putting `{{access_token}}` / `{{apiKey}}` in the prompt is obsolete: the credential is injected server-side and the agent never holds it.

## Recommended Structure

```markdown
# Objective

One clear sentence.

# Steps

1. **Fetch data** — call the integration's read tool for the open items.
2. **Process** — transform, filter, summarize in-container.
3. **Return** — call `output` with JSON matching the output schema; call `report` with a short human summary.

# Rules

- Constraints and edge cases
- Error handling: on a failed fetch, `log` the error and `output` a partial result rather than emitting prose.
- Output format expectations
```

Note: no tool inventory, no curl snippets, no credential placeholders. Steps name the tools by role and let `tools/list` supply the signatures.

## Memory

| Mechanism | Purpose | Read path |
|---|---|---|
| `note({ content, scope? })` | API quirks, learnings, archive entries | `recall_memory({ q?, limit? })` MCP tool |
| `pin({ key, content, scope? })` | Cross-run state / carry-over | Injected `## Checkpoint` / `## Pinned Slots` |

Include memory instructions only when the agent should learn across runs, and only if `note` (and/or `pin`) is in `runtime_tools`. Be selective.

## Incremental Processing

For scheduled/recurring agents, carry progress in the `checkpoint` pin:

```markdown
Read `last_sync` from `## Checkpoint` (it is auto-injected; do NOT call a tool to fetch it).

- **First run** (no `## Checkpoint`): process all items from the last 7 days.
- **Subsequent runs**: only items after `last_sync`.

At the end, call `pin({ key: "checkpoint", content: { last_sync: "<now>" } })`.
Process all pages before updating the checkpoint (timeout safety).
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Telling the agent to "respond with…" / "print…" the answer | Route it through a tool: `output` (structured) or `report` (narrative). Free text is discarded. |
| Listing the available tools in the prompt | Remove it — the agent reads `tools/list`; the prose only drifts and conflicts. |
| Writing usage prose / arg docs for a tool | Move it to the tool's MCP description, or the integration's `INTEGRATION.md`. |
| Constructing a sidecar proxy URL / `X-Provider` / `X-Target` | Use the integration tool `{ns}__api_call` (or `{ns}__{tool}`); credentials are server-side. |
| Putting `{{access_token}}`/`{{apiKey}}` in the prompt | Credentials are injected server-side via `delivery` — the agent never holds them. |
| Self-substituting `{{var}}` in an `api_call` body | Keep `{{var}}` literal with `substituteBody: true`; only replace agent-computed `<MARKERS>`. |
| Repeating `## User Input` / `## Configuration` / `## Memory` | The platform injects these — just reference the values. |
| Calling `recall_memory` to read a pin | Read `## Checkpoint` / `## Pinned Slots`; `recall_memory` searches the `note` archive only. |
| `required: true` on a property | Use the top-level `"required": [...]` array. |
| Output not mandatory / no format given | If `output.schema` is declared, `output` is required; describe the expected JSON. |
| Prompt in the wrong language | Match the target audience language. |
