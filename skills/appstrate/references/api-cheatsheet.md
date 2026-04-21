# Appstrate API — Cheatsheet (skill-local gotchas + pointers)

The public docs cover the API comprehensively. This file keeps only what a coding agent needs that isn't obvious from the reference docs: the `appstrate api` flag list, the non-obvious gotchas, and the quick error-resolution index.

## Authoritative references (read these first)

- **Authentication** (API keys, sessions, OAuth, headers): [/docs/api/authentication](https://appstrate.com/docs/api/authentication)
- **Error format** (RFC 9457 `application/problem+json`): [/docs/api/errors](https://appstrate.com/docs/api/errors)
- **Idempotency** (`Idempotency-Key` header, 409/422 rules): [/docs/api/idempotency](https://appstrate.com/docs/api/idempotency)
- **Webhooks** (HMAC, retries, Standard Webhooks spec): [/docs/api/webhooks-guide](https://appstrate.com/docs/api/webhooks-guide)
- **Rate limits** (per-endpoint buckets): [/docs/self-hosting/rate-limits](https://appstrate.com/docs/self-hosting/rate-limits)
- **Full endpoint list (live)**: `appstrate openapi list [--tag …] [--method …] [--search …]`, or `$APPSTRATE_URL/api/docs` (Swagger UI), or `appstrate openapi export -o openapi.json`

## Preferred call path: `appstrate api`

Always prefer `appstrate api` over raw curl: the CLI injects `Authorization: Bearer <token>`, `X-Org-Id`, and `X-App-Id` from the active profile. The agent never sees the raw token, never has to manage headers, never gets the scope-prefix HTML-200 bug (see below).

```bash
appstrate api GET /api/agents
appstrate api POST /api/agents/@scope/name/run -d '{"input":{"q":"…"}}'
appstrate api /api/agents                                  # method inferred
appstrate -p local api GET /api/agents                     # select profile
```

### `appstrate api` flag reference (all common curl flags are supported)

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

### SSE realtime

SSE endpoints accept the key via query param (EventSource can't send custom headers): `?token=ask_…`. With `appstrate api`, pass `-H 'Accept: text/event-stream'` and the CLI handles the bearer.

## Gotchas the reference docs don't make loud enough

1. **Scope prefix `@` is mandatory.** `GET /api/agents/tractr/my-agent` without the `@` is swallowed by the SPA catch-all middleware and returns HTML 200 (not JSON, not 404). Always write `@tractr/my-agent`. Issue #215.
2. **API key auth needs NO `X-Org-Id` and NO `X-App-Id`.** A key is pinned to one org + one application; both are resolved from the key. Passing them is redundant and, for `X-App-Id` that conflicts with the key's pinned app, returns 400. See [/docs/api/authentication](https://appstrate.com/docs/api/authentication) §API keys.
3. **Draft overwrite on import.** `POST /api/packages/import` returns 409 `DRAFT_OVERWRITE` when the package already has an unpublished draft. Add `-q force=true` to overwrite. Always prefer bumping the version instead.
4. **Version param on runs.** Pin a specific version with `-q version=1.0.0`, or `-q version=latest` for the default dist-tag. Omit to use whichever version resolves for the caller's application.
5. **`result: {}` on success.** The agent didn't call the `@appstrate/output` tool. Cause is always the same: `@appstrate/output` missing from `manifest.dependencies.tools`. Re-pack, re-import.
6. **Inline run 422 `MISSING_TOOL` / `MISSING_SKILL`.** The catalog-side check rejects a dependency the org hasn't imported. Run `appstrate api GET /api/packages/tools` (or `…/skills`) to confirm availability. Issue #155 / #156.
7. **HTML response on an app-scoped route.** Caused by: (a) missing `@` prefix in scope, or (b) raw curl without `X-App-Id` on a route that needs it (cookie auth only — API keys auto-resolve the app). Use `appstrate api` to avoid both.
8. **401 after a week.** Device-flow JWT expired + refresh token rotated out. Re-run `appstrate login [--profile <name>]`.
9. **403 after platform update.** API key predates a new scope. Create a fresh key in the UI, or re-run `appstrate login` if using a JWT.
10. **SSE with API key.** Use `?token=ask_…`, NOT `Authorization: Bearer`. Cookies work for browser EventSource; API keys work for server-side.
11. **`Profile "<name>" not configured`.** No `[profile.<name>]` entry in `config.toml`. Run `appstrate login --profile <name>`, or pick an existing profile.

## Run + schedule quick syntax (full spec in the docs)

- **Run a persisted agent**: `POST /api/agents/@scope/name/run`, body `{ input?, modelId?, proxyId? }` (JSON) or `{ input (JSON string), file }` (multipart). Lifecycle: `pending` → `running` → `success | failed | timeout | cancelled`. Full schema: [/docs/features/runs](https://appstrate.com/docs/features/runs).
- **Inline run** (no import): `POST /api/runs/inline`. Full body schema + limits: `references/inline-runs.md`.
- **Schedule**: `POST /api/agents/@scope/name/schedules`, body `{ name, cronExpression, timezone, connectionProfileId, input }`. Full spec + cron patterns: [/docs/features/scheduling](https://appstrate.com/docs/features/scheduling). Inline runs are NOT schedulable.
