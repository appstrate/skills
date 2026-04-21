---
name: appstrate
description: Create, deploy, run, and iterate on AI agents across one OR multiple self-hosted Appstrate instances (prod + staging + dev) — open-source platform for one-shot AI workflows in ephemeral Docker containers. Primary entry point is the `appstrate` CLI (`appstrate install`, `appstrate login`, `appstrate api`, `appstrate org`, `appstrate app`, `appstrate openapi`). Supports named profiles (keyring-backed tokens + TOML config under `~/.config/appstrate/config.toml`) so the user pilots multiple instances from one session. Use when the user wants to create/edit an agent (manifest.json + prompt.md), import/deploy a .afps package, run an agent either as a persisted package or inline (no import, ephemeral shadow package), dry-run validate a manifest, monitor runs, list runs globally, manage skills/tools/providers, connect OAuth or API-key services, schedule agents, write prompts, switch between Appstrate instances, call the REST API through `appstrate api`, or explore the OpenAPI schema. Also triggers on mentions of AFPS, sidecar proxy, scoped packages, inline runs, POST /api/runs/inline, INLINE_RUN_LIMITS, APPSTRATE_PROFILE, "on prod", "on local", "on dev", self-hosted Appstrate, or any `appstrate <command>` CLI invocation.
---

# Appstrate

Manage AI agents on self-hosted Appstrate instances via the `appstrate` CLI or the REST API. Everything is a **package** with a scoped name (`@scope/name`). Four types: `agent`, `skill`, `tool`, `provider`.

- **API docs**: `$APPSTRATE_URL/api/docs` on your instance (or `appstrate openapi list` for the active profile)
- **OpenAPI JSON**: `GET /api/openapi.json` (or `appstrate openapi export`)
- **GitHub (open-source)**: https://github.com/appstrate/appstrate
- **CLI source**: `apps/cli/` inside the monorepo

## Setup

The **recommended path** is the `appstrate` CLI. It handles install (local or Docker tiers), device-flow login (RFC 8628), token storage in the OS keyring, and pinning an org + application on the profile so every downstream call just works.

```bash
# One-liner install (Tier 0 = hobby / Bun, Tiers 1-3 = Docker stacks)
curl -fsSL https://get.appstrate.dev | bash

# Then sign in to your instance
appstrate login
```

`appstrate login` walks through instance URL → device code → browser approval → org pin → app pin. On a single-org account, everything is auto-picked. On a multi-org account, a picker is shown.

For first-time setup (choosing a tier, non-interactive flags, creating an API key for non-CLI callers, self-hosting): read `references/setup.md`.

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

**Fallback (legacy, or for non-CLI environments like CI without the binary): raw curl with an API key**

Some environments don't have the CLI installed (old CI images, restricted Docker containers, third-party scripts). In that case, fall back to an API key and raw curl:

```bash
# Requires APPSTRATE_URL, APPSTRATE_API_KEY (ask_…), APPSTRATE_ORG_ID, optionally APPSTRATE_APP_ID
curl -s "$APPSTRATE_URL/api/agents" \
  -H "Authorization: Bearer $APPSTRATE_API_KEY" \
  -H "X-Org-Id: $APPSTRATE_ORG_ID" \
  -H "X-App-Id: $APPSTRATE_APP_ID"
```

Create the API key in the UI (left sidebar → Application → Cles API → Nouvelle cle API). See `references/setup.md` > "Fallback: API key for non-CLI environments".

## Profile management

The CLI keeps one profile per Appstrate instance you sign into. Switch with `-p` per-call, or re-pin the default:

```bash
appstrate login --profile prod       # first-time: creates the profile
appstrate login --profile local --instance http://localhost:3000

appstrate whoami                     # who am I on the active profile
appstrate org list                   # orgs the active profile can see
appstrate org switch <id-or-slug>    # re-pin org on the active profile
appstrate app list                   # apps in the pinned org
appstrate app switch <id>            # re-pin app on the active profile
```

**Inferring a profile from the prompt**: when the user says "on prod" / "en prod" / "production" → use `prod`; "on local" / "sur mon install" → use `local`; "on dev" → use `dev`. If the named profile doesn't exist, run `ls $(XDG_CONFIG_HOME:-~/.config)/appstrate/config.toml` to check, or call `appstrate whoami --profile <name>` (exit 1 if unconfigured) and ask the user to run `appstrate login --profile <name>` or pick an existing one.

