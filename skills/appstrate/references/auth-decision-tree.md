# Choosing the right auth pattern for a custom provider

Read this when authoring a new `@scope/name` provider for a SaaS that doesn't already ship in `@appstrate/*`. The goal is to skip the trial-and-error: identify the SaaS's login shape in a few minutes, then go straight to the matching pattern.

## Table of Contents

- [1. Investigate first (10 min curl probe + Chrome DevTools)](#1-investigate-first-10-min-curl-probe--chrome-devtools)
- [2. Decision table](#2-decision-table)
- [3. Pattern recipes](#3-pattern-recipes)
- [4. Anti-bot escalation ladder](#4-anti-bot-escalation-ladder)

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

| Symptom from probe | Pattern | authMode |
|---|---|---|
| `POST /token` → JSON `{access_token, refresh_token, expires_in}`, no JS challenge, optional JWT claims to extract | **A. Server-side ROPC bootstrap** | `password` |
| Form `POST /login` with `j_username`/`username` + `password` → 302 + Set-Cookie session, single round-trip | **B. Single-POST with cookie capture** | `custom` + tool TS wrapping one `provider_call` |
| Form `POST /login` → CAS/SAML/OIDC handoff (3+ redirects, ticket → code → cookie), no captcha | **C. Multi-step CAS/OIDC bootstrap** | `custom` + tool TS chaining 3-6 `provider_call`s |
| Magic-link-by-email is the only viable path (password login wants a JS-computed challenge the sidecar can't generate, but the magic-link redemption is a plain GET) | **D. Email-orchestrated bootstrap** | `custom` + tool TS that triggers the email then polls `@appstrate/gmail` |
| Cookies expire weekly+ AND no automated bootstrap is possible (captcha at every login attempt, browserinfo3, etc.) | **E. Static cookie credentials (manual refresh)** | `custom` with cookies as credentials, captured by hand via Chrome DevTools |
| Login UI is fine in a browser but every curl/Bun/undici call gets `403 Cloudflare` / `429` regardless of credentials | **F. ASN-blocked SaaS** — orthogonal to pattern choice. Wire a residential rotating proxy via `PROXY_URL` (cascade: per-agent → org default → env), or accept manual cookie refresh | any |

**Two bonus knobs that can apply to any pattern**:
- **TLS fingerprint blocked** (200 in browser, 403/502 from sidecar even with the same cookies): add `definition.x-tlsClientByUrl: [{match, client: "curl"}]` for the affected URLs. See `manifest-schema.md` §`x-tlsClientByUrl`.
- **AWS ALB / sticky-session backends**: do a pre-flight `GET /login.jsa` from the bootstrap tool BEFORE the `POST` — primes `AWSALB`/`JSESSIONID` so the POST hits the same backend instance. See `manifest-schema.md` §"Session cookies".

---

## 3. Pattern recipes

Each recipe links to the canonical example in `manifest-schema.md` rather than duplicating manifest JSON here.

### A. Server-side ROPC (`authMode: "password"`)

The sidecar bootstraps + refreshes + injects headers — the LLM never touches credentials. Best when the SaaS exposes a clean `/token` JSON endpoint and (optionally) a refresh token.

- Manifest shape: see `manifest-schema.md` § "Canonical example (`password` / Resource Owner Password Credentials grant)".
- JWT claim extraction (e.g. `personId`) via the `claims` map + simplified JSONPath subset (`$`, `.foo`, `[N]`, `["key"]`, `| jwt |` pipe).
- No tool TS required — the agent calls `provider_call` and the sidecar handles auth transparently.

### B. Single-POST + cookie capture (`authMode: "custom"` + tool)

For Spring Security / Java EE / Rails sites with a one-shot form-encoded login. The tool TS issues ONE `provider_call({method:"POST", body:"j_username={{email}}&j_password={{password}}", substituteBody: true})` then validates with a GET on a known authenticated page.

- Cookies (JSESSIONID, app-specific) are captured into the per-run cookie jar by the sidecar's redirect-cookie-capture (see `manifest-schema.md` §"Session cookies").
- For AWS-ALB-backed sites, prepend a pre-flight `GET /login` to prime the LB stickiness cookie.
- Validation: GET an authenticated page and check for a binary signal (presence of a link to a `/private/...` URL, absence of the public login form input).

### C. Multi-step CAS / OAuth handoff

For SaaS where the form login fans out into 3-6 redirects (OIDC `authorize` → CAS `login` → `callback` → app session). The tool TS:

1. `GET /api/auth/csrf` (next-auth) or `GET /login` (CAS) — extract anti-CSRF / state hidden tokens.
2. `POST /api/auth/signin/<provider>` or equivalent — primes next-auth state cookies, redirects to the actual CAS form.
3. Parse hidden `execution` / `tmSessionId` / `service` from the form HTML.
4. `POST <CAS-login-url>` with credentials substituted server-side via `{{email}}` / `{{password}}` placeholders.
5. The sidecar follows the 302 chain; cookies of every hop are captured (BUGS-EVO §2.9).
6. Validate via the SaaS's `/api/auth/session` or `/login/home` equivalent.

The cookie-jar persistence across `provider_call`s within the same run is what makes this pattern viable — without the redirect-capture fix, cookies set on the `/callback/...` hop are dropped before the final 302.

### D. Magic-link-by-email (`@appstrate/gmail`-orchestrated)

When the password login requires a JS-computed challenge the sidecar can't generate (PoW, canvas fingerprint), but the **magic-link redemption** (`GET /login/onetime?key=…`) accepts plain HTTP. The tool TS:

1. `GET /login` → extract anti-CSRF token `t`.
2. `POST /login/onetime` with `{t, inputEmailHandle: {{email}}}` → SaaS sends an email.
3. Poll `@appstrate/gmail` (`GET /gmail/v1/users/me/messages?q=from:<sender>+newer_than:5m+after:<triggerEpoch>`) until the message arrives, max 60s.
4. `GET <message>?format=full` → walk `payload.parts[]` for `text/plain` (preferred) or `text/html`, base64url-decode.
5. Extract the magic link with a regex bounded to the SaaS's domain.
6. `GET <magic-link>` → cookies captured; validate via an authenticated page.

Caller note: agents that consume this pattern MUST declare BOTH the SaaS provider AND `@appstrate/gmail` in `dependencies.providers`. The Gmail connection MUST own the same email used as the SaaS account; if the default profile points elsewhere, override per-run via `providerProfiles` (see `inline-runs.md`).

### E. Static cookies (manual refresh)

When neither password nor magic-link is automatable. Provider's `credentials.schema` lists cookie names as fields (e.g. `cl_login`, `cl_b`); the user captures values from a logged-in browser via Chrome DevTools and saves them via `POST /api/connections/connect/@scope/name/credentials`. Re-capture when cookies expire (typically weekly to monthly).

The agent prompt or a wrapper tool injects `headers: { "Cookie": "{{cookie1_name}}={{cookie1_value}}; ..." }` on each call; the sidecar substitutes the placeholders server-side.

---

## 4. Anti-bot escalation ladder

When a pattern works in `curl` but fails in the sidecar:

1. **Set realistic headers** — `User-Agent: Mozilla/5.0 …`, `Accept`, `Accept-Language`, `Origin`, `Referer`. CORS-strict APIs (e.g. `capi.craigslist.org`) reject without `Origin` matching their allowlist (silent 502).
2. **Flip the URL to curl client** via `x-tlsClientByUrl: [{match, client:"curl"}]` — bypasses Bun's TLS fingerprint when the SaaS does JA3-only blocking. Doesn't help against Cloudflare full bot management.
3. **Switch to a residential proxy** via `PROXY_URL` env or per-agent override — the only fix for ASN-blacklist bot management (Cloudflare with bot tier, Akamai, DataDome). Datacenter / VPN exit nodes are blocked outright.
4. **Headless browser** — out of scope for the sidecar today. Last resort would be a custom tool that shells out to Playwright / Chromium in a separate runtime image. Not worth it for ≤ 2 SaaS — switch SaaS instead.

---

> **When in doubt**: probe (Section 1) before coding. The 10-minute investigation saves hours of the wrong pattern.
