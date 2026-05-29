# Creating an Integration — End-to-End Workflow

> **Most users never need this.** Appstrate ships 60+ built-in integrations under `@appstrate/*`. List with `appstrate api GET /api/integrations`. Only author a custom integration for a service not yet covered.

An **integration** (AFPS type `integration`, ex-`provider`) is how an agent reaches an external API. It is **agent-driven**: the agent declares which integration + which tools it needs, and OAuth scopes are inferred from that selection. Credentials are injected **sidecar-side** — the integration code never sees the secret. Authoritative platform docs: `INTEGRATIONS_RUNTIME.md` and the 660-line authoring guide `writing-an-integration-with-connect.md` in the `appstrate/appstrate` repo.

## 0. Decide the `source.kind`

| `source.kind` | Use when | Runtime |
|---|---|---|
| `none` | Plain REST API; the agent calls it via the credential-injecting `{ns}__api_call` tool. **Default — 59/62 built-ins.** | No MCP server; MITM/env injection only |
| `local` | You ship an MCP server (shell-out to a CLI, filesystem work, a real MITM security boundary). | One sandboxed runner container per integration; `source.server` → a packaged `mcp-server` |
| `remote` | A trusted hosted MCP server already exists (Google, Anthropic-hosted, Composio, Linear…). | Direct MCP HTTP client; no bundle, no MITM |

`source.kind:"api"` no longer exists — it became `none` + the additive `_meta["dev.appstrate/api"]` capability.

## 1. Manifest skeleton (kind `none`, api_key)

Start from `assets/integration-manifest.json`.

```json
{
  "$schema": "https://schemas.afps.dev/v0/integration.schema.json",
  "name": "@my-org/acme",
  "version": "1.0.0",
  "type": "integration",
  "schema_version": "0.1",
  "display_name": "Acme (API)",
  "description": "Acme CRM — contacts, deals, notes.",
  "source": { "kind": "none" },
  "auths": {
    "primary": {
      "type": "api_key",
      "authorized_uris": ["https://api.acme.com/**"],
      "credentials": {
        "schema": {
          "type": "object",
          "properties": { "api_key": { "type": "string", "description": "API key from Settings → Developer" } },
          "required": ["api_key"]
        }
      },
      "delivery": {
        "http": { "in": "header", "name": "Authorization", "prefix": "Bearer ", "value": "{$credential.api_key}" }
      },
      "_meta": { "dev.appstrate/auth": { "required": true } }
    }
  },
  "_meta": {
    "dev.appstrate/package": { "author": "Author" },
    "dev.appstrate/api": { "auths": { "primary": {} } }
  }
}
```

The `_meta["dev.appstrate/api"].auths.primary` block is what exposes the `{ns}__api_call` tool for a `none` integration — without it, a `none` integration contributes nothing callable.

## 2. `auths` — types and delivery

Auth types: **`oauth2 | api_key | basic | mtls | custom`** (`oauth1` removed; model it as `custom` + `connect.tool` if ever needed; `mtls` is new and must use `delivery.files`).

Each auth declares **`delivery`** (≥1 channel; `http` is exclusive of `env`/`files`):

- `delivery.http { in, name, prefix?, value, encoding?, allow_server_override? }`
  - `in` — only **`"header"`** is implemented (anything else fails at install).
  - `value` — runtime-expression template **`{$credential.<field>}`** / `{$outputs.<name>}`. ⚠️ NOT the 1.x `{{field}}` form.
  - `encoding: "base64"` — applied after `{$credential.*}` expansion, before `prefix`. GitHub git recipe: `{ prefix:"Basic ", value:"x-access-token:{$credential.access_token}", encoding:"base64" }`.
  - `allow_server_override` (default false) — strips a same-named header set by the MCP server (defence in depth).
- `delivery.env` — `{ ENV_NAME: { value, sensitive?, user_config_key? } }`, for `source.kind:local` (the MCP server reads the credential from its own env).
- `delivery.files` — `{ "<path>": { value, mode? } }`, for cert/key material (mtls, service-account JSON).

