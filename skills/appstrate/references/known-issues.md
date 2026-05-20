# Known issues — Appstrate platform & CLI

Conjunctural bugs and limitations observed on Appstrate self-hosted installs running upstream `main`. Each entry below ends with an **Upstream** line: when a fix is merged, the entry is kept as historical context (in case you're running an older snapshot) but tagged `RESOLVED`. When a workaround is the canonical answer, the entry says `no PR planned`.

> **Recently resolved**: PRs [#360](https://github.com/appstrate/appstrate/pull/360) (DELETE 500 cascade), [#361](https://github.com/appstrate/appstrate/pull/361) (UI accept `*/*`, PEP 370, healthcheck IPv4), [#362](https://github.com/appstrate/appstrate/pull/362) (prompt rendering: `./documents/`, pinned slots), [#363](https://github.com/appstrate/appstrate/pull/363) (`substituteBody` propagation), [#364](https://github.com/appstrate/appstrate/pull/364) (`ctx.providerCall` + `ctx.readResource`), [#365](https://github.com/appstrate/appstrate/pull/365) (sidecar 256 KB payload caps), [#366](https://github.com/appstrate/appstrate/pull/366) (5-min wall on long agent runs) — all merged into upstream `main` (commit `d27e9931` or later). If your install is from before 2026-05-08, the entries below tagged `RESOLVED` apply; otherwise they don't.

## Table of Contents

- [DELETE agent returns 500 once a run exists](#delete-agent-returns-500-once-a-run-exists)
- [`appstrate run` CLI cannot load `@appstrate/*` system tools](#appstrate-run-cli-cannot-load-appstrate-system-tools)
- [`appstrate run` rejects `.afps`, only accepts `.afps-bundle`](#appstrate-run-rejects-afps-only-accepts-afps-bundle)
- [Self-hosted Tier 3: signed upload URL points to `minio:9000`](#self-hosted-tier-3-signed-upload-url-points-to-minio9000)
- [Webapp file picker rejects `accept: "*/*"` literally](#webapp-file-picker-rejects-accept--literally)
- [Custom provider runs fail with `DraftPackageCatalog: ... has no files in storage`](#custom-provider-runs-fail-with-draftpackagecatalog--has-no-files-in-storage)
- [`POST /api/models` rejects optional `cost.cacheRead`/`cacheWrite` as required](#post-apimodels-rejects-optional-costcacheread--cachewrite-as-required)
- [`provider_call({ substituteBody: true })` silently dropped — placeholders forwarded literally](#provider_call-substitutebody-true-silently-dropped--placeholders-forwarded-literally)
- [Sidecar Bun fetch: SameSite=Lax cookies dropped on cross-host redirects](#sidecar-bun-fetch-samesitelax-cookies-dropped-on-cross-host-redirects)
- [Sidecar Bun fetch: AWS ALB stickiness lost between separate `provider_call`s](#sidecar-bun-fetch-aws-alb-stickiness-lost-between-separate-provider_calls)

---

## DELETE agent returns 500 once a run exists — `RESOLVED`

**Symptom (historical)**: `DELETE /api/packages/agents/{scope}/{name}` returned `500 internal_error` (RFC 9457, no `detail`) as soon as any run had terminated on the agent. The fix is a schema migration that sets `llm_usage.run_id` FK to `ON DELETE CASCADE`.

**If you hit it on a pre-2026-05-08 install**, the workaround is to delete via the **webapp UI** — that code path handles the run-cascade independently and was never broken.

**Upstream**: [PR #360](https://github.com/appstrate/appstrate/pull/360) **merged** into `main` (~2026-05-08).

---

## `appstrate run` CLI cannot load `@appstrate/*` system tools

**Symptom** when running an agent that depends on `@appstrate/output` (or `log`, `state`, etc.) via `appstrate run`:

```
warn: Failed to load tool '@appstrate/output': Cannot find module '@mariozechner/pi-ai'
  from '/var/folders/.../appstrate-run-XXXXX/.agent-tools/@appstrate/output/tool.js'
→ tool: output → ✗ Tool output not found
```

The agent then improvises, dumps text instead of calling `output`, and the run completes with `result.output: null`.

**Cause**: PiRunner extracts `tool.js` to a tmpdir, but the bundled `import { Type } from "@mariozechner/pi-ai"` doesn't resolve from that path. The CLI binary embeds `pi-ai` for itself but doesn't expose it to extracted tools.

**No user-side fix**: `bun add -g @mariozechner/pi-ai` does not help — Node module resolution from `/var/folders/.../` doesn't traverse into `~/.bun/install/global/node_modules/`.

**Workaround**: run via the server runtime instead.
- Persisted: `appstrate api POST /api/agents/{scope}/{name}/run -d '{"input":...}'`
- Inline (no import): `appstrate api POST /api/runs/inline` — see `references/inline-runs.md`

Both load system tools correctly.

**Upstream**: no PR planned — root cause requires either bundling `pi-ai` into each extracted `tool.js`, a Bun loader plugin in PiRunner, or symlinking the binary's embedded modules into the tmpdir. The server-runtime workaround above is the canonical answer.

---

## `appstrate run` rejects `.afps`, only accepts `.afps-bundle`

**Symptom**: `appstrate run /path/to/file.afps` fails with `archive does not contain bundle.json`, even though the help text says `.afps / .afps-bundle file`.

**Cause**: two distinct formats with the same-ish extension.

| Format | Root | Produced by | Consumed by |
|---|---|---|---|
| `.afps` | `manifest.json` (+ `prompt.md`) | `scripts/afps-pack.sh`, `POST /api/packages/import` | API import only |
| `.afps-bundle` | `bundle.json` + `packages/<scope>/<name>/<version>/...` | `GET /api/agents/{scope}/{name}/bundle` | `appstrate run` only |

**Workaround**: after import, fetch the bundle and run that:

```bash
appstrate api GET '/api/agents/@scope/name/bundle?source=draft' -o local.afps-bundle
appstrate run local.afps-bundle --input '{}' --model-source preset --model <preset-id>
```

Or skip the round-trip entirely and use inline run.

**Upstream**: no PR planned — an initial attempt (commit `08611892`) only improved the error message without resolving the format ambiguity, and was reverted (`4b9a5ebb`). The CLI help still lists `.afps`; until the formats are unified or the help is corrected, the workaround above is the canonical answer.

---

## Self-hosted Tier 3: signed upload URL points to `minio:9000`

**Symptom**: `POST /api/uploads` returns a signed URL like `http://minio:9000/...`. PUT-ing to it from the host (Mac/Linux, the webapp browser, `curl`, a coding agent) fails with `Could not resolve host: minio`. Reproducible from scratch on a fresh `appstrate install --tier 3`.

**Cause**: regression in the Tier 3 installer's compose generator. The canonical `docker-compose.yml` of the OSS repo correctly maps minio's port 9000 on the host **and** references `S3_PUBLIC_ENDPOINT`. The Tier 3 installer drops both: minio publishes only its console port (9001), and `S3_PUBLIC_ENDPOINT` is never propagated to the appstrate service. So the server's two-S3-clients code (it has dedicated logic to sign URLs with a separate public endpoint) falls back to the internal Docker hostname, which is unreachable from outside the network. Cloud is unaffected because its deployment sets `S3_PUBLIC_ENDPOINT=https://storage.appstrate.com` explicitly.

**Workaround** (permanent, drop-in): create `docker-compose.override.yml` next to the install's `docker-compose.yml`. Compose auto-merges it on every `up`, and it survives Appstrate updates.

```yaml
# ~/appstrate/docker-compose.override.yml
services:
  minio:
    networks:
      - appstrate-data
      - appstrate-public  # required: appstrate-data is internal:true,
                           # so the port mapping below is silently
                           # ignored without this second network
    ports:
      - "9000:9000"
  appstrate:
    environment:
      - S3_PUBLIC_ENDPOINT=http://localhost:9000
```

Apply it:

```bash
cd ~/appstrate
docker compose -p appstrate-appstrate-<id> up -d --force-recreate minio appstrate
```

Find the project id with `docker compose ls` (or the install's stdout — it printed it after install). After the recreate, `POST /api/uploads` returns URLs pointing to `localhost:9000` and PUT from the host returns HTTP 200.

**Upstream**: no PR planned — the compose override above is the canonical operator workaround. A proper installer fix (3 changes in the Tier 3 compose generator: re-add port `9000:9000`, attach minio to `appstrate-public`, propagate `S3_PUBLIC_ENDPOINT` default) is feasible but would also require a new install path, not a patch on existing installs.

---

## Webapp file picker rejects `accept: "*/*"` literally — `RESOLVED`

**Symptom (historical)**: a file field with `fileConstraints.<field>.accept = "*/*"` rejected every uploaded file in the webapp with `Extension non autorisée …`. The validator compared `*/*` literally instead of treating it as the HTML wildcard. Same logic for `image/*` and other family wildcards.

**If you hit it on a pre-2026-05-08 install**, enumerate MIMEs AND extensions explicitly:

```json
"accept": "application/pdf,image/jpeg,image/png,.pdf,.jpg,.png"
```

**Upstream**: [PR #361](https://github.com/appstrate/appstrate/pull/361) **merged** into `main` (~2026-05-08) — 1-line fix in `file-widget.tsx`.

---

## Custom provider runs fail with `DraftPackageCatalog: ... has no files in storage`

**Symptom**: any agent that depends on a custom provider you created fails at dispatch.
- Persisted run (`POST /api/agents/{scope}/{name}/run`) returns generic `500 internal_error` with no detail.
- Inline run (`POST /api/runs/inline`) surfaces the actual cause: `DraftPackageCatalog: <provider-id> has no files in storage`.

Use the inline-run path to get a real error when debugging — it bypasses the dispatcher's generic 500 wrapping.

**Cause**: the provider was either (a) created via `POST /api/providers` (flat payload), which writes the DB row but skips file storage entirely, or (b) imported via AFPS but the ZIP only contained `manifest.json`. The runtime requires the AFPS to also contain `PROVIDER.md` — that file gets injected into the agent's system prompt at dispatch so the LLM knows how to call the provider's API. With no files in storage, dispatch refuses to materialize the provider in the sandbox.

**Fix**: package the provider with **both** files, then re-import:

```
my-provider/
├── manifest.json     # type: "provider", definition.* (auth, allowed URIs, …)
└── PROVIDER.md       # endpoints, auth header, response shapes, gotchas
```

```bash
bash scripts/afps-pack.sh ./my-provider /tmp/p.afps
appstrate api POST /api/packages/import -F file=@/tmp/p.afps -q force=true
```

`force=true` overwrites any broken draft created by an earlier flat-create or partial import; no need to bump the version unless you want to keep the broken one as a debugging artefact. Re-running the agent immediately should now succeed.

For a `PROVIDER.md` template, `unzip -p` any built-in provider in [appstrate/appstrate/system-packages](https://github.com/appstrate/appstrate/tree/main/system-packages) (e.g. `provider-firecrawl-1.0.0.afps`).

> **Built-in providers (`@appstrate/*`) are unaffected** — they ship with their `PROVIDER.md` already in place. This bug only bites when you create your own custom provider.

**Upstream**: no PR planned — `PROVIDER.md` is the documented contract per AFPS spec. The 500 wrapping that hides the underlying error message could be improved (the inline-run path already surfaces it correctly), but the missing-`PROVIDER.md` failure is by design.

---

## `POST /api/models` rejects optional `cost.cacheRead` / `cacheWrite` as required

**Symptom**: when registering a custom LLM model via API:

```bash
appstrate api POST /api/models -d '{
  "label":"…", "api":"…", "baseUrl":"…", "modelId":"…", "providerKeyId":"…",
  "cost": { "input": 1.5, "output": 7.5 }
}'
```

Returns `400 validation_failed` with:

```
cost.cacheRead: Invalid input: expected number, received undefined
cost.cacheWrite: Invalid input: expected number, received undefined
```

The OpenAPI schema lists `cost` as a single optional object with all four sub-fields independently optional, but the runtime validator treats the inner fields as required once `cost` is present.

**Workaround**: omit the `cost` object entirely. The model is created successfully and pricing simply isn't tracked.

```bash
appstrate api POST /api/models -d '{
  "label":"Mistral Large 3", "api":"mistral-conversations",
  "baseUrl":"https://api.mistral.ai", "modelId":"mistral-large-2512",
  "providerKeyId":"<id>",
  "input":["text","image"], "contextWindow":256000, "maxTokens":32768
}'
```

If you need cost tracking, provide all four sub-fields (use `0` as a placeholder for cache pricing if unknown).

**Upstream**: no PR planned — the OpenAPI schema and the runtime Zod validator disagree on which `cost` sub-fields are required when `cost` is present. Either path (relax the validator or update the OpenAPI to match) is a 1-line change but no upstream fix has been opened. The omit-`cost` workaround above stays canonical.

---

## `provider_call({ substituteBody: true })` silently dropped — `RESOLVED`

**Symptom (historical)**: a custom-auth provider with `{ email, password }` credentials, an agent calling `provider_call({ method:"POST", body:'{"login":"{{email}}","password":"{{password}}"}', substituteBody: true })`. The body landed upstream with placeholders **untouched** (literal `{{email}}` / `{{password}}` strings).

**Root cause** — schema inconsistency across 3 layers: the sidecar parsed `substituteBody`, but the runtime-pi resolver didn't propagate it, AND the AFPS Zod schema didn't declare it (so safeParse stripped it). Headers/URL substitution worked because automatic.

**Implication of the bug**: before this fix, no Appstrate agent could do a programmatic `username/password` login via `substituteBody`. ADR-003-respecting alternatives (`custom` + tool TS using `substituteBody` to send creds to a login endpoint) were impossible.

**If you hit it on a pre-2026-05-08 install**: there's no agent-side workaround. Putting creds in agent config defeats ADR-003 (LLM sees them); pre-substituting client-side requires reading the credential from env which providers don't expose. Update to a post-PR #363 install.

**For tools that wrap providers depending on this fix**: defensively check upstream responses for a placeholder echo (`{{email}}` literal in auth-failure response bodies) and fail loud — surfaces install-version skew quickly.

**Upstream**: [PR #363](https://github.com/appstrate/appstrate/pull/363) **merged** into `main` (~2026-05-08) — 2 lines across 2 files. Tracked as `BUGS-EVO §2.6` upstream historically.

---

## Sidecar Bun fetch: SameSite=Lax cookies dropped on cross-host redirects

**Symptom**: a multi-step OIDC / OAuth login appears to succeed (POST CAS form returns 200, redirect chain follows) but ends on `?error=Callback` (next-auth) or equivalent vendor error. The session is rejected even though the credentials are valid.

The smoking gun is `"error":"Callback"` in the `__NEXT_DATA__` JSON of the final HTML page. next-auth couldn't verify the OAuth `state` because the `__Secure-next-auth.state` cookie (set during the initial `signin/<provider>` POST) wasn't sent on the final `/api/auth/callback/<provider>?code=...&state=...` hop.

**Cause**: Bun's `fetch` implementation in the sidecar doesn't carry `SameSite=Lax` HTTP-only cookies across cross-host redirects. When the redirect chain crosses domains (e.g., `id.example.com/oauth → www.example.com/api/auth/callback`), the cookie is stripped — even though a real browser would forward it because it's a top-level GET redirect (allowed by SameSite=Lax). HttpOnly cookies are also affected: the tool can't even read them via `document.cookie` and inject them manually.

**Tried and not working**:
- Setting `headers: { Cookie: "..." }` explicitly — the sidecar uses its own cookie jar; manual `Cookie` headers may be ignored or merged unpredictably.
- Following the redirect manually (`redirect: "manual"`) and re-issuing the GET — `provider_call` doesn't expose `redirect: "manual"`.

**Workaround**: route the entire login flow through **FlareSolverr** (Chromium-backed proxy). Chromium handles SameSite semantics correctly. See `references/flaresolverr-pattern.md` for the architecture, the `credentials-substitution-cross-target` pattern (preserves ADR-003), and the `login → sessionId → fetch` pattern.

When this fix is impractical (no Docker, multi-tenant cloud), the only alternative is to switch to a SaaS that doesn't require this style of flow, or to capture cookies manually from a browser session and use the `static cookies` pattern in `auth-decision-tree.md` §3-E.

**Upstream**: no PR planned at the platform layer. The fix lives in Bun itself (cookie jar SameSite semantics) and is out of scope for Appstrate. Pierre's stance ([issue #458](https://github.com/appstrate/appstrate/issues/458)) is that real-browser bypass should be tenant-side infrastructure (proxy + headless), not embedded in the sidecar.

---

## Sidecar Bun fetch: AWS ALB stickiness lost between separate `provider_call`s

**Symptom**: a Spring Security `j_username`/`j_password` form login that works in `curl --cookie-jar` from your laptop fails when executed via two separate `provider_call`s in a tool TS (`GET /login` then `POST /login`). Specifically, the POST lands on a different AWS Application Load Balancer instance than the GET, doesn't have a Spring `JSESSIONID` associated, and silently rejects the login (302 back to `/login` with no error message).

**Cause**: AWS ALB uses two cookies for stickiness — `AWSALB` (cookie-based) + `AWSALBCORS` (CORS variant). Both must be set on the GET and replayed on the POST. The sidecar's redirect-cookie-capture handles cookies set inside a **single** `provider_call` (across its redirect hops), but doesn't aggressively merge `Set-Cookie` headers across **separate** `provider_call`s when the second call lands before the first response's `Set-Cookie` has propagated to the jar.

This is timing-sensitive: it works on some networks (jar updates faster than the next call's TLS handshake) and fails on others.

**Workaround A — keep the bootstrap inside one tool call**: structure your login tool as a single `provider_call` that does the form POST with `j_username={{email}}&j_password={{password}}` directly. The sidecar's redirect-capture handles the GET-then-POST inside that single navigation. The decision-table entry "Pattern B (single-POST)" in `auth-decision-tree.md` already prescribes this — applies here.

**Workaround B — route via FlareSolverr**: for Spring Security flows that genuinely need a pre-flight GET (e.g., the login page produces a server-side token that the POST must echo), use FS sessions. Chromium handles ALB stickiness correctly because it batches cookie reads/writes inside one process. See `references/flaresolverr-pattern.md`.

**Upstream**: no PR planned. Workaround A handles the common case; workaround B handles the rest.
