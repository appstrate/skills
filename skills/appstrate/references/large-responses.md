# Large responses from `ctx.providerCall` — resolving `resource_link` blocks (≥32 KB)

When you write a custom tool (TypeScript, `dependencies.tools` in your agent bundle) that calls an external API through `ctx.providerCall(...)`, **upstream responses larger than 32 KB do not arrive inline**. The sidecar spills the body into a run-scoped `BlobStore` and returns an MCP `resource_link` block instead. If your tool doesn't know about this, `result.content[0].text` comes back empty and the body looks "missing" — the most common silent failure mode for tools that consume non-trivial API responses.

This document covers the recommended pattern (`ctx.readResource`, runtime-pi >= 1.0.0-beta.7) and the manual fallback for older runtimes, plus five gotchas that cost ~2h of debug each if missed.

---

## How `ctx.providerCall` returns bodies

The MCP `CallToolResult` shape depends on the upstream response size and the `INLINE_RESPONSE_THRESHOLD` constant (32 KB, hardcoded in `runtime-pi/sidecar/mcp.ts`):

**Body < 32 KB → inline `text` block:**
```json
{ "content": [{ "type": "text", "text": "<body>" }] }
```

**Body ≥ 32 KB → spill to BlobStore, returns `resource_link`:**
```json
{
  "content": [
    {
      "type": "resource_link",
      "name": "...",
      "uri": "appstrate://provider-response/{runId}/{ulid}",
      "mimeType": "..."
    }
  ]
}
```

