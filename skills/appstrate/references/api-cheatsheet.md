# Appstrate API — Conventions & Gotchas

**For the complete endpoint list, use the live source:**
- **CLI (recommended)**: `appstrate openapi list [--tag …] [--method …] [--search …]`
- **Swagger UI**: `$APPSTRATE_URL/api/docs` (cloud: https://app.appstrate.com/api/docs)
- **OpenAPI JSON**: `appstrate openapi export` or `GET /api/openapi.json`

This file documents the conventions, gotchas, and non-obvious behaviors the Swagger doesn't surface.

## Auth

Preferred: call via **`appstrate api`** — the CLI injects `Authorization: Bearer <token>`, `X-Org-Id`, and `X-App-Id` from the active profile automatically.

```bash
appstrate api GET /api/agents
appstrate api POST /api/agents/@scope/name/run -d '{"input":{"q":"…"}}'
```

Raw curl (fallback, for non-CLI environments) — every org-scoped request needs **three** headers:
```
Authorization: Bearer ask_…               # OR a device-flow JWT
X-Org-Id: <org-id>
X-App-Id: <application-id>                # required on app-scoped routes (most resource routes)
```

SSE realtime endpoints accept the API key via query param instead: `?token=ask_…`. With `appstrate api`, pass `-H 'Accept: text/event-stream'` and the CLI handles the bearer.

### `appstrate api` flag reference (most common)

| Flag | Purpose |
|---|---|
| `-H, --header 'k: v'` | Extra request header (repeatable) |
| `-d, --data 'str'` | Body (literal, `@file`, or `@-` for stdin) |
| `--data-raw` / `--data-binary` | Body without `@` interpretation / without content-type guess |
| `-F, --form 'k=v'` | Multipart field (supports `k=@path[;type=…]`) |
| `-q, --query 'k=v'` | Query parameter (repeatable) |
| `-G, --get` | Convert `-d` values to query string + send GET |
| `-X, --request METHOD` | Override method |
| `-o, --output file` | Write response body to file |
| `-i, --include` | Include status line + response headers on stdout |
| `-I, --head` | HEAD, headers only |
| `-s, --silent` | No UX hints, no error messages |
| `-S, --show-error` | Restore errors when combined with `-s` |
| `-f, --fail` | Exit non-zero on 4xx/5xx, suppress body |
| `--fail-with-body` | Like `-f` but keep body on stdout |
| `-L, --location` | Follow redirects |
| `-v, --verbose` | Trace headers on stderr (Authorization [REDACTED]) |
| `-w '%{http_code}'` | Write-out format string after body |
| `--retry N` | Retry on 408/429/5xx + network errors |
| `--max-time N` | Abort after N seconds |
| `--connect-timeout N` | Abort if headers don't arrive in N seconds |

## Scope prefix: `@` is mandatory

All `{scope}/{name}` paths require the `@` prefix:
- ✅ `@tractr/my-agent`
- ❌ `tractr/my-agent` → SPA catch-all middleware returns HTML 200 (silent failure — see issue #215)

## Run lifecycle

Statuses: `pending` → `running` → `success` | `failed` | `timeout` | `cancelled`

Run body (JSON): `{ input?, modelId?, proxyId? }`
Run body (multipart): `{ input (JSON string), file }`
Version param: `-q version=1.0.0` or `-q version=latest`

## Package import

- `POST /api/packages/import` — upload .afps ZIP
- 409 `DRAFT_OVERWRITE` → add `-q force=true` to overwrite draft
- Updates require `lockVersion` field (409 on conflict)
- GitHub import: `POST /api/packages/import-github`

## Schedules

Create body: `{ connectionProfileId*, cronExpression*, name?, timezone?, input? }`

Common cron: `0 9 * * 1-5` (weekdays 9am), `0 */6 * * *` (every 6h), `0 0 * * 1` (weekly Monday).

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| Agent run | 20/min |
| Inline run + validate (shared bucket) | 60/min (via `INLINE_RUN_LIMITS`) |
| Package import | 10/min |
| Package download | 50/min |
| Model/proxy/key test | 5/min |
| OpenRouter search | 10/min |

## Error Format

RFC 7807: `{ type, title, status, detail }`

| Status | Meaning |
|--------|---------|
| 400 | Validation error |
| 401 | Auth missing or invalid — run `appstrate login` (or `appstrate login --profile <name>`) |
| 403 | Insufficient permissions (check API key scopes) |
| 404 | Not found (or missing `@` prefix — check scope) |
| 409 | Conflict: draft overwrite or lockVersion mismatch |
| 422 | Dependency resolution failed (inline runs — declared skill/tool/provider not in catalog) |
| 429 | Rate limit exceeded |

## Common pitfalls

1. **`result: {}` on success** — `@appstrate/output` not in `dependencies.tools`. Add it to manifest.
2. **401 after a week** — device-flow JWT expired + refresh token rotated out. Re-run `appstrate login --profile <name>`.
3. **403 after platform update** — API key missing new scopes. Create a fresh key in the UI, or re-run `appstrate login` if using a JWT.
4. **HTML response** — Missing `@` prefix on scope, OR hitting an app-scoped route without `X-App-Id`. Use `appstrate api` to avoid both.
5. **Agent doesn't call output tool** — Tool not in manifest `dependencies.tools`. Re-import after fixing.
6. **SSE doesn't connect with API key** — Use `?token=ask_…` query param, not Authorization header. With `appstrate api`, add `-H 'Accept: text/event-stream'`.
7. **Inline run 422 `MISSING_TOOL` / `MISSING_SKILL`** — the catalog-side check rejects a dependency the org doesn't have. Run `appstrate api GET /api/packages/tools` (or `…/skills`) to confirm availability; see issue #155 (fixed #156).
8. **`Profile "<name>" not configured`** — no `[profile.<name>]` in `config.toml`. Run `appstrate login --profile <name>`.
