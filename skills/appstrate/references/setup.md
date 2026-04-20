# Appstrate Setup Guide

The fastest path is the `appstrate` CLI. It handles install, device-flow login (RFC 8628), token storage in the OS keyring, and org+app pinning so every downstream call just works.

## Primary path: CLI

### Step 1: Install Appstrate

Pick one of:

**A. Cloud (no install needed)** — use [app.appstrate.com](https://app.appstrate.com) directly. Skip to Step 2.

**B. Self-host via the one-liner installer** — any host with Docker 20+ and Compose V2:

```bash
curl -fsSL https://get.appstrate.dev | bash
```

The installer generates secrets, picks a free port, downloads images, starts the stack, waits for health. Re-run to upgrade — existing secrets are preserved. Overrides: `APPSTRATE_VERSION=v1.2.3`, `APPSTRATE_DIR=~/.appstrate`, `APPSTRATE_PORT=8080`.

**C. `appstrate install` (after installing the CLI binary)** — same result as the one-liner, but you control the flags:

```bash
appstrate install                      # interactive tier prompt (0/1/2/3)
appstrate install -t 0                 # Tier 0 = hobby / Bun, zero-Docker
appstrate install -t 3 --port 8080     # Tier 3 = full stack (Postgres+Redis+MinIO)
appstrate install --yes                # skip all prompts, smart defaults (CI-friendly)
appstrate install -t 0 --yes           # Tier 0, non-interactive, auto-pick free port
```

Tiers:
| Tier | Stack | When |
|---|---|---|
| 0 | PGlite + filesystem + in-memory | Dev/hobby, no Docker |
| 1 | PostgreSQL | Small prod |
| 2 | PostgreSQL + Redis | Standard prod |
| 3 | PostgreSQL + Redis + MinIO | Full prod (S3-style storage) |

> **Rule for coding agents: always pass `--yes` in non-interactive contexts** (your Bash tool, CI, Dockerfile `RUN`, cloud-init). `--tier N` alone only skips the tier prompt — it still errors out with "port 3000 in use" if another process (typically the user's dev server or a previous install) is holding the port. `--yes` additionally enables auto-pick of the next free port (3001, 3002, …), Docker-aware tier defaults, and auto-start of the dev server. Combine them as `--tier N --yes` when you already know which tier the user wants, or just `--yes` when you can trust the Docker-aware default (Tier 3 if Docker is running, else Tier 0).

Non-interactive flags for automation: `-y, --yes` (equivalent to `APPSTRATE_YES=1`), `-d, --dir`, `--port`, `--minio-console-port`, `--force`.

For supply-chain verification (SLSA provenance via `gh attestation verify` or offline minisign signatures), see `examples/self-hosting/README.md` in the `appstrate/appstrate` repo.

### Step 2: Sign in

```bash
appstrate login
```

The CLI will:
1. Prompt for the instance URL (cloud or your self-hosted URL, e.g. `http://localhost:3000`).
2. Open the browser to the device verification URL + print the user code.
3. After you approve, store the JWT access + refresh pair in the OS keyring.
4. Auto-pin an organization on the profile:
   - One org → auto-picked.
   - Multiple orgs → interactive picker.
   - Zero orgs → offers inline creation.
5. Cascade: auto-pin the default application (server provisions one per org).

Non-interactive forms (CI / scripts / onboarding flows):

```bash
appstrate login --instance https://app.appstrate.com \
  --org tractr --app default

appstrate login --instance https://app.appstrate.com \
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

If you pilot several instances (cloud + self-hosted + dev), create one profile per instance. The profile name is anything you like (conventionally `cloud`, `local`, `dev`):

```bash
appstrate login --profile cloud --instance https://app.appstrate.com
appstrate login --profile local --instance http://localhost:3000
appstrate login --profile dev   --instance https://dev.appstrate.internal
```

Pick the active profile per-call with `-p, --profile`, via the `APPSTRATE_PROFILE` env var, or set one as default in `config.toml`. Full guide: `references/profiles.md`.

---

## Fallback: API key for non-CLI environments

When the CLI can't run (restricted CI image, third-party Docker container, legacy bash scripts), fall back to an API key + raw curl. Three env vars:

```bash
APPSTRATE_URL=https://app.appstrate.com
APPSTRATE_API_KEY=ask_your_key_here
APPSTRATE_ORG_ID=your-org-id-here
APPSTRATE_APP_ID=your-app-id-here      # required on app-scoped routes
```

### Create the API key

1. Go to your instance UI (`app.appstrate.com` or your self-hosted URL) and sign in
2. In the left sidebar, scroll to the **Application** section (bottom)
3. Click **Cles API**
4. Click the blue **Nouvelle cle API** button (top right)
5. Fill the form:
   - **Nom**: a label (e.g., `CI — deploy bot`)
   - **Expire dans**: expiration delay (default 90 days)
   - **Permissions**: `Tous les scopes` for full access, or narrow per-resource
6. Click **Nouvelle cle API**
7. **Copy the key immediately** — it starts with `ask_` and is shown only once

### Get your Org ID and App ID

```bash
curl -s "$APPSTRATE_URL/api/orgs" \
  -H "Authorization: Bearer $APPSTRATE_API_KEY"
# → copy the `id` of the org you want

curl -s "$APPSTRATE_URL/api/applications" \
  -H "Authorization: Bearer $APPSTRATE_API_KEY" \
  -H "X-Org-Id: $APPSTRATE_ORG_ID"
# → copy the `id` of the app you want (usually the default one)
```

### Verify

```bash
curl -s "$APPSTRATE_URL/api/agents" \
  -H "Authorization: Bearer $APPSTRATE_API_KEY" \
  -H "X-Org-Id: $APPSTRATE_ORG_ID" \
  -H "X-App-Id: $APPSTRATE_APP_ID" | head -c 200
```

### Storage

- `.env` file in your project (works with any tool; **never commit this file**)
- Shell profile env vars (`~/.zshrc`, `~/.bashrc`)
- CI secret store (GitHub Actions secrets, GitLab CI variables, etc.)

### Migration path: API key → CLI

If a machine already has API-key env vars set and you want to adopt the CLI later, `appstrate login` happily coexists. The CLI always prefers its own keyring over the env vars — you can unset `APPSTRATE_URL` / `APPSTRATE_API_KEY` / `APPSTRATE_ORG_ID` / `APPSTRATE_APP_ID` once the CLI profile is configured.