For an LLM-driven agent, the model can call MCP `resources/read({ uri })` itself. For a **tool TS intermediary** that wants to parse the body and write it to disk (without polluting the agent's context with a 100 KB blob), you need to resolve the URI yourself.

---

## Recommended pattern — `ctx.readResource(uri)` (runtime-pi >= 1.0.0-beta.7)

The runtime exposes `readResource` as a thin wrapper over `mcp.readResource()` of the runner's MCP client. No new transport, no new auth, no port to discover.

```ts
// 4th arg of execute is the AppstrateToolCtx from @appstrate/runner-pi
import type { AppstrateToolCtx } from "@appstrate/runner-pi";

async function providerGet(
  ctx: AppstrateToolCtx,
  provider: string,
  target: string,
): Promise<string> {
  const result = await ctx.providerCall(provider, { method: "GET", target });
  const block = result?.content?.[0];

  // < 32 KB → inline text
  if (typeof block?.text === "string" && block.text.length > 0) return block.text;

  // ≥ 32 KB → resource_link spillover
  if (typeof block?.uri === "string" && block.uri.length > 0) {
    const resolved = await ctx.readResource(block.uri);
    const c = resolved?.contents?.[0];
    return typeof c?.text === "string"
      ? c.text
      : typeof c?.blob === "string"
        ? Buffer.from(c.blob, "base64").toString("utf8")
        : "";
  }

  return "";
}
```

That's it. One function covers both inline and spilled cases.

---

## Binary downloads — `responseMode: { toFile: ... }`

For **binary** payloads (PDFs, images, archives, audio, video), `ctx.readResource` is not optimal: the content travels base64-encoded inside the MCP envelope (capped at `SIDECAR_MAX_MCP_ENVELOPE_BYTES`, 16 MB default — surcharged by the ~33% base64 inflation), then is reloaded into RAM tool-side before `writeFile`. Risks: OOM, latency, silent failure beyond the cap.

The sidecar exposes `responseMode: { toFile: "<path>" }` which **streams the upstream body directly to a file** in the sandbox's shared filesystem. No base64, no envelope, no practical size limit (bounded only by container disk, typically several GB).

```ts
const result = await ctx.providerCall("@appstrate/google-drive", {
  method: "GET",
  target: `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`,
  responseMode: { toFile: "/tmp/download.pdf" },
});

// result.content[0].text is a JSON summary (status, size, path).
// The bytes are on disk at /tmp/download.pdf — read with fs/promises.
const stats = await stat("/tmp/download.pdf");
```

**When to use `toFile` vs `readResource`:**
- **`toFile`** — you need a file on disk (PDF to pass to `pdf-toolkit`, image to analyze, archive to unzip). Always prefer for binaries.
- **`ctx.readResource(uri)`** — you need the content **in memory** in the tool (parse JSON, extract short text). Right choice for text bodies up to a few MB.

**Sandbox path gotcha** — depending on the sandbox config, some absolute paths are restricted (e.g. `/tmp/` may need a subfolder). On write errors, retry with a relative path like `downloads/<name>` (the sandbox creates the folder under the runner's CWD).

## Fallback for runtime-pi <= 1.0.0-beta.6

If your tool must run on a runtime that predates `ctx.readResource`, the manual workaround is to JSON-RPC the sidecar's `/mcp` endpoint directly:

```ts
// Sidecar Hono app + MCP endpoint listens on PORT (default 8080).
// Port 8081 = forward-proxy SSRF (HTTP_PROXY env var) — DO NOT confuse them.
const SIDECAR_MCP_URLS = [
  "http://sidecar:8080/mcp",     // Docker hostname (Tier 3)
  "http://localhost:8080/mcp",    // Tier 0 Bun standalone
  "http://127.0.0.1:8080/mcp",
];

async function readBlobViaMcp(uri: string): Promise<string> {
  const reqBody = JSON.stringify({
    jsonrpc: "2.0",
    id: Date.now(),
    method: "resources/read",
    params: { uri },
  });
  for (const url of SIDECAR_MCP_URLS) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: reqBody,
      });
      if (!res.ok) continue;
      const parsed: any = await res.json();
      const c = parsed?.result?.contents?.[0];
      if (typeof c?.text === "string") return c.text;
      if (typeof c?.blob === "string") return Buffer.from(c.blob, "base64").toString("utf8");
    } catch {
      // try next candidate
    }
  }
  return "";
}
```

Defensive guardrail at tool startup — fail loud if neither path is available:

```ts
async execute(_id, params, _signal, ctx) {
  if (!ctx?.providerCall) {
    return { content: [{ type: "text", text: "Missing ctx.providerCall — runtime-pi too old" }], isError: true };
  }
  // Optionally: detect ctx.readResource presence and select path accordingly.
  ...
}
```

---

## Five gotchas

### 1. Sidecar port: 8080 (MCP) vs 8081 (forward-proxy)

`HTTP_PROXY=http://sidecar:8081` is exposed in the tool's env — that's the **forward-proxy** (SSRF protection + outbound tunnel), NOT the MCP endpoint. The MCP listens on `PORT` (default 8080), via `runtime-pi/sidecar/server.ts`:

```ts
const port = parseInt(process.env.PORT || "8080", 10);
const proxy = createForwardProxy({ config, listenPort: port + 1 });
```

This only impacts the fallback path — `ctx.readResource` hides this detail.

### 2. `runId` may be literal `"unknown"` in the URI

On Tier 0 / Bun standalone, the URI may be `appstrate://provider-response/unknown/<ulid>` instead of `appstrate://provider-response/{runId}/<ulid>`. The sidecar's `resources/read` accepts the literal value as it was stored — pass the URI you received in the `resource_link` verbatim, do NOT try to "fix" the runId.

### 3. No `inlineThreshold` option exposed to the caller

The 32 KB threshold is a server-side constant. `ctx.providerCall` ignores any custom option you pass (`inline: true`, `bufferAll: true`, `maxInlineSize: 1000000`, `responseMode: "inline"`, etc. — all tested empirically, no effect). Don't waste time trying to disable spillover via options.

### 4. The bug also hits "writer" tools, not just "fetcher" tools

Any tool that consumes an upstream response is affected — including writer tools that do a GET for pre-validation before a PUT/POST. Concrete example: a `github-contents-create` tool that fetches the existing file's `sha` before doing a PUT update. If the existing file is > 32 KB, the GET spills as `resource_link` → `sha` is never extracted → PUT loops on `422 sha is required` indefinitely. Easy to misdiagnose as a GitHub auth or API shape problem.

### 5. Related downstream bug — sidecar truncation at 256 KB before spillover (RESOLVED)

In older sidecar builds (`runtime-pi/sidecar/mcp.ts` before [PR #365](https://github.com/appstrate/appstrate/pull/365)), the text path read the upstream body via `readBodyBounded(res, MAX_RESPONSE_SIZE)` (256 KB cap, appends a `[truncated...]` marker) **before** deciding to spill into the BlobStore. So any text body between 256 KB and 1 MB arrived at the tool as a 256 KB chunk + the marker polluting the JSON, not the full body.

[PR #365](https://github.com/appstrate/appstrate/pull/365) merged into upstream `main` (~2026-05-08) raises the read cap to `ABSOLUTE_MAX_RESPONSE_SIZE` (1 MB) when a blob store is available — bodies up to 1 MB now pass through intact.

If you're on a pre-2026-05-08 install, **any text response > 256 KB will still be silently corrupted** at the tool boundary, regardless of `ctx.readResource`. There is no tool-side workaround — the data is already truncated by the time you receive the URI. Update the install to pick up the fix.

---

## Common Errors entries (cross-reference for `SKILL.md`)

| Error | Cause | Fix |
|-------|-------|-----|
| Tool TS receives empty body / `result.content[0].text === ""` but `ctx.providerCall` does not throw | Upstream response ≥ 32 KB → spilled as `resource_link` (`appstrate://provider-response/...`). Tool ignores the URI branch. | Resolve via `ctx.readResource(block.uri)` (runtime-pi >= 1.0.0-beta.7). See snippet above. |
| Writer tool (push GitHub, upsert Notion, etc.) doing a GET pre-check loops on 422/409 even though the resource exists | The pre-check GET spills as `resource_link` when the existing resource > 32 KB → `sha` / etag never extracted → retry without the right header → 422 | Same fix: apply `ctx.readResource` on the pre-check GET. |
| Body returned by `ctx.readResource` mysteriously truncated to ~259 KB with `[truncated: response exceeded 262144 bytes]` at the end | Sidecar bug in pre-2026-05-08 builds: truncates at 256 KB BEFORE BlobStore spillover (`runtime-pi/sidecar/mcp.ts`) | RESOLVED by [PR #365](https://github.com/appstrate/appstrate/pull/365). Update the install — no tool-side workaround on older builds. |
| `result.content[0].text === ""` or empty body from `ctx.providerCall` on a binary download > 500 KB | Binary content exceeds the inline cap and the base64 envelope path saturates / the tool fails to decode `c.blob` past a few MB | Use `responseMode: { toFile: "<path>" }`. Sidecar streams directly to disk; read the file with `fs.stat` / `fs.readFile` afterwards. |
