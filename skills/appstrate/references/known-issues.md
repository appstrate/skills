# Known issues — Appstrate platform & CLI

Conjunctural bugs and limitations observed on **`appstrate-version: 2026-03-21`** with CLI **`appstrate@1.0.0-alpha.64`**. If your instance reports a newer version, verify each entry before relying on the workaround — they may have been fixed.

> **Upstream patches in flight** — fixes for several issues below are open as PRs against `appstrate/appstrate`:
> [#360](https://github.com/appstrate/appstrate/pull/360) (DELETE 500 cascade) ·
> [#361](https://github.com/appstrate/appstrate/pull/361) (UI accept `*/*`, PEP 370, healthcheck IPv4) ·
> [#362](https://github.com/appstrate/appstrate/pull/362) (prompt rendering: `./documents/`, pinned slots) ·
> [#363](https://github.com/appstrate/appstrate/pull/363) (`substituteBody` propagation) ·
> [#364](https://github.com/appstrate/appstrate/pull/364) (`ctx.providerCall` + `ctx.readResource`) ·
> [#365](https://github.com/appstrate/appstrate/pull/365) (sidecar 256 KB payload caps) ·
> [#366](https://github.com/appstrate/appstrate/pull/366) (5-min wall on long agent runs).
> Once merged + released, the corresponding entry below becomes obsolete — check the PR status before assuming a bug applies to a recently updated install.

## Table of Contents

- [DELETE agent returns 500 once a run exists](#delete-agent-returns-500-once-a-run-exists)
- [`appstrate run` CLI cannot load `@appstrate/*` system tools](#appstrate-run-cli-cannot-load-appstrate-system-tools)
- [`appstrate run` rejects `.afps`, only accepts `.afps-bundle`](#appstrate-run-rejects-afps-only-accepts-afps-bundle)
- [Self-hosted Tier 3: signed upload URL points to `minio:9000`](#self-hosted-tier-3-signed-upload-url-points-to-minio9000)
- [Webapp file picker rejects `accept: "*/*"` literally](#webapp-file-picker-rejects-accept--literally)
- [Custom provider runs fail with `DraftPackageCatalog: ... has no files in storage`](#custom-provider-runs-fail-with-draftpackagecatalog--has-no-files-in-storage)
- [`POST /api/models` rejects optional `cost.cacheRead`/`cacheWrite` as required](#post-apimodels-rejects-optional-costcacheread--cachewrite-as-required)
- [`provider_call({ substituteBody: true })` silently dropped — placeholders forwarded literally](#provider_call-substitutebody-true-silently-dropped--placeholders-forwarded-literally)

---

## DELETE agent returns 500 once a run exists

**Symptom**: `DELETE /api/packages/agents/{scope}/{name}` returns `500 internal_error` (RFC 9457, no `detail`). Triggered as soon as any run has terminated on the agent (success/failed/cancelled). Fresh agents that never ran return 204 normally.

**Tried and not working** — bulk-delete runs (`DELETE /api/agents/{scope}/{name}/runs`) returns 500 too. Version-by-version deletion succeeds (204) but leaves the shell stuck (`hasUnarchivedChanges: true`).

**Workaround**: delete via the **webapp UI** — the UI uses a different code path that handles the run-cascade correctly. Don't waste cycles on API workarounds.

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

---

## Webapp file picker rejects `accept: "*/*"` literally

**Symptom**: a file field with `fileConstraints.<field>.accept = "*/*"` rejects every uploaded file in the webapp with:

```
Extension non autorisée pour "xxx.pdf" (accepté: */*)
```

The validator compares `*/*` literally instead of treating it as the standard HTML wildcard.

**Workaround**: enumerate MIMEs **and** extensions explicitly:

```json
"accept": "application/pdf,image/jpeg,image/png,.pdf,.jpg,.png"
```

Same logic for family wildcards — `image/*` is also rejected literally; expand it.

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

---

## `provider_call({ substituteBody: true })` silently dropped — placeholders forwarded literally

**Symptom**: a custom-auth provider with `{ email, password }` credentials, an agent calling `provider_call({ providerId, method:"POST", target:"...", body:'{"login":"{{email}}","password":"{{password}}"}', substituteBody: true })`. The body lands upstream with placeholders **untouched**:

```json
{ "json": { "login": "{{email}}", "password": "{{password}}" } }
```

instead of `{"login":"alice@example.com","password":"PWD-12345"}`. Reproducible on **both** local self-hosted and cloud (`https://app.appstrate.com`).

**Discriminating test**: the same request with a placeholder in a **header** (`X-Email: {{email}}`) substitutes correctly. So `fetchCredentials` works, `substituteVars` works — only the body path is broken.

**Root cause** — schema inconsistency across 3 layers:
1. Sidecar declares `substituteBody?: boolean`, parses it, performs conditional substitution. ✓
2. Resolver agent-side (`runtime-pi/mcp/provider-resolver.ts`) does NOT propagate `req.substituteBody` to the MCP args. ✗
3. AFPS runtime schema (`packages/afps-runtime/.../provider-tool.ts`) does NOT declare `substituteBody`. Zod safeParse strips it before it reaches the resolver. ✗

So the sidecar never sees the flag, falls into the buffered body branch without substitution, forwards literal placeholders. Headers and URL substitution still work because they're automatic in the sidecar (not opt-in).

**Implication**: **no OSS Appstrate agent can do a programmatic `username/password` login via `substituteBody` today without the platform patch.** PR #363 ([appstrate/appstrate#363](https://github.com/appstrate/appstrate/pull/363)) — 2 lines across 2 files — fixes this. Tracks as `BUGS-EVO §2.6` upstream.

**Workaround until merged** — for usages where this flag is required (ClassDojo, Amisgest, OrgaBusiness, any SaaS demanding a JSON `{email, password}` login instead of a Bearer header), **the platform patch is mandatory**. No agent-side workaround is viable: putting credentials in plain text in agent config defeats the security model (the LLM sees the secret), and pre-substituting client-side requires reading the credential from the runner's env which providers do not expose.

**For tools that wrap such providers**, defensively check the response for a placeholder echo (`{{email}}` literal in upstream error logs or auth-failure responses) and fail loud with a typed error pointing to this issue, rather than retrying or silently corrupting downstream state.
