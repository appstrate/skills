# Plan de migration du skill `appstrate` → branche plateforme `feat/integrations`

> Branche skill : `feat/integrations` (repo `appstrate/skills`).
> Cible plateforme : `appstrate/appstrate@feat/integrations` (≈234 commits au-dessus de `main`).
> Statut : **plan** — aucune édition de contenu encore appliquée.

Ce document liste tous les ajustements à porter dans le skill. Il distingue ce qui **change réellement** sur la branche de ce qui **ne change pas** (pour éviter la sur-correction), puis détaille le travail **fichier par fichier**, et liste les **points à vérifier** avant édition.

---

## A. Cadrage — ce qui change vs ce qui ne change pas

### A.1 Vrais deltas de la branche (à intégrer)

1. **Types de packages** : `tool` → `mcp-server`, `provider` → `integration`. Enum AFPS Appendix D : `["agent","skill","mcp-server","integration"]`. Catalogue système renommé `integration-*.afps` / `mcp-server-*.afps`.
2. **Dépendances d'agent** : `dependencies.{skills, mcp_servers, integrations}` (maps plates `{name: semver}`). `dependencies.tools` et `dependencies.providers` **n'existent plus** — `assertNoLegacyDepKeys()` les **rejette** à la publication.
3. **`runtime_tools: string[]`** (top-level, enum `["output","log","note","pin","report"]`) remplace les ex-packages `@appstrate/output` & co. Opt-in par agent. `output` requis **uniquement** si `output.schema` est déclaré (superRefine).
4. **`integrations_configuration.{@scope/name: {tools, scopes?, auth_key?}}`** (top-level, snake_case) : sélection d'outils/scopes par intégration. Chaque clé doit matcher une entrée `dependencies.integrations`.
5. **Modèle Integrations** : `source.kind` ∈ `none` (api_call seul) / `local` (`source.server` → package `mcp-server`, runner container par intégration) / `remote` (`source.remote.{url,transport}` MCP HTTP/SSE). `auths.{key}.{type, authorized_uris, allow_all_uris, credentials.schema, delivery.{http|env}}`. Scopes : `scope_catalog`, `default_scopes`, `tools_policy.{tool}.required_scopes.{auth_key}`.
6. **Outils sidecar exposés à l'agent** : `provider_call` **disparaît** → `{ns}__api_call({method,target,headers?,body?,responseMode?})` (+ `{ns}__api_upload` si déclaré). Chaque outil d'intégration exposé en `{ns}__{tool}`. `run_history` / `recall_memory` conservés.
7. **Casing snake_case** sur tout le wire/manifest : `display_name`, `schema_version`, `long_description`, `file_constraints`, `ui_hints`, `property_order`, `runtime_tools`, `integrations_configuration`, `connection_overrides`, `cron_expression`, `running_runs`… **Carve-outs camelCase préservés** : champs DB universels (`id`, `*Id`, `createdAt`, `updatedAt`…), surface headless (`externalId`, `isDefault`, `hasMore`, `payloadMode`, `eventType`, `statusCode`, `keyPrefix`), DTO model-provider (`providerId`, `displayName`, `apiShape`), endpoints model/proxy (`modelId`, `proxyId`, `credentialId`).
8. **Syntaxe de substitution credential** : `{$credential.<field>}` (ex. `{$credential.api_key}`, `{$credential.access_token}`) côté `delivery.http.value`. ⚠️ À confronter aux placeholders `{{access_token}}`/`{{apiKey}}` que le skill documente (voir §C — points à vérifier).
9. **Routes API** : suppression de `/api/providers/*`, `/api/connections/*`, `/api/connection-profiles/*`, `/api/me/application-profile` → unifiées sous `/api/integrations/*`, `/api/me/connections`, `/api/me/integration-pins`. Run kickoff : `providerProfiles` → **`connection_overrides`** (map plate `{@scope/integration: connection_id}`) ; 412 `missing_integration_connection`.
10. **CLI** : `appstrate run … --providers <mode>` → **`--integrations <remote|local|none>`** (défaut `remote`). Aucune autre commande nouvelle/supprimée.
11. **Per-run shared volume + MCP Roots** (#525) : un `mcp-server` peut opter via `_meta["dev.appstrate/workspace"].{mount, access}`. Le sidecar agit comme provider MCP Roots.
12. **Vocabulaire `mcp-server`** (MCPB) : `server.{type ∈ node|python|binary|uv, entry_point, mcp_config}`, override Bun via `_meta["dev.appstrate/mcp-server"].runtime`.

### A.2 Faux deltas — NE PAS présenter comme nouveautés

- **Model providers** : `core-providers`, `@appstrate/module-codex`, `@appstrate/module-claude-code`, routes `/api/model-provider-credentials/*` & `/api/model-providers-oauth/*` — **déjà dans `main`**.
- **Enveloppe de liste** `{ object:"list", data, hasMore }` — **déjà dans `main`**, et `hasMore` est **camelCase** (pas `has_more`).
- **`package_persistence`** (archive + pinned unifiés), routes `/persistence?kind=pinned|memory`, permission `persistence:read|delete` — déjà mergé ; vérifier seulement que le skill est aligné.

---

## B. Plan fichier par fichier

### `SKILL.md` (361 l.) — réécriture structurelle
- L8 : « Four types: `agent`, `skill`, `tool`, `provider` » → `agent`, `skill`, `mcp-server`, `integration`.
- Sommaire L12 : `Create a Tool` → `Create an MCP-server` ; `Create a Provider` → `Create an Integration`. Ajouter `Runtime Tools`.
- Quick Reference L134/146 : `/api/packages/tools` → `…/mcp-servers` ; `/api/providers` → `/api/integrations` (vérifier route exacte de listing). L138 `/api/oauth-clients` → `/api/integrations/{packageId}/oauth-clients/{authKey}`.
- §Create an Agent L147 : retirer « every dependency … `@appstrate/output` in dependencies.tools » → introduire `runtime_tools` + `dependencies.{mcp_servers, integrations}`.
- §Create a Tool (255-278) → **§Create an MCP-server** : vocabulaire MCPB, `server.{type,entry_point}`, plus de `dependencies.tools`. Le « tool = extension TypeScript invoquée par l'agent » devient « mcp-server = serveur MCP packagé ».
- §Create a Provider (280-305) → **§Create an Integration** : `source.kind` none/local/remote, `auths`, `delivery`. `ctx.providerCall`/`provider_call` → `{ns}__api_call`.
- Common Errors (313-330) : L315/L322 `@appstrate/output` in `dependencies.tools` → `runtime_tools: ["output"]`. L326/L328 `provider_call` → `{ns}__api_call`. L323 `fileConstraints` → `file_constraints`.
- References table (348-361) : renommer les pointeurs (tools→mcp-servers, provider→integration).

### `assets/agent-manifest.json` — réécriture
- `displayName` → `display_name` ; ajouter `schema_version`.
- `dependencies: { providers, skills, tools }` → `{ skills, mcp_servers, integrations }`.
- Supprimer `providersConfiguration` → ajouter `integrations_configuration: {}`.
- Ajouter `runtime_tools: ["output"]` (cohérent avec l'`output.schema` de l'exemple).
- `input.schema` wrapper : `propertyOrder` → `property_order` ; `fileConstraints` → `file_constraints` (clé `max_size`, pas `maxSize`) ; ajouter `ui_hints` en exemple.
- `x-outputRetries` : vérifier s'il reste `x-` ou passe snake_case.
- Corriger `$schema` (incohérence interne `flow.schema.json` vs `agent.schema.json` — choisir la valeur réelle de la branche).

### `assets/tool-manifest.json` → `assets/mcp-server-manifest.json` (renommer + réécrire)
- `type: "tool"` → `"mcp-server"`.
- Remplacer `entrypoint`/`tool.inputSchema` par le vocabulaire MCPB : `server.{type, entry_point, mcp_config}`, `tools[].{name, description}`.
- Ajouter exemple optionnel `_meta["dev.appstrate/workspace"]` + `_meta["dev.appstrate/mcp-server"].runtime`.

### `assets/skill-manifest.json` — quasi inchangé
- `displayName` → `display_name`. Vérifier `schema_version`.

### Nouveau : `assets/integration-manifest.json`
- 3 variantes (en commentaire ou 3 fichiers) : `kind:none` (api_key, modèle ActiveCampaign), `kind:remote` (clickup-mcp), `kind:local` (github-git → mcp-server). Inclure `auths.{key}.delivery.http.value: "{$credential.api_key}"`.

### `references/manifest-schema.md` (358 l.) — réécriture lourde
- §common `type` enum → `agent/skill/mcp-server/integration`.
- §dependencies : `{skills, mcp_servers, integrations}` ; documenter le rejet `LegacyDepKeyError`.
- Ajouter §`runtime_tools` (enum, règle output-si-schema) ; §`integrations_configuration`.
- §File fields : `fileConstraints` → `file_constraints` (`max_size`/`accept`/`max_files`) ; `propertyOrder` → `property_order` ; ajouter `ui_hints`.
- §Tool Fields → §MCP-server Fields (MCPB) ; §Provider Fields → §Integration Fields (source/auths/delivery/scopes/tools_policy).
- Résoudre les incohérences internes relevées : signature `execute` (3 vs 4 args — n/a si on retire le modèle tool-TS), import SDK, liste `authMode`.

### `references/system-tools.md` (105 l.) → refondre en `references/runtime-tools.md`
- Tout le modèle « tool déclaré dans `dependencies.tools` » → `runtime_tools`.
- `provider_call` (MCP-injected) → `{ns}__api_call`.
- `PUT /api/agents/.../tools` (toolIds) : vérifier le nouvel endpoint (mcp_servers / runtime_tools).

### `references/create-agent.md` (181 l.) — réécriture
- Manifeste exemple : `dependencies.{mcp_servers,integrations}` + `runtime_tools` + `integrations_configuration`.
- L21 « System tools (output, set-state, report…) » → `runtime_tools` (note : `set-state`/`add-memory` remplacés par `pin`/`note`).
- L126-138 sidecar `$SIDECAR_URL/proxy` + `X-Provider`/`X-Target` → modèle `{ns}__api_call`. Placeholders `{{access_token}}` → confronter `{$credential.…}`.
- Post-import L167-180 : `PUT …/skills`, `…/model` à revalider ; `PUT …/tools` → mcp-servers/integrations.

### `references/create-connector.md` (279 l.) → `references/create-integration.md`
- Tout le workflow provider → integration. `type:"provider"` → `"integration"` ; `definition.authMode` → `auths.{key}.type` ; `definition.authorizedUris` → `auths.{key}.authorized_uris` ; `definition.injection` → `auths.{key}.delivery.http`.
- `POST /api/connections/connect/@scope/name/api-key` → flux `/api/integrations/{packageId}/auths/{authKey}/connect/*`.
- Squelette tool TS `ctx.providerCall` : statuer s'il reste pertinent (intégrations local = serveur MCP, pas extension TS pi). Probable suppression/refonte.
- `PROVIDER.md` → équivalent pour integration (vérifier si toujours requis / nom du fichier).

### `references/auth-decision-tree.md` (125 l.) — mise à jour ciblée
- `authMode` → `auths.{key}.type` ; `substituteBody:true` & `provider_call` → modèle `delivery.http` + `{$credential.…}` / `{ns}__api_call`.
- Patterns ROPC/CAS/cookie : revalider contre le nouveau modèle delivery (env vs http MITM).

### `references/prompt-writing.md` (204 l.) — mise à jour
- §Authenticated Provider API (`X-Provider`/`X-Target`, `$SIDECAR_URL/proxy`) → `{ns}__api_call`.
- §Placeholder Semantics : `{{var}}` vs `<MARKER>` → intégrer `{$credential.…}` (nouvelle syntaxe serveur-side). Seuil troncature : réconcilier 50KB (proxy) vs 32KB (resource_link).
- Sections auto-injectées : vérifier `## Checkpoint`/`## Pinned Slots`/`## Memory` toujours exactes.

### `references/large-responses.md` (185 l.) — mise à jour
- `ctx.providerCall` → `{ns}__api_call` + `responseMode`. `appstrate://provider-response/…` → vérifier nouveau scheme. `ctx.readResource` : valider survivance dans le modèle mcp-server.

### `references/tools-vs-scripts.md` (85 l.) — réviser ou retirer
- Le cadre « tool custom (extension TS) vs script » change : « tool » = mcp-server désormais. Reformuler « mcp-server vs script de skill ».

### `references/flaresolverr-pattern.md` (391 l.) — mise à jour ciblée
- `providerCall`/`@scope/X` credentials/`substituteBody` → modèle delivery integration. Patterns FS à reformuler en integration `kind:local` (runner) ou `none` (api_call). Conserver l'avertissement non-upstream / Cloud-incompatible.

### `references/concepts.md` (48 l.) — mise à jour
- L27-34 : 4 types (mcp-server/integration). Modèle « sidecar injecte credentials » : préciser delivery env/http. L48 `@appstrate/output` → `runtime_tools`.

### `references/inline-runs.md` (186 l.) — mise à jour ciblée
- Exemple manifeste inline : `dependencies.tools {@appstrate/output}` → `runtime_tools` + `dependencies.{mcp_servers,integrations}`. `providerProfiles` → `connection_overrides`. `$schema` agent.
- `INLINE_RUN_LIMITS` : `max_tools` → vérifier renommage (`max_mcp_servers` ?), ajout `max_integrations` ?

### `references/state-and-checkpoint.md` (90 l.) — vérification
- `pin`/`note`/`recall_memory` : déjà aligné `package_persistence`. Vérifier que `note`/`pin` sont bien des `runtime_tools` (pas des MCP tools). `/persistence` shape inchangé.

### `references/known-issues.md` (147 l.) — tri
- Réévaluer chaque bug sur la branche : `appstrate run` system-tools (peut être résolu), `minio:9000` (toujours via `S3_PUBLIC_ENDPOINT`), `DraftPackageCatalog` (`POST /api/providers` flat → route supprimée donc bug n/a), `cost.cacheRead/cacheWrite`, ALB stickiness. Retirer les bugs corrigés, garder/mettre à jour les autres.

### `references/api-cheatsheet.md` (72 l.) — mise à jour
- Routes/gotchas : `/api/packages/tools` → mcp-servers ; `dependencies.tools` → runtime_tools ; `MISSING_TOOL` → vérifier nouveau code.

### `references/profiles.md`, `references/setup.md` — quasi inchangés
- Terminologie uniquement (provider→integration là où cité). Vérifier `POST /api/api-keys`, `/api/provider-keys`.

### `scripts/afps-pack.sh` — inchangé
- Packing ZIP générique, pas de dépendance au type. Aucun changement.

### Cohérence transverse (toute la base)
- Grep final : plus aucune occurrence non intentionnelle de `dependencies.tools`, `dependencies.providers`, `provider_call`, `@appstrate/output`, `fileConstraints`, `providersConfiguration`, `type: "tool"`, `type: "provider"`.
- Mettre à jour la `description` du frontmatter `SKILL.md` (triggers : ajouter `integration`, `mcp-server`, `runtime_tools` ; retirer/ajuster « managing skills/tools/providers »).

---

## C. Points à vérifier avant/pendant l'édition

### C.0 Tranchés (vérifiés dans la branche le 2026-05-29)

- ✅ **`/api/provider-keys` n'existe plus** → `apps/api/src/openapi/paths/` ne contient que `model-provider-credentials.ts`, `model-providers-oauth.ts`, `models.ts`. ⚠️ SKILL.md L55 (`POST /api/provider-keys` puis `POST /api/models … providerKeyId`) est **déjà faux** (renommé dès `main`, pas un delta de la branche) → corriger en `POST /api/model-provider-credentials` + `POST /api/models`.
- ✅ **Le modèle « tool = extension TS pi » SURVIT** (réorganisé) : `packages/runner-pi/src/tool-context.ts`, `api-call-bridge.ts`, `runtime-tools/{mcp-forward,runtime-tool-extensions}.ts`, `runtime-pi/extension-wrapper.ts` + `registerTool`/`ExtensionAPI` toujours présents. → Ne PAS supprimer create-connector/large-responses/tools-vs-scripts ; les **réconcilier** (le « tool » côté package devient mcp-server, mais l'API d'extension `ctx.providerCall`/`ctx.readResource` reste un mécanisme runtime).
- ✅ **Deux couches de substitution COEXISTENT, ne pas en remplacer une par l'autre** :
  - `{$credential.<field>}` = substitution **serveur-side dans le manifeste d'intégration** (`auths.{key}.delivery.http.value`) — l'intégration ne voit jamais le secret.
  - `substituteBody: true` + `{{var}}` = argument de l'outil agent-facing `{ns}__api_call` (toujours présent dans `runtime-pi/sidecar/mcp.ts`). → Documenter les **deux**, à leurs niveaux respectifs.

### C.1 Restent à vérifier
1. **Route de listing des packages** : `/api/packages/mcp-servers` & listing intégrations — confirmer les chemins exacts.
2. **`PUT /api/agents/.../tools`** : nouvel endpoint pour attacher mcp-servers/integrations/runtime_tools.
3. **`x-outputRetries`** : conservé en `x-` ou snake_case ?
4. **`$schema`** d'agent : `flow.schema.json` vs `agent.schema.json` (incohérence interne existante).
5. **`INLINE_RUN_LIMITS`** : `max_tools` renommé (`max_mcp_servers` ?) + ajout `max_integrations` ?
6. **known-issues** : statut réel de chaque bug sur la branche (certains corrigés, ex. route flat `POST /api/providers` supprimée).

---

## D. Ordre d'exécution proposé

1. Réécrire les **assets** (sources de vérité des exemples) : agent, mcp-server, integration, skill.
2. Réécrire les **références cœur** : manifest-schema, runtime-tools, create-agent, create-integration, create-mcp-server.
3. Réécrire le **SKILL.md** (s'appuie sur les références).
4. Mettre à jour les **références satellites** : auth-decision-tree, prompt-writing, large-responses, concepts, inline-runs, api-cheatsheet, flaresolverr, tools-vs-scripts, known-issues.
5. **Passe de cohérence** (grep transverse + description frontmatter).
6. **Review skill-creator** (« skillcrit ») + corrections.