Full profile guide, keyring/TOML layout, cross-instance iteration: `references/profiles.md`.

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
| Install locally (coding agent / CI) | `appstrate install -t <0\|1\|2\|3> --yes` — **always pass `--yes`** in non-interactive contexts (Bash tool, CI, Dockerfile). `--yes` alone uses Docker-aware defaults; `-t N --yes` pins the tier. Auto-picks the next free port on conflict (3001, 3002, …). `--tier` alone errors on port conflict. |
| Install locally (interactive terminal) | `curl -fsSL https://get.appstrate.dev \| bash` or `appstrate install` — prompts for tier and port |
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

### 0. Discover available resources

Before writing the manifest, check what's available in the org:

```bash
# System tools (output, set-state, report, log, add-memory)
appstrate api GET /api/packages/tools

# Skills (knowledge packages to attach)
appstrate api GET /api/packages/skills

# Providers (OAuth/API-key services to connect)
appstrate api GET /api/providers

# Existing agents (avoid name collisions)
appstrate api GET /api/agents
```

Use these results to choose the right `dependencies.tools`, `dependencies.skills`, and `dependencies.providers` for the manifest. For system tools details and decision guide: `references/system-tools.md`.

### 1. Write manifest.json

Use the template at `templates/agent-manifest.json`. Key fields:

```json
{
  "name": "@my-org/my-agent",
  "version": "1.0.0",
  "type": "agent",
  "schemaVersion": "1.0",
  "displayName": "My Agent",
  "description": "What it does",
  "author": "Author",
  "dependencies": {
    "providers": { "@appstrate/gmail": "^1.0.0" },
    "tools": { "@appstrate/output": "^1.0.0" },
    "skills": {}
  },
  "providersConfiguration": {
    "@appstrate/gmail": {
      "scopes": ["https://www.googleapis.com/auth/gmail.modify"],
      "connectionMode": "user"
    }
  },
  "input": { "schema": { "type": "object", "properties": {}, "required": [] } },
  "output": { "schema": { "type": "object", "properties": { "summary": { "type": "string" } }, "required": ["summary"] } },
  "timeout": 300
}
```

Critical rules:
- `name` MUST be `@scope/name` format (lowercase, hyphens OK)
- `type` is `"agent"`
- `dependencies.tools` — system tools are NOT auto-enabled. Declare each tool the agent needs (see `references/system-tools.md` for the decision guide)
- `dependencies.providers` is `Record<string, semverRange>` (NOT an array)
- `required` is a top-level array (NOT `required: true` on properties)
- `connectionMode`: `"user"` (each user connects) or `"admin"` (shared creds)

For the full manifest schema: `references/manifest-schema.md`.

### 2. Write prompt.md

The agent prompt. Plain Markdown, no template syntax. The platform auto-injects: User Input, Configuration, Previous State, Memory, Tools, Skills, Connected Providers, Output Format.

```markdown
# Objective

One clear sentence.

# Steps

1. **Fetch data** — Use sidecar proxy for authenticated calls:
   curl -s "$SIDECAR_URL/proxy" \
     -H "X-Provider: @appstrate/gmail" \
     -H "X-Target: https://gmail.googleapis.com/gmail/v1/users/me/messages" \
     -H "Authorization: Bearer {{access_token}}"
2. **Process** — Transform, filter, summarize
3. **Return results** as JSON matching the output schema
```

Key rules:
- Sidecar proxy: `$SIDECAR_URL/proxy` + `X-Provider` + `X-Target` headers
- Credential placeholders: `{{access_token}}` (OAuth2), `{{apiKey}}` (API key), `{{fieldName}}` (custom)
- Public APIs: call directly with curl, no sidecar needed
- Do NOT repeat injected sections (User Input, Config, etc.)
- If `@appstrate/output` is in dependencies, instruct the agent to call the `output` tool to return structured results

For detailed prompt guidance: `references/prompt-writing.md`.

### 3. Package as .afps

```bash
bash scripts/afps-pack.sh /path/to/agent-dir /tmp/my-agent.afps
```

