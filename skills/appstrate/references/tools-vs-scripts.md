# Tool custom vs script in a skill — arbitrage

When packaging a new agent, you face a recurring choice: should this transformation be a **custom tool** (separate AFPS package, sandbox runtime, validated input schema) or a **script in a skill** (`<skill>/scripts/foo.py`, invoked from the prompt via inline bash)?

## Table of Contents

- [Decision matrix](#decision-matrix)
- [The one-line rule](#the-one-line-rule)
- [Anti-pattern: "1 tool = N sub-actions"](#anti-pattern-1-tool--n-sub-actions)
- [The "LLM parsing" case: neither tool nor script](#the-llm-parsing-case-neither-tool-nor-script)
- [Smell-driven Common Errors](#smell-driven-common-errors)

## Decision matrix

| Criterion | → Custom tool | → Script in skill |
|---|---|---|
| Reusable across agents (≥ 2 distinct agents benefit) | ✓ | (coupled to one agent) |
| Needs secrets / providers (API keys, OAuth) | ✓ (sidecar handles credentials) | (otherwise the agent must read env) |
| Strict input/output schema validated at runtime | ✓ | (text/file output) |
| Runtime isolation (heavy deps, separate process) | ✓ | (runs inside agent runtime) |
| Versioning independent of the agent | ✓ | (bumping the agent version is enough) |
| Deterministic local workspace operation (read file, parse, pure transform) | overkill | ✓ |
| Operation requiring LLM "reasoning" / non-deterministic structured parsing | neither | neither (see below) |

## The one-line rule

If the operation is **deterministic + local to the workspace + no creds + not reused by other agents** → script. Otherwise → tool. **If it requires LLM reasoning, it's the agent itself that does it** (read input file, write structured output following a schema documented in references) — neither tool nor script.

## Anti-pattern: "1 tool = N sub-actions"

```json
// BAD — aggregator tool with sub-actions
{
  "name": "@scope/data-pipeline",
  "input": {
    "schema": {
      "type": "object",
      "properties": {
        "action": { "enum": ["extract", "classify", "export"] },
        "params": { "type": "object" }
      }
    }
  }
}
```

Why this hurts:
- The LLM picks two things at once (which tool + which action). More margin for error.
- Tool description becomes vague ("does 3 things") → poor discoverability in the LLM's tool list.
- Discriminated-union input schemas validate too leniently — the LLM can mix params from two sub-actions and the runtime accepts it.
- When a sub-action fails, the LLM can't tell whether the tool or the action is broken. Retries become ambiguous.

**Corollary** — if a tool's manifest declares an `action` enum or `command` enum, that's a signal to (a) split it into N independent tools (if genuinely cross-agent reusable), or (b) demote to scripts in the companion skill with N distinct bash entrypoints.

## The "LLM parsing" case: neither tool nor script

In a standalone Claude Code skill, a script that calls Anthropic API (e.g. `parse-factures.py` running Haiku to structure free-form text) is legitimate — it runs outside an agent.

In Appstrate, the agent **is** the LLM. A "non-deterministic structured parsing" step becomes a prompt instruction:

```md
## Step: parse raw texts to structured JSON

Read `factures-raw.json` (produced by `extract-factures-text.py`).

For each entry, apply the schema in `references/facture-schema.md` and extract:
`vendor`, `vendor_normalized`, `date`, `amount`, `currency`, `description`,
`invoice_number`, `confidence`.

Write the result to `factures-parsed.json` in the same shape as the input.

Do NOT call an external tool. You do this parsing yourself by reading the raw
file and writing the structured file.
```

Benefits: zero extra API calls, zero extra cost, zero provider to wire, traceability in the agent's run log.

## Smell-driven Common Errors

| Smell | Diagnosis | Fix |
|---|---|---|
| Agent manifest declares 4-5 custom tools (`@scope/foo-extract`, `@scope/foo-parse`, `@scope/foo-transform`, `@scope/foo-export`) all called in sequence by this agent only | Over-engineering. Each "tool" is a deterministic local transformation. | Demote to scripts in `<skill>/scripts/foo-{extract,parse,transform,export}.py`, invoked via bash from the prompt. Keep the manifest lean. |
| Custom tool declares an `action: enum` or `command: enum` field in its input schema | "1 tool = N actions" anti-pattern | Split into N tools (if truly reusable cross-agents), or demote to scripts in the skill. |
| Agent calls an LLM-wrapper tool (e.g. `@scope/text-summarizer` proxying Anthropic API) to summarize text it already has in context | The agent IS the LLM — it can summarize itself | Replace the tool call with an inline prompt instruction. Saves one API call + one provider. |
| A skill script reads `process.env.ANTHROPIC_API_KEY` and calls `messages.create` | The script duplicates the agent's role | Remove the API call, lift the instruction into the agent prompt. The script keeps only the deterministic part (extract text, format JSON). |
