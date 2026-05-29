# Known issues — Appstrate platform & CLI

Conjunctural bugs and limitations. Each entry states whether it was **observed on `main`** and what its status is on **`feat/integrations`** (the branch this skill targets). Entries end with an **Upstream** line stating `no PR planned` when the workaround is the canonical answer.

## Table of Contents

- [`appstrate run` system-tools / runtime tools (probably resolved)](#appstrate-run-system-tools--runtime-tools-probably-resolved)
- [`.afps` vs `.afps-bundle` rejection](#afps-vs-afps-bundle-rejection)
- [Self-hosted Tier 3: signed upload URL points to `minio:9000` (persists)](#self-hosted-tier-3-signed-upload-url-points-to-minio9000-persists)
- [Custom integration runs fail with `DraftPackageCatalog: ... has no files in storage` (N/A)](#custom-integration-runs-fail-with-draftpackagecatalog--has-no-files-in-storage-na)
- [`POST /api/models` and `cost.cacheRead`/`cacheWrite` (probably fixed)](#post-apimodels-and-costcacheread--cachewrite-probably-fixed)
- [Sidecar Bun fetch: AWS ALB stickiness lost between separate `{ns}__api_call`s](#sidecar-bun-fetch-aws-alb-stickiness-lost-between-separate-nsapi_calls)

---

## `appstrate run` system-tools / runtime tools (probably resolved)

**On `main`** — running an agent that depended on `@appstrate/output` (or `log`, `state`, …) via `appstrate run` failed to load the tool:

```
warn: Failed to load tool '@appstrate/output': Cannot find module '@mariozechner/pi-ai'
  from '/var/folders/.../appstrate-run-XXXXX/.agent-tools/@appstrate/output/tool.js'
→ tool: output → ✗ Tool output not found
```

The agent improvised, dumped text instead of calling `output`, and the run completed with `result.output: null`. Cause on `main`: PiRunner extracted `tool.js` to a tmpdir and the bundled `import { Type } from "@mariozechner/pi-ai"` didn't resolve from that path.

**On `feat/integrations` — probably resolved.** The whole model changed: `@appstrate/*` tool packages no longer exist. The five system tools (`output`, `log`, `note`, `pin`, `report`) are now **`runtime_tools`** — platform built-ins hosted natively by the runner (MCP tools server-side, Pi extensions on the `appstrate run` path), opt-in via the manifest `runtime_tools` array. There is no extracted `tool.js` and no `@mariozechner/pi-ai` import to resolve, so this specific failure mode should not occur. Do not state `appstrate run` is broken for runtime tools. <!-- TODO confirmer par test sur feat/integrations -->

**Recommended path regardless** — for anything beyond a quick local check, dispatch through the server runtime:
- Persisted: `appstrate api POST /api/agents/{scope}/{name}/run -d '{"input":...}'`
- Inline (no import): `appstrate api POST /api/runs/inline` — see `references/inline-runs.md`

---

## `.afps` vs `.afps-bundle` rejection

**Symptom**: `appstrate run /path/to/file.afps` fails with `archive does not contain bundle.json`, even though the help text lists `.afps`. The two extensions name distinct formats:

| Format | Root | Produced by | Consumed by |
|---|---|---|---|
| `.afps` | `manifest.json` (+ `prompt.md`) | `scripts/afps-pack.sh`, `POST /api/packages/import` | API import only |
| `.afps-bundle` | `bundle.json` + `packages/<scope>/<name>/<version>/...` | `GET /api/agents/{scope}/{name}/bundle` | `appstrate run` only |

**Workaround** — to run locally, import first and fetch the bundle:

```bash
appstrate api GET '/api/agents/@scope/name/bundle?source=draft' -o local.afps-bundle
appstrate run local.afps-bundle --input '{}' --model-source preset --model <preset-id>
```

**Upstream**: no PR planned — a bundle-format fix attempt only improved the error message and was reverted. The terminology above (`.afps` = import format rooted at `manifest.json`; `.afps-bundle` = runnable bundle rooted at `bundle.json`) holds on `feat/integrations`. <!-- TODO confirmer terminologie .afps/.afps-bundle sur feat/integrations -->

---

## Self-hosted Tier 3: signed upload URL points to `minio:9000` (persists)

**Status: PERSISTS on `feat/integrations`.** Uploads (`/api/uploads`, reserve→PUT→`upload://`) and `S3_PUBLIC_ENDPOINT` are unchanged on the branch, so this regression and its workaround remain valid as-is.

**Symptom**: `POST /api/uploads` returns a signed URL like `http://minio:9000/...`. PUT-ing to it from the host (Mac/Linux, the webapp browser, `curl`, a coding agent) fails with `Could not resolve host: minio`. Reproducible from scratch on a fresh `appstrate install --tier 3`.

**Cause**: regression in the Tier 3 installer's compose generator. The canonical `docker-compose.yml` of the OSS repo correctly maps minio's port 9000 on the host **and** references `S3_PUBLIC_ENDPOINT`. The Tier 3 installer drops both: minio publishes only its console port (9001), and `S3_PUBLIC_ENDPOINT` is never propagated to the appstrate service. So the server's two-S3-clients code (it has dedicated logic to sign URLs with a separate public endpoint) falls back to the internal Docker hostname, which is unreachable from outside the network. Cloud is unaffected because its deployment sets `S3_PUBLIC_ENDPOINT=https://storage.appstrate.com` explicitly.

**Workaround** (permanent, drop-in): create `docker-compose.override.yml` next to the install's `docker-compose.yml`. Compose auto-merges it on every `up`, and it survives Appstrate updates. On a Tier 3 self-host you set `S3_PUBLIC_ENDPOINT=http://localhost:<port-minio>` (the host-published minio port, 9000 by default below):

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

## Custom integration runs fail with `DraftPackageCatalog: ... has no files in storage` (N/A)

**Status: N/A on `feat/integrations`.** This bug was specific to creating a custom provider via `POST /api/providers` (flat payload), which wrote the DB row but skipped file storage. **The `/api/providers` route has been removed.** There is no flat-create path anymore: integration creation happens **only** by importing an AFPS ZIP via `POST /api/packages/import`, which always stores the package files. The "DB row without files" state is no longer reachable through the supported API, so this entry is obsolete.

For reference, the underlying contract on `feat/integrations`: a custom integration is packaged as an AFPS ZIP containing `manifest.json` (`type: "integration"`) plus an optional `INTEGRATION.md` (inlined into the agent prompt as `### API Documentation`; replaces the old mandatory `PROVIDER.md`). Pack and import:

```bash
bash scripts/afps-pack.sh ./my-integration /tmp/acme.afps
appstrate api POST /api/packages/import -F file=@/tmp/acme.afps -q force=true
```

See `create-integration.md`.

---

## `POST /api/models` and `cost.cacheRead`/`cacheWrite` (probably fixed)

**On `main`** — registering a model with a partial `cost` object (e.g. `{ "input": 1.5, "output": 7.5 }`) returned `400 validation_failed` on `cost.cacheRead` and `cost.cacheWrite`: the OpenAPI schema listed all four sub-fields as optional, but the runtime validator required them once `cost` was present.

**On `feat/integrations` — probably fixed.** The OpenAPI schema in `models.ts` now declares `cacheRead`/`cacheWrite` (camelCase, per the model-providers DTO carve-out), aligning the schema with the validator, so a partial `cost` object should be accepted. <!-- TODO confirmer par test (POST /api/models avec cost partiel) -->

**Fallback workaround** (if it still bites): omit the `cost` object entirely (the model is created, pricing simply isn't tracked), or pass all four sub-fields (use `0` as a placeholder for unknown cache pricing).

---

## Sidecar Bun fetch: AWS ALB stickiness lost between separate `{ns}__api_call`s

For the general "GET-then-POST" pre-flight pattern used to prime ALB / `JSESSIONID` cookies before a login POST, see the canonical reference in **`references/manifest-schema.md` §"Pre-flight GET for sticky-session load balancers"**. The entry below covers only the residual *timing-sensitive* failure mode that survives even with the pre-flight in place. The cookie-jar pattern remains relevant on `feat/integrations`; only the call surface changed (`provider_call` → `{ns}__api_call`).

**Symptom**: a Spring Security `j_username`/`j_password` form login that works in `curl --cookie-jar` from your laptop fails when executed via two separate `{ns}__api_call`s (`GET /login` then `POST /login`). Specifically, the POST lands on a different AWS Application Load Balancer instance than the GET, doesn't have a Spring `JSESSIONID` associated, and silently rejects the login (302 back to `/login` with no error message).

**Cause**: AWS ALB uses two cookies for stickiness — `AWSALB` (cookie-based) + `AWSALBCORS` (CORS variant). Both must be set on the GET and replayed on the POST. The sidecar's redirect-cookie-capture handles cookies set inside a **single** `{ns}__api_call` (across its redirect hops), but doesn't aggressively merge `Set-Cookie` headers across **separate** `{ns}__api_call`s when the second call lands before the first response's `Set-Cookie` has propagated to the jar.

This is timing-sensitive: it works on some networks (jar updates faster than the next call's TLS handshake) and fails on others.

**Workaround A — keep the bootstrap inside one tool call**: structure the login as a single `{ns}__api_call` that does the form POST with `j_username={{email}}&j_password={{password}}` directly (via `substituteBody`). The sidecar's redirect-capture handles the GET-then-POST inside that single navigation. The decision-table entry "Pattern B (single-POST)" in `auth-decision-tree.md` already prescribes this — applies here.

**Workaround B — route via a local integration + solver**: for Spring Security flows that genuinely need a pre-flight GET (e.g., the login page produces a server-side token that the POST must echo), drive a tenant-side browser solver. Chromium handles ALB stickiness correctly because it batches cookie reads/writes inside one process. See `references/flaresolverr-pattern.md`.

**Upstream**: no PR planned. Workaround A handles the common case; workaround B handles the rest.
