# FlareSolverr escape hatch — when the sidecar isn't enough

Read this when **Patterns A-F in `auth-decision-tree.md` aren't viable**: the SaaS gates auth behind machinery the Bun sidecar can't run (real Chromium fingerprint, JS-computed cookies, anti-bot challenges, in-page-only `fetch()`). FlareSolverr — a Chromium-backed proxy — bypasses these by running an actual headless browser, then exposing its cookie jar + navigation API over HTTP.

This is an **escape hatch**, not a default. The sidecar pipeline + the patterns in `auth-decision-tree.md` cover ~90% of real SaaS. Use FS when you've ruled out the cheaper paths and have one of the symptoms below.

## Table of Contents

- [1. When to reach for FlareSolverr](#1-when-to-reach-for-flaresolverr)
- [2. Architecture](#2-architecture)
- [3. Setup](#3-setup)
- [4. The `credentials-substitution-cross-target` pattern](#4-the-credentials-substitution-cross-target-pattern)
- [5. The `login → sessionId → fetch` pattern](#5-the-login--sessionid--fetch-pattern)
- [6. Known FS limitations + local patches](#6-known-fs-limitations--local-patches)
- [7. Caveats before adopting](#7-caveats-before-adopting)

---

## 1. When to reach for FlareSolverr

Symptoms — at least one of these justifies the FS detour. None of them == stay in the standard sidecar.

| Symptom | Why FS solves it |
|---|---|
| `429 Too Many Requests` or Cloudflare `Just a moment…` interstitial in the response body, even with realistic headers + residential proxy. Browser passes fine on the same IP. | Bot management (CF, DataDome, Akamai) checks more than TLS fingerprint — also JS challenge execution, canvas, WebGL. Chromium executes them naturally; Bun fetch can't. |
| `Something went wrong, check again in a couple of minutes` (or vendor equivalent) on POST CAS login, even with valid credentials, valid hidden tokens, and recent traffic. | The login page loaded ThreatMetrix / risk-engine iframes that fingerprint asynchronously. POST-ing too fast (before the FP is sent server-side) trips the risk engine. With FS you can `sleep` between page load and form submit, letting the async FP land. |
| Login redirects to a vendor error page with `Origin: null` rejected (ASP.NET Identity Server, AWS Cognito hosted UI, Auth0 universal login). | These IdPs validate `Sec-Fetch-Site: same-origin` on the form POST. The upstream FS `_post_request` uses a `data:` URL → `Sec-Fetch-Site: cross-site` → reject. The local patch (§6) does an in-page form submit, which yields `same-origin`. |
| The post-login JSON endpoint redirects to the homepage instead of returning JSON, even with `Accept: application/vnd.foo+json` set. | Some upstreams gate JSON endpoints on a specific `Accept` header that Chromium overrides on navigation requests (Chromium always sends `Accept: text/html,…` on doc-level navigation). Use `evalScript` (§6) to do an in-page `fetch()` instead. |

If you don't see your symptom here, you're probably hitting something more basic — re-read `auth-decision-tree.md` §3 (pattern recipes) and §4 (anti-bot ladder steps 1-3) first.

---

## 2. Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│ Appstrate run                                                         │
│                                                                       │
│  ┌──────────────┐  providerCall(@scope/X, target: FS, body:{ … })     │
│  │ tool TS      │ ───────────────────────────────────────────────┐    │
│  │ (login)      │                                                ▼    │
│  └──────────────┘                              ┌────────────────────┐ │
│         ▲                                      │ sidecar Bun        │ │
│         │ {status, sessionId}                  │  - reads @scope/X  │ │
│         │                                      │    credentials     │ │
│  ┌──────────────┐                              │  - substitutes     │ │
│  │ tool TS      │   providerCall(@default/    │    {{email}}/…     │ │
│  │ (inbox-fetch)│   flaresolverr-fetch, …)    │  - POSTs JSON to   │ │
│  └──────────────┘ ──────────────────────────► │    FS endpoint     │ │
│                                                └─────────┬──────────┘ │
│                                                          │            │
└──────────────────────────────────────────────────────────┼────────────┘
                                                           │
                       ┌───────────────────────────────────▼──────────┐
                       │ FlareSolverr container (host.docker.internal │
                       │                          :8191)              │
                       │  - Chromium headless                         │
                       │  - per-session cookie jar (sessions.*)       │
                       │  - request.get / request.post / evalScript   │
                       └───────────────────────────────────┬──────────┘
                                                           │
                                                  ┌────────▼──────┐
                                                  │ Upstream SaaS │
                                                  │ (CF / IdP)    │
                                                  └───────────────┘
```

Two providers cooperate:
- **`@scope/<saas>`** — the SaaS provider you authored. Its `authorizedUris` MUST include `http://host.docker.internal:8191/**` so the sidecar will let your tool send POSTs there.
- **`@default/flaresolverr`** — the FS provider. Empty credentials (no auth on FS itself; relies on Docker network isolation).

The tool TS goes through `@scope/<saas>` (not `@default/flaresolverr`) when it needs `substituteBody` for credentials — see §4.

---

## 3. Setup

Self-hosted only. Don't deploy FS on multi-tenant Appstrate cloud — the credential-substitution pattern below assumes the FS endpoint is trusted infra co-located with the sidecar.

### 3.1 Container

```bash
docker run -d --name flaresolverr \
  -p 8191:8191 \
  --restart unless-stopped \
  -e LOG_LEVEL=info \
  ghcr.io/flaresolverr/flaresolverr:latest
```

Health-check: `curl http://localhost:8191/` returns `{"msg":"FlareSolverr is ready!"}`. ARM64 + amd64 supported. ~500 MB RAM per active Chromium session; FS auto-expires idle sessions after ~10 min.

If you need the local patches in §6 (most non-trivial SaaS will), build from a fork instead of using the upstream image — see §6.4.

### 3.2 `@default/flaresolverr` provider

Minimal manifest (no credentials, just allowed-URI guard):

```json
{
  "name": "@default/flaresolverr",
  "version": "1.0.0",
  "type": "provider",
  "schemaVersion": "1.1",
  "displayName": "FlareSolverr",
  "definition": {
    "authMode": "custom",
    "credentials": { "schema": { "type": "object", "properties": {} } },
    "authorizedUris": ["http://host.docker.internal:8191/**"]
  }
}
```

Connect with empty credentials via `POST /api/connections/connect/@default/flaresolverr/credentials -d '{}'`.

### 3.3 Generic fetch wrapper tool

`@default/flaresolverr-fetch` — generic GET/POST through FS, takes `{url, method?, post_data?, cookies?, session?, max_timeout_ms?}`, returns flat `{success, status, url, body, cookies, user_agent}`. Useful as a building block when the SaaS tool doesn't need credentials in the body (post-bootstrap API calls reusing a session). Source pattern in §5.

---

## 4. The `credentials-substitution-cross-target` pattern

**The problem**: your tool needs to send credentials (`{{email}}`/`{{password}}`) to the SaaS but the request has to be routed through FS (so a real Chromium does the navigation). If you call FS via `@default/flaresolverr` and use `substituteBody:true`, the sidecar looks for credentials in **`@default/flaresolverr`** — which has none. The substitution silently no-ops.

**The fix**: extend the SaaS provider's `authorizedUris` to include the FS endpoint, and route the FS call through the **SaaS provider** (not the FS provider). The sidecar will:
1. See the target `http://host.docker.internal:8191/v1` is allowed under `@scope/<saas>`'s `authorizedUris`. ✓
2. Read the credentials of `@scope/<saas>`. ✓
3. Substitute `{{email}}`/`{{password}}` in the JSON body you're sending to FS (which itself contains a `postData` field). ✓
4. POST the substituted body to FS. ✓
5. FS forwards `postData` to the real SaaS upstream.

Where it matters: the placeholder is **inside a JSON string field** (`postData`), not at the top level of the body. The sidecar's substitution is a string-replace, not a JSON-walk, so it handles this naturally.

### 4.1 Example

```ts
// inside a login tool TS
const result = await ctx.providerCall("@scope/<saas>", {
  method: "POST",
  target: "http://host.docker.internal:8191/v1",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    cmd: "request.post",
    session: sessionId,
    url: "https://login.<saas>.com/login",
    postData: "username={{email}}&password={{password}}&csrf=<extracted>",
  }),
  substituteBody: true, // ← critical
});
```

Manifest side:

```json
"authorizedUris": [
  "https://login.<saas>.com/**",
  "https://api.<saas>.com/**",
  "http://host.docker.internal:8191/**"   // ← critical for this pattern
]
```

### 4.2 Why this preserves ADR-003

The LLM only sees the literal `"{{email}}"` / `"{{password}}"` strings in the tool source. The tool TS doesn't `await ctx.readCredentials(...)` — it just emits placeholders. The sidecar substitutes them server-side, on its way to FS. The tool runtime, the LLM, and the user-facing logs never observe the values. FS receives the resolved values in `postData`, but FS is trusted local infra (Docker network, no external auth).

### 4.3 Form-urlencoded special characters

The sidecar substitution is a verbatim string-replace — it does not URL-encode. If a credential contains `&`, `=`, `+`, or `%`, the resulting `postData` will be malformed.

**Workaround**: store a pre-encoded variant in credentials (`email_encoded`, `password_encoded`) and reference those placeholders instead. Document this in `PROVIDER.md`.

---

## 5. The `login → sessionId → fetch` pattern

After login, the authenticated session lives **inside FS** (Chromium cookie jar), not in the sidecar. If you call `provider_call` on a post-login API endpoint, it goes via Bun fetch — which never saw the login cookies — and you get `401`/`session_invalid`.

The fix is to keep the FS session alive across tool calls and route every subsequent SaaS API call through FS too. Two pieces of mechanics:

1. **The login tool doesn't destroy the FS session on success** — it returns `sessionId` in its output and skips `sessions.destroy`. FS auto-expires after ~10 min idle, which is enough for one agent run.
2. **A companion `*-inbox-fetch` / `*-list` tool** takes `sessionId` as input and uses it to fetch authenticated API endpoints via `@default/flaresolverr-fetch` (or a custom call routed through the SaaS provider when you need credentials substitution again).

### 5.1 Login tool ending — keep session alive

```ts
let cleanupOnError = true;
const destroySession = async () => {
  try { await fsPost({ cmd: "sessions.destroy", session: sessionId }); } catch {}
};

try {
  // … login flow …
  cleanupOnError = false; // success — keep session alive for the caller
  return { content: [{ type: "text", text: JSON.stringify({
    status: "ok", sessionId, /* + whatever else the agent needs */
  })}]};
} finally {
  if (cleanupOnError) await destroySession();
}
```

### 5.2 Companion fetch tool

```ts
// <saas>-inbox-fetch — takes sessionId, fetches one endpoint
const Params = Type.Object({ sessionId: Type.String({ minLength: 1 }) });

async execute(_id, params, _signal, ctx) {
  const r = await ctx.providerCall("@scope/<saas>", {
    method: "POST",
    target: "http://host.docker.internal:8191/v1",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      cmd: "request.get",
      session: params.sessionId,
      url: "https://api.<saas>.com/messages/unread",
      maxTimeout: 60000,
    }),
  });
  // parse FS envelope, then upstream JSON …
}
```

### 5.3 Agent prompt orchestration

```
1. Call <saas>_login() → capture sessionId from output.
2. Call <saas>_inbox_fetch({ sessionId }) → returns messageCount.
3. Emit via output(…).
```

That's it. The LLM doesn't see the FS endpoint, doesn't construct any HTTP — it just chains two tool calls and reads structured output.

### 5.4 When NOT to keep the session

If the post-login work is trivial (one read, no further auth needed downstream) and the SaaS exposes a token-based auth on top of the cookie session (refresh token, JWT), prefer **Pattern A (ROPC)** in `auth-decision-tree.md`: extract the token from the cookie jar via `evalScript` (§6.3), store it in the provider's credentials, then call subsequent endpoints from the sidecar with a Bearer header. Skips FS for the API surface entirely.

---

## 6. Known FS limitations + local patches

Upstream FlareSolverr (`3.4.x` as of writing) is a thin wrapper around Selenium. It works for the majority of CF-protected sites but trips on three specific things you'll hit while implementing the patterns in §4-5. The fixes are small (~20 lines total) and local to `flaresolverr_service.py`.

Build the patched image and tag it:

```bash
git clone https://github.com/FlareSolverr/FlareSolverr.git
cd FlareSolverr
# apply patches from §6.1, §6.2, §6.3 below (Edits to src/flaresolverr_service.py + src/dtos.py)
docker build -t flaresolverr-patched:1.2 .
docker run -d --name flaresolverr -p 8191:8191 --restart unless-stopped flaresolverr-patched:1.2
```

### 6.1 Patch: `_post_request` → in-page form submit

**Problem**: upstream `_post_request` navigates Chromium to `data:text/html,…` then auto-submits. Result: `Origin: null` (correct for vendors that allow it) but `Sec-Fetch-Site: cross-site` (incorrect — vendors that enforce same-origin reject).

**Fix**: navigate to the target's origin root first (loading a live document), then inject the form via `execute_script` and submit. Browser emits `Sec-Fetch-Site: same-origin` + `Origin: https://target` + `Referer: https://target/`.

```python
def _post_request(req, driver):
    target_url = req.url
    parsed = urlparse(target_url)
    origin_root = f"{parsed.scheme}://{parsed.netloc}/"

    current_url = driver.current_url
    current_parsed = urlparse(current_url) if current_url else None
    same_origin = (current_parsed and current_parsed.scheme == parsed.scheme
                   and current_parsed.netloc == parsed.netloc)
    if not same_origin:
        driver.get(origin_root)

    # parse req.postData into [(name, value)] pairs (form-urlencoded)
    # then build fields_js — one createElement('input') per pair, escape values
    submit_script = (
        "var f=document.createElement('form');"
        "f.method='POST';"
        f"f.action={json.dumps(target_url)};"
        + fields_js +
        "document.body.appendChild(f);f.submit();"
    )
    driver.execute_script(submit_script)
```

Validation: `cmd:request.post` against `httpbin.org/post` now returns `"Origin": "https://httpbin.org"`, `"Sec-Fetch-Site": "same-origin"`.

### 6.2 Patch: accept `headers` param via CDP

**Problem**: FS v2 stripped the `headers` param ("Request parameter 'headers' was removed in FlareSolverr v2"). You can't set custom request headers anymore — which matters for vendor APIs that gate JSON endpoints on `Accept`.

**Fix**: re-accept `headers` (as a dict, not the old list-of-strings format), forward to Chromium via CDP `Network.setExtraHTTPHeaders` before navigation.

```python
# in _controller_v1_handler:
if req.headers is not None and not isinstance(req.headers, dict):
    logging.warning("'headers' must be a dict; ignoring.")
    req.headers = None

# in _resolve_challenge, before driver.get / _post_request:
if req.headers:
    try:
        driver.execute_cdp_cmd("Network.enable", {})
        driver.execute_cdp_cmd("Network.setExtraHTTPHeaders", {"headers": req.headers})
    except Exception as e:
        logging.warning(f"Failed to set custom headers via CDP: {e}")
```

**Limitation that this fix does NOT solve**: Chromium overrides `Accept` (and `User-Agent`) on navigation requests regardless of what CDP says — those are document-level headers Chromium considers its own. Custom headers like `X-API-Version`, `Authorization`, `Origin` go through fine; `Accept` doesn't. For Accept-gated endpoints, use §6.3 (evalScript).

### 6.3 Patch: `evalScript` for in-page fetch

**Problem**: many vendor APIs gate JSON behind a specific `Accept` header (e.g. `application/vnd.messagebox-unread-counts.v1+json`). Chromium's navigation always sends `Accept: text/html,…`, overriding §6.2. The endpoint either redirects to a homepage or returns HTML.

**Fix**: add an `evalScript` param. After navigation, the request handler runs the provided JS via `driver.execute_script` and returns its value. The script can `fetch()` from inside the authenticated origin, with whatever headers it wants.

In `dtos.py`:

```python
class V1RequestBase(object):
    # … existing fields …
    evalScript: str = None  # JS to run via execute_script after navigation

class ChallengeResolutionResultT:
    # … existing fields …
    evalResult = None       # result of evalScript (any JSON-serializable value)
```

In `flaresolverr_service.py`, after `challenge_res.response = driver.page_source`:

```python
if req.evalScript:
    try:
        challenge_res.evalResult = driver.execute_script(
            f"return (async () => {{ {req.evalScript} }})();"
        )
    except Exception as e:
        challenge_res.evalResult = {"__evalError__": str(e)}
```

**Usage from a tool TS** — note the `evalScript` is a **string literal in the tool source**, never built from LLM input (would be a JS injection):

```ts
const evalScript = [
  "const r = await fetch('/api/messages/unread', {",
  "  credentials: 'include',",
  "  headers: {",
  "    'Accept': 'application/vnd.foo.v1+json',",
  "    'Content-Type': 'application/json'",
  "  }",
  "});",
  "return JSON.stringify({ status: r.status, body: await r.text() });",
].join("\n");

const r = await ctx.providerCall("@scope/<saas>", {
  method: "POST",
  target: "http://host.docker.internal:8191/v1",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    cmd: "request.get",
    session: sessionId,
    url: "https://www.<saas>.com/",  // any same-origin authenticated page
    maxTimeout: 60000,
    evalScript,
  }),
});
// parse envelope.solution.evalResult, then JSON.parse it
```

### 6.4 Maintaining the fork

These three patches are ~30 lines total against `FlareSolverr 3.4.6`. If you rebase against a newer upstream, the touch-points are:
- `_post_request` in `src/flaresolverr_service.py` (currently around line 490)
- `_controller_v1_handler` validation block (~line 120) and `_resolve_challenge` headers application (~line 370)
- `V1RequestBase` + `ChallengeResolutionResultT` in `src/dtos.py`

If upstream FS ships a new release with native fixes (issue #1613 tracks Sec-Fetch-Site; no tracker for evalScript yet), drop the corresponding patch.

---

## 7. Caveats before adopting

Before adding FS to your stack, weigh these against staying in the sidecar:

- **Non-upstream patches**: the three fixes above are local. Anyone running your tools must build the same patched image. Document the exact image tag (e.g., `flaresolverr-patched:1.2`) and patch list. Pierre's stance (Appstrate issue [#458](https://github.com/appstrate/appstrate/issues/458)) is that bot-tier bypass should live in a tenant-side proxy — not in the sidecar. FS is consistent with that view (it's tenant-side), but the platform won't ship the patches for you.
- **Infra cost**: ~500 MB RAM per active session, 5-30s per navigation (real Chromium). Two concurrent agents → 1 GB. Plan accordingly on small VMs.
- **Multi-tenancy is harder**: FS sessions aren't tenant-scoped. Two tenants sharing one FS container can race on `sessions.create`/`destroy` if their tools use overlapping session IDs. For multi-tenant deployments, run one FS container per tenant (or per agent run) — costs more, but avoids the cross-tenant cookie leak.
- **Not Appstrate Cloud-compatible**: the pattern assumes `host.docker.internal:8191` is reachable from the sidecar. Cloud sidecars don't have your FS container. If you're targeting cloud, document the limitation in `PROVIDER.md` and either fall back to a degraded mode or refuse to run.
- **Maintenance**: each upstream change a vendor ships (login flow, fingerprint scripts, redirect chains) may require re-reverse-engineering. Capture the curl-equivalent of a real browser login in Chrome DevTools every time you touch the tool — it's the only source of truth for what "valid" looks like.

If those trade-offs don't fit your context, stay in the sidecar and use the patterns in `auth-decision-tree.md` instead.
