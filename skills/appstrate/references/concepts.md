# Appstrate — Concepts (pointer)

The full conceptual overview lives on the public docs. They are the single source of truth for what Appstrate is, what a package / agent / run / organization is, how data flows, and which dependency types exist.

- **Platform overview**: [appstrate.com/docs/get-started/concepts](https://appstrate.com/docs/get-started/concepts)
- **Feature-by-feature reference** (one page per primitive):
  - Agents: `/docs/features/agents`
  - Skills: `/docs/features/skills`
  - MCP-servers: `/docs/features/mcp-servers`
  - Integrations: `/docs/features/integrations`
  - Packages: `/docs/features/packages`
  - Runs: `/docs/features/runs`
  - Memory: `/docs/features/memory`
  - Scheduling: `/docs/features/scheduling`
  - Proxies: `/docs/features/proxies`
  - Webhooks: `/docs/features/webhooks`
  - Realtime (SSE): `/docs/features/realtime`
  - Sandbox and sidecar: `/docs/features/sandbox-and-sidecar`
  - Organizations: `/docs/features/organizations`
  - Applications: `/docs/features/applications`
  - End-users: `/docs/features/end-users`
  - Multi-tenancy: `/docs/features/multi-tenancy`

## Skill-relevant summary (what the agent needs to know without opening the docs)

Appstrate is an open-source platform that runs AI agents in ephemeral Docker containers. A run = spin up container → inject prompt + deps → agent executes → return output → destroy container. Agents are powered by the [Pi Coding Agent](https://github.com/nichochar/pi-coding-agent) SDK; Appstrate wraps it with orchestration, auth, state, memory, and a **sidecar** that injects credentials (via the integration's `delivery`: env vars for a local runner, or HTTP MITM/proxy) so the agent process never sees raw tokens.

**Four package types**, all scoped `@scope/name`, all packaged as `.afps` (ZIP with `manifest.json` at root):

| Type | What it is | Skill notes |
|---|---|---|
| `agent` | prompt + schemas + deps | Orchestrates the run. See `references/manifest-schema.md` §Agent. |
| `skill` | Markdown knowledge | No code execution; injected into the prompt. |
| `mcp-server` | a packaged MCP server (code) | Executable extension exposing MCP tools; referenced by a `local` integration's `source.server`, not by an agent directly. See `references/create-mcp-server.md`. |
| `integration` | connector to an external API | `source.kind` none/local/remote; declarative auth + credential `delivery`; reached via the sidecar tools `{ns}__api_call` / `{ns}__{tool}`. See `references/create-integration.md`. |

(The legacy types `tool` → `mcp-server` and `provider` → `integration`; the old keys `dependencies.tools` / `dependencies.providers` are rejected at publish.)

**Three org roles**: `owner`, `admin`, `member`. All resources scoped to one organization; API keys are pinned to one org + one application.

**Data axes** (what persists across runs and what doesn't):

| Axis | Changes each run? | Persists? | Who sets it? | Mechanism |
|---|---|---|---|---|
| `input` | yes | no | end user | `input.schema` |
| `config` | rarely | yes | admin | `config.schema` |
| `output` | yes | no | agent | `output({ data })` runtime tool |
| `memory` | yes | yes (appended) | agent | `note` (archive) + `pin` (named slots), in `package_persistence` |

**Dependency rules** (the one thing agents get wrong most often): nothing is auto-enabled. Every integration, mcp-server, and skill the agent uses must be listed explicitly in `manifest.dependencies.{integrations,mcp_servers,skills}`. System tools are no longer packages: the five `output`/`log`/`note`/`pin`/`report` are opt-in `runtime_tools`. The most common bug is omitting `"output"` from `runtime_tools` when `output.schema` is declared — the run succeeds with `result: {}`.
