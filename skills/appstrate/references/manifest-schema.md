# AFPS Manifest Schema Reference (skill quick-ref)

> **Canonical spec**: AFPS (Agent Flow Packaging Standard) v1.0 is the open CC-BY format Appstrate uses. The authoritative schema + spec lives at [afps.appstrate.dev](https://afps.appstrate.dev). JSON Schema for validation: `https://afps.appstrate.dev/schema/v1/{type}.schema.json`. Appstrate-side overview: [appstrate.com/docs/resources/afps-specification](https://appstrate.com/docs/resources/afps-specification).
>
> This file is the **skill-local quick-ref** for writing manifests in-context without having to fetch the full JSON Schema. When in doubt, the afps.appstrate.dev schema wins.

Every package has a `manifest.json`.

## Table of Contents

- [Common Fields](#common-fields)
- [Dependencies](#dependencies)
- [Agent Fields](#agent-fields)
- [Input/Output/Config Schemas](#inputoutputconfig-schemas)
  - [File / upload fields](#file--upload-fields-pdf-image-attachments)
- [State and Memories](#state-and-memories)
- [Skill Fields](#skill-fields)
- [Tool Fields](#tool-fields)
- [Provider Fields](#provider-fields)
- [Validation Rules](#validation-rules)

## Common Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `$schema` | string | No | Schema URL for editor validation |
| `name` | string | **Yes** | Scoped name: `@scope/name` |
| `version` | string | **Yes** | Semver: `MAJOR.MINOR.PATCH[-prerelease]` |
| `type` | enum | **Yes** | `agent`, `skill`, `tool`, `provider` |
| `displayName` | string | Agents: yes | Human-readable name |
| `description` | string | No | Short description |
| `keywords` | string[] | No | Tags for marketplace |
| `license` | string | No | SPDX identifier |

Name regex: `^@[a-z0-9]([a-z0-9-]*[a-z0-9])?/[a-z0-9]([a-z0-9-]*[a-z0-9])?$`

In API paths, scope includes `@`: `@my-org/my-agent` → `/api/agents/@my-org/my-agent`

## Dependencies

```json
{
  "dependencies": {
    "providers": { "@appstrate/gmail": "^1.0.0" },
    "skills": { "@appstrate/email-writing": "^1.0.0" },
    "tools": { "@appstrate/web-scraper": "^1.0.0" }
  }
}
```

All three sub-fields optional. Values are semver ranges: `^1.0.0`, `~1.0.0`, `>=1.0.0 <2.0.0`, `*`.

## Agent Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `schemaVersion` | string | **Yes** | — | `"1.0"` (pattern: `^1\.(0\|[1-9]\d*)$`) |
| `author` | string | **Yes** | — | Author name |
| `timeout` | number | No | — | Max execution time (seconds) |
| `x-outputRetries` | integer | No | 0 | Retry on output validation failure (0-5) |

### Providers Configuration

```json
{
  "providersConfiguration": {
    "@appstrate/gmail": {
      "scopes": ["https://www.googleapis.com/auth/gmail.modify"],
      "connectionMode": "user"
    }
  }
}
```

- `scopes`: OAuth scopes needed
- `connectionMode`: `"user"` (per-user) or `"admin"` (shared org creds)

## Input/Output/Config Schemas

All use JSON Schema with these types:

| Type | Notes |
|------|-------|
| `"string"` | Supports `enum`, `default`, `minLength`, `maxLength`, `pattern`, `format`, `contentMediaType` |
| `"number"` | Supports `minimum`, `maximum`. AJV coerces `"50"` -> `50` |
| `"boolean"` | Supports `default` |
| `"array"` | Requires `items` |
| `"object"` | Nested `properties` + `required` |

> **There is no `"file"` type.** A common mistake is to write `"type": "file"` — this is not a valid JSON Schema 2020-12 type and the AFPS validator rejects the manifest with `Manifest validation failed: input.schema: Must be a valid JSON Schema 2020-12 document`. Use the file fields recipe below instead.

Display: `title` (label), `description` (help text), `default`, `propertyOrder` (field order).

**Critical**: `required` is a top-level array, NOT per-property boolean.

```json
{
  "input": {
    "schema": {
      "type": "object",
      "properties": {
        "query": { "type": "string", "title": "Search Query" },
        "limit": { "type": "number", "default": 10 }
      },
      "required": ["query"],
      "propertyOrder": ["query", "limit"]
    }
  }
}
```

### File / upload fields (PDF, image, attachments)

To accept a user-uploaded file in `input`, declare a **string** property with **three keys together** — `format: "uri"`, `contentMediaType: "<mime>"`, and a sibling `fileConstraints` block (placed next to `schema`, NOT inside it):

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
          "title": "Document à extraire",
          "description": "PDF or image. Uploaded via upload://, delivered to ./documents/<filename> in the sandbox."
        }
      },
      "required": ["document"]
    },
    "fileConstraints": {
      "document": {
        "accept": "application/pdf,image/jpeg,image/png,image/webp,.pdf,.jpg,.jpeg,.png,.webp",
        "maxSize": 33554432
      }
    },
    "propertyOrder": ["document"]
  }
}
```

**Why all three keys are required** — the server-side `input-parser.collectUploadRefs` recognizes a property as a file field only if `format === "uri" && contentMediaType` is present. Without these two, the value `"upload://upl_xxx"` is treated as a plain string, `consumeUpload` is never called, and the sandbox starts with an empty `./documents/` (no `## Documents` section in the system prompt). The webapp file-picker widget uses the same detection — without these keys, it shows a plain text input instead of a file picker.

**`fileConstraints`** — sibling of `schema`, keyed by property name. Three sub-keys:
- `accept` — comma-separated list of MIMEs **and** extensions (e.g. `"application/pdf,.pdf"`). **Do NOT use `"*/*"`** — the webapp validator compares it literally and rejects all files. Always enumerate.
- `maxSize` — bytes (max 100 MB).
- `maxFiles` — optional, for arrays.

**Multiple files** — use `type: "array", items: { type: "string", format: "uri", contentMediaType: "<mime>" }`. The platform applies the same detection on `items`.

**How to test the wiring** — after import, open the agent in the webapp and click "Run". If the input field renders as a file picker, the manifest is correctly wired. If it renders as a plain text input, one of the three keys is missing.

## State and Memories

**State**: Free-form JSON, overwritten each run. Agent returns `result.state`, injected as `## Previous State` next run.

**Memories**: Single list shared across all users of the agent (appended, never overwritten). Injected as `## Memory` in the prompt. Use the `add_memory` tool to save learnings. No manifest config needed.

## Skill Fields

Minimal manifest. Content lives in `SKILL.md` (YAML frontmatter + Markdown).

```json
{
  "name": "@my-org/my-skill",
  "version": "1.0.0",
  "type": "skill",
  "displayName": "My Skill",
  "description": "What this skill provides"
}
```

Skills can bundle `scripts/`, `references/`, `assets/` directories. The entire .afps content is extracted into `.pi/skills/{id}/` in the container.

## Tool Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `entrypoint` | string | **Yes** | Path to TypeScript entry (e.g., `"index.ts"`) |
| `tool.name` | string | **Yes** | Tool identifier (snake_case) |
| `tool.description` | string | **Yes** | Description for agent tool selection |
| `tool.inputSchema` | object | **Yes** | JSON Schema for parameters |

```json
{
  "name": "@my-org/my-tool",
  "version": "1.0.0",
  "type": "tool",
  "entrypoint": "index.ts",
  "tool": {
    "name": "my_tool",
    "description": "Does something useful",
    "inputSchema": {
      "type": "object",
      "properties": {
        "query": { "type": "string", "description": "Search query" }
      },
      "required": ["query"]
    }
  }
}
```

**Execute signature**: `(toolCallId, params, signal)` — params is the **second** argument.
**Return type**: `{ content: [{ type: "text", text: "..." }] }` — NOT a plain string.
**Import**: `import { tool } from "@mariozechner/pi-coding-agent"`

## Provider Fields

Root field is `definition` with `authMode`. Auth-specific fields are **nested under `definition.<authMode>`** (NOT flat under `definition`). Getting this wrong is the #1 bug when authoring custom providers by hand.

### Always on `definition` (root)

- `authMode`: `"oauth2" | "oauth1" | "api_key" | "basic" | "custom"` (required)
- `authorizedUris`: `string[]` — URL patterns with `*` wildcards; the sidecar rejects outgoing requests that don't match
- `allowAllUris`: `boolean` — bypass the URI whitelist (use with caution)
- `availableScopes`: `[{ value, label }]` — scope catalog for the connection form
- `credentialHeaderName`: `string` — e.g. `"Authorization"`
- `credentialHeaderPrefix`: `string` — e.g. `"Bearer"` (space auto-handled)
- `credentialTransform`: `{ template, encoding: "base64" }` — optional transform before injection

Plus common metadata: `iconUrl`, `categories`, `docsUrl`, `setupGuide`.

### Nested per `authMode`

| `authMode` | Nested under | Required fields | Optional |
|---|---|---|---|
| `oauth2` | `definition.oauth2` | `authorizationUrl`, `tokenUrl` | `refreshUrl`, `defaultScopes`, `scopeSeparator`, `pkceEnabled`, `tokenAuthMethod`, `tokenContentType`, `authorizationParams`, `tokenParams` |
| `oauth1` | `definition.oauth1` | `requestTokenUrl`, `authorizationUrl`, `accessTokenUrl` | `authorizationParams` |
| `api_key` / `basic` / `custom` | `definition.credentials` | `schema` (JSON Schema for the credential form) | `fieldName` (which schema property holds the secret used in `{{variable}}` substitution) |

### Canonical example (OAuth2, from real @appstrate/slack)

```json
{
  "definition": {
    "authMode": "oauth2",
    "oauth2": {
      "authorizationUrl": "https://slack.com/oauth/v2/authorize",
      "tokenUrl": "https://slack.com/api/oauth.v2.access",
      "defaultScopes": ["channels:read", "chat:write"],
      "scopeSeparator": ",",
      "pkceEnabled": false
    },
    "credentialHeaderName": "Authorization",
    "credentialHeaderPrefix": "Bearer",
    "authorizedUris": ["https://slack.com/api/*"],
    "availableScopes": [{ "value": "chat:write", "label": "Send messages" }]
  }
}
```

### Canonical example (API key, from real @appstrate/firecrawl)

```json
{
  "definition": {
    "authMode": "api_key",
    "credentials": {
      "schema": {
        "type": "object",
        "properties": { "api_key": { "type": "string" } },
        "required": ["api_key"]
      },
      "fieldName": "api_key"
    },
    "credentialHeaderName": "Authorization",
    "credentialHeaderPrefix": "Bearer",
    "authorizedUris": ["https://api.firecrawl.dev/*"]
  }
}
```

### Two creation paths (same end-state in DB)

- `POST /api/providers` — accepts **flat** payload (`authorizationUrl`, `tokenUrl`, ... at top level), the server nests them internally. Faster for one-off internal providers.
- `POST /api/packages/import` with an AFPS ZIP — manifest must have the **nested** shape shown above. Gives semver + integrity + portability.

Full field list: [AFPS provider schema](https://afps.appstrate.dev/schema/v1/provider.schema.json).

## Validation Rules

- Versions: forward-only, no downgrades
- `latest` dist-tag: auto-managed on non-prerelease publishes
- AJV: `coerceTypes: true`, no `additionalProperties: false`
- Custom fields: use `x-` prefix (e.g., `x-outputRetries`)
- Updates require `lockVersion` field (optimistic locking, 409 on conflict)
