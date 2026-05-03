# Creating an Agent — Full Workflow

## Table of Contents

- [Step 0: Discover available resources](#step-0-discover-available-resources)
- [Step 1: Write manifest.json](#step-1-write-manifestjson)
- [Step 2: Write prompt.md](#step-2-write-promptmd)
- [Step 3: Package as .afps](#step-3-package-as-afps)
- [Step 4: Import](#step-4-import)
- [Step 5: Configure (optional post-import)](#step-5-configure-optional-post-import)

The five steps below assume `appstrate whoami` succeeds (user is logged in on the active profile). For install/login, see `SKILL.md` §Setup.

## Step 0: Discover available resources

Before writing the manifest, check what's available in the org so dependencies resolve at import time:

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

Use these results to choose the right `dependencies.tools`, `dependencies.skills`, and `dependencies.providers`. System tools decision guide: `system-tools.md`.

## Step 1: Write manifest.json

Start from `assets/agent-manifest.json`. Key fields:

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

Critical rules (sources of most import-time failures):

- `name` MUST be `@scope/name` format (lowercase, hyphens OK).
- `type` is `"agent"`.
- `dependencies.tools` — system tools are NOT auto-enabled. Declare each tool the agent needs. Forgetting `@appstrate/output` is the single most common bug (manifests without it return `result: {}` on success). See `system-tools.md` for the decision guide.
- `dependencies.providers` is `Record<string, semverRange>`, NOT an array.
- `required` is a top-level array (`"required": ["field"]`), NOT `required: true` on individual properties.
- `connectionMode`: `"user"` (each user connects their own account) or `"admin"` (shared org-level credentials).
- **File / upload fields** — there is no `"file"` type. Declare the property as `"type": "string"` with `format: "uri"` + `contentMediaType: "<mime>"` plus a sibling `fileConstraints` block. All three keys must be present together — see `manifest-schema.md` §"File / upload fields" for the full recipe.

Full manifest schema (all 4 package types, every field): `manifest-schema.md`.

## Step 2: Write prompt.md

Plain Markdown, no template syntax. The platform auto-injects: User Input, Configuration, Previous State, Memory, Tools, Skills, Connected Providers, Output Format. Do NOT repeat those sections in the file you author.

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

- Sidecar proxy for authenticated calls: `$SIDECAR_URL/proxy` + `X-Provider` + `X-Target` headers.
- Credential placeholders: `{{access_token}}` (OAuth2), `{{apiKey}}` (API key), `{{fieldName}}` (custom auth modes).
- Public APIs: call directly with curl, no sidecar needed.
- If `@appstrate/output` is in dependencies, instruct the agent explicitly to call the `output` tool to return structured results.

Detailed prompt guidance (structure, memory, common mistakes): `prompt-writing.md`.

## Step 3: Package as .afps

```bash
bash scripts/afps-pack.sh /path/to/agent-dir /tmp/my-agent.afps
```

The `.afps` is a ZIP with `manifest.json` at root (not nested in a subdirectory). Manual alternative when the helper script isn't available:

```bash
cd "$AGENT_DIR" && zip -r /tmp/my-agent.afps manifest.json prompt.md
```

## Step 4: Import

```bash
appstrate api POST /api/packages/import -F file=@/tmp/my-agent.afps
```

If 409 `DRAFT_OVERWRITE`: add `-q force=true` to overwrite the draft. Always prefer bumping the version instead to preserve history.

## Step 5: Configure (optional post-import)

```bash
# Attach skills
appstrate api PUT /api/agents/@scope/name/skills \
  -H 'Content-Type: application/json' \
  -d '{"skillIds": ["@scope/skill1"]}'

# Set config values (persisted, applied to every run)
appstrate api PUT /api/agents/@scope/name/config \
  -H 'Content-Type: application/json' \
  -d '{"language": "fr"}'

# Override LLM model
appstrate api PUT /api/agents/@scope/name/model \
  -H 'Content-Type: application/json' \
  -d '{"modelId": "claude-sonnet-4-20250514"}'
```
