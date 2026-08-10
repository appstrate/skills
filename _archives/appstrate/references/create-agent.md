# Creating an Agent — Full Workflow

## Table of Contents

- [Step 0: Discover available resources](#step-0-discover-available-resources)
- [Step 1: Write manifest.json](#step-1-write-manifestjson)
  - [File / upload input fields](#file--upload-input-fields)
  - [Critical rules](#critical-rules)
- [Step 2: Write prompt.md](#step-2-write-promptmd)
- [Step 3: Package as .afps](#step-3-package-as-afps)
- [Step 4: Import](#step-4-import)
- [Step 5: Configure (optional post-import)](#step-5-configure-optional-post-import)

The five steps below assume `appstrate whoami` succeeds (user is logged in on the active profile). For install/login, see `SKILL.md` §Setup.

> **Casing**: every manifest field is **snake_case** (`display_name`, `schema_version`, `mcp_servers`, `integrations_configuration`, `file_constraints`, `property_order`). See `manifest-schema.md` for the full rules + camelCase carve-outs.

## Step 0: Discover available resources

```bash
# Skills (knowledge packages to attach)
appstrate api GET /api/packages/skills

# Integrations (external API connectors) — installed/available in the app
appstrate api GET /api/integrations

# Existing agents (avoid name collisions)
appstrate api GET /api/packages/agents
```

**Inspect an integration before referencing it** — the import will be **rejected** if you reference tools or an `auth_key` that the integration doesn't actually expose. Read its manifest from the list (`GET /api/integrations`, each item has `id`, `source`, `manifest`) and check three things:

- `manifest.source.kind` — `none` (REST via `{ns}__api_call`, **no named tools**), or `local`/`remote` (MCP server, **named tools**).
- `manifest.auths` — the real auth keys (e.g. `primary`, or `oauth`/`pat`). Use one of these as `auth_key`.
- `manifest.tools_policy` — the real tool names (only present for MCP integrations). These are the only valid values for `integrations_configuration.<id>.tools`.

```bash
appstrate api GET /api/integrations -o /tmp/ints.json
# then inspect, e.g. the gmail entry's manifest.{source.kind, auths, tools_policy}
```

There is **no** `/api/packages/tools` or `/api/packages/providers` listing — those package families were removed. MCP servers and integrations are selected **in the manifest** (`dependencies` + `integrations_configuration`), not via a separate REST call. Runtime tools are a fixed built-in set (see `runtime-tools.md`).

> **Before depending on an MCP server**, apply the arbitrage in `tools-vs-scripts.md`. Deterministic local transformations (parse a file, generate a CSV, rename fields) belong in a companion skill's `scripts/`, not in a packaged MCP server. And if a step needs LLM reasoning, the agent itself does it — no server, no script.

## Step 1: Write manifest.json

Start from `assets/agent-manifest.json`. Key fields:

```json
{
  "$schema": "https://schemas.afps.dev/v0/agent.schema.json",
  "name": "@my-org/my-agent",
  "version": "1.0.0",
  "type": "agent",
  "schema_version": "0.1",
  "display_name": "My Agent",
  "description": "What it does",
  "author": "Author",
  "dependencies": {
    "skills": {},
    "mcp_servers": {},
    "integrations": { "@appstrate/gmail-mcp": "^1.0.0" }
  },
  "integrations_configuration": {
    "@appstrate/gmail-mcp": {
      "tools": ["list_labels", "get_thread"],
      "auth_key": "primary"
    }
  },
  "runtime_tools": ["output", "report"],
  "input": { "schema": { "type": "object", "properties": {}, "required": [] } },
  "output": { "schema": { "type": "object", "properties": { "summary": { "type": "string" } }, "required": ["summary"] } },
  "timeout": 300
}
```

- **`dependencies.integrations`** / **`dependencies.mcp_servers`** / **`dependencies.skills`** are flat maps `{ "@scope/name": "semverRange" }`. The legacy keys `dependencies.tools` and `dependencies.providers` are **rejected at publish** (`LegacyDepKeyError`).
- **`integrations_configuration.<id>`** configures a depended-on integration. Each key must match a `dependencies.integrations` entry. Fields:
  - `tools: string[]` (or `"*"`) — **the integration's tools to expose to the agent. REQUIRED to get anything callable.** ⚠️ **Absent or `[]` = ZERO tools exposed** (the run-time resolver filters everything out) — the agent then sees no integration tool at all and falls back to `read`/`bash`. This is the #1 silent mistake.
    - `source.kind: none` (REST proxy) → list **`"api_call"`** (the credential-injecting tool), plus **`"api_upload"`** if you need resumable uploads. `api_call` IS a selectable tool — you must name it.
    - `source.kind: local`/`remote` (MCP) → list the real tool names from the integration's `manifest.tools_policy` (verify via `GET /api/integrations`). Inventing names → **import rejected** (`unknown_tool`).
    - `"*"` → expose everything (only if the integration sets `allow_undeclared_tools`).
    - Tool selection also drives OAuth scope inference (least privilege).
  - `auth_key` — one of the integration's real `manifest.auths` keys (e.g. `primary`, `oauth`, `pat`). Disambiguates a multi-auth integration; a wrong key is rejected.
  - `scopes` — optional explicit OAuth scopes (escape hatch; normally inferred from `tools`).

  Full integration model: `create-integration.md`.
- **`runtime_tools`** replaces the old `@appstrate/output` dependency. See `runtime-tools.md`.

### File / upload input fields

```json
"input": {
  "schema": {
    "type": "object",
    "properties": {
      "document": {
        "type": "string",
        "format": "uri",
        "contentMediaType": "application/pdf",
        "title": "Document",
        "description": "PDF to analyze"
      }
    },
    "required": ["document"]
  },
  "file_constraints": {
    "document": { "accept": "application/pdf,.pdf", "max_size": 33554432 }
  }
}
```

**Why all three keys are mandatory** — the upload-ref collector only recognizes a property as a file field when `format === "uri" && contentMediaType` is set. Without them, an `upload://upl_xxx` value is treated as a plain string, never consumed, and the sandbox starts without the file. Same detection drives the webapp file picker.

**`file_constraints` placement** — sibling of `schema`, NOT inside it (snake_case; key `max_size`). Keyed by property name. Avoid `accept: "*/*"`; enumerate MIMEs + extensions.

For arrays of files, multiple files, full schema details: `manifest-schema.md` §"File / upload fields".

### Critical rules

- `name` MUST be `@scope/name` (lowercase, hyphens OK).
- `type` is `"agent"`.
- `schema_version` is `"MAJOR.MINOR"` with MAJOR = 0 (e.g. `"0.1"`); a MAJOR > 0 is rejected.
- If `output.schema` is declared (non-empty), `runtime_tools` MUST include `"output"` (validator rejects otherwise). An agent with no output schema may finish without calling `output`.
- `dependencies.*` are `Record<string, semverRange>`, NOT arrays.
- `required` is a top-level array (`"required": ["field"]`), NOT `required: true` per property.
- **File fields**: no `"file"` type — use `"type":"string"` + `format:"uri"` + `contentMediaType` + sibling `file_constraints`.
- Never emit `dependencies.tools` / `dependencies.providers` / `type:"tool"` / `type:"provider"` — all rejected.

Full manifest schema (all 4 package types, every field): `manifest-schema.md`.

## Step 2: Write prompt.md

Plain Markdown, no template syntax. The platform auto-injects (data-only) sections — User Input, Configuration, Checkpoint, Pinned Slots, Memory, Skills, per-integration `## Integration: <id>` + API docs, Output Format — **and a `### Communication` contract**. Do NOT repeat these, and **do NOT list tools or write tool-usage prose** — the agent learns tools from MCP `tools/list`, and each tool is self-documented by its description.

The single load-bearing invariant to internalize: **any plain text you write outside a tool call is never delivered to the user.** All communication (result, status, question, error) must go through a tool call (`output`, `report`, `log`, or an integration tool).

```markdown
# Objective

One clear sentence.

# Steps

1. Fetch the data you need by calling the integration's tools.
2. Process: transform, filter, summarize.
3. Call `output` with a JSON object matching the output schema, and `report` with a human-readable summary.
```

Key rules:
- External API calls go through the integration's MCP tools (`{ns}__api_call` or `{ns}__{tool}`), not raw curl to a sidecar URL. The credential is injected server-side.
- If `output.schema` is declared, instruct the agent to call `output`.
- Detailed prompt guidance (the Communication contract, what's auto-injected, common mistakes): `prompt-writing.md`.

## Step 3: Package as .afps

```bash
bash scripts/afps-pack.sh /path/to/agent-dir /tmp/my-agent.afps
```

The `.afps` is a ZIP with `manifest.json` at root (not nested). Manual alternative:

```bash
cd "$AGENT_DIR" && zip -r /tmp/my-agent.afps manifest.json prompt.md
```

## Step 4: Import

```bash
appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps
```

If 409 `DRAFT_OVERWRITE`: add `-q force=true` to overwrite the draft. Prefer bumping the version to preserve history.

## Step 5: Configure (optional post-import)

```bash
# Attach skills
appstrate api PUT /api/agents/@scope/name/skills \
  -H 'Content-Type: application/json' \
  -d '{"skillIds": ["@scope/skill1"]}'

# Set config values (persisted, applied to every run)
appstrate api PUT /api/agents/@scope/name/config \
  -H 'Content-Type: application/json' \
  -d '{"language": "fr"}'

# Override LLM model
appstrate api PUT /api/agents/@scope/name/model \
  -H 'Content-Type: application/json' \
  -d '{"modelId": "claude-sonnet-4-20250514"}'
```

There is **no** `PUT .../tools` endpoint — integration/tool selection lives in the manifest (`integrations_configuration`). Connecting an integration's credentials is a separate, agent-driven flow under `/api/integrations/*` (see `create-integration.md` + `profiles.md`).
