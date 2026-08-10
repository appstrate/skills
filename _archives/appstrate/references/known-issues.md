# Known issues — Appstrate platform & CLI

Conjunctural bugs and limitations observed on Appstrate self-hosted installs running upstream `main`. Each entry below ends with an **Upstream** line stating `no PR planned` when the workaround is the canonical answer.

## Table of Contents

- [Use the server runtime, not `appstrate run`](#use-the-server-runtime-not-appstrate-run)
- [Self-hosted Tier 3: signed upload URL points to `minio:9000`](#self-hosted-tier-3-signed-upload-url-points-to-minio9000)
- [Custom provider runs fail with `DraftPackageCatalog: ... has no files in storage`](#custom-provider-runs-fail-with-draftpackagecatalog--has-no-files-in-storage)
- [`POST /api/models` rejects optional `cost.cacheRead`/`cacheWrite` as required](#post-apimodels-rejects-optional-costcacheread--cachewrite-as-required)
- [Sidecar Bun fetch: AWS ALB stickiness lost between separate `provider_call`s](#sidecar-bun-fetch-aws-alb-stickiness-lost-between-separate-provider_calls)

---

## Use the server runtime, not `appstrate run`

Two reproducible bugs make the local PiRunner unsuitable as a default. Both have the same answer: dispatch through the server runtime instead.

**Bug 1 — system tools fail to load**. Running an agent that depends on `@appstrate/output` (or `log`, `state`, …) via `appstrate run` produces:

```
warn: Failed to load tool '@appstrate/output': Cannot find module '@mariozechner/pi-ai'
  from '/var/folders/.../appstrate-run-XXXXX/.agent-tools/@appstrate/output/tool.js'
→ tool: output → ✗ Tool output not found
```

The agent improvises, dumps text instead of calling `output`, and the run completes with `result.output: null`. Cause: PiRunner extracts `tool.js` to a tmpdir, but the bundled `import { Type } from "@mariozechner/pi-ai"` doesn't resolve from that path. `bun add -g @mariozechner/pi-ai` doesn't help (Node module resolution doesn't traverse into the global bun store).

**Bug 2 — `.afps` rejected, only `.afps-bundle` accepted**. `appstrate run /path/to/file.afps` fails with `archive does not contain bundle.json`, even though the help text lists `.afps`. The two extensions name distinct formats:

| Format | Root | Produced by | Consumed by |
|---|---|---|---|
| `.afps` | `manifest.json` (+ `prompt.md`) | `scripts/afps-pack.sh`, `POST /api/packages/import` | API import only |
| `.afps-bundle` | `bundle.json` + `packages/<scope>/<name>/<version>/...` | `GET /api/agents/{scope}/{name}/bundle` | `appstrate run` only |

**Canonical workaround for both**: use the server runtime.
- Persisted: `appstrate api POST /api/agents/{scope}/{name}/run -d '{"input":...}'`
- Inline (no import): `appstrate api POST /api/runs/inline` — see `references/inline-runs.md`

If you genuinely need `appstrate run` (offline, CI without server access), import first and fetch the bundle:

```bash
appstrate api GET '/api/agents/@scope/name/bundle?source=draft' -o local.afps-bundle
appstrate run local.afps-bundle --input '{}' --model-source preset --model <preset-id>
```

This still hits Bug 1 if the agent uses any `@appstrate/*` tool — only the server runtime fixes that.

**Upstream**: no PR planned for either. Bug 1 requires bundling `pi-ai` into each extracted `tool.js` (or a Bun loader plugin in PiRunner). Bug 2 attempt (commit `08611892`) only improved the error message and was reverted (`4b9a5ebb`). Until then, the server-runtime workaround is the canonical answer.

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

**Symptom**: registering a model with a partial `cost` object (e.g. `{ "input": 1.5, "output": 7.5 }`) returns `400 validation_failed` on `cost.cacheRead` and `cost.cacheWrite`. The OpenAPI schema lists all four sub-fields as optional, but the runtime validator requires them once `cost` is present.

**Workaround**: omit the `cost` object entirely (the model is created, pricing simply isn't tracked), or pass all four sub-fields (use `0` as a placeholder for unknown cache pricing).

**Upstream**: no PR planned — OpenAPI schema and runtime Zod validator disagree on which `cost` sub-fields are required when `cost` is present. The omit-`cost` workaround stays canonical.

---

## Sidecar Bun fetch: AWS ALB stickiness lost between separate `provider_call`s

For the general "GET-then-POST" pre-flight pattern used to prime ALB / `JSESSIONID` cookies before a login POST, see the canonical reference in **`references/manifest-schema.md` §"Pre-flight GET for sticky-session load balancers"**. The entry below covers only the residual *timing-sensitive* failure mode that survives even with the pre-flight in place.

**Symptom**: a Spring Security `j_username`/`j_password` form login that works in `curl --cookie-jar` from your laptop fails when executed via two separate `provider_call`s in a tool TS (`GET /login` then `POST /login`). Specifically, the POST lands on a different AWS Application Load Balancer instance than the GET, doesn't have a Spring `JSESSIONID` associated, and silently rejects the login (302 back to `/login` with no error message).

**Cause**: AWS ALB uses two cookies for stickiness — `AWSALB` (cookie-based) + `AWSALBCORS` (CORS variant). Both must be set on the GET and replayed on the POST. The sidecar's redirect-cookie-capture handles cookies set inside a **single** `provider_call` (across its redirect hops), but doesn't aggressively merge `Set-Cookie` headers across **separate** `provider_call`s when the second call lands before the first response's `Set-Cookie` has propagated to the jar.

This is timing-sensitive: it works on some networks (jar updates faster than the next call's TLS handshake) and fails on others.

**Workaround A — keep the bootstrap inside one tool call**: structure your login tool as a single `provider_call` that does the form POST with `j_username={{email}}&j_password={{password}}` directly. The sidecar's redirect-capture handles the GET-then-POST inside that single navigation. The decision-table entry "Pattern B (single-POST)" in `auth-decision-tree.md` already prescribes this — applies here.

**Workaround B — route via FlareSolverr**: for Spring Security flows that genuinely need a pre-flight GET (e.g., the login page produces a server-side token that the POST must echo), use FS sessions. Chromium handles ALB stickiness correctly because it batches cookie reads/writes inside one process. See `references/flaresolverr-pattern.md`.

**Upstream**: no PR planned. Workaround A handles the common case; workaround B handles the rest.
