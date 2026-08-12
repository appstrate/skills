# Référence Google Workspace MCP

État vérifié le 12 août 2026. Les serveurs sont encore en Developer Preview. Consulter la documentation officielle avant une nouvelle installation ou après une modification du catalogue Google.

## Produits

| Produit | API produit | Service MCP | Endpoint distant | Test de lecture |
| --- | --- | --- | --- | --- |
| Gmail | `gmail.googleapis.com` | `gmailmcp.googleapis.com` | `https://gmailmcp.googleapis.com/mcp/v1` | `list_labels` |
| Drive | `drive.googleapis.com` | `drivemcp.googleapis.com` | `https://drivemcp.googleapis.com/mcp/v1` | `list_recent_files` ou `search_files` |
| Docs | `docs.googleapis.com` | `docsmcp.googleapis.com` | `https://docsmcp.googleapis.com/mcp/v1` | `read_doc` |
| Sheets | `sheets.googleapis.com` | `sheetsmcp.googleapis.com` | `https://sheetsmcp.googleapis.com/mcp/v1` | `get_spreadsheet` ou `get_values` |
| Slides | `slides.googleapis.com` | `slidesmcp.googleapis.com` | `https://slidesmcp.googleapis.com/mcp/v1` | `read_presentation` |
| Calendar | `calendar-json.googleapis.com` | `calendarmcp.googleapis.com` | `https://calendarmcp.googleapis.com/mcp/v1` | `list_calendars` |
| People | `people.googleapis.com` | `people.googleapis.com` | `https://people.googleapis.com/mcp/v1` | `get_user_profile` |
| Chat | `chat.googleapis.com` | `chatmcp.googleapis.com` | `https://chatmcp.googleapis.com/mcp/v1` | `search_conversations` |

## Activation CLI

```bash
gcloud services enable \
  gmail.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  sheets.googleapis.com \
  slides.googleapis.com \
  calendar-json.googleapis.com \
  chat.googleapis.com \
  people.googleapis.com \
  gmailmcp.googleapis.com \
  drivemcp.googleapis.com \
  docsmcp.googleapis.com \
  sheetsmcp.googleapis.com \
  slidesmcp.googleapis.com \
  calendarmcp.googleapis.com \
  chatmcp.googleapis.com \
  --project="PROJECT_ID"
```

## Accès IAM

Le rôle prédéfini `roles/mcp.toolUser` contient la permission d’appeler les outils MCP. Un rôle plus large, comme Owner, peut déjà la fournir.

```bash
gcloud projects add-iam-policy-binding "PROJECT_ID" \
  --member="user:WORKSPACE_EMAIL" \
  --role="roles/mcp.toolUser" \
  --condition=None
```

Le rôle IAM autorise l’appel du service MCP. Les scopes OAuth autorisent l’accès aux données de l’utilisateur. Le statut d’utilisateur test autorise le compte à franchir l’écran de consentement pendant la phase de test. Ces contrôles sont indépendants.

## Points humains obligatoires

1. Inscription et acceptation au Google Workspace Developer Preview Program.
2. Acceptation des politiques Google Auth Platform.
3. Configuration de Branding, Audience, Data Access et des utilisateurs test.
4. Création ou modification du client OAuth Web et de ses URI de redirection.
5. Configuration de l’application Google Chat avec les fonctions interactives désactivées.
6. Consentement OAuth de chaque utilisateur.

Google indique que les clients OAuth Google classiques ne peuvent pas être créés ou modifiés par programmation. Le client géré par `gcloud iam oauth-clients` appartient à une autre surface IAM et ses scopes pris en charge ne couvrent pas Gmail, Drive ou Calendar.

## Diagnostic

