# Google Workspace MCP reference

Status verified on August 12, 2026. These servers are still in Developer Preview. Consult the official
documentation before a new installation or after Google changes its catalog.

## Products

| Product | Product API | MCP service | Remote endpoint | Read test |
| --- | --- | --- | --- | --- |
| Gmail | `gmail.googleapis.com` | `gmailmcp.googleapis.com` | `https://gmailmcp.googleapis.com/mcp/v1` | `list_labels` |
| Drive | `drive.googleapis.com` | `drivemcp.googleapis.com` | `https://drivemcp.googleapis.com/mcp/v1` | `list_recent_files` or `search_files` |
| Docs | `docs.googleapis.com` | `docsmcp.googleapis.com` | `https://docsmcp.googleapis.com/mcp/v1` | `read_doc` |
| Sheets | `sheets.googleapis.com` | `sheetsmcp.googleapis.com` | `https://sheetsmcp.googleapis.com/mcp/v1` | `get_spreadsheet` or `get_values` |
| Slides | `slides.googleapis.com` | `slidesmcp.googleapis.com` | `https://slidesmcp.googleapis.com/mcp/v1` | `read_presentation` |
| Calendar | `calendar-json.googleapis.com` | `calendarmcp.googleapis.com` | `https://calendarmcp.googleapis.com/mcp/v1` | `list_calendars` |
| People | `people.googleapis.com` | `people.googleapis.com` | `https://people.googleapis.com/mcp/v1` | `get_user_profile` |
| Chat | `chat.googleapis.com` | `chatmcp.googleapis.com` | `https://chatmcp.googleapis.com/mcp/v1` | `search_conversations` |

## CLI activation

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

## IAM access

The predefined `roles/mcp.toolUser` role contains permission to call MCP tools. A broader role such as
Owner may already provide it.

```bash
gcloud projects add-iam-policy-binding "PROJECT_ID" \
  --member="user:WORKSPACE_EMAIL" \
  --role="roles/mcp.toolUser" \
  --condition=None
```

The IAM role authorizes calls to the MCP service. OAuth scopes authorize access to user data. Test
user status allows an account through the consent screen during testing. These controls are
independent.

## Required human steps

1. Enroll in and accept the Google Workspace Developer Preview Program.
2. Accept Google Auth Platform policies.
3. Configure Branding, Audience, Data Access, and test users.
4. Create or modify the Web OAuth client and its redirect URIs.
5. Configure the Google Chat application with interactive features disabled.
6. Complete OAuth consent for every user.

Google states that classic Google OAuth clients cannot be created or modified programmatically. A
client managed through `gcloud iam oauth-clients` belongs to a different IAM surface and its supported
scopes do not cover Gmail, Drive, or Calendar.

## Diagnosis

| Symptom | Likely layer | Check |
| --- | --- | --- |
| `SERVICE_DISABLED` or HTTP 403 naming an API | Service Usage | Check both product API and MCP service |
| `permission denied` on every tool | IAM or Preview | Check project acceptance and `mcp.tools.call` |
| `insufficient_scopes` | OAuth or manifest | Compare granted scopes with the tool policy |
| Google returns `userinfo.email` | Scope normalization | Declare that it implies `email` in the manifest |
| User cannot grant consent | Audience or test user | Check Internal, External, Testing, and the user list |
| Chat fails while services are active | Chat configuration | Configure the Chat app and disable interactive features |
| Appstrate run is `success`, but the check fails | Business output | Also inspect `output.success` and upstream call details |

## Appstrate packages

A company can publish organization-owned packages under its own namespace, such as
`@acme/gmail-mcp` or `@acme/google-drive-mcp`. These packages can be imported immediately into that
organization and can carry a correction without waiting for a new product release.

Packages under `@appstrate/*` are distributed with the system. A source change must be merged and
Appstrate deployed before it becomes the system version on an instance.

Never impose another company's namespace. Determine the target organization's slug or namespace
before naming or building a package.

A new package version must declare the actual tool catalog observed through `tools/list`, apply the
minimum scopes per tool, and pass manifest schema validation before building the AFPS archive.

## Two Appstrate administration interfaces

### Appstrate MCP

Every organization has a Streamable HTTP endpoint:

```text
https://INSTANCE/api/mcp/o/ORG_ID
```

Copy the exact URL from organization settings. The endpoint fixes the organization and uses its
default application unless the MCP connection carries an `X-Application-Id` that belongs to that
organization. Register separate MCP connections for multiple organizations.

The connection supports two paths: browser OAuth, or an API key carrying `mcp:read` and `mcp:invoke`.
Called operations then enforce their own Appstrate permissions.

Administration workflow:

1. Call `get_me` to verify the target and visible connections.
2. Call `search_operations` with the intended action.
3. Use the `best_match` contract, or call `describe_operation` if the match remains ambiguous.
4. Call `invoke_operation` with the current schema.
5. Use `run_and_wait` for tests that require a run and wait for its terminal state.

Do not memorize operation names or request bodies in the skill. The Appstrate MCP catalog and its
OpenAPI specification are the current source of truth.

### Appstrate CLI

The CLI uses named profiles. Always pass the profile explicitly, such as `appstrate -p local` or
`appstrate -p cloud`, then read help from the installed command. Use `appstrate api` as an
authenticated path to a REST operation without a specialized command.

The CLI is the natural fallback when the MCP is not connected or when a local file, particularly a
package archive, cannot be transported through the current MCP contract.

### Choice

| Situation | Recommended interface |
| --- | --- |
| MCP already connected to the correct organization | Appstrate MCP |
| Discover the current API contract | Appstrate MCP |
| Start and wait for a run | Appstrate MCP with `run_and_wait` |
| Import a local file that the MCP cannot transport | Appstrate CLI |
| Reproducible shell automation | Appstrate CLI |
| MCP unavailable or unauthorized | Appstrate CLI |
| CLI absent and MCP authorized | Appstrate MCP |

## Official sources

- `https://developers.google.com/workspace/guides/configure-mcp-servers`
- `https://developers.google.com/workspace/guides/configure-mcp-security`
- `https://developers.google.com/identity/protocols/oauth2/resources/best-practices`
- `https://github.com/googleapis/gcloud-mcp`
