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

### Output schema — `result.output.X` nesting (not `result.X`)

The agent calls `@appstrate/output` with `output({ data: { summary: "...", stats: {...} } })`. The `data` payload is what `manifest.output.schema` describes. But when reading the run via `GET /api/runs/{id}`, the result is **wrapped under `result.output`**:

```json
{
  "result": {
    "output": {
      "summary": "...",
      "stats": {...}
    }
  }
}
```

Read `result.output.<field>`, NOT `result.<field>`. The schema describes the shape of `data`, NOT the shape of `result`. This trips up most first-time agent debuggers — runs land as `success`, `output` was called correctly, but `result.summary` reads as `undefined` and the dev wastes hours chasing a non-bug.

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

> **`authMode: "password"` was proposed but rejected upstream** ([issue #457](https://github.com/appstrate/appstrate/issues/457)). For SaaS that exposes a clean ROPC `/token` endpoint, use `authMode: "custom"` + a tool TS that POSTs `grant_type=password&...&username={{email}}&password={{password}}` with `substituteBody: true` (now working since [PR #363](https://github.com/appstrate/appstrate/pull/363) merged). Store the resulting `{access_token, refresh_token, expires_at}` in the credentials via `@default/appstrate-self` PATCH, and inject `Authorization: Bearer …` via `credentialHeaderName/Prefix`. See `auth-decision-tree.md` §B / §C for the recipe.

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

### Canonical example (`custom` + tool TS bootstrap — replaces the rejected `password` mode)

For reverse-engineered SaaS with a ROPC `/token` endpoint but no public OAuth, write a tool TS that POSTs the bootstrap request through the sidecar with `substituteBody: true`. Store the resulting tokens via `@default/appstrate-self` PATCH, then call subsequent endpoints with the standard `Authorization: Bearer …` header. The recipe and a full worked example are in `auth-decision-tree.md` §C and §F.

### TLS-fingerprint blocked upstreams (JA3 / Cloudflare bot tier)

Some Cloudflare-protected SaaS silently reject Bun/undici TLS fingerprints with `403`/`502` while accepting the same payload from `curl` or a real browser. There is **no in-sidecar bypass** in upstream Appstrate main: a per-URL `curl`-client rerouting extension (`x-tlsClientByUrl`) was proposed but rejected — see [issue #458](https://github.com/appstrate/appstrate/issues/458). Pierre's stance is that JA3 bypass should live in tenant-side infrastructure (proxy or headless browser), not in the sidecar.

Diagnose JA3 blocking by curl-vs-fetch differential: `curl -X POST <url> -d '<body>'` from your machine works → the sidecar gets `403`/`502`. Once identified, the two viable mitigations are:

- **Residential proxy** for cookie-only bot tiers — see `auth-decision-tree.md` §4 step 2.
- **Real headless browser via FlareSolverr** for full bot management (Cloudflare with JS challenge, DataDome, Akamai) — see `references/flaresolverr-pattern.md`.

### Session cookies — automatic capture across redirect chains

The sidecar keeps a per-provider, per-run cookie jar. Every `Set-Cookie` returned by upstream — at the **final** hop AND at every intermediate hop of a 3xx redirect chain — is merged into that jar (de-duplicated by name). On the next `provider_call` to the same provider in the same run, the jar is replayed as the `Cookie` header automatically.

Practical implication: a TypeScript tool that bootstraps a session via a multi-step login flow (CAS + OAuth + OIDC handoff with 3–4 redirects, classic SAML/CAS deployments) only needs to invoke its login chain once at the start of the run. All subsequent `provider_call`s authenticate automatically — no need to capture the Set-Cookie response headers, no need to template them back as a `Cookie` header on follow-up requests. Streaming bodies fall back to last-hop-only capture (a buffered body is required to replay across 307/308).

The jar is **run-scoped**: it resets when the sidecar is acquired for a new run. Long-lived session cookies are not persisted across runs by the sidecar — re-bootstrap on every run, or persist a refresh token in the provider's credentials via `@default/appstrate-self` PATCH (see `auth-decision-tree.md` §C "Multi-step CAS / OAuth handoff" for that pattern).

**Pre-flight GET for sticky-session load balancers**: SaaS behind an AWS ALB (or any L7 LB with cookie-based stickiness — `AWSALB`, `JSESSIONID` set BEFORE the app sees the request) silently reject a POST login when the LB stickiness cookie isn't primed: the POST lands on a different LB instance from the one that will hold the resulting Spring/Tomcat session, and the next authenticated call gets the login form back even though the POST returned 200. Fix in the bootstrap tool: do a `GET` on the login URL FIRST so the sidecar's jar receives the LB cookies, THEN `POST` credentials. Symptom is silent — diagnose by comparing the cookie jar after step 1 (should contain `AWSALB` / `JSESSIONID` from the GET) to after step 2.

### Provider package files

An AFPS provider package MUST contain two files:

| File | Required | Purpose |
|------|----------|---------|
| `manifest.json` | yes | Provider definition (auth mode, allowed URIs, scopes, …) |
| `PROVIDER.md` | **yes** | API documentation (endpoints, params, response shapes, gotchas) — injected into the agent's system prompt at runtime so the LLM knows how to call the API |

**`PROVIDER.md` is not optional.** Without it, the runtime errors at dispatch with `DraftPackageCatalog: <provider-id> has no files in storage` and the agent can't run. For style + structure, copy any built-in provider AFPS in [appstrate/appstrate/system-packages](https://github.com/appstrate/appstrate/tree/main/system-packages) (e.g. `provider-firecrawl-1.0.0.afps`) and `unzip -p <file> PROVIDER.md`.

### Two creation paths — NOT equivalent

- **`POST /api/packages/import`** with an AFPS ZIP (recommended) — `manifest.json` (nested shape above) + `PROVIDER.md`. Only this path stores the files the runtime needs. Use this for any provider you intend to actually call from an agent.
- **`POST /api/providers`** (flat payload) — accepts `authorizationUrl`, `tokenUrl`, … at top level; the server nests them internally. Creates the DB row but **does NOT populate the file storage**, so the provider appears in the UI but agents that depend on it fail at dispatch (see "DraftPackageCatalog" in `references/known-issues.md`). Avoid for runtime use; only acceptable for definition-only experiments.

### Saving a credential

Once the provider package is imported, save the user credential via the connection endpoint. The body uses **camelCase `apiKey`**, not the snake_case `api_key` defined in the provider's `credentials.schema`:

```bash
appstrate api POST '/api/connections/connect/@scope/name/api-key' \
  -H 'Content-Type: application/json' \
  -d '{"apiKey": "sk-..."}'
# → { "success": true }
```

Verify with `GET /api/connections` — entry should report `status: "connected"`.

Full field list: [AFPS provider schema](https://afps.appstrate.dev/schema/v1/provider.schema.json).

## Validation Rules

- Versions: forward-only, no downgrades
- `latest` dist-tag: auto-managed on non-prerelease publishes
- AJV: `coerceTypes: true`, no `additionalProperties: false`
- Custom fields: use `x-` prefix (e.g., `x-outputRetries`)
- Updates require `lockVersion` field (optimistic locking, 409 on conflict)
