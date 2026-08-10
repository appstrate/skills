# Appstrate — Concepts (pointer)

The full conceptual overview lives on the public docs. They are the single source of truth for what Appstrate is, what a package / agent / run / organization is, how data flows, and which dependency types exist.

- **Platform overview**: [appstrate.com/docs/get-started/concepts](https://appstrate.com/docs/get-started/concepts)
- **Feature-by-feature reference** (one page per primitive):
  - Agents: `/docs/features/agents`
  - Skills: `/docs/features/skills`
  - Tools: `/docs/features/tools`
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

Appstrate is an open-source platform that runs AI agents in ephemeral Docker containers. A run = spin up container → inject prompt + deps → agent executes → return output → destroy container. Agents are powered by the [Pi Coding Agent](https://github.com/nichochar/pi-coding-agent) SDK; Appstrate wraps it with orchestration, auth, state, memory, and a **sidecar proxy** that injects credentials so the agent process never sees raw tokens.

**Four package types**, all scoped `@scope/name`, all packaged as `.afps` (ZIP with `manifest.json` at root):

| Type | What it is | Skill notes |
|---|---|---|
| `agent` | prompt + schemas + deps | The thing that runs. See `references/manifest-schema.md` §Agent. |
| `skill` | Markdown knowledge | No code execution, just injected into the prompt. |
| `tool` | TypeScript code | Executable extension the agent calls by name. See `references/system-tools.md`. |
| `provider` | external service | OAuth / API-key / custom credentials, consumed via the sidecar. |

**Three org roles**: `owner`, `admin`, `member`. All resources scoped to one organization; API keys are pinned to one org + one application.

**Data axes** (what persists across runs and what doesn't):

| Axis | Changes each run? | Persists? | Who sets it? |
|---|---|---|---|
| `input` | yes | no | end user |
| `config` | rarely | yes | admin |
| `output` | yes | no | agent |
| `state` | yes | yes (overwritten) | agent |
| `memory` | yes | yes (appended) | agent |

**Dependency rules** (the one thing agents get wrong most often): nothing is auto-enabled. Every provider, tool, and skill the agent uses must be listed explicitly in `manifest.dependencies`. The most common bug is forgetting `@appstrate/output` in `dependencies.tools` — the run succeeds with `result: {}`.
