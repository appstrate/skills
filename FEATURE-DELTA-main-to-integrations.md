# Cartographie fonctionnelle vérifiée — `main` → `feat/integrations`

> Source de vérité pour la réécriture du skill `appstrate`.
> Établie le 2026-05-29 par audit de 5 sous-agents sur le code de la branche (`appstrate/appstrate@feat/integrations`, HEAD `323f25d5`) comparé à `origin/main` (`33709d3f`). Chaque point est vérifié par diff réel, pas par notes de commit.
> Périmètre : **surface externe uniquement** (CLI `appstrate`, API REST, manifestes AFPS, paradigme de prompt). Cible plateforme : `@afps-spec/schema@^0.4.0` (AFPS 0.x, MAJOR borné à 0).

## 0. Le pivot conceptuel (à retenir avant tout)

`feat/integrations` migre la plateforme vers **AFPS 2.0/0.x** (reset de versioning). Trois bascules structurelles :

1. **Types de packages** : `tool` → **`mcp-server`**, `provider` → **`integration`**. Les types `tool`/`provider` et les clés `dependencies.tools`/`dependencies.providers` sont **rejetés à la publication** (`LegacyDepKeyError`).
2. **Connexions agent-driven** : le modèle « un provider = une connexion + `provider_call` global » est remplacé par des **intégrations** multi-auth, avec scopes OAuth **inférés par agent** depuis sa sélection d'outils, injection credential déclarative sidecar-side, et une **cascade de résolution à 7 mécanismes** au lancement du run.
3. **Tout passe par des outils** : le prompt ne liste plus les outils (c'est `tools/list` MCP qui fait foi) ; **tout texte libre hors appel d'outil est jeté** ; `provider_call` global → outils **namespacés par intégration** `{ns}__api_call` / `{ns}__{tool}`. Les system tools (`output/log/note/pin/report`) deviennent des **`runtime_tools`** opt-in hébergés en MCP.

Plus : casing **snake_case** sur tout le manifeste/wire (avec carve-outs camelCase), nouvelle syntaxe de substitution credential **`{$credential.<field>}`**.

## 1. Vue d'ensemble — vrais deltas vs faux deltas

| Domaine | Verdict | Note |
|---|---|---|
| Types packages tool/provider → mcp-server/integration | **VRAI** | enum + rejet legacy deps |
| `dependencies.{tools,providers}` → `{mcp_servers,integrations}` + `integrations_configuration` | **VRAI** | maps plates |
| `runtime_tools` remplace `@appstrate/output` & co | **VRAI** | opt-in, output requis si output.schema |
| Casing manifeste/wire → snake_case | **VRAI** | + carve-outs camelCase |
| `provider_call` → `{ns}__api_call` / `{ns}__{tool}` / `{ns}__api_upload` | **VRAI** | pas d'alias |
| Paradigme prompt (Communication, pas de liste d'outils, INTEGRATION.md) | **VRAI** | réécriture prompt-writing |
| Modèle Integrations (source none/local/remote, auths, delivery, scopes) | **VRAI** | nouveau de bout en bout |
| Routes `/api/providers,/connections,/connection-profiles,/app-profiles` → `/api/integrations/*` + `/api/me/*` | **VRAI** | suppressions + unification |
| Run kickoff `providerProfiles` → `connection_overrides` + 412 | **VRAI** | inline NON concerné |
| Schedule body → snake_case + actor + `connection_overrides` (readiness supprimé) | **VRAI** | |
| CLI `--providers` → `--integrations` ; groupe `connections` supprimé | **VRAI** | |
| AFPS `@^0.4.0`, `$schema` = `schemas.afps.dev/v0/<type>.schema.json` | **VRAI** | |
| INLINE_RUN_LIMITS : `max_tools`/`max_authorized_uris`/`wildcard_uri_allowed` supprimés | **VRAI** | pas de rename, pas d'ajout |
| substitution `{{x}}` → `{$credential.x}` (manifeste delivery) | **VRAI** | `substituteBody`+`{{}}` survit comme arg de `api_call` |
| oauth1 supprimé ; mtls ajouté | **VRAI** | |
| DB timestamptz + squash migrations + colonnes runs/schedules | **VRAI** | effet wire = offsets TZ + casing |
| Model providers (`/api/model-provider-credentials`, `/models`, `core-providers`, modules codex/claude-code) | **FAUX** | déjà dans main |
| Enveloppe liste `{object, data, hasMore}` (`hasMore` camelCase) | **FAUX** | déjà dans main |
| Persistence (`/persistence`, package_persistence, recall_memory, run_history) | **FAUX** (sauf casing `actor_type/actor_id`) | déjà dans main |
| Uploads `/api/uploads` + `S3_PUBLIC_ENDPOINT` | **FAUX** | inchangé |
| Run lifecycle (statuts, 202, pas de mode sync) | **FAUX** | inchangé |
| Cost tracking (`runs.cost`) | **FAUX** | nouveau doc seulement |
| `x-outputRetries`, `flow.schema.json`, `/api/provider-keys` | **FAUX / inexistants** | déjà retirés avant la branche |

## 2. AFPS, manifestes, types, casing

- **AFPS** : `@afps-spec/schema@^0.4.0` (était `^1.5.0`). `schema_version` format `MAJOR.MINOR`, MAJOR=0 (ex `"0.1"`) ; MAJOR>0 rejeté. `$schema` = `https://schemas.afps.dev/v0/<type>.schema.json` (`agent`/`skill`/`mcp-server`/`integration`). **`flow.schema.json` n'existe plus** (renommé `agent` avant la branche → faux-delta).
- **Types** : enum `["agent","skill","integration","mcp-server"]` (`packages/db/src/schema/enums.ts`, `packages/core/src/validation.ts`). Rejet legacy : `assertNoLegacyDepKeys` / `LegacyDepKeyError` (`packages/core/src/dependencies.ts`).
- **Manifeste AGENT** (snake_case) : `name, version, type, schema_version, display_name, description, long_description, keywords, license, author, …, dependencies.{skills,mcp_servers,integrations}, integrations_configuration, runtime_tools, input, config, output, timeout, _meta`. `x-outputRetries` **supprimé** (faux-delta).
  - `integrations_configuration.<@scope/name> = { tools?: string[]|"*", scopes?: string[], auth_key? }` ; chaque clé doit matcher une dep `integrations` (sinon rejet `refineIntegrationsConfiguration`).
  - `runtime_tools?: string[]` enum `["output","log","note","pin","report"]`. **superRefine** : si `output.schema` non vide ⇒ `runtime_tools` doit inclure `"output"`.
- **Manifeste MCP-SERVER** (nouveau, vocabulaire MCPB) : `type:"mcp-server"`, `server.{type ∈ node|python|binary|uv, entry_point, mcp_config{command,args,env,platform_overrides}}, tools[], user_config`. Override Bun : `_meta["dev.appstrate/mcp-server"].runtime:"bun"`. Opt-in workspace : `_meta["dev.appstrate/workspace"].{mount,access}`. Source : `packages/core/src/mcp-server.ts`.
- **Manifeste INTEGRATION** (nouveau) : voir §3.
- **Wrappers input/config/output** : `{ schema, file_constraints{accept,max_size}, ui_hints{placeholder}, property_order }` (snake_case). Lecteur **snake_case-only** (fallback camelCase 1.x supprimé). Fichiers : `{type:"string", format:"uri", contentMediaType}`, jamais `type:"file"`. Source : `packages/core/src/form.ts`.
- **Casing** : règle = wire/JSON/manifeste/OpenAPI/SQL → snake_case ; TS interne → camelCase. **Carve-outs camelCase** (autorité `docs/CASING_CONVENTIONS.md`, nouveau, 528 l.) : tables Better Auth ; champs DB universels (`id`, `*Id`, `createdAt/updatedAt/expiresAt/runNumber`…) ; DTO model-providers (`providerId`, `displayName`, `apiShape`) ; DTO headless (`keyPrefix`, `externalId`, `isDefault`, `hasMore`, `payloadMode`, `eventType`, `statusCode`) ; endpoints model/proxy standalone (`modelId`, `proxyId`, `credentialId`) ; widget RJSF (`ui:*`, `maxSize`/`maxFiles` côté widget) ; `runs.token_usage` (`input_tokens`… convention SDK) ; payloads SSE/CloudEvents/webhooks/BullMQ/logger. ⚠️ timestamps **domaine** flippent en snake_case (`started_at`, `completed_at`, `last_run_at`, `next_run_at`, `connected_at`) — distincts des timestamps DB universels.

## 3. Integrations — runtime, connexions, credentials, scopes

- **62 intégrations système** dans `scripts/system-packages/integration-*/` : 59 `none`, 1 `local` (`github-git`), 3 `remote` (`clickup-mcp`, `github-mcp`, `gmail-mcp@2.0.0`).
- **`source.kind`** :
  - `none` : pas de serveur MCP ; atteint l'upstream via la capacité `api_call` (vendor `_meta`). Cas par défaut (REST direct).
  - `local` : `source.server.{name,version,vendored?}` → réfère un package `mcp-server` ; un runner conteneur par intégration (cap-drop ALL, réseau isolé). Pour shell-out / filesystem / frontière MITM réelle.
  - `remote` : `source.remote.{url, transport: "streamable-http"|"sse"}` ; client MCP HTTP, injection `Authorization` via wrapper fetch (retry 1× sur 401). Pour MCP hébergé de confiance.
  - ⚠️ `source.kind:"api"` **supprimé** → devenu `none` + capacité `_meta["dev.appstrate/api"]`.
- **`auths.{key}`** : types `oauth2 | api_key | basic | mtls | custom`. **`oauth1` supprimé** (#507). `mtls` **nouveau**. Champs : `type, authorized_uris, allow_all_uris, default_scopes, scope_catalog[].{value,label,implies?}, credentials.schema, delivery, connect, …(OAuth: token_endpoint, authorization_endpoint, …)`.
- **`delivery`** (≥1 canal, `http` exclusif de `env`/`files`) :
  - `delivery.http { in, name, prefix?, value, encoding?, allow_server_override? }`. **Gate install** : seul `in:"header"` est implémenté. `value` = template `{$credential.<field>}` / `{$outputs.<name>}`. `encoding:"base64"` appliqué après expansion, avant prefix (recette git : `prefix:"Basic ", value:"x-access-token:{$credential.access_token}", encoding:"base64"`). `allow_server_override` (défaut false) strip un header homonyme posé par le serveur.
  - `delivery.env` : pour `source.kind:local` (credential dans l'env du runner).
  - `delivery.files` : pour cert/clé (mtls **doit** utiliser files — `mtls`+`http` rejeté à l'install).
- **Substitution** : grammaire Arazzo `{$credential.<field>}` (regex `/\{\$credential\.([A-Za-z0-9_]+)\}/g`). ⚠️ **PAS** la forme 1.x `{{field}}`. (Distinct de l'argument `substituteBody`+`{{}}` de l'outil `api_call`, voir §5.)
- **ConnectStrategy** (#487) — sélection auto depuis le manifeste : `oauth2` → OAuth2+PKCE ; `api_key/basic/mtls/custom` nu → Fields ; `custom`+`connect.login` → Login (1 requête HTTP déclarative) ; `custom`+`connect.tool` (`run_at:run-start`) → LoginSecret ; (`run_at:link`) → Orchestrated. `connect.steps` renommé **`connect.login`** (singulier, #58061c89). Gating §7.7 : un `delivery.value` ne peut référencer que des `connect.outputs` déclarés.
- **Scopes niveau 2** : `scope_catalog[].{value,label,implies?}`, `default_scopes`, `authorized_uris`/`allow_all_uris` (**seule** frontière URL). `tools_policy.{tool}.required_scopes.{auth_key}` = map **par-auth** (AFPS 0.4). **Supprimés** : `url_patterns`, `scope_auth_key`. Scopes **inférés par agent** : `∪(required_scopes des tools sélectionnés)`. Principe « **connection picker offers every auth ; no single-auth gate** » : toute auth déclarée peut servir tout tool.
- **api_call vendor** (#345f0ca2) : capacité additive via `_meta["dev.appstrate/api"].auths.{key}.{upload_protocols?}`, orthogonale à `source.kind`. 1 auth → `api_call` ; multi → `api_call__{authKey}` ; `api_upload` si `upload_protocols`.
- **Connexions multi-auth par acteur** : N connexions simultanées (OAuth + PAT coexistent). Cycle : connect/revoke ; **410** sur revoked ; refresh révoqué → `needsReconnection`. Validation des credentials contre `credentials.schema` (#504) ; `$ref` fragment-only (SSRF guard).
- **Docs rattachées** : `docs/architecture/INTEGRATIONS_RUNTIME.md`, `docs/guides/writing-an-integration-with-connect.md` (660 l.), `docs/adr/ADR-015-afps-2.0-sidecar-mcp-surface.md`.

## 4. Routes API & CLI

- **Fichiers OpenAPI supprimés** : `providers.ts`, `connections.ts`, `connection-profiles.ts`, `app-profiles.ts`. **Ajouté** : `integrations.ts` (21 opérations / 14 chemins). `model-provider-credentials.ts` + `models.ts` **identiques à main** ; `model-providers-oauth.ts` quasi-identique (retrait de l'alias déprécié `POST /api/model-providers-oauth/import`).
- **`/api/integrations/*`** (app-scoped) : `GET /api/integrations`, `GET /callback`, `GET /{packageId}`, `POST /{packageId}/activate`, `DELETE /{packageId}/deactivate`, `GET|PUT|DELETE /{packageId}/oauth-clients/{authKey}`, `POST /{packageId}/auths/{authKey}/connect/fields`, `POST /{packageId}/auths/{authKey}/connect/oauth2`, `GET /{packageId}/connections`, `PATCH /{packageId}/connections/{connectionId}`, `GET /{packageId}/agent-resolution/{agentPackageId}`, `PATCH /{packageId}/settings`, `GET|PUT|DELETE /{packageId}/pins[/{agentPackageId}]`, `GET /{packageId}/consuming-agents`, `GET|PUT|DELETE /{packageId}/default`. ⚠️ Pas de route `required-scopes` (c'est un champ de schéma).
- **`/api/me/*`** : `GET /api/me/connections`, `DELETE /api/me/connections/{connectionId}`, `GET|PUT|DELETE /api/me/integration-pins`. (`/api/me/application-profile` supprimé.)
- **Listing packages** : seuls `GET /api/packages/agents` et `/api/packages/skills` existent. ⚠️ **Pas** de `/api/packages/mcp-servers` ni `/integrations` ni `/tools` ni `/providers` (tools+providers listing supprimés). La sélection d'intégrations/outils d'un agent vit dans le **manifeste** (`integrations_configuration`), résolue via `/api/integrations/.../agent-resolution/{agentPackageId}` + pins.
- **Attache agent** : `PUT .../skills`, `.../config`, `.../model`, `.../proxy` conservés. **Supprimés** : `PUT .../tools`, `.../app-profile`, `.../provider-profiles`, `.../readiness`.
- **`/api/provider-keys`** : n'existe ni sur main ni sur la branche (faux-delta — SKILL.md L55 déjà faux ; utiliser `/api/model-provider-credentials` + `/api/models`).
- **CLI** : `appstrate run --providers` → **`--integrations <remote|local|none>`** (défaut remote). Flags `run` supprimés : `--connection-profile/--cp`, `--provider-profile`, `--no-preflight`, `--preflight-timeout`. **Groupe `appstrate connections …` entièrement supprimé** (`connections list`, `connections profile {list,current,switch,create}`). Aucune commande ajoutée. Surface conservée : `install/start/stop/restart/logs/status/uninstall`, `login/logout/whoami/token`, `org {list,current,switch,create}`, `app {…}`, `models list`, `api <target>`, `openapi`, `run`, `doctor`, `self-update`.

## 5. Runtime tools, surface MCP sidecar, paradigme prompt

- **5 runtime_tools** (MCP, `packages/core/src/runtime-tool-defs.ts`) :
  - `output({ data })` — requis si `output.schema` ; valide AJV.
  - `log({ level: info|warn|error, message })`.
  - `note({ content (≤2000), scope?: actor|shared })` — archive (lue via `recall_memory`).
  - `pin({ key (^[a-z0-9_]+$, ≤64), content, scope? })` — slot épinglé ; `"checkpoint"` = carry-over.
  - `report({ content })` — description « MANDATORY — call at least once before finishing » (mandatory-si-chargé, pas d'install-gate).
  - Opt-in via `manifest.runtime_tools` ; rien injecté par défaut.
- **Surface MCP agent-facing** :
  - First-party : `run_history({ limit?, fields? })`, `recall_memory({ q?, limit? })` (l'arg réel est **`q`**, la doc dit `query`).
  - Par intégration : **`{ns}__api_call`** (remplace `provider_call`, pas d'alias) — args `{ target (uri, requis), method?, headers?, body (string|fromBytes|multipart|fromFile), responseMode?{toFile,maxInlineBytes}, substituteBody? }`. L'intégration+auth sont **implicites dans le nom** (pas de `providerId`). `{ns}__api_upload` (si `upload_protocols`, exécuté agent-side). `{ns}__{tool}` (outils du serveur MCP, gated par allowlist).
  - Enveloppe résultat `_meta["dev.appstrate/upstream"] = { status, headers (allowlist), finalUrl? }` (`status:0` = préflight).
  - ⚠️ `substituteBody:true` + `{{x}}` survit comme **argument de `api_call`** (substitution du body côté sidecar) — distinct de `{$credential.x}` (manifeste). Les deux couches coexistent.
- **Paradigme prompt** (`renderPlatformPrompt`) :
  - Section **`### Communication`** : tout texte libre hors appel d'outil **n'est jamais délivré** ; router toute communication (résultat, statut, question, erreur) via un appel d'outil.
  - **Plus de liste d'outils dans le prompt** (`### Tools`/`toolDocs` supprimés) : `tools/list` MCP fait foi ; chaque outil est auto-documenté par sa `description`/`inputSchema`. → **Ne jamais lister les outils ni écrire de prose d'usage d'outil dans un prompt d'agent.**
  - `## Connected Providers` → **`## Integration: {id}`** + `### API Documentation` (inline `INTEGRATION.md`, AFPS §3.5).
  - Sections **data-only** conservées : `## Checkpoint`, `## Pinned Slots`, `## Memory` (mémoires épinglées seulement ; l'archive se lit via `recall_memory`). `## User Input`, `## Documents`, `## Configuration`, `### Skills`, `## Output Format` conservées.
- **Large responses** : seuil réel **32 KB** (corriger l'ancienne prose 64 KB) ; `resource_link` URI `appstrate://api-response/{runId}/{ulid}` ; `ctx.readResource(uri)` (4e arg `execute`) ; `responseMode.toFile` / `maxInlineBytes` ; spill auto en fichier workspace (`resources/…`).
- **Workspace + MCP Roots** (#525) : `_meta["dev.appstrate/workspace"].{mount,access:ro|rw}` sur un `mcp-server` ; le sidecar est provider MCP Roots. UID 1001 invariant.

## 6. Runs, schedules, persistence, uploads, DB

- **Lifecycle** : inchangé (`pending→running→success|failed|timeout|cancelled`, 202 fire-and-forget, pas de mode sync).
- **Inline runs** : `providerProfiles` **supprimé** (body inline + `/validate` + remote + registry). **Pas** de `connection_overrides` sur l'inline (s'appuie sur la cascade fallback/pins). INLINE_RUN_LIMITS : `rate_per_min, manifest_bytes, prompt_bytes, max_skills, retention_days` conservés ; `max_tools`, `max_authorized_uris`, `wildcard_uri_allowed` **supprimés** (pas de rename/ajout). PLATFORM_RUN_LIMITS inchangé.
- **Run kickoff persisté** (`POST /api/agents/{scope}/{name}/run`) : accepte **`connection_overrides`** = `{ "@scope/integration": "<connection_id>" }` (flat). Persisté `runs.connection_overrides` (exposé wire), snapshot `runs.resolved_connections` (**jamais exposé wire**). **412 `missing_integration_connection`** si la connexion choisie est inaccessible.
- **Cascade de résolution (7 mécanismes)** : 1) pin admin (`integration_pins` user_id=NULL) → 2) org default enforce → 3) run override (`runs.connection_overrides`) → 4) schedule override → 5) pin member → 6) org default soft → 7) fallback (connexions accessibles : 1=auto, 0=not_connected, N=must_choose). (`ConnectionResolutionSource` a 7 valeurs.)
- **Schedules** : body **snake_case** (`cron_expression`, `config_override`, `model_id_override`, `proxy_id_override`, `version_override`, `connection_overrides`, `name`, `timezone`, `input`). **`connectionProfileId` supprimé** → acteur (`user_id`/`end_user_id`). Réponse : `actor_name`/`actor_type` (plus de `profileName`/`readiness`). `connection_overrides` frozen au create.
- **Persistence** : faux-delta sauf **casing** des query/réponse `actor_type`/`actor_id` (était `actorType`/`actorId`). Routes `/persistence?kind=pinned|memory`, permissions, `recall_memory`/`run_history`, `note`/`pin` inchangés.
- **Uploads** : `/api/uploads` (reserve→PUT→`upload://`) + `S3_PUBLIC_ENDPOINT` **inchangés**. (La capacité integration `{ns}__api_upload` est distincte du flow REST.)
- **DB** : timestamptz global (réponses ISO avec offset TZ), squash migrations (`0000_init.sql`), colonnes runs `connection_overrides`/`resolved_connections` (remplacent `connection_profile_id`/`provider_profile_ids`/`provider_statuses`), `credential_proxy_usage.provider_id` → `integration_id`.
- **Cost** : `runs.cost` inchangé (nouveau doc `RUN_COST.md` seulement).

## 7. Divergences inter-agents réconciliées

1. **Cascade de résolution = 7 mécanismes** (un agent disait 5). Tranché : `ConnectionResolutionSource` a 7 valeurs (incl. les 2 `org_default` enforce/soft).
2. **`api_upload`** : existe comme capacité MCP integration `{ns}__api_upload` (côté sidecar, si `upload_protocols`), distinct du flow REST `/api/uploads` (inchangé). Les deux coexistent.
3. **`recall_memory`** : arg réel = **`q`** (la doc SIDECAR.md dit `query`).
4. **Seuil large response = 32 KB** réel (l'ancienne prose disait 64 KB).
5. **substitution** : `{$credential.x}` (manifeste delivery, serveur-side) ET `substituteBody`+`{{x}}` (argument de `api_call`) coexistent à des couches différentes.

## 8. Impact par fichier du skill (synthèse)

| Fichier skill | Nature du travail |
|---|---|
| `SKILL.md` | Types, sommaire, Quick Reference (routes), §Create Tool→MCP-server, §Create Provider→Integration, Common Errors, description frontmatter |
| `assets/agent-manifest.json` | snake_case, `dependencies.{mcp_servers,integrations}`, `integrations_configuration`, `runtime_tools`, `$schema` v0 |
| `assets/tool-manifest.json` → `assets/mcp-server-manifest.json` | Renommer + vocabulaire MCPB |
| (nouveau) `assets/integration-manifest.json` | 3 variantes none/local/remote |
| `assets/skill-manifest.json` | snake_case |
| `references/manifest-schema.md` | Réécriture lourde (types, deps, runtime_tools, integrations_configuration, MCP-server, Integration fields) |
| `references/system-tools.md` → `runtime-tools.md` | runtime_tools, `{ns}__api_call` |
| `references/create-agent.md` | deps + runtime_tools + integrations_configuration ; retirer endpoints supprimés |
| `references/create-connector.md` → `create-integration.md` | Réécriture (source.kind, auths, delivery, connect, scopes) |
| `references/auth-decision-tree.md` | Stratégies ConnectStrategy, `{$credential}`, mtls→files |
| `references/prompt-writing.md` | **Réécriture majeure** : Communication contract, ne pas lister les outils, INTEGRATION.md |
| `references/large-responses.md` | 32 KB, URI `appstrate://api-response/...`, `{ns}__api_call` |
| `references/tools-vs-scripts.md` | « tool » = mcp-server ; reformuler |
| `references/flaresolverr-pattern.md` | Reclasser sous `source.kind:local` + `connect.tool` |
| `references/concepts.md` | 4 types, delivery, runtime_tools |
| `references/inline-runs.md` | Retirer `providerProfiles` + 3 limites ; `dependencies` integrations ; pas de `connection_overrides` inline |
| `references/state-and-checkpoint.md` | casing `actor_type`/`actor_id` ; sections data-only |
| `references/api-cheatsheet.md` | routes (agents/skills only), retirer tools/providers |
| `references/known-issues.md` | tri (bugs corrigés vs persistants) ; uploads/S3 inchangé |
| `references/profiles.md` | retirer groupe CLI `connections`/`connection-profiles` |
| `references/setup.md` | terminologie ; `/api/model-provider-credentials` |
| `scripts/afps-pack.sh` | inchangé |

## 9. Restant à vérifier (mineur, pendant l'édition)
- `INTEGRATION.md` : nom/format exact du fichier de doc injecté pour une intégration (équivalent de `PROVIDER.md`).
- Endpoint exact d'import de packages mcp-server/integration (via `/api/packages/import` ZIP — pas de listing REST dédié).
- `x-` prefix vs snake_case pour les éventuels champs `x-*` restants.
- Statut réel de chaque bug de `known-issues.md` sur la branche (ex. `appstrate run` system-tools).
