# MCP-server vs script in a skill — arbitrage

When packaging a new agent, you face a recurring choice: should this transformation be a **packaged MCP server** (AFPS type `mcp-server`, referenced by a `local` integration, sandbox runtime) or a **script in a skill** (`<skill>/scripts/foo.py`, invoked from the prompt via inline bash)?

> The old "custom tool (TS extension)" package type no longer exists. There is no `tool` type and no `dependencies.tools` — a unit of reusable executable code is now an `mcp-server` package, surfaced to the agent as `{ns}__{tool}` through a `local` integration. See `create-mcp-server.md` and `create-integration.md`.

## Table of Contents

- [Decision matrix](#decision-matrix)
- [The one-line rule](#the-one-line-rule)
- [Calling an external API: integration, not mcp-server](#calling-an-external-api-integration-not-mcp-server)
- [Anti-pattern: "1 mcp-server = N sub-actions"](#anti-pattern-1-mcp-server--n-sub-actions)
- [The "LLM parsing" case: neither mcp-server nor script](#the-llm-parsing-case-neither-mcp-server-nor-script)
- [Smell-driven Common Errors](#smell-driven-common-errors)

## Decision matrix

| Criterion | → MCP-server | → Script in skill |
|---|---|---|
| Reusable across agents (≥ 2 distinct agents benefit) | ✓ | (coupled to one agent) |
| Needs real code execution (shell-out, process speaking MCP) | ✓ (sandboxed runner) | (otherwise the agent's runtime must do it) |
| Needs a shared filesystem / per-run workspace + MCP Roots | ✓ (`_meta["dev.appstrate/workspace"]`) | (script runs inside the agent runtime) |
| Strict input/output schema validated at runtime | ✓ (MCP tool `inputSchema`) | (text/file output) |
| Runtime isolation (heavy deps, separate process) | ✓ | (runs inside agent runtime) |
| Versioning independent of the agent | ✓ (own package version) | (bumping the agent version is enough) |
| Deterministic local workspace operation (read file, parse, pure transform) | overkill | ✓ |
| Operation requiring LLM "reasoning" / non-deterministic structured parsing | neither | neither (see below) |

## The one-line rule

- **Deterministic + local to the workspace + no creds + not reused by other agents** → script in `scripts/`.
- **Needs LLM reasoning** → the agent does it itself (read input file, write structured output following a schema documented in references) — neither mcp-server nor script.
- **Needs reusable executable code / shell-out / a shared filesystem boundary** → packaged `mcp-server`, reached via a `local` integration (`create-mcp-server.md`).

## Calling an external API: integration, not mcp-server

To reach an external REST API, **do not build an mcp-server**. Prefer an integration with `source.kind: none` + the credential-injecting `{ns}__api_call` tool (`create-integration.md`). The sidecar handles auth, credential injection, and URL allowlisting — no code to ship or version.

Reach for a `local` integration backed by an `mcp-server` only when you genuinely need executable code: shell-out to a CLI, filesystem work, a process that already speaks MCP, or a real MITM/security boundary. For a trusted hosted MCP server, use a `remote` integration instead.

## Anti-pattern: "1 mcp-server = N sub-actions"

```json
// BAD — aggregator mcp-server tool with sub-actions
{
  "name": "do_thing",
  "inputSchema": {
    "type": "object",
    "properties": {
      "action": { "enum": ["extract", "classify", "export"] },
      "params": { "type": "object" }
    }
  }
}
```

Why this hurts:
- The LLM picks two things at once (which tool + which action). More margin for error.
- The tool `description` becomes vague ("does 3 things") → poor discoverability via `tools/list` (the prompt never lists tools — the description is the agent's only guidance).
- Discriminated-union input schemas validate too leniently — the LLM can mix params from two sub-actions and the runtime accepts it.
- When a sub-action fails, the LLM can't tell whether the tool or the action is broken. Retries become ambiguous.

**Corollary** — if an mcp-server tool declares an `action` enum or `command` enum, that's a signal to (a) expose it as N independent MCP tools in the same server (if genuinely cross-agent reusable), or (b) demote to scripts in the companion skill with N distinct bash entrypoints.

## The "LLM parsing" case: neither mcp-server nor script

In a standalone Claude Code skill, a script that calls Anthropic API (e.g. `parse-factures.py` running Haiku to structure free-form text) is legitimate — it runs outside an agent.

In Appstrate, the agent **is** the LLM. A "non-deterministic structured parsing" step becomes a prompt instruction:

```md
## Step: parse raw texts to structured JSON

Read `factures-raw.json` (produced by `extract-factures-text.py`).

For each entry, apply the invoice schema bundled with this agent's skill and extract:
`vendor`, `vendor_normalized`, `date`, `amount`, `currency`, `description`,
`invoice_number`, `confidence`.

Write the result to `factures-parsed.json` in the same shape as the input.

Do NOT call an external tool. You do this parsing yourself by reading the raw
file and writing the structured file.
```

Benefits: zero extra API calls, zero extra cost, zero integration to wire, traceability in the agent's run log.

## Smell-driven Common Errors

| Smell | Diagnosis | Fix |
|---|---|---|
| Agent depends on several `mcp-server` packages (via `local` integrations) — `@scope/foo-extract`, `@scope/foo-parse`, `@scope/foo-transform`, `@scope/foo-export` — all called in sequence by this agent only | Over-engineering. Each is a deterministic local transformation. | Demote to scripts in `<skill>/scripts/foo-{extract,parse,transform,export}.py`, invoked via bash from the prompt. Keep `dependencies` lean. |
| An mcp-server tool declares an `action: enum` or `command: enum` field in its `inputSchema` | "1 mcp-server = N actions" anti-pattern | Expose N MCP tools (if truly reusable cross-agents), or demote to scripts in the skill. |
| Agent ships an `mcp-server` just to wrap a plain REST API | An integration `kind:none` + `{ns}__api_call` does this with no code | Replace the mcp-server with a `none` integration; declare it in `dependencies.integrations` + `integrations_configuration`. |
| Agent calls an LLM-wrapper tool (e.g. an mcp-server proxying Anthropic API) to summarize text it already has in context | The agent IS the LLM — it can summarize itself | Replace the tool call with an inline prompt instruction. Saves one API call + one integration. |
| A skill script reads `process.env.ANTHROPIC_API_KEY` and calls `messages.create` | The script duplicates the agent's role | Remove the API call, lift the instruction into the agent prompt. The script keeps only the deterministic part (extract text, format JSON). |