| Symptôme | Couche probable | Contrôle |
| --- | --- | --- |
| `SERVICE_DISABLED` ou HTTP 403 mentionnant une API | Service Usage | Vérifier l’API produit et le service MCP |
| `permission denied` sur tous les outils | IAM ou Preview | Vérifier l’acceptation du projet et `mcp.tools.call` |
| `insufficient_scopes` | OAuth ou manifeste | Comparer les scopes accordés et la politique de l’outil |
| Google renvoie `userinfo.email` | Normalisation du scope | Déclarer qu’il implique `email` dans le manifeste |
| L’utilisateur ne peut pas consentir | Audience ou utilisateur test | Vérifier Internal, External, Testing et la liste des utilisateurs |
| Chat échoue alors que les services sont actifs | Configuration Chat | Configurer l’application Chat et désactiver les fonctions interactives |
| Le run Appstrate est `success`, mais le contrôle échoue | Sortie métier | Vérifier aussi `output.success` et les détails de l’appel amont |

## Packages Appstrate

Une entreprise peut publier des packages propres à son organisation avec son propre namespace, par exemple `@acme/gmail-mcp` ou `@acme/google-drive-mcp`. Ces packages d’organisation sont importables immédiatement dans l’organisation concernée et peuvent porter une correction sans attendre une nouvelle version du produit.

Les packages `@appstrate/*` sont distribués avec le système. Une modification de leur source nécessite une fusion puis un déploiement Appstrate avant de devenir la version système d’une instance.

Ne jamais imposer le namespace d’une autre entreprise. Déterminer le slug ou le namespace de l’organisation cible avant de nommer ou construire un package.

Une nouvelle version d’un package doit déclarer le catalogue réel des outils observé avec `tools/list`, appliquer les scopes minimaux par outil et être validée par le schéma de manifeste avant construction de l’archive AFPS.

## Deux interfaces d’administration Appstrate

### MCP Appstrate

Chaque organisation possède un endpoint Streamable HTTP :

```text
https://INSTANCE/api/mcp/o/ORG_ID
```

Copier l’URL exacte depuis les réglages de l’organisation. L’endpoint fixe l’organisation et utilise son application par défaut, sauf si la connexion MCP porte un `X-Application-Id` appartenant à cette organisation. Pour plusieurs organisations, enregistrer plusieurs connexions MCP.

La connexion accepte deux parcours : OAuth dans le navigateur, ou clé API portant `mcp:read` et `mcp:invoke`. Les opérations appelées appliquent ensuite leurs propres permissions Appstrate.

Workflow d’administration :

1. Appeler `get_me` pour vérifier la cible et les connexions visibles.
2. Appeler `search_operations` avec l’intention recherchée.
3. Utiliser le contrat `best_match`, ou appeler `describe_operation` si la correspondance reste ambiguë.
4. Appeler `invoke_operation` avec le schéma courant.
5. Utiliser `run_and_wait` pour les tests nécessitant un run et attendre l’état terminal.

Ne pas mémoriser les noms d’opérations ni leurs bodies dans le skill. Le catalogue MCP Appstrate et son OpenAPI sont la source de vérité courante.

### CLI Appstrate

La CLI utilise des profils nommés. Toujours passer le profil explicitement, par exemple `appstrate -p local` ou `appstrate -p cloud`, puis lire l’aide de la commande installée. Utiliser `appstrate api` comme passage authentifié vers une opération REST sans commande spécialisée.

La CLI est le repli naturel lorsque le MCP n’est pas connecté ou lorsqu’un fichier local, notamment une archive de package, ne peut pas être transmis par le contrat MCP courant.

### Choix

| Situation | Interface recommandée |
| --- | --- |
| MCP déjà connecté à la bonne organisation | MCP Appstrate |
| Découverte du contrat API courant | MCP Appstrate |
| Lancement et attente d’un run | MCP Appstrate avec `run_and_wait` |
| Import depuis un fichier local non transportable par le MCP | CLI Appstrate |
| Automatisation shell reproductible | CLI Appstrate |
| MCP indisponible ou non autorisé | CLI Appstrate |
| CLI absente, MCP autorisé | MCP Appstrate |

## Sources officielles

- `https://developers.google.com/workspace/guides/configure-mcp-servers`
- `https://developers.google.com/workspace/guides/configure-mcp-security`
- `https://developers.google.com/identity/protocols/oauth2/resources/best-practices`
- `https://github.com/googleapis/gcloud-mcp`
