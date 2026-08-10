# Choosing the right auth pattern for a custom integration

Read this when authoring a new `@scope/name` **integration** (AFPS type `integration`, ex-`provider`) for a SaaS that doesn't already ship in `@appstrate/*`. The goal is to skip the trial-and-error: identify the SaaS's login shape in a few minutes, then go straight to the matching `source.kind` + auth strategy.

Two axes drive the decision:
1. **`source.kind`** — where the integration runs (`none` = REST via `{ns}__api_call`; `local` = a packaged `mcp-server` runner for shell-out / filesystem / real MITM boundary; `remote` = a trusted hosted MCP server). See `create-integration.md` §0.
2. **`auths.{key}.type`** + `connect` shape — how the credential is acquired and injected. The platform picks the **ConnectStrategy** purely from the manifest.

## Table of Contents

- [1. Investigate first (10 min curl probe + Chrome DevTools)](#1-investigate-first-10-min-curl-probe--chrome-devtools)
- [2. Decision table](#2-decision-table)
- [3. Pattern recipes](#3-pattern-recipes)
- [4. Anti-bot escalation ladder](#4-anti-bot-escalation-ladder)
- [5. When even the ladder isn't enough](#5-when-even-the-ladder-isnt-enough)

---

## 1. Investigate first (10 min curl probe + Chrome DevTools)

Before picking a pattern, answer these three questions about the SaaS:

| Question | How to answer | Cost |
|---|---|---|
| **Does the login endpoint return a JSON token?** (RFC 6749 ROPC, `{access_token, refresh_token, expires_in}`) | `curl -X POST <login-url> -d 'grant_type=password&...'` — look for `application/json` + `access_token` field | 30 sec |
| **Or does it set session cookies on a 302?** (Spring Security, Java EE, Rails) | Same `curl -L --cookie-jar` — look for `Set-Cookie: JSESSIONID=…` (or app-specific name) on a hop in the redirect chain | 30 sec |
| **Is the login form protected by a JS-computed challenge?** (PoW, canvas fingerprint, hidden tokens regenerated each load) | View source on the login page — search for `browserinfo`, `hcaptcha`, `recaptcha`, `<input type="hidden" name="execution"`, hash that looks JS-computed | 1 min |

For SPAs / OIDC flows, log in once with **Chrome DevTools → Network** open, then read the request waterfall on the redirect chain. That answers all three at once. (Use Chrome MCP from this skill — see SKILL.md `appstrate api` flow.)

---

## 2. Decision table

This table routes to **both** the `source.kind` and the auth strategy. Default `source.kind` is `none` (plain REST through `{ns}__api_call`); only escalate to `local` (a packaged `mcp-server` runner) when you genuinely need to shell out, touch a filesystem, or stand up a real MITM boundary (e.g. driving a container-side solver — see §5), and to `remote` when a trusted hosted MCP server already exists.

| Symptom from probe | `source.kind` | Auth strategy (`auths.{key}`) |
|---|---|---|
| `POST /token` → JSON `{access_token, refresh_token, expires_in}`, no JS challenge, optional JWT claims to extract | `none` | **A. ROPC via `custom` + `connect.tool`** — a connect tool POSTs the token request, persists `{$outputs.access_token}` for delivery |
| Form `POST /login` with `j_username`/`username` + `password` → 302 + Set-Cookie session, single round-trip | `none` | **B. Single declarative login** — `custom` + `connect.login` (one HTTP request, capture cookie outputs) |
| Form `POST /login` → CAS/SAML/OIDC handoff (3+ redirects, ticket → code → cookie), no captcha | `none` | **C. Multi-step CAS/OIDC** — `custom` + `connect.tool` (`run_at: link`) chaining 3-6 `{ns}__api_call`s |
| Magic-link-by-email is the only viable path (password login wants a JS-computed challenge the sidecar can't generate, but the magic-link redemption is a plain GET) | `none` | **D. Email-orchestrated** — `custom` + `connect.tool` that triggers the email then polls `@appstrate/gmail` |
| Cookies expire weekly+ AND no automated bootstrap is possible (captcha at every login attempt, browserinfo3, etc.) | `none` | **E. Static cookie credentials (manual refresh)** — `custom`, cookies as `credentials.schema` fields, captured by hand via Chrome DevTools |
| Clean OAuth 2.0 authorization-code flow (consent screen, `authorize` → `token`) | `none` | `oauth2` — OAuth2 + PKCE, discovery + auto-refresh, scopes inferred per-agent |
| Pasteable static API key / basic creds, no exchange step | `none` | `api_key` / `basic` nu (no `connect`) → **Fields** strategy |
| mTLS client-cert auth | `none` | `mtls` (**new**) — cert/key delivered via `delivery.files` (mtls + `delivery.http` is rejected at install) |
| JS-computed PoW / canvas / Sec-Fetch-Site enforced / in-page-`fetch()`-only — a real browser is required to authenticate | `local` | `custom` + `connect.tool` (`run_at: link`) orchestrating a container-side solver (FlareSolverr). See §5 + `flaresolverr-pattern.md` |
| Login UI is fine in a browser but every curl/Bun/undici call gets `403 Cloudflare` / `429` regardless of credentials | (orthogonal) | **F. ASN-blocked SaaS** — wire a residential rotating proxy via `PROXY_URL` (cascade: per-agent → org default → env), or accept manual cookie refresh; applies on top of any strategy |

**Bonus knob that can apply to any pattern**:
- **AWS ALB / sticky-session backends**: do a pre-flight `GET /login.jsa` from the connect tool BEFORE the `POST` — primes `AWSALB`/`JSESSIONID` so the POST hits the same backend instance. <!-- TODO vérifier le §"Session cookies" de manifest-schema (section retirée) -->

> **`oauth1` is gone** (#507). If you ever hit an OAuth 1.0a upstream, model it as `custom` + a `connect.tool` that signs requests — there is no first-class `oauth1` strategy anymore.

---

## 3. Pattern recipes

Each recipe links to the canonical manifest shape in `create-integration.md` / `manifest-schema.md` rather than duplicating manifest JSON here. All recipes below are `source.kind: none` unless noted, and all credential delivery uses the `{$credential.<field>}` / `{$outputs.<name>}` syntax in `delivery.value` (NOT the 1.x `{{field}}`).

### A. ROPC bootstrap (`type: "custom"` + `connect.tool`)

For SaaS that exposes a clean `/token` JSON endpoint (RFC 6749 ROPC). A `connect.tool` (run once in an ephemeral connect-run via `run_at: link`, or per-run via `run_at: run-start` — see the ConnectStrategy table below) POSTs `grant_type=password&username=...&password=...&...`. The tool parses `{access_token, refresh_token, expires_in}`, decodes JWT claims if needed, and declares them as `connect.outputs`. The auth's `delivery.http.value` then references `{$outputs.access_token}` (gated to declared outputs only — §7.7).

Subsequent `{ns}__api_call`s carry `Authorization: Bearer <token>` automatically via `delivery.http` (`{ prefix: "Bearer ", value: "{$outputs.access_token}" }`). Token renewal is handled by `expires_in_output` + the strategy's refresh hook, or a `run_at: run-start` connect tool that re-mints per run (LoginSecret strategy).

> A server-side `password` auth type that would have done all this natively was [proposed and rejected upstream](https://github.com/appstrate/appstrate/issues/457) — the canonical solution is the `custom` + `connect.tool` pattern above. The LLM never sees the credentials: the connect tool runs sidecar-side and only its declared `outputs` survive.
>
> The old `@default/appstrate-self` PATCH-back-to-credentials mechanism (writing refreshed tokens into the integration's own credentials) **no longer exists** on `feat/integrations` (no such system integration is shipped). Use `connect.outputs` + `expires_in_output` for token lifecycle instead — the platform refreshes OAuth2 transparently, and a `connect.tool` re-mints session secrets per run.

### B. Single declarative login (`type: "custom"` + `connect.login`)

For Spring Security / Java EE / Rails sites with a one-shot form-encoded login. Use `connect.login` (singular — ex `connect.steps`): one declarative HTTP request, no tool code.

```
connect.login = {
  request: { method: "POST", url: ".../login", content_type: "application/x-www-form-urlencoded",
             body: "j_username=...&j_password=..." },
  success_criteria: [ ... ],   // e.g. 302 + Set-Cookie present
  outputs: { session: "..." }, // ≥1 output required
}
```

- Cookies (JSESSIONID, app-specific) captured by the connect flow become `connect.outputs`, referenced from `delivery` via `{$outputs.<name>}`.
- For AWS-ALB-backed sites, the pre-flight `GET /login` to prime the LB stickiness cookie may need a `connect.tool` instead of the single-request `connect.login`. <!-- TODO vérifier le support du pré-flight dans connect.login -->
- Validation: `success_criteria` checks for a binary signal (a 302, a specific `Set-Cookie`, absence of the public login form).

### C. Multi-step CAS / OAuth handoff (`type: "custom"` + `connect.tool`, `run_at: link`)

For SaaS where the form login fans out into 3-6 redirects (OIDC `authorize` → CAS `login` → `callback` → app session). A `connect.tool` runs once in an ephemeral connect-run and chains the calls via `{ns}__api_call`:

1. `GET /api/auth/csrf` (next-auth) or `GET /login` (CAS) — extract anti-CSRF / state hidden tokens.
2. `POST /api/auth/signin/<provider>` or equivalent — primes next-auth state cookies, redirects to the actual CAS form.
3. Parse hidden `execution` / `tmSessionId` / `service` from the form HTML.
4. `POST <CAS-login-url>` with credentials substituted server-side via the `api_call` arg `substituteBody: true` + `{{email}}` / `{{password}}` placeholders (sidecar-side body substitution — distinct from the manifest's `{$credential.…}` delivery syntax).
5. The sidecar follows the 302 chain; cookies of every hop are captured into the per-run cookie jar. <!-- TODO vérifier la sémantique redirect-cookie-capture sur feat/integrations -->
6. Validate via the SaaS's `/api/auth/session` or `/login/home` equivalent, and declare the session as a `connect.outputs` for `delivery`.

The cookie-jar persistence across `{ns}__api_call`s within the same connect-run is what makes this pattern viable.

### D. Magic-link-by-email (`type: "custom"` + `connect.tool`, `@appstrate/gmail`-orchestrated)

When the password login requires a JS-computed challenge the sidecar can't generate (PoW, canvas fingerprint), but the **magic-link redemption** (`GET /login/onetime?key=…`) accepts plain HTTP. A `connect.tool`:

1. `GET /login` → extract anti-CSRF token `t`.
2. `POST /login/onetime` with `{t, inputEmailHandle: ...}` (credential via `substituteBody`) → SaaS sends an email.
3. Poll `@appstrate/gmail` via `{ns}__api_call` (`GET /gmail/v1/users/me/messages?q=from:<sender>+newer_than:5m+after:<triggerEpoch>`) until the message arrives, max 60s.
4. `GET <message>?format=full` → walk `payload.parts[]` for `text/plain` (preferred) or `text/html`, base64url-decode.
5. Extract the magic link with a regex bounded to the SaaS's domain.
6. `GET <magic-link>` → cookies captured; validate via an authenticated page; declare session as `connect.outputs`.

Caller note: an agent that consumes this integration MUST declare BOTH the SaaS integration AND `@appstrate/gmail` in `dependencies.integrations` (+ `integrations_configuration`). The Gmail connection MUST own the same email used as the SaaS account; if the resolved connection points elsewhere, override per-run via `connection_overrides` (see `inline-runs.md` / `profiles.md`).

### E. Static cookies (manual refresh) (`type: "custom"`, Fields strategy)

When neither password nor magic-link is automatable. The integration's `auths.{key}.credentials.schema` lists cookie names as fields (e.g. `cl_login`, `cl_b`); the user captures values from a logged-in browser via Chrome DevTools and saves them with the Fields connect:

```bash
appstrate api POST '/api/integrations/@scope%2Fname/auths/primary/connect/fields' \
  -H 'Content-Type: application/json' -d '{"credentials": {"cl_login": "...", "cl_b": "..."}}'
```

Re-capture when cookies expire (typically weekly to monthly). `delivery.http` injects `{ in:"header", name:"Cookie", value:"cl_login={$credential.cl_login}; cl_b={$credential.cl_b}" }` on each call. Credential field names must match `credentials.schema` exactly (validated — a mis-keyed field connects "successfully" but injects nothing).

---

## 4. Anti-bot escalation ladder

When a pattern works in `curl` but fails through the sidecar:

1. **Set realistic headers** — `User-Agent: Mozilla/5.0 …`, `Accept`, `Accept-Language`, `Origin`, `Referer`. CORS-strict APIs reject without `Origin` matching their allowlist (silent 502).
2. **Switch to a residential proxy** via `PROXY_URL` env or per-agent override — the only fix for ASN-blacklist bot management (Cloudflare with bot tier, Akamai, DataDome). Datacenter / VPN exit nodes are blocked outright.
3. **Real headless browser via FlareSolverr** — for the cases the steps above can't reach (JS-computed PoW/fingerprint, in-page-fetch-only JSON endpoints, JA3-fingerprint blocking that the sidecar's Bun fetch can't disguise). Modelled as `source.kind: local` + `connect.tool`. See §5.

---

## 5. When even the ladder isn't enough

Some symptoms are unfixable without running a real browser:

| Symptom | Why the ladder doesn't help |
|---|---|
| Endpoint returns the homepage HTML instead of JSON despite a perfect `Accept: application/vnd.foo+json` | Chromium overrides `Accept` on navigation. Only an in-page `fetch()` respects it. |
| POST CAS login lands on vendor "Something went wrong" page even with valid creds + tokens | Vendor's risk engine wants ThreatMetrix-style async fingerprint that requires running JS. |
| Login form requires `Sec-Fetch-Site: same-origin` (ASP.NET Identity, Auth0 universal login, AWS Cognito hosted UI) | Curl-equivalent POST is always `cross-site`. Need a real form submit from the actual origin. |

The pattern that handles these is **FlareSolverr** (Chromium-backed solver), reclassified under `source.kind: local` (a runner container that shells out to the solver) or `custom` + an orchestrated `connect.tool`. See **`references/flaresolverr-pattern.md`** for the full architecture, setup, 3 local patches (Sec-Fetch-Site, custom headers, `evalScript`), and caveats (non-upstream, infra cost, Cloud-incompatible `host.docker.internal`).

This is an **escape hatch**: only reach for it when one of the symptoms above is your actual blocker. The other 90% of SaaS work fine with `source.kind: none` + the sidecar's `{ns}__api_call`.

---

> **When in doubt**: probe (Section 1) before coding. The 10-minute investigation saves hours of the wrong pattern.

## ConnectStrategy reference (manifest → strategy)

The platform selects the strategy automatically from the manifest (#487):

| Manifest shape | Strategy |
|---|---|
| `type: "oauth2"` | OAuth 2.0 + PKCE (discovery, auto-refresh) |
| `type: api_key/basic/mtls/custom`, no `connect` | Fields (paste the credential) |
| `type: "custom"` + `connect.login` | Login — one declarative HTTP request |
| `type: "custom"` + `connect.tool` (`run_at: run-start`) | LoginSecret — store a secret, mint a session each run |
| `type: "custom"` + `connect.tool` (`run_at: link`) | Orchestrated — run a tool once in an ephemeral connect-run |

Gating (§7.7): a `delivery.value` may reference only declared `connect.outputs` (or the orchestrated tool's `produces`). Referencing a bootstrap secret directly in delivery is a manifest error; `connect.login` must declare ≥1 `outputs`.
