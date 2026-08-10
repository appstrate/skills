# Appstrate Setup Guide (edge cases)

> **When to use this file.** The default setup path is documented directly in `SKILL.md`: the user runs `bunx appstrate install` (or `curl … | bash`) + `appstrate login` in their own terminal, and the agent verifies with `appstrate whoami`. **Only consult this reference when:**
>
> - The user explicitly delegates install to the agent (headless VM, CI runner, throwaway sandbox) AND accepts the Docker-aware default risk;
> - You need the non-interactive flags (`-t N --yes`, `--port`, `--dir`) or the env vars (`APPSTRATE_NO_LAUNCH`, `APPSTRATE_VERSION`, `APPSTRATE_BIN_DIR`);
> - The CLI isn't available at all and the caller has to fall back to API-key + raw curl.
>
> For the happy path (human at a terminal, picks Tier 0 interactively), go back to `SKILL.md` § Setup.

## Table of Contents

- [Primary path: CLI](#primary-path-cli)
  - [Step 1: Install Appstrate](#step-1-install-appstrate)
  - [Step 2: Sign in](#step-2-sign-in)
  - [Step 3: Verify](#step-3-verify)
  - [Step 4 (multi-instance): named profiles](#step-4-multi-instance-named-profiles)
- [Fallback: API key for non-CLI environments](#fallback-api-key-for-non-cli-environments)

The fastest path is the `appstrate` CLI. It handles install, device-flow login (RFC 8628), token storage in the OS keyring, and org+app pinning so every downstream call just works.

## Primary path: CLI

### Step 1: Install Appstrate

Tiers:
| Tier | Runtime | Services | Storage | When |
|---|---|---|---|---|
| 0 | Bun | None (PGlite in-process) | Filesystem | Dev/hobby, zero-Docker |
| 1 | Docker | PostgreSQL | Filesystem | Small prod |
| 2 | Docker | PostgreSQL + Redis | Filesystem | Standard prod |
| 3 | Docker | PostgreSQL + Redis + MinIO | S3 | Full prod |

> ⚠️ **Tier default is context-dependent.** Interactive `appstrate install` defaults to **Tier 0**. Non-interactive paths (`--yes` alone, `curl … \| bash` piped into a non-TTY) use **Docker-aware defaults**: Tier 3 if `docker` is on PATH and the daemon responds, otherwise Tier 0. Coding agents run in the non-interactive bucket. Always pin the tier explicitly with `-t N --yes`.

Pick one of four install paths:

**A. `bunx appstrate install` (cleanest path for coding agents, requires Bun on PATH)** — no binary download, no minisign, tier explicit in one command:

```bash
bunx appstrate install -t 0 --yes
bunx appstrate install -t 3 --port 8080 --yes
```

Install Bun first if needed: `curl -fsSL https://bun.sh/install | bash`.

**B. One-liner with forwarded install flags** — single invocation, tier explicit:

```bash
curl -fsSL https://get.appstrate.dev | bash -s -- --tier 0 --yes
curl -fsSL https://get.appstrate.dev | bash -s -- --tier 3 --port 8080 --yes
```

Anything after `-s --` is passed verbatim to the embedded `appstrate install`.

**C. Two-step install (CLI first, then instance)** — use when you want the CLI binary on disk before deciding on tier:

```bash
APPSTRATE_NO_LAUNCH=1 curl -fsSL https://get.appstrate.dev | bash
# CLI is at ~/.local/bin/appstrate. Make sure it is on PATH, then:
appstrate install -t 0 --yes
```

**D. Interactive one-liner (for humans at a terminal, NOT for coding agents)**:

```bash
curl -fsSL https://get.appstrate.dev | bash
```

Prompts for tier (defaults to Tier 0), then runs through install. Prompts are swallowed in non-TTY contexts, which is why paths A/B/C exist.

**One-liner env var overrides** (apply to paths B, C, D):
- `APPSTRATE_VERSION=v1.2.3` — pin a release (default: latest pinned)
- `APPSTRATE_BIN_DIR=/usr/local/bin` — install location (default: `$HOME/.local/bin`)
- `APPSTRATE_NO_LAUNCH=1` — download CLI only, skip the embedded `appstrate install` (path C)
- `APPSTRATE_NO_MODIFY_PATH=1` — don't touch shell rc files
- `APPSTRATE_SKIP_VERIFY=1` — skip minisign + checksum verification (requires `CI=true`, not recommended)

**`appstrate install` flags** (apply to paths A, B, C):
- `-t, --tier <0|1|2|3>` — tier; REQUIRED for coding agents (see warning above)
- `-y, --yes` — skip all prompts, auto-pick free ports (3001, 3002, …), auto-start dev server; equivalent to `APPSTRATE_YES=1`
- `-d, --dir <path>` — install directory (default: `~/appstrate`)
- `--port <n>` — primary HTTP port (default: 3000 with auto-bump on conflict when `--yes`)
- `--minio-console-port <n>` — MinIO console port (Tier 3 only)
- `--force` — overwrite existing install dir

> **Prereq for paths B, C, D: `minisign`**. The installer verifies the CLI binary against a minisign signature before executing it, so `minisign` must be on `PATH`:
> - macOS: `brew install minisign`
> - Debian/Ubuntu: `sudo apt install minisign`
> - Alpine: `apk add minisign`
> - Other: https://jedisct1.github.io/minisign/
>
> Path A (`bunx appstrate install`) does not need minisign — it runs the CLI from the published npm package and skips the binary download.
>
> To bypass verification in a throwaway CI debug shell (not recommended), prefix with `APPSTRATE_SKIP_VERIFY=1` and set `CI=true`.

Re-run any install path to upgrade — existing secrets are preserved.

For supply-chain verification (SLSA provenance via `gh attestation verify` or offline minisign signatures), see `examples/self-hosting/README.md` in the `appstrate/appstrate` repo.

### Step 2: Sign in

```bash
appstrate login
```

The CLI will:
1. Prompt for the instance URL (e.g. `http://localhost:3000` for local dev, or your production hostname).
2. Open the browser to the device verification URL + print the user code.
3. After you approve, store the JWT access + refresh pair in the OS keyring.
4. Auto-pin an organization on the profile:
   - One org → auto-picked.
   - Multiple orgs → interactive picker.
   - Zero orgs → offers inline creation.
5. Cascade: auto-pin the default application (server provisions one per org).

Non-interactive forms (CI / scripts / onboarding flows):

```bash
appstrate login --instance https://appstrate.example.com \
  --org my-org --app default

appstrate login --instance http://localhost:3000 \
  --create-org "My New Org" --create-app "Production"

appstrate login --no-org --no-app    # skip pinning, use explicit headers later
```

### Step 3: Verify

```bash
appstrate whoami                       # server-authoritative identity
appstrate org current                  # pinned org id (exit 1 if none)
appstrate app current                  # pinned app id (exit 1 if none)
appstrate api GET /api/agents          # first API call through the CLI
```

That's it. Every subsequent `appstrate api …` call auto-injects the bearer token + `X-Org-Id` + `X-App-Id`.

### Step 4 (multi-instance): named profiles

If you pilot several instances (prod + staging + dev), create one profile per instance. The profile name is anything you like (conventionally `prod`, `local`, `dev`):

```bash
appstrate login --profile prod  --instance https://appstrate.example.com
appstrate login --profile local --instance http://localhost:3000
appstrate login --profile dev   --instance https://dev.appstrate.internal
```

Pick the active profile per-call with `-p, --profile`, via the `APPSTRATE_PROFILE` env var, or set one as default in `config.toml`. Full guide: `references/profiles.md`.

### Step 5: Connect an LLM model

Agent runs fail at dispatch if the org has no LLM model connected. Two paths:

- **UI (simplest)**: webapp → **Settings → Models → Add a model**. Pick the model provider, paste the credential, save.
- **API (scriptable)**: there is **no** `/api/provider-keys` endpoint. Add a model credential, then register the model:

  ```bash
  # 1. Store a provider credential (api_key providers only; OAuth uses the pairing flow).
  #    Returns a credential with an `id`. Discover providerIds via GET /api/model-provider-credentials/registry.
  appstrate api POST /api/model-provider-credentials \
    -H 'Content-Type: application/json' \
    -d '{ "providerId": "anthropic", "apiKey": "sk-ant-..." }'

  # 2. Register a model against that credential id (NOT providerId — the apiShape/baseUrl
  #    are resolved from the credential).
  appstrate api POST /api/models \
    -H 'Content-Type: application/json' \
    -d '{ "modelId": "claude-sonnet-4-20250514", "credentialId": "<id-from-step-1>" }'
  ```

  These endpoints use camelCase carve-outs (`providerId`, `modelId`, `credentialId`, `displayName`). The validator has a gotcha around the `cost` object — see `references/known-issues.md`.

---

## Fallback: API key for non-CLI environments

When the CLI can't run (restricted CI image, third-party container, legacy bash script), use an API key with raw curl. A key is pinned to a single org + application, so **you do not need `X-Org-Id` or `X-App-Id` headers** — the `Authorization: Bearer ask_...` header is sufficient.

- **Authoritative reference**: [appstrate.com/docs/api/authentication](https://appstrate.com/docs/api/authentication) — prefix, scope matrix, SSE query-param, impersonation, errors.
- **Live OpenAPI for your instance**: `$APPSTRATE_URL/api/docs` (Swagger UI) or `appstrate openapi list` / `appstrate openapi export`.
- **Create the first key from the UI**: webapp → **Paramètres de l'organisation** → **Application** section → **Clés API** → **Nouvelle clé API**. The raw key is shown once, copy it immediately. Subsequent keys can be created via `POST /api/api-keys`.
