# Creating an MCP-server

An `mcp-server` (AFPS type `mcp-server`, ex-`tool`) packages a Model Context Protocol server. It is **not** referenced directly by an agent — a `local` integration points at it via `source.server`, and the agent depends on that integration. The server's tools then reach the agent namespaced as `{ns}__{tool}`.

Use an mcp-server when you need real code execution (shell-out, filesystem, a process speaking MCP) rather than a plain REST call. For plain REST, a `none` integration + `{ns}__api_call` is simpler (see `create-integration.md`).

## Manifest (MCPB vocabulary)

Start from `assets/mcp-server-manifest.json`.

```json
{
  "$schema": "https://schemas.afps.dev/v0/mcp-server.schema.json",
  "name": "@my-org/acme-mcp",
  "version": "1.0.0",
  "type": "mcp-server",
  "schema_version": "0.1",
  "manifest_version": "0.3",
  "display_name": "Acme (MCP server)",
  "description": "What the server exposes.",
  "server": {
    "type": "node",
    "entry_point": "server/index.ts",
    "mcp_config": { "command": "bun", "args": ["server/index.ts"] }
  },
  "tools": [
    { "name": "do_thing", "description": "What the agent reads via tools/list when deciding to call it." }
  ],
  "_meta": {
    "dev.appstrate/mcp-server": { "runtime": "bun" },
    "dev.appstrate/workspace": { "mount": "/workspace", "access": "rw" }
  }
}
```

- `server.type` ∈ `node | python | binary | uv` (MCPB). **No `bun` value** — for a Bun-native server keep `type: "node"` and add `_meta["dev.appstrate/mcp-server"].runtime: "bun"`.
- `server.mcp_config` — `{ command, args, env?, platform_overrides? }`. Bridge user-config into env via `delivery.env.<VAR>.user_config_key` on the consuming integration.
- `tools[]` — `{ name, description }`. Descriptions are the agent's only guidance (no prompt listing).
- The server runs in a sandboxed runner container (cap-drop ALL, isolated network), one per integration per run. UID/GID 1001 invariant.

## Per-run shared workspace + MCP Roots (opt-in)

Add `_meta["dev.appstrate/workspace"]` to share the per-run workspace with the agent:

```json
"_meta": { "dev.appstrate/workspace": { "mount": "/workspace", "access": "rw" } }
```

- `mount` — absolute POSIX path; rejects `..`, root `/`, and kernel prefixes (`/proc`, `/sys`, `/dev`, `/etc`).
- `access` — `"ro"` (default) | `"rw"`. Kernel-enforced in docker mode (tier 3); advisory in process mode (tier 0–2).
- The sidecar acts as the MCP **Roots** provider: on `roots/list` it returns `[{ uri: "file://<mount>", name: "workspace" }]`. Reference servers: `filesystem`, `git-mcp-server`. Use this for clone → edit → commit → push loops where the agent edits files (via runtime Read/Edit on `/workspace`) and the server does the plumbing.

## Pack & import

```bash
bash scripts/afps-pack.sh ./my-mcp-server /tmp/acme-mcp.afps
appstrate api POST /api/packages/import -F file=@/tmp/acme-mcp.afps
```

Then ship a `local` integration whose `source.server` points at `@my-org/acme-mcp`, and have agents depend on that integration. There is no REST listing for mcp-servers — selection happens through the integration in the agent manifest.
