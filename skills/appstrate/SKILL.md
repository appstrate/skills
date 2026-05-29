---
name: appstrate
description: Build, deploy, run, and iterate on AI agents on self-hosted Appstrate instances via the `appstrate` CLI and REST API. Covers writing an agent (manifest.json + prompt.md), declaring `runtime_tools` (output/log/note/pin/report), wiring **integrations** (`source.kind` none/local/remote, credential delivery) and **mcp-servers** (MCPB `server.{type,entry_point}`), packaging as `.afps`, importing, running (persisted or inline via `/api/runs/inline`), validating a manifest dry-run, monitoring, scheduling, connecting OAuth or API-key services, and switching between prod/staging/dev profiles (`APPSTRATE_PROFILE`, "on prod / local / dev"). Everything is a package with a scoped name (`@scope/name`); four types: `agent`, `skill`, `mcp-server`, `integration`. Triggers on AFPS, sidecar `{ns}__api_call`, integrations, mcp-servers, runtime_tools, scoped packages (`@scope/name`), `INLINE_RUN_LIMITS`, self-hosted Appstrate, or any `appstrate` CLI invocation. **Assumes `appstrate whoami` already succeeds** — does NOT run `appstrate install` (install is a human decision, routed to manual terminal steps).
---

# Appstrate

Manage AI agents on self-hosted Appstrate instances via the `appstrate` CLI or the REST API. Everything is a **package** with a scoped name (`@scope/name`). Four types: `agent`, `skill`, `mcp-server`, `integration`.

> **AFPS 0.x note** — this skill targets the `feat/integrations` platform line (`@afps-spec/schema@^0.4.0`). Manifests are **snake_case**; the former `tool`/`provider` types are now `mcp-server`/`integration`; system tools are `runtime_tools`; external API access flows through **integrations** and the sidecar tool `{ns}__api_call` (the old global `provider_call` is gone).

## Sections