> **Credential field names must match `credentials.schema` exactly** (validated since #504). A field named `apiKey` in the connect body but `api_key` in the schema connects "successfully" yet injects nothing → unauthenticated calls that silently succeed. Keep everything snake_case and consistent.

## 3. Acquiring the credential — ConnectStrategy

The platform picks the strategy purely from the manifest:

| Manifest shape | Strategy |
|---|---|
| `type: "oauth2"` | OAuth 2.0 + PKCE (discovery, auto-refresh) |
| `type: api_key/basic/mtls/custom`, no `connect` | Fields (paste the credential) |
| `type: "custom"` + `connect.login` | Login — one declarative HTTP request |
| `type: "custom"` + `connect.tool` (`run_at: run-start`) | LoginSecret — store a secret, mint a session each run |
| `type: "custom"` + `connect.tool` (`run_at: link`) | Orchestrated — run a tool once in an ephemeral connect-run |

- `connect.login` (singular; ex `connect.steps`): `{ request{method,url,content_type,body}, success_criteria[], outputs{}, expires_in_output?, identity_outputs?, limits? }`.
- **Gating (§7.7)**: a `delivery.value` may reference only declared `connect.outputs` (or the orchestrated tool's `produces`). Referencing `{$credential.<bootstrap-secret>}` directly in delivery is a manifest error. `connect.login` must declare ≥1 `outputs`.

Decision shortcut: OAuth2 → `oauth2`; pasteable key → Fields; single login request → `connect.login`; cookie/CSRF/multi-step → `connect.tool` (`link` for a durable cookie captured once, `run-start` to re-mint per run). Full recipes: `auth-decision-tree.md`.

## 4. Scopes (OAuth, level 2)

```json
"auths": { "oauth": {
  "type": "oauth2",
  "scope_catalog": [{ "value": "repo", "label": "Repos", "implies": ["public_repo"] }, { "value": "public_repo", "label": "Public repos" }],
  "default_scopes": ["public_repo"],
  "authorized_uris": ["https://api.github.com/**"]
}}
```

Root `tools_policy.{tool}.required_scopes` is a **per-auth map**:

```json
"tools_policy": {
  "list_issues": { "required_scopes": { "oauth": ["public_repo"] } },
  "issue_write": { "required_scopes": { "oauth": ["repo"] } }
}
```

- Scopes are **inferred per-agent**: `∪(required_scopes of selected tools)`. An agent picking `[list_issues, issue_write]` consents to `["public_repo","repo"]` (and `repo` implies `public_repo`).
- `authorized_uris` (+ `allow_all_uris`) is the **sole** URL boundary (`url_patterns` and `scope_auth_key` were removed).
- **"Picker offers every auth; no single-auth gate"**: any declared auth (e.g. a `pat` alongside `oauth`) can serve any selected tool — there is no tool→auth hard lock.

## 5. `local` and `remote` sources

- **`local`** — `"source": { "kind": "local", "server": { "name": "@my-org/acme-mcp", "version": "^1.0.0" } }`. Ship a companion `mcp-server` package (see `create-mcp-server.md`). The integration's `auths.delivery.env` (or `http` via the per-run MITM) feeds the runner.
- **`remote`** — `"source": { "kind": "remote", "remote": { "url": "https://mcp.acme.com/mcp", "transport": "streamable-http" } }`. The sidecar opens an MCP HTTP client and injects `Authorization` via a fetch wrapper (retry once on 401 after refresh). `transport ∈ "streamable-http" | "sse"`.

Both still layer `auths` on top; both can also opt into `api_call` via `_meta["dev.appstrate/api"]`.

## 6. `INTEGRATION.md` (optional but recommended)

Ship an `INTEGRATION.md` next to `manifest.json`. Its content is inlined into the agent's prompt as `### API Documentation` under `## Integration: <id>` (AFPS §3.5) — endpoints, params, response shapes, gotchas the LLM needs. (This replaces the old mandatory `PROVIDER.md`.) For style, `unzip -p` any built-in `integration-*.afps` from `appstrate/appstrate/system-packages`.

## 7. Pack, import, connect

```bash
bash scripts/afps-pack.sh ./my-integration /tmp/acme.afps
appstrate api POST /api/packages/import -F file=@/tmp/acme.afps
# Connect a fields/api_key credential (agent-driven, under /api/integrations):
appstrate api POST '/api/integrations/@my-org%2Facme/auths/primary/connect/fields' \
  -H 'Content-Type: application/json' \
  -d '{"credentials": {"api_key": "sk-..."}}'
```

OAuth2 → `…/auths/{authKey}/connect/oauth2` (returns `auth_url` + `state`). Multiple connections per actor are supported (OAuth + PAT can coexist); a run picks exactly one via the 7-tier resolution cascade (admin pin → org default enforce → run override → schedule override → member pin → org default soft → fallback). See `profiles.md`.

## 8. Anti-bot / TLS-fingerprint upstreams

For Cloudflare/JA3-gated SaaS there is no in-sidecar bypass. Model it as `source.kind: local` + a `connect.tool` that drives a tenant-side solver (e.g. FlareSolverr). See `flaresolverr-pattern.md`.

## Anti-patterns
- Emitting `type: "provider"`, `dependencies.providers`, or `provider_call` — all rejected/removed.
- `{{field}}` in `delivery.value` — use `{$credential.field}`.
- `authorized_uris: ["**"]` without reason — prefer explicit hosts; `allow_all_uris: true` only when truly needed.
- mtls with `delivery.http` — rejected; use `delivery.files`.
