# Profiles — Managing Multiple Appstrate Instances

## Table of Contents

- [Storage layout](#storage-layout)
- [Profile resolution order](#profile-resolution-order)
- [Creating and switching profiles](#creating-and-switching-profiles)
- [Selecting a profile per-call](#selecting-a-profile-per-call)
- [Re-pinning org or app on an existing profile](#re-pinning-org-or-app-on-an-existing-profile)
- [Inferring a profile from the user prompt](#inferring-a-profile-from-the-user-prompt)
- [Cross-profile operations](#cross-profile-operations)
- [Gotchas](#gotchas)

For users who pilot multiple Appstrate instances (production, staging, local dev, per-project), the `appstrate` CLI uses **named profiles**. The profile name is free-form (conventionally `prod`, `local`, `dev`); every command accepts `-p, --profile <name>` to target one.

## Storage layout

The CLI splits secrets from non-secrets, same split as AWS / gcloud / doctl:

```
$XDG_CONFIG_HOME/appstrate/config.toml        # non-secret: instance URL, userId, email, orgId, appId
(fallback: ~/.config/appstrate/config.toml    when XDG_CONFIG_HOME is unset)

OS keyring                                    # secret: JWT access + refresh tokens, one entry per profile
```

### `config.toml` example

```toml
defaultProfile = "prod"

[profile.prod]
instance = "https://appstrate.example.com"
userId = "usr_abc123"
email = "olivier@tractr.net"
orgId = "org_tractr"
appId = "app_default"

[profile.local]
instance = "http://localhost:3000"
userId = "usr_xyz789"
email = "olivier@tractr.net"
orgId = "org_local"
appId = "app_default"

[profile.dev]
instance = "https://dev.appstrate.internal"
userId = "usr_dev456"
email = "olivier@tractr.net"
orgId = "org_dev"
# appId omitted → --no-app was used at login, caller must pass X-App-Id explicitly
```

**Permissions**: `~/.config/appstrate/` is `chmod 700`, `config.toml` is `chmod 600`. Writes are atomic (tmp + rename) so a Ctrl-C mid-save can't leave a half-parsed file.

**Secrets**: access + refresh tokens never touch `config.toml`. They live in the OS keyring (Keychain on macOS, Secret Service / libsecret on Linux, Credential Manager on Windows).

## Profile resolution order

When the CLI needs to pick a profile, it looks in this order (first match wins):

1. **`--profile <name>` / `-p <name>` flag** — explicit on the command line
2. **`APPSTRATE_PROFILE` env var** — session-level override
3. **`defaultProfile` key in `config.toml`** — persisted default
4. **Literal `"default"`** — last-resort name

If the resolved name has no matching `[profile.<name>]` section in `config.toml`, the CLI exits 1 with a hint: `Profile "<name>" not configured. Run: appstrate login --profile <name>`.

## Creating and switching profiles

### First-time login to a new profile

```bash
appstrate login --profile prod --instance https://appstrate.example.com
appstrate login --profile local --instance http://localhost:3000
appstrate login --profile dev   --instance https://dev.appstrate.internal
```

Each login creates the `[profile.<name>]` section + stores the token pair in the keyring. On the first ever login the profile becomes the default automatically.

### Change the default

```bash
appstrate org switch <id-or-slug> --profile prod   # re-pin org on 'prod'
# (no standalone "set default profile" command yet — edit config.toml if needed)
```

To change `defaultProfile`, edit `~/.config/appstrate/config.toml` directly (it's a 1-line TOML edit), or set `APPSTRATE_PROFILE` in your shell rc file.

### Inspect profiles

```bash
appstrate whoami --profile prod                    # server identity on 'prod'
appstrate org current --profile prod               # pinned org id
appstrate app current --profile prod               # pinned app id
appstrate token --profile prod                     # token metadata (exp, refresh)

# Raw view of all profiles:
cat ~/.config/appstrate/config.toml
```

### Delete a profile

```bash
appstrate logout --profile prod
```

`logout` revokes the session server-side + wipes the keyring entry + removes the `[profile.<name>]` section from `config.toml`.

## Selecting a profile per-call

**Global flag** (the explicit path):

```bash
appstrate -p local api GET /api/agents
appstrate --profile dev whoami
```

**Env var** (session-scoped override):

```bash
export APPSTRATE_PROFILE=local
appstrate api GET /api/agents      # uses 'local' until unset
unset APPSTRATE_PROFILE
```

**Default** — when neither flag nor env var is set, the CLI uses `defaultProfile` from `config.toml`, or `"default"` if that key is missing.

## Re-pinning org or app on an existing profile

When the user switches context (e.g., they joined a new org, or want to target a different application within the same org), use the `org` / `app` subcommands instead of re-running full login:

```bash
appstrate org list                         # orgs the active profile can see
appstrate org switch <id-or-slug>          # re-pin on active profile
appstrate org create "New Org"             # creates + auto-pins

appstrate app list                         # apps in the pinned org
appstrate app switch <id>                  # re-pin on active profile
appstrate app create "Production"          # creates + auto-pins

# Scope to a specific profile with -p
appstrate -p prod app switch app_xyz
```

All `{list,current,switch,create}` subcommands respect the global `-p, --profile` flag.

## Inferring a profile from the user prompt

When the user mentions an instance by name or context, resolve to a profile:

| User says | Profile to use |
|---|---|
| "on prod", "production", "staging" | `prod` |
| "on local", "en local", "my self-hosted", "sur mon install", "localhost" | `local` |
| "on dev", "dev instance", "appstrate-dev" | `dev` |
| No mention | `defaultProfile` from `config.toml` (or `"default"`) |
| "on all my instances" | iterate every profile — see below |

If an inferred profile doesn't exist, check `cat ~/.config/appstrate/config.toml` or call `appstrate whoami --profile <name>` (exits 1 if unconfigured), then ask the user to run `appstrate login --profile <name>` or pick an existing one.

## Cross-profile operations

When the user asks to inspect or act across instances (e.g., "list agents on all my instances"), iterate the sections of `config.toml`:

```bash
# Extract profile names from the TOML — one-liner, no parser dep
profiles=$(grep -E '^\[profile\.' ~/.config/appstrate/config.toml \
  | sed -E 's/^\[profile\.([^]]+)\].*/\1/')

for name in $profiles; do
  echo "--- $name ---"
  appstrate -p "$name" api GET /api/agents -s | head -c 300
  echo
done
```

Each invocation goes through the CLI, which picks the right bearer token + org/app headers for that profile — no env leaks, no manual header juggling.

## Gotchas

1. **`APPSTRATE_PROFILE` beats `defaultProfile`** — if you export it for a quick test, remember to `unset APPSTRATE_PROFILE` after, or the override sticks across your whole session.
2. **Profile file never contains secrets** — it's safe to `cat` or commit-scan. Tokens are in the keyring, not the file. Still, keep `~/.config/appstrate/` at `chmod 700` to hide profile names + org IDs.
3. **Keyring entry orphans** — deleting `config.toml` manually leaves keyring entries behind. Use `appstrate logout --profile <name>` for a clean removal.
4. **Cross-org within one instance** — each profile pins one `orgId`. To target a different org on the same URL, either `appstrate org switch <other>` (mutates the profile) or create a second profile (e.g., `prod-tractr`, `prod-lakaz`) via `appstrate login --profile prod-lakaz`.
5. **Cross-app within one org** — same logic: `appstrate app switch <other>` mutates, or multi-profile for parallel targeting.
6. **Stale tokens after server-side revocation** — if an admin revokes your session, the CLI will hit 401 and show a re-login hint. Run `appstrate login --profile <name>` to refresh.
7. **`--no-org` / `--no-app` at login time** — skips pinning entirely. Every subsequent `appstrate api` call in that profile must pass the header manually: `appstrate -p dev api GET /api/agents -H 'X-Org-Id: …' -H 'X-App-Id: …'`. Usually only useful for multi-tenant admin tooling that switches context per-call.