[Setup](#setup) · [Profile management](#profile-management) · [API Conventions](#api-conventions) · [Quick Reference](#quick-reference) · [Create an Agent](#create-an-agent) · [Runtime Tools](#runtime-tools) · [Run an Agent](#run-an-agent) · [Run Inline](#run-inline-no-package-import) · [Update an Agent](#update-an-agent-iterate) · [Schedule an Agent](#schedule-an-agent) · [Create a Skill](#create-a-skill) · [Create an MCP-server](#create-an-mcp-server) · [Create an Integration](#create-an-integration) · [Data Model](#data-model-input-vs-config-vs-memory-vs-output) · [Common Errors](#common-errors) · [References](#references)

- **API docs**: `$APPSTRATE_URL/api/docs` on your instance (or `appstrate openapi list` for the active profile)
- **OpenAPI JSON**: `GET /api/openapi.json` (or `appstrate openapi export`)
- **GitHub (open-source)**: https://github.com/appstrate/appstrate
- **CLI source**: `apps/cli/` inside the monorepo

## Setup

Before doing anything else, verify the user already has a working Appstrate install:

```bash
appstrate whoami
```

If that succeeds, skip to [API conventions](#api-conventions). If it fails (command not found, `Profile "default" not configured`, network error), the user hasn't installed yet — stop and walk them through the manual install below.

### Manual install (instruct the user, do not run via Bash)

Appstrate install is a human decision: tier, Docker-or-not, port, directory. **Do not execute `appstrate install` via your Bash tool.** Prompts don't work in a non-TTY shell, defaults flip to Docker-aware (Tier 3 instead of Tier 0), and the user loses control over their own infrastructure. Ask the user to run these themselves:

```bash
# If Bun is on PATH (fastest path, no binary download)
bunx appstrate install

# Otherwise (auto-installs Bun, verifies binary with minisign)
curl -fsSL https://get.appstrate.dev | bash
```

Both prompt for the tier (default **Tier 0** = Bun only, zero Docker) and pick a free port starting at 3000. The installer generates secrets, boots the stack, opens the webapp when healthy. Then `appstrate login` (interactive device-flow). Re-run `appstrate whoami` from your Bash tool to confirm.

> **Minisign prerequisite** for the `curl | bash` path: `brew install minisign` (macOS), `sudo apt install minisign` (Debian/Ubuntu), `apk add minisign` (Alpine). The `bunx` path skips this.

> **If the user has no LLM key connected**, agent runs fail at dispatch. Two paths: **UI** (simplest) → webapp → Settings → Models → Add a model; **API** (scriptable) → `POST /api/model-provider-credentials` then `POST /api/models`. Validator gotcha around the `cost` object: see `references/known-issues.md`.

For edge cases the skill does NOT cover by default (headless CI, agent-delegated install, tier upgrades, API-key fallback): `references/setup.md`. For multi-instance (prod + staging + dev): named profiles via `--profile <name>`, see `references/profiles.md`.

### Call the API — two paths

**Primary (recommended for coding agents): `appstrate api`**

```bash
appstrate api GET /api/packages/agents
appstrate api POST /api/agents/@your-org/my-agent/run -d '{"input":{"query":"weekly"}}'
appstrate api /api/packages/agents             # method inferred
```

`appstrate api` injects `Authorization: Bearer <token>`, `X-Org-Id`, and `X-App-Id` from the active profile. The agent **never sees the raw token**. Supports common curl flags: `-H`, `-d`, `-F`, `-q`, `-X`, `-o`, `-i`, `-s`, `-L`, `-w '%{http_code}'`, etc. Pick the profile with `-p, --profile <name>` (or `APPSTRATE_PROFILE`).

**Fallback (legacy, or non-CLI environments): raw curl with an API key**

A key is pinned to one org + one application, so the bearer header is the only auth needed:

```bash
curl -s "$APPSTRATE_URL/api/packages/agents" -H "Authorization: Bearer $APPSTRATE_API_KEY"
```

First key from the webapp: **Org settings → Application → API Keys → New** (shown once).

## Profile management

One profile per Appstrate instance, selected with `-p, --profile <name>`. **Infer the profile from the prompt**: "on prod"/"production" → `prod`; "on local"/"localhost"/"sur mon install" → `local`; "on dev" → `dev`; no mention → active default. If the inferred profile isn't configured, run `appstrate whoami --profile <name>` (exit 1) and ask the user to `appstrate login --profile <name>`. Keyring/TOML layout, cross-instance iteration: `references/profiles.md`. (Note: the CLI `connections` command group and connection-profiles were removed — connections are now managed per-integration; see `profiles.md`.)

## API Conventions

**Auth** — `appstrate api` handles it. For raw curl, every org-scoped request needs:
```
Authorization: Bearer ask_…          # OR a device-flow JWT
X-Org-Id: <org-id>
X-App-Id: <application-id>            # required for app-scoped routes (most resource routes)
```

**Scoped routes** — scope MUST include the literal `@`: `@your-org/my-agent`. Without `@`, the SPA middleware returns HTML. **The `@` must be literal, not URL-encoded** — `encodeURIComponent("@scope")` → `%40scope` → misleading `404`. Interpolate `${scope}` raw.

**Casing** — request bodies and responses are **snake_case** (`cron_expression`, `connection_overrides`, `display_name`), with camelCase carve-outs for universal DB fields (`id`, `*Id`, `createdAt`, `hasMore`) and model/proxy endpoints (`modelId`, `proxyId`). List responses are enveloped: `{ object, data, hasMore }`.

**SSE realtime** — SSE endpoints accept the API key via query param `?token=ask_…`; for `appstrate api`, pass `-H 'Accept: text/event-stream'`.

## Quick Reference

| Task | Action |
|------|--------|
| Install Appstrate | **Don't run via Bash.** Tell the user to run `bunx appstrate install` (or `curl -fsSL https://get.appstrate.dev \| bash`), then `appstrate login`. Verify with `appstrate whoami`. |
| Check identity | `appstrate whoami` |
| List orgs / apps | `appstrate org {list,current,switch,create}` · `appstrate app {…}` |
| Explore the API | `appstrate openapi list [--search term] [--method POST]` · `openapi show <op>` |
| Call the API | `appstrate api <METHOD> </api/path> [curl-flags]` |
| List agents / skills | `appstrate api GET /api/packages/agents` · `…/skills` |
| List integrations | `appstrate api GET /api/integrations` |
| Create an agent | Write manifest.json + prompt.md, pack as .afps, import |
| Run an agent (persisted) | `appstrate api POST /api/agents/@scope/name/run -d '{"input":…}'` |
| Run an agent (inline) | `appstrate api POST /api/runs/inline` — manifest + prompt in body → `202 { runId, packageId }` |
| Validate a manifest (dry-run) | `appstrate api POST /api/runs/inline/validate` |
| Check run / logs | `appstrate api GET /api/runs/{id}` · `…/logs` |
| List runs | `appstrate api GET /api/runs -q kind=all -q status=success` |
| Update an agent | Bump version, re-pack, re-import |
| Schedule an agent | `appstrate api POST /api/agents/@scope/name/schedules` (inline runs are not schedulable) |
| Import any package | `appstrate api POST /api/packages/import -F file=@pkg.afps` (agent/skill/mcp-server/integration) |
| Connect an integration | `appstrate api POST '/api/integrations/{packageId}/auths/{authKey}/connect/fields'` (or `/connect/oauth2`) |
| Upload files (before a run) | `POST /api/uploads` → `PUT` bytes → pass `"upload://upl_xxx"` in `input.<file_field>` (see [File uploads](#file-uploads)) |

There is **no** `/api/packages/tools` or `/api/packages/providers` listing, and **no** `PUT /api/agents/.../tools` — MCP servers and integrations are selected in the agent manifest. For conventions, gotchas, rate limits: `references/api-cheatsheet.md`.

## Create an Agent

Five-step workflow. Full detail (code templates, field rules, post-import): `references/create-agent.md`.

1. **Discover** — `appstrate api GET /api/packages/skills`, `GET /api/integrations`, `GET /api/packages/agents`.
2. **Write `manifest.json`** — start from `assets/agent-manifest.json`. Snake_case. `name` is `@scope/name`; dependencies are flat maps `dependencies.{skills,mcp_servers,integrations}`; per-integration tool selection in `integrations_configuration`; `runtime_tools` opt-in; `required` is a top-level array. Schema: `references/manifest-schema.md`.
3. **Write `prompt.md`** — plain Markdown. The platform auto-injects data-only sections (User Input, Configuration, Checkpoint, Pinned Slots, Memory, Skills, per-integration docs, Output Format) **plus a Communication contract**. Do NOT repeat them, and **do NOT list tools** (the agent learns them from MCP `tools/list`). Guidance: `references/prompt-writing.md`.
4. **Package** — `bash scripts/afps-pack.sh /path/to/agent-dir /tmp/my-agent.afps` (ZIP with `manifest.json` at root).
5. **Import** — `appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps`. On 409 `DRAFT_OVERWRITE`, bump the version (preferred) or add `-q force=true`.

## Runtime Tools

Five platform built-ins — `output`, `log`, `note`, `pin`, `report` — opt-in per agent via the manifest `runtime_tools: string[]` array (no package dependency). `output` is required iff `output.schema` is declared. Full reference + the sidecar MCP surface (`run_history`, `recall_memory`, `{ns}__api_call`, `{ns}__{tool}`): `references/runtime-tools.md`.

## Run an Agent

```bash
appstrate api POST /api/agents/@scope/name/run \
  -H 'Content-Type: application/json' \
  -d '{"input": {"query": "weekly report"}}'

# Pin a specific integration connection for this run (optional):
appstrate api POST /api/agents/@scope/name/run \
  -d '{"input": {}, "connection_overrides": {"@appstrate/gmail": "<connection_id>"}}'
```

`connection_overrides` is a flat map `{ "@scope/integration": "<connection_id>" }` (replaces the old `providerProfiles`). If the chosen connection isn't accessible, the run fails **412 `missing_integration_connection`**. The resolved choice is snapshotted server-side (`resolved_connections`, never returned on the wire). Connection resolution cascades through 7 mechanisms (admin pin → org default enforce → run override → schedule override → member pin → org default soft → fallback) — see `references/profiles.md`.

### File uploads

Do NOT pass files as multipart on the run endpoint. Use the upload-token flow:

```bash
appstrate api POST /api/uploads -H 'Content-Type: application/json' \
  -d '{"name":"recu.pdf","size":341307,"mime":"application/pdf"}'   # → { uri, url }
curl -X PUT -H 'Content-Type: application/pdf' --data-binary @recu.pdf "$URL"
appstrate api POST /api/agents/@scope/name/run -d '{"input":{"document":"upload://upl_xxx"}}'
```

The manifest field must be wired as a file field (`format:"uri"` + `contentMediaType` + sibling `file_constraints`). See `references/manifest-schema.md`.

> **Self-hosted Tier 3 gotcha**: the signed URL hostname is Docker-internal (`minio:9000`) and won't resolve from your host unless `S3_PUBLIC_ENDPOINT` is set. Workaround in `references/known-issues.md`.

### Monitor

```bash
appstrate api GET /api/runs/{id}                 # status
appstrate api GET /api/runs/{id}/logs            # logs
appstrate api POST /api/runs/{id}/cancel         # cancel
appstrate api GET /api/realtime/runs/{id} -H 'Accept: text/event-stream'   # SSE
appstrate api GET /api/runs -q kind=inline -q status=success -q limit=50   # global list
```

Status lifecycle: `pending` → `running` → `success` | `failed` | `timeout` | `cancelled`. Runs are fire-and-forget (`202`); there is no synchronous result mode.

## Run Inline (No Package Import)

Put the full manifest + prompt in the body. Dependencies must reference **existing** org/system packages. Not schedulable. `connection_overrides` is NOT accepted inline (resolution falls back to pins/defaults).

```bash
appstrate api POST /api/runs/inline           # → 202 { runId, packageId }
appstrate api POST /api/runs/inline/validate  # dry-run preflight, no credits
```

Body schema, `INLINE_RUN_LIMITS` (note: `max_tools`/`max_authorized_uris`/`wildcard_uri_allowed` were removed), compaction: `references/inline-runs.md`.

## Update an Agent (Iterate)

1. Edit prompt.md / manifest.json → 2. Bump version → 3. Re-pack → 4. Re-import. Same version + `-q force=true` overwrites the draft (no history). Prefer bumping.

## Schedule an Agent

`POST /api/agents/@scope/name/schedules` with a **snake_case** body: `{ name, cron_expression, timezone, input, connection_overrides? }` (+ optional `config_override`, `model_id_override`, `proxy_id_override`, `version_override`). There is **no** `connectionProfileId` — the schedule runs as the creating actor; `connection_overrides` (frozen at creation) pins integration connections. Inline runs are NOT schedulable.

## Create a Skill

A **skill** is a Markdown knowledge package the agent reads at runtime (no code execution). Files: `manifest.json` (`type:"skill"`, start from `assets/skill-manifest.json`) + `SKILL.md` (+ optional `scripts/`, `references/`). Pack + import like an agent. Fields: `references/manifest-schema.md` §"Skill Fields".

## Create an MCP-server

An **mcp-server** (ex-`tool`) packages a Model Context Protocol server (MCPB vocabulary: `server.{type,entry_point,mcp_config}`, `tools[]`). It's referenced by a `local` integration's `source.server`, not by an agent directly. Use it for code execution (shell-out, filesystem). Can opt into the per-run shared workspace + MCP Roots. Full guide: `references/create-mcp-server.md`. Start from `assets/mcp-server-manifest.json`.

## Create an Integration

An **integration** (ex-`provider`) connects an external API. `source.kind` is `none` (REST via `{ns}__api_call`), `local` (packaged mcp-server runner), or `remote` (hosted MCP HTTP/SSE). Auth (`oauth2|api_key|basic|mtls|custom`) + credential `delivery` are declarative; the sidecar injects credentials so the integration never sees the secret. OAuth scopes are inferred per-agent from the tools it selects.

```bash
bash scripts/afps-pack.sh ./my-integration /tmp/my-integration.afps
appstrate api POST /api/packages/import -F file=@/tmp/my-integration.afps
appstrate api POST '/api/integrations/@scope%2Fname/auths/primary/connect/fields' \
  -d '{"credentials": {"api_key": "..."}}'
```

> **Most users never need this** — 60+ built-ins exist (`GET /api/integrations`). Full workflow (source kinds, auths, delivery `{$credential.x}`, ConnectStrategy, scopes, `INTEGRATION.md`): `references/create-integration.md`. Auth-pattern decision table: `references/auth-decision-tree.md`. Anti-bot (FlareSolverr): `references/flaresolverr-pattern.md`. Start from `assets/integration-manifest.json`.

## Data Model: input vs config vs memory vs output

Distinct mechanisms with different persistence. Full breakdown: `references/concepts.md` + `references/state-and-checkpoint.md`.

- **input** — per-run arguments (validated against `input.schema`).
- **config** — persisted per-agent settings (applied to every run).
- **memory** — `note()` archive (read via `recall_memory`) + `pin()` named slots (`## Checkpoint` / `## Pinned Slots`), in `package_persistence`.
- **output** — structured result via `output({ data })`, read at `result.output.<field>`.

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `result: {}` on success | `output` not in `runtime_tools` | Add `"output"` to `runtime_tools` (required when `output.schema` is declared) |
| Publish rejected — legacy dependency key | Manifest uses `dependencies.tools` / `dependencies.providers` | Use `dependencies.mcp_servers` / `dependencies.integrations` |
| Publish rejected — unknown package type | `type:"tool"` / `type:"provider"` | Use `mcp-server` / `integration` |
| 409 `DRAFT_OVERWRITE` | Unpublished changes | Add `-q force=true` (or bump version) |
| HTML response instead of JSON | Missing `@` in scope, or missing `X-App-Id` | Use `@scope/name`; let `appstrate api` inject headers |
| `404 …/%40scope/…` though the agent exists | URL built with `encodeURIComponent(scope)` → `%40` | Interpolate the scope raw |
| Run `success` but `result.summary` is `undefined` | Result is nested under `result.output.X` | Read `result.output.summary` |
| 412 `missing_integration_connection` | Chosen/required integration connection not accessible to the actor | Connect the integration, or pass a valid `connection_overrides` (see `profiles.md`) |
| Agent can't reach the integration (logs: `api_call ready (0 tools)`, agent falls back to `read`/`bash`, "tool not available") | `integrations_configuration[id].tools` is **absent/`[]`** → resolver exposes **zero** tools | Add the tool(s): `"tools": ["api_call"]` for a `none` integration (the #1 silent mistake), or the real `tools_policy` names for MCP. See `references/create-agent.md` |
| Agent ignores instructions you wrote as prose | Free text outside a tool call is never delivered | Route everything through tool calls; don't list/describe tools in the prompt (`prompt-writing.md`) |
| `{ns}__api_call` returns empty `text` | Response ≥ 32 KB spilled to a `resource_link` | Resolve via `ctx.readResource(uri)` (`references/large-responses.md`) |
| Integration connects but calls are unauthenticated | Credential field name ≠ `credentials.schema` field | Match field names exactly (snake_case) |
| `Profile "<name>" not configured` | No `config.toml` entry | `appstrate login --profile <name>` |
| CLI rejects a flag this skill documents | Skill older than the installed CLI | `curl -fsSL https://raw.githubusercontent.com/appstrate/skills/main/install.sh \| bash -s appstrate --update` |

## References

**Canonical public docs** (authoritative — check first for anything the skill doesn't cover):

- Platform concepts: [/docs/get-started/concepts](https://appstrate.com/docs/get-started/concepts) + [/docs/features/*](https://appstrate.com/docs/features/agents)
- API authentication: [/docs/api/authentication](https://appstrate.com/docs/api/authentication) · Errors (RFC 9457): [/docs/api/errors](https://appstrate.com/docs/api/errors)
- CLI reference: [/docs/using-appstrate/cli](https://appstrate.com/docs/using-appstrate/cli)
- AFPS spec (open standard): [afps.appstrate.dev](https://afps.appstrate.dev)
- Live OpenAPI for your instance: `$APPSTRATE_URL/api/docs` or `appstrate openapi list`

**Skill-local references**:

| Need | File |
|------|------|
| Full Create-an-Agent workflow | `references/create-agent.md` |
| Runtime tools + sidecar MCP surface | `references/runtime-tools.md` |
| Create an integration (source kinds, auths, delivery, scopes) | `references/create-integration.md` |
| Create an MCP-server (MCPB, workspace, Roots) | `references/create-mcp-server.md` |
| Platform concepts quick-ref | `references/concepts.md` |
| Manifest schema quick-ref | `references/manifest-schema.md` |
| Writing effective prompts (Communication contract) | `references/prompt-writing.md` |
| API cheatsheet: `appstrate api` flags + gotchas | `references/api-cheatsheet.md` |
| Inline runs (endpoints, limits, compaction) | `references/inline-runs.md` |
| Multi-instance profiles + integration connections/pins | `references/profiles.md` |
| Setup edge cases (headless CI, API-key fallback) | `references/setup.md` |
| MCP-server vs script in a skill — decision rule | `references/tools-vs-scripts.md` |
| Auth-pattern decision table (ConnectStrategy) | `references/auth-decision-tree.md` |
| Large responses (32 KB spill, resource_link, readResource) | `references/large-responses.md` |
| FlareSolverr anti-bot pattern | `references/flaresolverr-pattern.md` |
| State & checkpoint (pin/note, persistence) | `references/state-and-checkpoint.md` |
| Known platform & CLI bugs with workarounds | `references/known-issues.md` |
