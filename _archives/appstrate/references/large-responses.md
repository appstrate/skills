# Large responses from `{ns}__api_call` — resolving `resource_link` blocks (≥32 KB)

When an agent (or a custom `mcp-server` tool) calls an external API through an integration's `{ns}__api_call` MCP tool, **upstream responses larger than 32 KB do not arrive inline**. The sidecar spills the body into a run-scoped `BlobStore` and returns an MCP `resource_link` block instead of inline `text`. If the caller doesn't handle this, `content[0].text` comes back empty and the body looks "missing" — the most common silent failure mode for non-trivial API responses.

> **Who calls what.** Credentialed outbound calls go through the LLM-facing `{ns}__api_call` MCP tool (the integration + auth are implied by the tool name — there is no `providerId` argument, and no `ctx.apiCall`/`ctx.providerCall` method). The **only** capability on the custom-tool context (`AppstrateToolCtx`, the 4th arg of a tool's `execute`) is **`readResource(uri)`**, which resolves a `resource_link` URI. So: the call is made via the MCP tool; the spill is resolved via `ctx.readResource`.

This document covers the recommended pattern (`ctx.readResource`, runtime-pi >= 1.0.0-beta.7) and the manual fallback for older runtimes, plus the gotchas that cost ~2h of debug each if missed.

---

## How `{ns}__api_call` returns bodies

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
      "uri": "appstrate://api-response/{runId}/{ulid}",
      "mimeType": "..."
    }
  ]
}
```

For an LLM-driven agent, the model resolves the spill automatically — the runner also writes spilled blobs to the workspace under `resources/…` so the agent can read them as files. For a **custom `mcp-server` tool** that consumes the result of an `{ns}__api_call` and wants to parse the body itself (without pushing a 100 KB blob through the agent's context), resolve the `resource_link` URI via `ctx.readResource`.

---

## Recommended pattern — `ctx.readResource(uri)` (runtime-pi >= 1.0.0-beta.7)

The runtime exposes `readResource` as a thin wrapper over `mcp.readResource()` of the runner's MCP client. No new transport, no new auth, no port to discover. Given a `CallToolResult` from an `{ns}__api_call` (the call itself is the MCP tool — `ctx` does not make it), normalise inline-vs-spill like this:

```ts
// 4th arg of execute is the AppstrateToolCtx from @appstrate/runner-pi
import type { AppstrateToolCtx } from "@appstrate/runner-pi";

// `result` is the CallToolResult returned by the {ns}__api_call MCP tool.
async function readApiCallBody(
  ctx: AppstrateToolCtx,
  result: { content?: Array<{ text?: string; uri?: string }> },
): Promise<string> {
  const block = result?.content?.[0];

  // < 32 KB → inline text
  if (typeof block?.text === "string" && block.text.length > 0) return block.text;

  // ≥ 32 KB → resource_link spillover (appstrate://api-response/{runId}/{ulid})
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

`responseMode` is an argument of the `{ns}__api_call` MCP tool. When the agent invokes (e.g. `@appstrate/google-drive`'s) `{ns}__api_call` with:

```json
{
  "method": "GET",
  "target": "https://www.googleapis.com/drive/v3/files/<fileId>?alt=media",
  "responseMode": { "toFile": "downloads/file.pdf" }
}
```

the result's `content[0].text` is a JSON summary (status, size, path) and the bytes land on disk at `downloads/file.pdf` in the shared workspace — read them with `fs/promises` from a tool, or hand the path to another tool (e.g. a PDF reader).

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
  if (!ctx?.readResource) {
    // runtime-pi too old — fall back to readBlobViaMcp() above.
    return { content: [{ type: "text", text: "Missing ctx.readResource — using MCP fallback" }] };
  }
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

On Tier 0 / Bun standalone, the URI may be `appstrate://api-response/unknown/<ulid>` instead of `appstrate://api-response/{runId}/<ulid>`. The sidecar's `resources/read` accepts the literal value as it was stored — pass the URI you received in the `resource_link` verbatim, do NOT try to "fix" the runId.

### 3. No `inlineThreshold` option exposed to the caller

The 32 KB threshold is a server-side constant. `{ns}__api_call` ignores any custom option you pass (`inline: true`, `bufferAll: true`, `maxInlineSize: 1000000`, `responseMode: "inline"`, etc. — all tested empirically, no effect). Don't waste time trying to disable spillover via options.

### 4. The bug also hits "writer" tools, not just "fetcher" tools

Any tool that consumes an upstream response is affected — including writer tools that do a GET for pre-validation before a PUT/POST. Concrete example: a `github-contents-create` tool that fetches the existing file's `sha` before doing a PUT update. If the existing file is > 32 KB, the GET spills as `resource_link` → `sha` is never extracted → PUT loops on `422 sha is required` indefinitely. Easy to misdiagnose as a GitHub auth or API shape problem.

---

## Common Errors entries (cross-reference for `SKILL.md`)

| Error | Cause | Fix |
|-------|-------|-----|
| Tool TS receives empty body / `result.content[0].text === ""` but `{ns}__api_call` does not throw | Upstream response ≥ 32 KB → spilled as `resource_link` (`appstrate://api-response/...`). Tool ignores the URI branch. | Resolve via `ctx.readResource(block.uri)` (runtime-pi >= 1.0.0-beta.7). See snippet above. |
| Writer tool (push GitHub, upsert Notion, etc.) doing a GET pre-check loops on 422/409 even though the resource exists | The pre-check GET spills as `resource_link` when the existing resource > 32 KB → `sha` / etag never extracted → retry without the right header → 422 | Same fix: apply `ctx.readResource` on the pre-check GET. |
| `result.content[0].text === ""` or empty body from `{ns}__api_call` on a binary download > 500 KB | Binary content exceeds the inline cap and the base64 envelope path saturates / the tool fails to decode `c.blob` past a few MB | Use `responseMode: { toFile: "<path>" }`. Sidecar streams directly to disk; read the file with `fs.stat` / `fs.readFile` afterwards. |
