# Known issues — Appstrate platform & CLI

Conjunctural bugs and limitations observed on **`appstrate-version: 2026-03-21`** with CLI **`appstrate@1.0.0-alpha.64`**. If your instance reports a newer version, verify each entry before relying on the workaround — they may have been fixed.

## Table of Contents

- [DELETE agent returns 500 once a run exists](#delete-agent-returns-500-once-a-run-exists)
- [`appstrate run` CLI cannot load `@appstrate/*` system tools](#appstrate-run-cli-cannot-load-appstrate-system-tools)
- [`appstrate run` rejects `.afps`, only accepts `.afps-bundle`](#appstrate-run-rejects-afps-only-accepts-afps-bundle)
- [Self-hosted Tier 3: signed upload URL points to `minio:9000`](#self-hosted-tier-3-signed-upload-url-points-to-minio9000)
- [Webapp file picker rejects `accept: "*/*"` literally](#webapp-file-picker-rejects-accept--literally)

---

## DELETE agent returns 500 once a run exists

**Symptom**: `DELETE /api/packages/agents/{scope}/{name}` returns `500 internal_error` (RFC 9457, no `detail`). Triggered as soon as any run has terminated on the agent (success/failed/cancelled). Fresh agents that never ran return 204 normally.

**Tried and not working** — bulk-delete runs (`DELETE /api/agents/{scope}/{name}/runs`) returns 500 too. Version-by-version deletion succeeds (204) but leaves the shell stuck (`hasUnarchivedChanges: true`).

**Workaround**: delete via the **webapp UI** — the UI uses a different code path that handles the run-cascade correctly. Don't waste cycles on API workarounds.

---

## `appstrate run` CLI cannot load `@appstrate/*` system tools

**Symptom** when running an agent that depends on `@appstrate/output` (or `log`, `state`, etc.) via `appstrate run`:

```
warn: Failed to load tool '@appstrate/output': Cannot find module '@mariozechner/pi-ai'
  from '/var/folders/.../appstrate-run-XXXXX/.agent-tools/@appstrate/output/tool.js'
→ tool: output → ✗ Tool output not found
```

The agent then improvises, dumps text instead of calling `output`, and the run completes with `result.output: null`.

**Cause**: PiRunner extracts `tool.js` to a tmpdir, but the bundled `import { Type } from "@mariozechner/pi-ai"` doesn't resolve from that path. The CLI binary embeds `pi-ai` for itself but doesn't expose it to extracted tools.

**No user-side fix**: `bun add -g @mariozechner/pi-ai` does not help — Node module resolution from `/var/folders/.../` doesn't traverse into `~/.bun/install/global/node_modules/`.

**Workaround**: run via the server runtime instead.
- Persisted: `appstrate api POST /api/agents/{scope}/{name}/run -d '{"input":...}'`
- Inline (no import): `appstrate api POST /api/runs/inline` — see `references/inline-runs.md`

Both load system tools correctly.

---

## `appstrate run` rejects `.afps`, only accepts `.afps-bundle`

**Symptom**: `appstrate run /path/to/file.afps` fails with `archive does not contain bundle.json`, even though the help text says `.afps / .afps-bundle file`.

**Cause**: two distinct formats with the same-ish extension.

| Format | Root | Produced by | Consumed by |
|---|---|---|---|
| `.afps` | `manifest.json` (+ `prompt.md`) | `scripts/afps-pack.sh`, `POST /api/packages/import` | API import only |
| `.afps-bundle` | `bundle.json` + `packages/<scope>/<name>/<version>/...` | `GET /api/agents/{scope}/{name}/bundle` | `appstrate run` only |

**Workaround**: after import, fetch the bundle and run that:

```bash
appstrate api GET '/api/agents/@scope/name/bundle?source=draft' -o local.afps-bundle
appstrate run local.afps-bundle --input '{}' --model-source preset --model <preset-id>
```

Or skip the round-trip entirely and use inline run.

---

## Self-hosted Tier 3: signed upload URL points to `minio:9000`

**Symptom**: `POST /api/uploads` returns a signed URL like `http://minio:9000/...`. PUT-ing to it from the host (Mac/Linux, the webapp browser, `curl`, a coding agent) fails with `Could not resolve host: minio`. Reproducible from scratch on a fresh `appstrate install --tier 3`.

**Cause**: regression in the Tier 3 installer's compose generator. The canonical `docker-compose.yml` of the OSS repo correctly maps minio's port 9000 on the host **and** references `S3_PUBLIC_ENDPOINT`. The Tier 3 installer drops both: minio publishes only its console port (9001), and `S3_PUBLIC_ENDPOINT` is never propagated to the appstrate service. So the server's two-S3-clients code (it has dedicated logic to sign URLs with a separate public endpoint) falls back to the internal Docker hostname, which is unreachable from outside the network. Cloud is unaffected because its deployment sets `S3_PUBLIC_ENDPOINT=https://storage.appstrate.com` explicitly.

**Workaround** (permanent, drop-in): create `docker-compose.override.yml` next to the install's `docker-compose.yml`. Compose auto-merges it on every `up`, and it survives Appstrate updates.

```yaml
# ~/appstrate/docker-compose.override.yml
services:
  minio:
    networks:
      - appstrate-data
      - appstrate-public  # required: appstrate-data is internal:true,
                           # so the port mapping below is silently
                           # ignored without this second network
    ports:
      - "9000:9000"
  appstrate:
    environment:
      - S3_PUBLIC_ENDPOINT=http://localhost:9000
```

Apply it:

```bash
cd ~/appstrate
docker compose -p appstrate-appstrate-<id> up -d --force-recreate minio appstrate
```

Find the project id with `docker compose ls` (or the install's stdout — it printed it after install). After the recreate, `POST /api/uploads` returns URLs pointing to `localhost:9000` and PUT from the host returns HTTP 200.

---

## Webapp file picker rejects `accept: "*/*"` literally

**Symptom**: a file field with `fileConstraints.<field>.accept = "*/*"` rejects every uploaded file in the webapp with:

```
Extension non autorisée pour "xxx.pdf" (accepté: */*)
```

The validator compares `*/*` literally instead of treating it as the standard HTML wildcard.

**Workaround**: enumerate MIMEs **and** extensions explicitly:

```json
"accept": "application/pdf,image/jpeg,image/png,.pdf,.jpg,.png"
```

Same logic for family wildcards — `image/*` is also rejected literally; expand it.
