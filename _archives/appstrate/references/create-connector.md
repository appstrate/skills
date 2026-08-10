# Create a custom connector (provider + tool + bootstrap)

Build a new `@scope/name` provider for a SaaS that isn't covered by the 60+ built-in `@appstrate/*` providers. This file describes the **end-to-end workflow** — from "we need integration X" to "the agent runs in prod". For the narrower choice of *which auth pattern* matches the SaaS, see `auth-decision-tree.md`.

## Table of Contents

- [0. Confirm it's not already covered](#0-confirm-its-not-already-covered)
- [1. Workflow at a glance](#1-workflow-at-a-glance)
- [2. Probe the SaaS](#2-probe-the-saas-10-min)
- [3. Pick the auth pattern](#3-pick-the-auth-pattern)
- [4. Draft the provider manifest](#4-draft-the-provider-manifest)
- [5. Write the bootstrap script](#5-write-the-bootstrap-script-when-credentials-need-manual-acquisition)
- [6. Import + connect the provider](#6-import--connect-the-provider)
- [7. Write the usage tool (if needed)](#7-write-the-usage-tool-if-needed)
- [8. Thin orchestrator agent](#8-thin-orchestrator-agent)
- [9. E2E validation](#9-e2e-validation)
- [10. Publishing checklist](#10-publishing-checklist)
- [Edge cases](#edge-cases)
- [Anti-patterns observed in past connectors](#anti-patterns-observed-in-past-connectors)

---

## 0. Confirm it's not already covered

```bash
appstrate api GET /api/packages/providers -q search=<saas-name>
```

If a built-in `@appstrate/<name>` exists, use it — don't fork. Only build a custom provider when the API is genuinely missing or the built-in is too narrow for the use case.

## 1. Workflow at a glance

Eight steps, each with a clear stopping point so you can pause and resume:

```
0. confirm gap         (API not in @appstrate/*)
1. probe SaaS          (10 min curl + DevTools → know the auth shape)
2. pick auth pattern   (auth-decision-tree §2 → A/B/C/D/E pattern letter)
3. draft manifest      (manifest.json + PROVIDER.md)
4. bootstrap script    (Python stdlib, only when credential acquisition is manual)
5. import + connect    (afps-pack + import + connections/connect)
6. usage tool          (TS, only when auth needs orchestration the provider alone can't do)
7. orchestrator agent  (thin agent that exposes the connector to the rest of the system)
8. E2E validation      (real run on a real period, real data on disk)
```

Steps 4, 6, 7 are conditional — many SaaS don't need them. The minimal viable connector is just steps 0-3-5: provider manifest, import, connect via API-key.

## 2. Probe the SaaS (10 min)

Full procedure in `auth-decision-tree.md` §1. Three questions in 10 minutes:

1. Does login return a JSON token? → ROPC candidate
2. Or set session cookies on 302? → Cookie-capture candidate
3. Is there a JS-computed challenge? → Magic-link or static-cookie candidate

If the SaaS uses an exotic per-request signature (HMAC over `secret + method + url + body + timestamp` — Shopify webhooks, certain telco/hosting APIs, some bank APIs), note this here — you'll need [§Edge cases > Per-request signature](#per-request-signature-hmac--sha1-sha256-of-secret--method--url--body--timestamp) instead of a standard pattern.

## 3. Pick the auth pattern

Decision table + pattern recipes (A through F): `auth-decision-tree.md` §2-3. Don't write a single line of manifest before this step lands on a letter: `authMode` choice constrains the credential schema shape and whether a bootstrap script is needed, both expensive to redo.

## 4. Draft the provider manifest

Two files, side by side:

```
providers/<saas>/
├── manifest.json    # type: "provider"
└── PROVIDER.md      # injected into every consuming agent's system prompt — REQUIRED
```

### Manifest essentials

- `name: "@scope/<saas>"` (scope starts with `@`)
- `type: "provider"`
- `definition.authMode`: one of `apiKey | bearerToken | basic | oauth2 | password | custom`. The pattern letter from §3 maps directly to an `authMode`.
- `definition.credentials.schema`: JSON Schema for what the user pastes into the connection UI. Mark secrets with `"format": "password"`.
- `definition.authorizedUris`: restrict to the SaaS's actual hostnames using `**` globs. Two reasons: (1) defence in depth, the sidecar refuses outbound calls to unauthorized hosts; (2) lets you legitimately route through a third-party endpoint (e.g. FlareSolverr) by adding its host here. See `manifest-schema.md` §Provider Fields.
- `definition.injection` (optional): tells the sidecar which header to inject the credential into. Default for `apiKey` mode is `Authorization: Bearer <key>` — override only if the SaaS expects something else (`X-Api-Key`, `X-Auth-Token`, …).
- `setupGuide.steps[]`: short imperative sentences the operator sees when first connecting.

### PROVIDER.md essentials

This file is **auto-injected** into the system prompt of every agent that depends on this provider. Keep it tight:

1. **Auth summary in 3-5 lines** — what the sidecar does for the agent. State explicitly that the agent must NOT compute auth itself. Include a verbatim block clarifying `{{placeholder}}` (literal, server-side) vs `<MARKER>` (agent-computed) — cf. [[llm-placeholder-mask-substitution-bug]].
2. **Endpoints used** as a Markdown table (method, path, what it returns). Helps the LLM build correct URLs without guessing.
3. **Setup procedure** in 3-5 steps. If a bootstrap script exists (step 5), reference it here.
4. **Scopes / accessRules** (for OAuth ConsumerKey-style schemes) — apply principle of least privilege. List explicitly.
5. **Limitations** — pagination caps, expiry windows on pre-signed URLs, ConsumerKey revocation triggers, rate limits.

Anti-pattern: dumping the whole upstream API doc. The LLM doesn't need every endpoint — only the ones your agents will hit. More noise = more hallucination opportunity.

## 5. Write the bootstrap script (when credentials need manual acquisition)

OAuth 3-leg flows (request a credential ID, validate in a browser, poll until accepted), classic OAuth Authorization Code, or any "go validate this URL in a browser, then poll until ready" pattern needs a side-script the operator runs once.

Convention: `providers/<saas>/bootstrap.py`, **Python standard library only** (no `pip install` step). Typical shape:

```python
#!/usr/bin/env python3
"""Bootstrap <SaaS> credentials. Usage: python3 bootstrap.py --foo X --bar Y"""
import argparse, json, sys, time, urllib.request

# 1. Request the credential (POST /auth/credential or similar)
# 2. Print the validation URL the operator opens in their browser
# 3. Poll a safe authenticated endpoint every 5s for up to N minutes
# 4. On success, print the final credentials as a single JSON block
#    ready to paste into the Appstrate connection UI
```

Why Python stdlib: zero install friction. The operator runs `python3 bootstrap.py` and gets credentials in under 5 minutes without touching a venv. Bash is also fine when the SaaS exposes a simple curl flow; TypeScript is overkill for a one-shot script.

Skip this step if the SaaS gives you the credentials directly (API token from their dashboard, OAuth Client Credentials grant, etc.).

## 6. Import + connect the provider

```bash
# Pack & import
bash <skill>/scripts/afps-pack.sh providers/<saas> /tmp/<saas>-provider.afps
appstrate -p <profile> api POST /api/packages/import -F file=@/tmp/<saas>-provider.afps

# Connect (depends on authMode)
# apiKey / bearerToken:
appstrate api POST '/api/connections/connect/@scope/<saas>/api-key' -d '{"apiKey":"..."}'

# custom / password / oauth2:
appstrate api POST '/api/connections/connect/@scope/<saas>/credentials' -d '{"credentials":{...}}'
```

The connection body is **camelCase** (`apiKey` not `api_key`). Mismatches are the #1 cause of `400 INVALID_REQUEST` at this step — see [Common Errors](../SKILL.md#common-errors).

## 7. Write the usage tool (if needed)

Skip when:
- `authMode` is `apiKey`/`bearerToken`/`basic` AND the SaaS API is JSON-clean AND the agent can call it directly via `provider_call` with one round-trip per logical action.

Write one when:
- The auth flow needs orchestration (multi-step bootstrap login, magic-link, multi-call refresh) — extract it into `tools/<saas>-login` or `tools/<saas>-bootstrap` so the agent doesn't repeat it on every run.
- The usage pattern is "list N items → for each, fetch detail + download bytes" — extracting it as a tool avoids N×3 LLM round-trips (often a 5-10× cost-and-latency win vs. an LLM-driven loop).
- The response bodies are large enough to spill to `BlobStore` (≥ 32 KB) — the tool can handle `ctx.readResource(uri)` resolution centrally instead of teaching every agent the pattern. See `large-responses.md`.

Tool TS skeleton:

```typescript
import { Type } from "typebox";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PROVIDER = "@scope/<saas>";

const Params = Type.Object({
  /* … input schema … */
});

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "<verb>_<resource>",
    label: "<SaaS> — <action>",
    description: "<one-line, mentions the provider and the return shape>",
    parameters: Params,
    async execute(_id, params, _signal, ctx?: any) {
      if (!ctx?.providerCall) {
        return errorResult("ctx.providerCall not available — runtime-pi too old");
      }
      // 1. Call the SaaS via ctx.providerCall — never via raw fetch
      // 2. Read body via the readBody/readBlob helper pair (handles
      //    resource_link spillover for ≥32KB responses)
      // 3. Aggregate, return structured JSON in content[0].text
    },
  });
}
```

The `readBody` / `readBlob` helper pattern (handling both inline text and `resource_link` URI spillover) is ~30 lines of utility code per tool — copy-paste between tools until the platform exposes a shared helper. Without it, large responses come back silently empty: see `large-responses.md`.

Manifest declares `dependencies.providers: { "@scope/<saas>": "^X.Y.Z" }` and (if the tool also writes back to its own Appstrate connection, e.g. token refresh) `"@default/appstrate-self": "^1.0.0"`.

## 8. Thin orchestrator agent

For most connectors the agent that uses the new provider is best kept **thin**: input schema, one or two tool calls, structured `output()`. Heavy lifting belongs in the tool. A typical orchestrator runs under 50 lines of `prompt.md`: take an input range, call one tool, call `output()` with a structured shape. No retries, no LLM-driven branching.

For multi-source orchestrators (one agent fanning out to several connectors of the same shape), the agent stays thin but iterates: one tool call per source, same `output()` shape. New sources = new tool, prompt update, no architectural change.

## 9. E2E validation

Before declaring the connector done:

```bash
# Run with real input on a known-good period (small enough to verify by hand)
appstrate -p local api POST /api/agents/@scope/<agent>/run \
  -H 'Content-Type: application/json' \
  -d '{"input": {"dateFrom":"2025-12-01","dateTo":"2026-01-01"}}'

# Check the run
appstrate api GET /api/runs/<runId>
appstrate api GET /api/runs/<runId>/logs
```

Verify:
- `status: success`
- `result.output` matches the agent's `output.schema`
- The number of items returned matches what you'd manually count in the SaaS UI for that period
- (If the tool downloads bytes) the first file opens correctly in its native viewer

Capture this E2E case in the connector's mémoire (per-project memory file) so future debugging has a known-good baseline.

## 10. Publishing checklist

When the connector is local-only (private SaaS for one org), it can stay in your local workspace untracked or in a private git remote. When you want to publish (open-source or to a wider Appstrate org):

- [ ] **Versioning**: semver. `1.0.0` for first stable; bump major on any breaking change to credential schema, manifest shape, or tool input/output schema.
- [ ] **Scope**: `@<org>/<saas>` — use a stable org slug. Once shipped, renames break consumers' dependency declarations.
- [ ] **PROVIDER.md complet**: auth summary, endpoints used, scopes/accessRules, setup procedure, limitations. Auto-injected into agent system prompts → quality matters.
- [ ] **No secrets in the repo**: scan with `git diff` before committing. Credentials live in the Appstrate connection store, never in manifest.json defaults.
- [ ] **`bootstrap.py` reproducible**: works from a clean Python install on the user's machine. No undocumented env vars.
- [ ] **Tool TS factored**: no N×LLM round-trips when one batched tool call works. No retry logic the platform already provides.
- [ ] **Sidecar dependency declared**: if the connector relies on a non-default sidecar feature (e.g. `requestSignature`, FlareSolverr passthrough, a runtime-pi version threshold), document it in PROVIDER.md and pin the minimum runtime-pi version in the agent manifest.
- [ ] **`authorizedUris` minimal**: only the hostnames the provider legitimately reaches.

## Edge cases

### Per-request signature (HMAC / SHA1-SHA256 of secret + method + url + body + timestamp)

When the SaaS computes a signature header from `(secret, method, url, body, timestamp)` on **every** request (Shopify webhooks, AWS-SigV4-style schemes, several telco/hosting APIs), neither a stored bearer token nor a stored cookie suffices. The secret must never leave the sidecar (the LLM and the tool TS would see it on every retry otherwise).

Appstrate's `requestSignature` provider feature handles this server-side. Manifest block (illustrative example: a SaaS requiring `X-Sig = "$1$" + sha1(secret + "+" + key + "+" + METHOD + "+" + URL + "+" + BODY + "+" + TS)`):

```json
"requestSignature": {
  "timestampHeader": "X-Timestamp",
  "staticHeaders": {
    "X-Application": "{{app_key}}",
    "X-Consumer": "{{consumer_key}}"
  },
  "signature": {
    "headerName": "X-Sig",
    "algorithm": "sha1",
    "encoding": "hex-lower",
    "prefix": "$1$",
    "separator": "+",
    "components": [
      "{{app_secret}}", "{{consumer_key}}",
      "{{request_method}}", "{{request_url}}",
      "{{request_body}}", "{{request_timestamp}}"
    ]
  }
}
```

Whitelisted algorithms: `sha1` + `hex-lower` (MVP). HMAC-SHA256 / base64 require extending the platform whitelist — coordinate before adding a connector that needs them.

### Credentials substitution cross-target

When the SaaS provider's auth must execute through a third-party endpoint (e.g. login routed via FlareSolverr to bypass Cloudflare), declare the FlareSolverr host in the SaaS provider's `authorizedUris` and use `substituteBody: true` so the sidecar substitutes `{{email}}` / `{{password}}` placeholders inside the FlareSolverr POST body, server-side. The FlareSolverr provider doesn't see the credentials. Full pattern: `references/flaresolverr.md` §4.B.

### Anti-bot / Cloudflare / ASN blocks

Escalation ladder: `auth-decision-tree.md` §4. Short version:
1. Realistic headers (User-Agent, Origin, Referer).
2. `x-tlsClientByUrl` to bypass Bun JA3 fingerprint.
3. Residential proxy via `PROXY_URL`.
4. FlareSolverr (Chromium-backed). Full setup + the two usage patterns (direct wrapper tool vs credentials-substitution cross-target) + patched-image requirement: `references/flaresolverr.md`.

### Cookies sticky on AWS-ALB / Spring Security

Pre-flight `GET /login` before `POST /login` to prime `AWSALB` / `JSESSIONID` cookies on the same backend instance. Documented in `auth-decision-tree.md` §2 + `manifest-schema.md` §Session cookies. Symptom: POST returns 200 OK but lands an "Invalid CSRF" or "Session expired" error page because the LB routed it to a different instance.

## Anti-patterns observed in past connectors

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| Tool TS that re-does the auth on every call (re-sends `username`/`password` to `/login`) | Lets the LLM see credentials in `headers:` / `body:` arguments; rate-limits the SaaS; defeats the sidecar's whole point | Confine auth to a `<saas>-login` tool or to `authMode: "password"` — usage tools just call `provider_call`, the sidecar injects auth |
| Provider that exposes `appSecret` as a credential field AND returns it via `/internal/credentials` for the tool to use | The secret is now in agent container memory, observable in core dumps, leakable via prompt injection | Use `requestSignature` to keep the secret sidecar-only |
| Tool that does N×3 sequential round-trips (list → for each: GET detail + download) | Each round-trip is one LLM thinking turn → 5-10× cost and latency vs. one batch tool that does all N internally | Factor the loop into the tool; agent calls it once |
| Agent that retries failed `provider_call` with backoff in its prompt | LLM-driven retries are non-deterministic, expensive, and miss the platform's built-in retry semantics | Trust the sidecar; if a call fails twice, fail loud — surface the error in `output()` instead of looping |
| LLM substitutes `{{email}}` with `<USERNAME>` mask in `body:` arguments | Modern LLMs sometimes self-mask placeholders, breaking server-side substitution silently | Verbatim placeholder block in PROVIDER.md — clarify `{{var}}` (literal, server-side) vs `<MARKER>` (agent-computed). See `prompt-writing.md` §"Placeholder Semantics" |
| `authorizedUris: ["**"]` (or omitted) | Disables the sidecar's outbound URL allowlist — any prompt-injected URL is callable with the user's credentials | Narrow to actual hostnames + glob suffixes only |
| Bootstrap script that requires `pip install` | Friction at every new operator onboarding | Python stdlib only (`urllib.request`, `json`, `hashlib`, `time`) |
