---
name: appstrate
description: Build, deploy, run, and iterate on AI agents on self-hosted Appstrate instances via the `appstrate` CLI and REST API. Use for writing or editing an agent (manifest.json + prompt.md), packaging as `.afps`, importing, running (persisted or inline/ephemeral), validating a manifest dry-run, monitoring runs, scheduling, managing skills/tools/providers, connecting OAuth or API-key services, switching between prod/staging/dev profiles, or calling `appstrate api` / exploring the OpenAPI schema. **Assumes `appstrate whoami` already succeeds** — the skill does NOT run `appstrate install` (install is a human decision, routed to manual terminal steps). Triggers on mentions of AFPS, sidecar proxy, scoped packages (`@scope/name`), inline runs (`/api/runs/inline`), `INLINE_RUN_LIMITS`, `APPSTRATE_PROFILE`, "on prod / local / dev", self-hosted Appstrate, or any `appstrate <command>` invocation.
---

# Appstrate

Manage AI agents on self-hosted Appstrate instances via the `appstrate` CLI or the REST API. Everything is a **package** with a scoped name (`@scope/name`). Four types: `agent`, `skill`, `tool`, `provider`.

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

Appstrate install is a human decision: tier, Docker-or-not, port, directory. **Do not execute `appstrate install` via your Bash tool.** Prompts don't work in a non-TTY shell, defaults flip to Docker-aware (Tier 3 instead of Tier 0), and the user loses control over their own infrastructure. Instead, ask the user to run these commands themselves in a terminal:

```bash
# If Bun is on PATH (fastest path, no binary download)
bunx appstrate install

# Otherwise (auto-installs Bun, verifies binary with minisign)
curl -fsSL https://get.appstrate.dev | bash
```

Both prompt interactively for the tier (default **Tier 0** = Bun only, zero Docker) and pick a free port starting at 3000. The installer generates secrets, boots the stack, opens the webapp when healthy.

Then sign in (also interactive — opens a browser for device-flow approval):

```bash
appstrate login
```

Re-run `appstrate whoami` from your Bash tool to confirm. When it returns the user's identity + pinned org + pinned app, setup is done.

> **Minisign prerequisite** for the `curl | bash` path: `brew install minisign` (macOS), `sudo apt install minisign` (Debian/Ubuntu), `apk add minisign` (Alpine). The `bunx` path skips this entirely.

> **If the user has no LLM key connected**, agent runs will fail at dispatch. Tell them to open the webapp at `http://localhost:3000` → Settings → Models → Add a model. The skill cannot add API keys for them (no public endpoint for it).

For edge cases the skill does NOT cover by default (headless CI, agent-delegated install, tier upgrades, non-interactive flags, API-key fallback for environments without the CLI): `references/setup.md`.

For multi-instance setups (prod + staging + dev): use named profiles via `--profile <name>`. Full guide: `references/profiles.md`.

### Call the API — two paths

**Primary (recommended for coding agents): `appstrate api`**

```bash
appstrate api GET /api/agents
appstrate api POST /api/agents/@tractr/my-agent/run -d '{"input":{"query":"weekly"}}'
appstrate api /api/agents                    # method inferred
```

`appstrate api` injects `Authorization: Bearer <token>`, `X-Org-Id`, and `X-App-Id` from the active profile. The agent **never sees the raw token**. Supports every common curl flag: `-H`, `-d`, `-F`, `-q`, `-X`, `-o`, `-i`, `-s`, `-L`, `-f`, `--fail-with-body`, `--retry`, `--max-time`, `-v`, `-w '%{http_code}'`, etc.

Pick the active profile with the global `-p, --profile <name>` flag (or `APPSTRATE_PROFILE` env var, or the `defaultProfile` in `config.toml`):

```bash
appstrate -p local api GET /api/agents
APPSTRATE_PROFILE=local appstrate api GET /api/agents
```

**Fallback (legacy, or for non-CLI environments): raw curl with an API key**

When the CLI can't run (old CI images, restricted containers, third-party scripts), use an API key. A key is pinned to one org + one application, so the bearer header is the only auth needed — no `X-Org-Id`, no `X-App-Id`:

```bash
curl -s "$APPSTRATE_URL/api/agents" \
  -H "Authorization: Bearer $APPSTRATE_API_KEY"
```

