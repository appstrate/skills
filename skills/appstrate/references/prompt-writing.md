# Writing Effective prompt.md Files

## Table of Contents

- [Container Environment](#container-environment)
- [Auto-Injected Sections](#auto-injected-sections)
- [Sidecar Proxy Protocol](#sidecar-proxy-protocol)
- [Placeholder Semantics — `{{var}}` vs `<MARKER>`](#placeholder-semantics--var-vs-marker)
- [Recommended Structure](#recommended-structure)
- [Memory](#memory-scopes)
- [Incremental Processing](#incremental-processing)
- [Common Mistakes](#common-mistakes)

## Container Environment

- **Runtimes**: Bun (primary) + Python3/pip
- **Working dir**: `/workspace`
- **Uploads**: `./documents/<filename>` (relative to cwd), only when the manifest field is wired as a file field (see `manifest-schema.md` §"File / upload fields"). If the system prompt has no `## Documents` section, the file wasn't injected — fix the manifest, don't search for the file.
- **Ephemeral**: destroyed after execution. Persist via state, memory, output only.
- **Network**: direct outbound HTTP/HTTPS for public endpoints. Sidecar only for authenticated provider calls.

## Auto-Injected Sections

The platform prepends these automatically. Do NOT repeat them in prompt.md:

1. `## System` + `### Environment` — identity, container, timeout
2. `### Persistence` — state + memory
3. `### Tools` — `workspace_list/read/write/delete/move/mkdir/delete_folder` + attached tools
4. `### Skills` — references at `.pi/skills/`
5. `## Authenticated Provider API` — sidecar proxy with `X-Provider`
6. `## User Input` — input field values
7. `## Documents` — uploaded file paths
8. `## Configuration` — config values
9. `## Previous State` — JSON from last execution (legacy `set-state` path)
10. `## Checkpoint` — content of `pin({ key: "checkpoint", ... })` from the previous run, rendered as fenced JSON
11. `## Pinned Slots` — content of every `pin({ key: "<custom>", ... })` (any key other than `"checkpoint"`), rendered as `### <key>` subsections (requires platform patch `ebaa95c7` — without it, slots with custom keys are stored but not rendered)
12. `## Memory` — pinned memos (no key, written via `note` with `pinned: true`)
13. `## Execution History` — curl for history via sidecar
14. `## Output Format` — expected JSON + validation rules

> **State / pin pattern (post-ADR-011/012/013)** — modern agents read cross-run state from sections 10-11, NEVER via `recall_memory` (which only searches the archive of `note(content)` entries with `key=null`). Tell the LLM explicitly in `prompt.md`: *"Read state from `## Checkpoint` and `## Pinned Slots`. Do NOT call `recall_memory` to look for state — that tool searches archive notes, not pinned slots."* Full pattern + 5 gotchas: see `references/state-and-checkpoint.md`.

## Sidecar Proxy Protocol

Authenticated API calls MUST go through the sidecar:

```bash
curl -s "$SIDECAR_URL/proxy" \
  -H "X-Provider: @appstrate/gmail" \
  -H "X-Target: https://gmail.googleapis.com/gmail/v1/users/me/messages" \
  -H "Authorization: Bearer {{access_token}}"
```

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Provider` | Yes | Scoped provider ID (`@scope/name`) |
| `X-Target` | Yes | Full target URL |
| `X-Substitute-Body` | No | `true` to replace `{{placeholders}}` in body |
| `X-Proxy` | No | Override proxy for this request |

### Credential Placeholders

| Auth Mode | Placeholder | Example |
|-----------|-------------|---------|
| OAuth2 | `{{access_token}}` | `Authorization: Bearer {{access_token}}` |
| API Key | `{{apiKey}}` | `X-Api-Key: {{apiKey}}` |
| Custom | `{{fieldName}}` | Any field from `credentialSchema` |

### Response Behavior

- Forwarded as-is (status + body + Content-Type)
- >50KB truncated (`X-Truncated: true`)
- Sidecar errors: `{ "error": "..." }` with 4xx/5xx

Public APIs (no auth): call directly, no sidecar needed.

## Placeholder Semantics — `{{var}}` vs `<MARKER>`

Two superficially-similar placeholder conventions with **opposite** semantics coexist in `authMode: "custom"` provider login bodies. Confusing them silently breaks the call — the LLM masks `{{email}}` as `<USERNAME>`, the sidecar finds no `{{...}}` left to substitute, and the upstream receives the literal mask. Symptom: `502 invalid_grant` / `401 INVALID_CREDENTIALS` while curl direct works.

**Scope** — only `authMode: "custom"`. The 4 other modes (`oauth2`, `oauth1`, `api_key`, `basic`) inject credentials via header server-side; the LLM never touches placeholders. Custom shows up on reverse-engineered SaaS (no public OAuth, undocumented token endpoints) where the agent must construct a `POST /token` body manually.

### `{{var}}` — server-side substitution, MUST stay literal

The sidecar replaces every `{{var}}` in the body with `credentials.var` when `substituteBody: true`. The agent never sees the real values. **Keep the placeholders intact character-for-character.**

```typescript
// ✅ Correct
provider_call({
  body: "grant_type=password&username={{email}}&password={{password}}&...",
  substituteBody: true
})

// ❌ Wrong — agent self-substituted with masks → upstream gets literal `<USERNAME>` → 401/502
provider_call({
  body: "grant_type=password&username=<USERNAME>&password=<PASSWORD>&...",
  substituteBody: true
})
```

### `<MARKER>` — agent-computed, MUST be replaced before the call

Angle-bracketed UPPERCASE names (`<FRESH_DEVICE_ID>`, `<ACCESS_TOKEN>`, `<MONTH_FOLDER_ID>`) are markers the agent replaces with a value it computes (UUID, token from a previous response, resolved ID).

```typescript
// ✅ Correct — agent replaces the marker
body: "...&device_id=appstrate-2026-05-09T15-41-41-0dc4&..."

// ❌ Wrong — marker left literal
body: "...&device_id=<FRESH_DEVICE_ID>&..."
```

### Verbatim CRITICAL block to embed

Drop this in the prompt or the provider's `PROVIDER.md` whenever both conventions interpolate the same body:

```md
> **CRITICAL — placeholder semantics:**
> - `{{email}}` / `{{password}}` are SERVER-SIDE. Keep them character-for-character.
>   The sidecar substitutes via `substituteBody: true`. NEVER replace with masks
>   (`<USERNAME>`, `<MASKED>`) or actual values.
> - `<FRESH_DEVICE_ID>` is AGENT-SIDE. Replace with a value YOU compute
>   (e.g. `uuidgen` via bash tool).
```

**Best home for the block: the provider's `PROVIDER.md`** — auto-injected into every consuming agent's system prompt, single source of truth.

### Diagnose after the fact

```bash
appstrate api GET /api/runs/{runId}/logs \
  | jq -r '.[] | select(.data.tool == "provider_call") | .data.args.body'
```

If `username=<USERNAME>` (or any angle-bracket form) appears where `{{email}}` was expected, the agent self-substituted. Fix the prompt or the provider's `PROVIDER.md`.

## Recommended Structure

```markdown
# Objective

One clear sentence.

# Steps

1. **Fetch data**
   ```bash
   curl -s "$SIDECAR_URL/proxy" \
     -H "X-Provider: @appstrate/provider" \
     -H "X-Target: https://api.example.com/endpoint" \
     -H "Authorization: Bearer {{access_token}}"
   ```
2. **Process** — Transform, filter, summarize
3. **Return results** — JSON matching output schema

# Incremental Processing

How to use Previous State for delta processing.

# Rules

- Constraints and edge cases
- Error handling
- Output format
```

## Memory

| Scope | Purpose | Visibility |
|-------|---------|------------|
| Memories | API quirks, data patterns, learnings | Shared across all users of the agent |

Include memory instructions only when the agent should learn across runs. Be selective.

## Incremental Processing

For scheduled/recurring agents, use state to track progress:

```markdown
Check `## Previous State` for `lastSyncTimestamp`.

- **First run**: Process all items from last 7 days.
- **Subsequent runs**: Only items after `lastSyncTimestamp`.

Always return `state.lastSyncTimestamp` = current timestamp.
Process all pages before updating timestamp (timeout safety).
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Repeating `## User Input` or `## Configuration` | Platform injects these — just reference values |
| `X-Service` instead of `X-Provider` | Use `X-Provider: @scope/name` |
| Missing `X-Target` header | Always include full URL |
| URL-based routing (`$SIDECAR_URL/proxy/https://...`) | Use header: `X-Target` for URL |
| No credential placeholder | Add `Authorization: Bearer {{access_token}}` etc. |
| Hardcoding URLs from config | Put in `config.schema`, reference from config |
| `required: true` on properties | Use top-level `"required": ["field1"]` array |
| No output format specified | Include clear JSON example |
| Writing prompt in wrong language | Match target audience language |
| JSON output not mandatory | Agent must always return valid JSON |
