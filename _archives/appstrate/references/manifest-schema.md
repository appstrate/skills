# AFPS Manifest Schema Reference (skill quick-ref)

> **Canonical spec**: AFPS (Agent Flow Packaging Standard) is the open format Appstrate uses. This platform targets the **0.x line** (`@afps-spec/schema@^0.4.0`). JSON Schema per type: `https://schemas.afps.dev/v0/{type}.schema.json` (`agent` / `skill` / `mcp-server` / `integration`). When in doubt, the published schema wins.
>
> This file is the **skill-local quick-ref**. The full integration model (auths, delivery, connect, scopes) lives in `create-integration.md`; the MCP-server model in `create-mcp-server.md`.

Every package has a `manifest.json`. **All manifest fields are snake_case** (`display_name`, `schema_version`, `mcp_servers`, `integrations_configuration`, `file_constraints`, `property_order`). The reader is snake_case-only — the 1.x camelCase fallback was removed.

## Table of Contents

- [Common Fields](#common-fields)
- [Dependencies](#dependencies)
- [Agent Fields](#agent-fields)
- [Input/Output/Config Schemas](#inputoutputconfig-schemas)
  - [File / upload fields](#file--upload-fields-pdf-image-attachments)
  - [Output schema nesting](#output-schema--resultoutputx-nesting)
- [State and Memory](#state-and-memory)
- [Skill Fields](#skill-fields)
- [MCP-server Fields](#mcp-server-fields)
- [Integration Fields](#integration-fields)
- [Validation Rules](#validation-rules)

## Common Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `$schema` | string | No | `https://schemas.afps.dev/v0/<type>.schema.json` |
| `name` | string | **Yes** | Scoped name: `@scope/name` |
| `version` | string | **Yes** | Semver: `MAJOR.MINOR.PATCH[-prerelease]` |
| `type` | enum | **Yes** | `agent`, `skill`, `mcp-server`, `integration` |
| `schema_version` | string | **Yes** | `"MAJOR.MINOR"`, MAJOR = 0 (e.g. `"0.1"`). A MAJOR > 0 is rejected |
| `display_name` | string | Agents: yes | Human-readable name |
| `description` | string | No | Short description |
| `keywords` | string[] | No | Tags |
| `license` | string | No | SPDX identifier |

Name regex: `^@[a-z0-9]([a-z0-9-]*[a-z0-9])?/[a-z0-9]([a-z0-9-]*[a-z0-9])?$`. In API paths, scope includes `@`: `/api/agents/@my-org/my-agent`.

The legacy types `tool` and `provider` are gone (`tool` → `mcp-server`, `provider` → `integration`, AFPS Appendix D). `x-outputRetries` and `flow.schema.json` no longer exist.

## Dependencies

```json
{
  "dependencies": {
    "skills":       { "@appstrate/email-writing": "^1.0.0" },
    "mcp_servers":  { "@scope/some-mcp": "^1.0.0" },
    "integrations": { "@appstrate/gmail": "^1.0.0" }
  }
}
```

Flat maps `{ "@scope/name": "semverRange" }` (`^1.0.0`, `~1.0.0`, `*`, …). All optional. **The legacy keys `dependencies.tools` and `dependencies.providers` are rejected at publish** (`LegacyDepKeyError` → use `mcp_servers` / `integrations`).

## Agent Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `author` | string\|object | **Yes** | Name, or `{name,email?,url?}` |
| `runtime_tools` | string[] | No | Subset of `["output","log","note","pin","report"]`. See `runtime-tools.md` |
| `integrations_configuration` | object | No | Per-integration tool/scope/auth selection (below) |
| `timeout` | number | No | Max execution time (seconds) |

### `integrations_configuration`

```json
{
  "integrations_configuration": {
    "@appstrate/gmail": {
      "tools": ["list_messages", "send_message"],
      "scopes": ["https://www.googleapis.com/auth/gmail.modify"],
      "auth_key": "oauth"
    }
  }
}
```

- `tools`: `string[]` (or `"*"`) — the integration's tools to expose. **REQUIRED to expose anything.** ⚠️ **Absent or `[]` = ZERO tools exposed at run-time** (the resolver filters everything; the agent sees no integration tool and falls back to `read`/`bash`) — the #1 silent mistake. By `source.kind`: `none` → `["api_call"]` (+ `"api_upload"` if needed); `local`/`remote` → real names from `manifest.tools_policy` (inventing → `unknown_tool` at import); `"*"` → all (needs `allow_undeclared_tools`). Note: `api_call` **is** a selectable tool name — a `none` integration is NOT "tool-less", you must list `"api_call"`.
- `scopes`: optional explicit OAuth scopes (escape hatch); normally inferred from `tools`.
- `auth_key`: one of the integration's real `manifest.auths` keys (e.g. `primary`, `oauth`, `pat`). A wrong key is rejected.
- Each key MUST match a `dependencies.integrations` entry (orphan keys are rejected). Verify tools + auth keys via `GET /api/integrations` before referencing them.

> **No `providers_configuration` anymore.** Tool/scope selection drives OAuth scope inference at consent time.

## Input/Output/Config Schemas

The wrapper is `{ schema, file_constraints?, ui_hints?, property_order? }` (snake_case). `schema` is pure JSON Schema 2020-12.

| Type | Notes |
|------|-------|
| `"string"` | `enum`, `default`, `minLength`, `maxLength`, `pattern`, `format`, `contentMediaType` |
| `"number"` | `minimum`, `maximum`. AJV coerces `"50"` → `50` |
| `"boolean"` | `default` |
| `"array"` | requires `items` |
| `"object"` | nested `properties` + `required` |

> **No `"file"` type.** Writing `"type": "file"` fails validation. Use the file-fields recipe below.

Display lives in the wrapper, not the schema: `property_order: string[]`, `ui_hints.<key>.placeholder`. **`required` is a top-level array**, NOT per-property boolean.

```json
{
  "input": {
    "schema": {
      "type": "object",
      "properties": {
        "query": { "type": "string", "title": "Search Query" },
        "limit": { "type": "number", "default": 10 }
      },
      "required": ["query"]
    },
    "ui_hints": { "query": { "placeholder": "e.g. weekly report" } },
    "property_order": ["query", "limit"]
  }
}
```

### File / upload fields (PDF, image, attachments)

Declare a **string** property with three keys together — `format: "uri"`, `contentMediaType: "<mime>"`, and a sibling `file_constraints` block (next to `schema`, snake_case):

```json
{
  "input": {
    "schema": {
      "type": "object",
      "properties": {
        "document": {
          "type": "string",
          "format": "uri",
          "contentMediaType": "application/pdf",
          "title": "Document",
          "description": "PDF or image. Uploaded via upload://, delivered to ./documents/<filename> in the sandbox."
        }
      },
      "required": ["document"]
    },
    "file_constraints": {
      "document": {
        "accept": "application/pdf,image/jpeg,image/png,.pdf,.jpg,.png",
        "max_size": 33554432
      }
    },
    "property_order": ["document"]
  }
}
```

**Why all three keys** — the upload-ref collector recognizes a file field only when `format === "uri" && contentMediaType` is present; otherwise `upload://…` is treated as a plain string and never consumed. The webapp file picker uses the same detection.

**`file_constraints`** (sibling of `schema`, keyed by property):
- `accept` — comma-separated MIMEs **and** extensions. **Never `"*/*"`** (compared literally → rejects all files).
- `max_size` — bytes (max 100 MB).
- `max_files` — optional, for arrays.

**Multiple files** — `type: "array", items: { type:"string", format:"uri", contentMediaType:"<mime>" }`.

### Output schema — `result.output.X` nesting (not `result.X`)

The agent calls `output({ data: { summary: "...", stats: {...} } })`. `data` is what `output.schema` describes. But reading the run via `GET /api/runs/{id}`, the result is wrapped under `result.output`:

```json
{ "result": { "output": { "summary": "...", "stats": {} } } }
```

Read `result.output.<field>`, NOT `result.<field>`. Runs land `success`, `output` was called, yet `result.summary` is `undefined` — it's nesting, not a bug.

## State and Memory

State/memory are not manifest config — they are written via runtime tools and rendered (data-only) into the prompt:
- `pin({ key:"checkpoint", … })` → `## Checkpoint` (carry-over); other keys → `## Pinned Slots`.
- `note({ content, scope? })` → archive, read back via the `recall_memory` MCP tool (NOT rendered in the prompt).

See `runtime-tools.md` + `state-and-checkpoint.md`.

## Skill Fields

Minimal manifest; content lives in `SKILL.md` (YAML frontmatter + Markdown).

```json
{
  "name": "@my-org/my-skill",
  "version": "1.0.0",
  "type": "skill",
  "schema_version": "0.1",
  "display_name": "My Skill",
  "description": "What this skill provides"
}
```

Skills bundle `scripts/`, `references/`, `assets/`; extracted into `.pi/skills/{id}/` in the container.

## MCP-server Fields

A `mcp-server` packages a Model Context Protocol server (MCPB vocabulary). It is referenced by a `local` integration's `source.server`. Full guide: `create-mcp-server.md`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `server.type` | enum | **Yes** | `node` \| `python` \| `binary` \| `uv` (no `bun`; use the `_meta` runtime override) |
| `server.entry_point` | string | **Yes** | Entry file (e.g. `server/index.ts`) |
| `server.mcp_config` | object | **Yes** | `{ command, args, env?, platform_overrides? }` |
| `tools[]` | array | No | `{ name, description }` advertised to the agent |
| `user_config` | object | No | MCPB user-config entries |

```json
{
  "name": "@my-org/my-mcp",
  "version": "1.0.0",
  "type": "mcp-server",
  "schema_version": "0.1",
  "manifest_version": "0.3",
  "server": { "type": "node", "entry_point": "server/index.ts", "mcp_config": { "command": "bun", "args": ["server/index.ts"] } },
  "tools": [{ "name": "my_tool", "description": "…" }],
  "_meta": {
    "dev.appstrate/mcp-server": { "runtime": "bun" },
    "dev.appstrate/workspace": { "mount": "/workspace", "access": "rw" }
  }
}
```

- Bun-native servers keep `server.type: "node"` + `_meta["dev.appstrate/mcp-server"].runtime: "bun"`.
- Opt into the per-run shared workspace with `_meta["dev.appstrate/workspace"].{mount, access:"ro"|"rw"}` (the sidecar acts as the MCP Roots provider). `mount` is an absolute POSIX path (no `..`, no `/`, no `/proc//sys//dev//etc`).

## Integration Fields

An `integration` reaches an external API. The shape depends on `source.kind`; auth lives under `auths.{key}`. Full guide (delivery, connect strategies, scopes, all 3 source kinds): `create-integration.md`. Quick-ref:

```json
{
  "name": "@my-org/acme",
  "version": "1.0.0",
  "type": "integration",
  "schema_version": "0.1",
  "display_name": "Acme (API)",
  "source": { "kind": "none" },
  "auths": {
    "primary": {
      "type": "api_key",
      "authorized_uris": ["https://api.acme.com/**"],
      "credentials": { "schema": { "type": "object", "properties": { "api_key": { "type": "string" } }, "required": ["api_key"] } },
      "delivery": { "http": { "in": "header", "name": "Authorization", "prefix": "Bearer ", "value": "{$credential.api_key}" } }
    }
  },
  "_meta": { "dev.appstrate/api": { "auths": { "primary": {} } } }
}
```

- **`source.kind`**: `none` (REST via `api_call` only), `local` (`source.server` → a packaged `mcp-server`, one runner container per integration), `remote` (`source.remote.{url, transport}` MCP HTTP/SSE).
- **`auths.{key}.type`**: `oauth2 | api_key | basic | mtls | custom` (`oauth1` removed; `mtls` added).
- **`delivery.http`**: `{ in:"header", name, prefix?, value, encoding?, allow_server_override? }`. Only `in:"header"` is implemented. `value` uses the **`{$credential.<field>}`** runtime-expression syntax (NOT 1.x `{{field}}`). `encoding:"base64"` applies after expansion, before `prefix`. mtls must use `delivery.files`.
- **Scopes (level 2)**: `auths.{key}.{scope_catalog, default_scopes, authorized_uris, allow_all_uris}` + root `tools_policy.{tool}.required_scopes.{auth_key}` (per-auth map). `authorized_uris` is the sole URL boundary (`url_patterns`/`scope_auth_key` removed). Scopes are inferred per-agent from selected tools.
- **`api_call` capability**: opt in via `_meta["dev.appstrate/api"].auths.{key}` (additive, orthogonal to `source.kind`). One auth → `{ns}__api_call`; multiple → `{ns}__api_call__{authKey}`.
- **`INTEGRATION.md`** (optional, AFPS §3.5) — API documentation inlined into the agent prompt as `### API Documentation` under `## Integration: <id>`. Bundle it next to `manifest.json` so the agent knows how to use the integration.

### Connecting a credential

Connection is **agent-driven** under `/api/integrations/*` (no more `/api/connections/connect/...`). For an api_key/fields auth:

```bash
appstrate api POST '/api/integrations/@scope%2Fname/auths/primary/connect/fields' \
  -H 'Content-Type: application/json' \
  -d '{"credentials": {"api_key": "sk-..."}}'
```

(OAuth2 uses `…/connect/oauth2`.) `credentials` field names must match the auth's `credentials.schema` exactly (validated — a mis-keyed field silently breaks injection). See `create-integration.md` + `profiles.md` for the full connection/pins/defaults model.

## Validation Rules

- Versions: forward-only, no downgrades. `latest` dist-tag auto-managed on non-prerelease publishes.
- AJV (dynamic schemas): `coerceTypes: true`, no `additionalProperties: false`.
- AFPS manifests are validated **strict** against the published JSON Schema — unknown top-level keys are rejected (use `_meta` for vendor extensions).
- Updates use optimistic locking (`lockVersion`, 409 on conflict).
- `$ref` in `credentials.schema` must be fragment-only (`#/...`) — external refs rejected (SSRF guard).