Authoritative reference (scope matrix, impersonation, SSE query-param, errors): [appstrate.com/docs/api/authentication](https://appstrate.com/docs/api/authentication). First key is created from the webapp: **Paramètres de l'organisation → Application → Clés API → Nouvelle clé API** (shown once).

## Profile management

One profile per Appstrate instance, selected with `-p, --profile <name>`. Commands reference: [/docs/using-appstrate/cli#profile-workflow](https://appstrate.com/docs/using-appstrate/cli#profile-workflow). Keyring/TOML layout, cross-instance iteration, gotchas: `references/profiles.md`.

**Infer profile from the user prompt**: "on prod" / "production" → `prod`; "on local" / "sur mon install" / "localhost" → `local`; "on dev" → `dev`; no mention → active default. If the inferred profile is not configured, run `appstrate whoami --profile <name>` (exit 1) and ask the user to run `appstrate login --profile <name>` rather than guessing.

## API Conventions

**Auth** — `appstrate api` handles this automatically. For raw curl, every org-scoped request needs:
```
Authorization: Bearer ask_…          # OR a device-flow JWT
X-Org-Id: <org-id>
X-App-Id: <application-id>           # NEW: required for app-scoped routes (most resource routes)
```

**Scoped routes** — scope MUST include the `@` prefix: `@tractr/my-agent`, NOT `tractr/my-agent`. Without `@`, the catch-all SPA middleware swallows the request and returns HTML.

**SSE realtime** — SSE endpoints accept the API key via query param: `?token=ask_…`. For `appstrate api`, pass `-H 'Accept: text/event-stream'` and the CLI handles the bearer.

All curl examples below use `appstrate api` by default. If you need the raw-curl form, swap `appstrate api METHOD /api/x` → `curl -X METHOD "$APPSTRATE_URL/api/x" -H "Authorization: …" -H "X-Org-Id: …" -H "X-App-Id: …"`.

## Quick Reference

| Task | Action |
|------|--------|
| Install Appstrate | **Don't run via Bash.** Tell the user to run `bunx appstrate install` (or `curl -fsSL https://get.appstrate.dev \| bash` if no Bun) in their own terminal, then `appstrate login`. Verify with `appstrate whoami` from your Bash tool. |
| Sign in to an instance | `appstrate login [--instance <url>]` |
| Check identity | `appstrate whoami` |
| List orgs / switch / create | `appstrate org {list,current,switch,create}` |
| List apps / switch / create | `appstrate app {list,current,switch,create}` |
| Explore the API | `appstrate openapi list [--search term] [--tag …] [--method POST]` |
| Show one endpoint | `appstrate openapi show <operationId \| METHOD /path>` |
| Dump full OpenAPI | `appstrate openapi export [-o file.json]` |
| Call the API | `appstrate api <METHOD> </api/path> [curl-flags]` |
| Create an agent | Write manifest.json + prompt.md, pack as .afps, import |
| Run an agent (persisted) | `appstrate api POST /api/agents/@scope/name/run -d '{"input":…}'` |
| Run an agent (inline, no import) | `appstrate api POST /api/runs/inline` — manifest + prompt in body, returns `202 { runId, packageId }` |
| Validate a manifest (dry-run) | `appstrate api POST /api/runs/inline/validate` — preflight without firing, no credits burned |
| Check run status | `appstrate api GET /api/runs/{id}` |
| View logs | `appstrate api GET /api/runs/{id}/logs` |
| List runs globally | `appstrate api GET /api/runs -q kind=all -q status=success` |
| Update an agent | Bump version, re-pack, re-import |
| Schedule an agent | `appstrate api POST /api/agents/@scope/name/schedules` (inline runs are not schedulable) |
| List everything | `appstrate api GET /api/agents`, `…/api/packages/skills`, `…/api/packages/tools` |
| Manage applications | `appstrate app …` or `appstrate api /api/applications` |
| Manage end users | `appstrate api /api/end-users` (per-application) |
| Upload files | `appstrate api POST /api/uploads/request` → upload → `appstrate api POST /api/uploads/confirm` |
| Configure OAuth clients | `appstrate api /api/oauth-clients` (OIDC provider) |

For API conventions, gotchas, and rate limits: `references/api-cheatsheet.md`. For the full endpoint list, `appstrate openapi list` or fetch `GET /api/openapi.json`.

## Create an Agent

Five-step workflow. Full detail (code templates, manifest field rules, prompt structure, post-import configure commands): `references/create-agent.md`.

1. **Discover available resources** — list system tools, skills, providers, existing agent names: `appstrate api GET /api/packages/tools` (+ `/skills`, `/api/providers`, `/api/agents`).
2. **Write `manifest.json`** — start from `assets/agent-manifest.json`. Critical: `name` is `@scope/name`, every dependency declared explicitly (nothing auto-enabled), `required` is a top-level array. Schema details: `references/manifest-schema.md`. Tools decision guide: `references/system-tools.md`.
3. **Write `prompt.md`** — plain Markdown, no template syntax. Platform auto-injects User Input, Configuration, Previous State, Memory, Tools, Skills, Providers, Output Format — do not repeat them. Guidance: `references/prompt-writing.md`.
4. **Package as .afps** — `bash scripts/afps-pack.sh /path/to/agent-dir /tmp/my-agent.afps`. The `.afps` is a ZIP with `manifest.json` at root.
5. **Import** — `appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps`. On 409 `DRAFT_OVERWRITE`, bump the version (preferred) or add `-q force=true`.

Optional post-import: attach skills, set config values, override LLM model (see `references/create-agent.md` §Step 5).

## Run an Agent

```bash
# Basic run
appstrate api POST /api/agents/@scope/name/run \
  -H 'Content-Type: application/json' \
  -d '{"input": {"query": "weekly report"}}'

# With file upload (multipart)
appstrate api POST /api/agents/@scope/name/run \
  -F 'input={"description": "Process this"}' \
  -F 'file=@/path/to/file.pdf'

# Specific version
appstrate api POST /api/agents/@scope/name/run -q version=1.0.0 \
  -d '{"input": {}}'
```

### Monitor

```bash
# Status
appstrate api GET /api/runs/{id}

# Logs
appstrate api GET /api/runs/{id}/logs

# Cancel
appstrate api POST /api/runs/{id}/cancel

# SSE realtime stream
appstrate api GET /api/realtime/runs/{id} -H 'Accept: text/event-stream'

# Global run list (cross-agent, supports kind=all|package|inline, status, date filters)
appstrate api GET /api/runs -q kind=inline -q status=success -q limit=50
```

Status lifecycle: `pending` → `running` → `success` | `failed` | `timeout` | `cancelled`

## Run Inline (No Package Import)

Skip the pack/import cycle by putting the full manifest + prompt in the request body. Good for one-shot agents or rapid iteration. Dependencies must reference **existing** org/system packages (no new inline definitions). Not schedulable.

```bash
appstrate api POST /api/runs/inline           # execute, returns 202 { runId, packageId }
appstrate api POST /api/runs/inline/validate  # dry-run preflight, no credits
```

Full request/response schema, `INLINE_RUN_LIMITS`, compaction, choosing inline vs package import: `references/inline-runs.md`.

## Update an Agent (Iterate)

1. Edit prompt.md and/or manifest.json
2. Bump version (e.g., `1.0.0` → `1.1.0`)
3. Re-pack: `bash scripts/afps-pack.sh $AGENT_DIR /tmp/my-agent.afps`
4. Re-import: `appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps`

Same version + `-q force=true` overwrites the draft (no version history). Always prefer bumping.

## Schedule an Agent

`POST /api/agents/@scope/name/schedules` with `{ name, cronExpression, timezone, connectionProfileId, input }`. Inline runs are NOT schedulable (schedules require a persisted package). Full body spec, cron patterns, worker rate limits: [/docs/features/scheduling](https://appstrate.com/docs/features/scheduling).

## Create a Skill

A **skill** is a Markdown knowledge package the agent reads at runtime (no code execution). Full concept + lifecycle: [/docs/features/skills](https://appstrate.com/docs/features/skills). Files:

```
manifest.json    # type: "skill" — start from assets/skill-manifest.json
SKILL.md         # YAML frontmatter + Markdown body (the knowledge the agent consumes)
scripts/         # Optional — bundled helper scripts
references/      # Optional — extra Markdown docs the agent can load on demand
```

Pack + import like an agent:
```bash
bash scripts/afps-pack.sh /path/to/skill-dir /tmp/my-skill.afps
appstrate api POST /api/packages/import -F file=@/tmp/my-skill.afps
```

Manifest field list: `references/manifest-schema.md` > "Skill Fields".

## Create a Tool

A **tool** is an **executable TypeScript extension** the agent invokes as a function. Full concept + sandbox model: [/docs/features/tools](https://appstrate.com/docs/features/tools). Files:

```
manifest.json    # type: "tool" — start from assets/tool-manifest.json
index.ts         # Tool implementation
```

Non-obvious skill-side requirements:
- `manifest.entrypoint` must point to `index.ts` (or your compiled output).
- `manifest.tool.inputSchema` is a **JSON Schema** validated by the runtime before calling the tool.
- `index.ts` must implement the execute signature from `@mariozechner/pi-coding-agent`. Install as a dev dependency: `bun add -d @mariozechner/pi-coding-agent`. Signature: `(toolCallId, params, signal)` — `params` is the **second** arg, not the first. Return type: `{ content: [{ type: "text", text: "..." }] }`, NOT a plain string.
- The tool runs inside the agent's sandbox container with `fetch` + filesystem access, but has no access to the caller's keyring or shell env.

Pack + import:
```bash
bash scripts/afps-pack.sh /path/to/tool-dir /tmp/my-tool.afps
appstrate api POST /api/packages/import -F file=@/tmp/my-tool.afps
```

Manifest field list + execute signature + return format: `references/manifest-schema.md` > "Tool Fields".

## Data Model: input vs config vs state vs memory vs output

Five distinct mechanisms, different persistence semantics. Full conceptual breakdown + examples: `references/concepts.md` (skill-local) and [/docs/features/memory](https://appstrate.com/docs/features/memory) + [/docs/features/runs](https://appstrate.com/docs/features/runs).

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `result: {}` on success | `@appstrate/output` not in `dependencies.tools` | Add `"@appstrate/output": "^1.0.0"` to manifest dependencies |
| 409 `DRAFT_OVERWRITE` | Package has unpublished changes | Add `-q force=true` to import URL |
| 403 `agents:write required` | API key missing new scopes after platform update | Create a new API key in the UI, or re-run `appstrate login` |
| HTML response instead of JSON | Missing `@` in scope, or missing `X-App-Id` on an app-scoped route | Use `@scope/name`; let `appstrate api` inject headers |
| `Profile "<name>" not configured` | No `config.toml` entry for that profile | Run `appstrate login --profile <name>` |
| Agent doesn't call `output` tool | Tool not in available tool list | Verify `dependencies.tools` in manifest, re-import |
| CLI rejects a flag this skill documents (e.g. `unknown option '--foo'`) | Skill is older than the installed CLI version | Suggest the user updates this skill: `curl -fsSL https://raw.githubusercontent.com/appstrate/skills/main/install.sh \| bash -s appstrate --update` |

## References

**Canonical public docs** (always authoritative, check these first for anything the skill doesn't cover):

- Platform concepts: [/docs/get-started/concepts](https://appstrate.com/docs/get-started/concepts) + [/docs/features/*](https://appstrate.com/docs/features/agents)
- API authentication: [/docs/api/authentication](https://appstrate.com/docs/api/authentication)
- Error format (RFC 9457): [/docs/api/errors](https://appstrate.com/docs/api/errors)
- Idempotency: [/docs/api/idempotency](https://appstrate.com/docs/api/idempotency)
- Webhooks: [/docs/api/webhooks-guide](https://appstrate.com/docs/api/webhooks-guide)
- Rate limits: [/docs/self-hosting/rate-limits](https://appstrate.com/docs/self-hosting/rate-limits)
- CLI reference: [/docs/using-appstrate/cli](https://appstrate.com/docs/using-appstrate/cli)
- AFPS spec (open standard): [afps.appstrate.dev](https://afps.appstrate.dev)
- Live OpenAPI for your instance: `$APPSTRATE_URL/api/docs` or `appstrate openapi list`

**Skill-local references** (quick-refs + operational knowledge not in the public docs):

| Need | File |
|------|------|
| Full 5-step Create an Agent workflow (code, rules, post-import) | `references/create-agent.md` |
| Platform concepts quick-ref (+ pointers to all features pages) | `references/concepts.md` |
| Manifest schema quick-ref (+ pointer to AFPS spec) | `references/manifest-schema.md` |
| Writing effective prompts | `references/prompt-writing.md` |
| System tools decision guide (output, state, report, etc.) | `references/system-tools.md` |
| API cheatsheet: `appstrate api` flags + skill-specific gotchas | `references/api-cheatsheet.md` |
| Inline runs (endpoints, limits, compaction, gotchas) | `references/inline-runs.md` |
| Multi-instance profiles (keyring + TOML, `--profile`, `appstrate org/app`) | `references/profiles.md` |
| Setup edge cases (headless CI, agent-delegated install, API-key fallback) | `references/setup.md` |