The .afps is a ZIP with manifest.json at root (not nested). Manual alternative:
```bash
cd "$AGENT_DIR" && zip -r /tmp/my-agent.afps manifest.json prompt.md
```

### 4. Import

```bash
appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps
```

If 409 `DRAFT_OVERWRITE`: add `-q force=true` to overwrite the draft.

### 5. Configure (optional post-import)

```bash
# Attach skills
appstrate api PUT /api/agents/@scope/name/skills \
  -H 'Content-Type: application/json' \
  -d '{"skillIds": ["@scope/skill1"]}'

# Set config values
appstrate api PUT /api/agents/@scope/name/config \
  -H 'Content-Type: application/json' \
  -d '{"language": "fr"}'

# Override LLM model
appstrate api PUT /api/agents/@scope/name/model \
  -H 'Content-Type: application/json' \
  -d '{"modelId": "claude-sonnet-4-20250514"}'
```

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

`POST /api/agents/@scope/name/schedules` with `{ name, cronExpression, timezone, connectionProfileId, input }`. Inline runs are NOT schedulable (schedules require a persisted package). Body fields + common cron patterns: `references/api-cheatsheet.md` > "Schedules".

## Create a Skill

A **skill** is a Markdown knowledge package that the agent reads at runtime. No code. Files:

```
manifest.json    # type: "skill" — start from templates/skill-manifest.json
SKILL.md         # YAML frontmatter + Markdown body (the knowledge the agent consumes)
scripts/         # Optional — bundled helper scripts
references/      # Optional — extra Markdown docs the agent can load on demand
```

Pack + import the same way as an agent:
```bash
bash scripts/afps-pack.sh /path/to/skill-dir /tmp/my-skill.afps
appstrate api POST /api/packages/import -F file=@/tmp/my-skill.afps
```

Full field list: `references/manifest-schema.md` > "Skill Fields".

## Create a Tool

A **tool** is an **executable TypeScript extension** the agent invokes as a function. This is real code compiled into the agent's runtime, not Markdown. Files:

```
manifest.json    # type: "tool" — start from templates/tool-manifest.json
index.ts         # Tool implementation
```

Non-obvious requirements:
- `manifest.entrypoint` must point to `index.ts` (or your compiled output).
- `manifest.tool.inputSchema` is a **JSON Schema** validated by the runtime before calling the tool.
- `index.ts` must implement the execute signature from `@mariozechner/pi-coding-agent` (the SDK the agent runtime uses). Install as a dev dependency: `bun add -d @mariozechner/pi-coding-agent`.
- The tool runs inside the agent's sandbox container, so it can use `fetch`, file system, etc. — but has no access to the caller's keyring or shell env.

Pack + import the same way:
```bash
bash scripts/afps-pack.sh /path/to/tool-dir /tmp/my-tool.afps
appstrate api POST /api/packages/import -F file=@/tmp/my-tool.afps
```

Full field list + execute signature + return format: `references/manifest-schema.md` > "Tool Fields".

## Data Model: input vs config vs state vs memory vs output

| Mechanism | Changes each run? | Who sets it? | Persists? | Use for |
|-----------|:-:|:-:|:-:|---------|
| **input** | Yes | End user | No | Runtime params: query, date range, file |
| **config** | Rarely | Admin | Yes | Setup-once: language, max items |
| **output** | Yes | Agent | No | Structured results for the user |
| **state** | Yes | Agent | Yes (overwritten) | Cursor, last sync timestamp |
| **memory** | Yes | Agent | Yes (appended) | Learned preferences, patterns |

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

| Need | File |
|------|------|
| Platform concepts (visual overview) | `references/concepts.md` |
| Full manifest schema (all 4 types) | `references/manifest-schema.md` |
| Writing effective prompts | `references/prompt-writing.md` |
| System tools (output, state, report, etc.) | `references/system-tools.md` |
| API conventions & gotchas | `references/api-cheatsheet.md` |
| Inline runs (endpoints, limits, compaction, gotchas) | `references/inline-runs.md` |
| Multi-instance profiles (keyring + TOML, `--profile`, `appstrate org/app`) | `references/profiles.md` |
| Full endpoint list (live) | `appstrate openapi list` or `GET /api/openapi.json` |
| Step-by-step setup guide (CLI + API-key fallback) | `references/setup.md` |
