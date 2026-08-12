---
name: appstrate-google-workspace
description: Configure, audit, connect, and diagnose Google Workspace MCP servers in Appstrate through gcloud, the local gcloud MCP, the Appstrate MCP, or the Appstrate CLI. Use for Gmail, Drive, Docs, Sheets, Slides, Calendar, People, or Chat MCP; OAuth, scopes, test users, IAM mcp.toolUser, disabled services, Developer Preview, local or cloud installation; and read-only integration validation.
---

# Google Workspace MCP in Appstrate

Orchestrate automatable steps through CLIs, then guide the user only where Google requires a human
action.

## Distinguish the layers

1. `@google-cloud/gcloud-mcp` is a local administration MCP server. It runs the `gcloud` CLI with the
   active account's permissions.
2. Google Workspace MCP servers are separate remote services for Gmail, Drive, Docs, Sheets, Slides,
   Calendar, People, and Chat.
3. The Appstrate MCP and Appstrate CLI administer an instance. They are two interfaces to the same
   platform with different connection mechanisms.
4. Appstrate integrations define the endpoints, scopes, tool policies, and OAuth connections used by
   agents.

One working layer does not prove that the other layers are configured correctly.

## Load the reference

Read [references/google-workspace-mcp.md](references/google-workspace-mcp.md) before installation,
activation, manifest migration, or diagnosis. It contains services, endpoints, tests, and known
errors.

## Process

### 1. Fix the target

Obtain explicitly:

- `PROJECT_ID` and `PROJECT_NUMBER`;
- the Google Workspace account to connect;
- the Appstrate instance, organization, and application;
- the available Appstrate interface, MCP, CLI, or both;
- the Google products to enable;
- the requested mode: audit, configuration, or diagnosis.

Never infer the project from implicit configuration for an operation that changes Google Cloud. Use
`--project` on every relevant command. For Appstrate, confirm the target through the MCP or use an
explicit CLI profile.

### 2. Verify identities before changing anything

Run:

```bash
gcloud config list --format='text(core.account,core.project)'
gcloud projects describe PROJECT_ID \
  --format='text(projectId,projectNumber,lifecycleState)'
```

If the account or project does not match the target, stop mutations and correct the connection.

For a complete audit, run `scripts/audit-google-workspace-mcp.sh PROJECT_ID WORKSPACE_EMAIL`. The
script is read-only.

### 3. Separate automation from human steps

Delegate to the CLI: service activation, authorized IAM reads and grants, diagnostics, Appstrate
package imports, integration activation, and tests.

Guide the user in the browser to:

- accept terms and submit the Developer Preview application;
- configure Branding, Audience, Data Access, and test users;
- create or modify the Google Auth Platform Web OAuth client;
- configure the Google Chat application;
- complete OAuth consent for each account.

Google does not support programmatic creation or modification of classic Google OAuth clients. Do not
present `gcloud iam oauth-clients` as a substitute because IAM clients do not cover the required
Workspace scopes.

### 4. Enable only what was requested

Enable both the product API and its corresponding MCP service. People uses
`people.googleapis.com` for both functions.

Treat IAM changes and service activation as authorized only when the user's request covers that
configuration. Verify the target immediately before the call.

### 5. Choose the Appstrate interface

Prefer the Appstrate MCP when already connected to the correct organization and it exposes the
required operation. Call `get_me` first to confirm identity, organization, role, and existing
integration connections. Then search for the intent with `search_operations`. Use its `best_match` if
the contract fits, otherwise call `describe_operation`, then `invoke_operation`. Use `run_and_wait` to
start a test and wait directly for its terminal state.

An Appstrate MCP endpoint belongs to one organization. The organization cannot be switched within a
session. Connect a distinct endpoint for each organization and verify the effective application
before a mutation.

Use the Appstrate CLI when the MCP is not connected, the operation requires a local file that the
current MCP contract cannot transport, or the user explicitly requests the CLI. Read help from the
installed version, choose an explicit profile, and use `appstrate api` when the REST operation has no
dedicated command.

Do not mix evidence. An MCP read confirms the MCP target, while a read through
`appstrate -p PROFILE` confirms the CLI target. Recheck the target in the interface that will perform
the mutation.

### 6. Configure Appstrate without exposing secrets

Never display a client secret, verification code, access token, or refresh token in output.

Reuse a secret stored in a protected environment file without copying it into chat, Git, a manifest,
or a document. Use a protected temporary file or an in-memory variable, then clear its content.

Use the target organization's namespace for portable packages, for example `@acme/gmail-mcp`.
Reserve `@appstrate/*` for system packages distributed with the product. Never reuse another
company's namespace as a generic convention.

Configure each integration with:

- the official remote endpoint;
- `openid`, `email`, and the minimum scopes required by its tools;
- equivalence between `https://www.googleapis.com/auth/userinfo.email` and `email`;
- the Appstrate Web OAuth client and its exact callback;
- a separate OAuth connection for each user account.

### 7. Test without writing

Begin with the read operations listed in the reference. Do not create, modify, send, move, or delete
Google data during a connection test.

For an Appstrate run, verify both levels:

```text
status = success
output.success = true
```

A technically completed run can contain a functional failure in its output. Retain the run identifier
and a non-sensitive summary of the result.

### 8. Diagnose by layer

Classify each error before correcting it: disabled service, Preview program, IAM, OAuth, scope, Chat
configuration, Appstrate package, or remote tool. Read the upstream error and do not compensate for
one layer with a permission on another.

After correcting the issue, rerun one read-only operation first. Then expand validation to other
products and instances.

## Completion criteria

Finish only when:

- the target account and project are confirmed;
- requested services are enabled;
- IAM access is verified;
- OAuth connections exist with the expected scopes;
- every requested product passes a read-only test with both success statuses;
- remaining human steps and undeployed system changes are clearly reported.
