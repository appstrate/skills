---
name: appstrate-architect
description: Architect, audit, configure, deploy, and validate an Appstrate implementation for an organization and its teams. Use for new or existing local and cloud instances, organizations, applications, models, integrations, connections, skills, agents, team rollout, or go-live verification through the Appstrate MCP server or CLI.
---

# Architect and deploy Appstrate in an organization

Build an implementation that AI architects and teams can operate, from instance inventory through
proven end-to-end use cases. Base every decision on the live contract of the target instance. Do not
assume that a package, operation, or capability is available.

## 1. Confirm the target and interface

Fix the instance, organization, application, user, and role before any mutation.

Prefer the Appstrate MCP server when it is already connected to the correct organization. Call
`get_me`, then discover the required operation through the available search and describe tools. Use
the CLI when MCP is unavailable, a local file must be transferred, or the user requests it. Read the
installed help and confirm the profile with `appstrate -p PROFILE whoami`.

MCP evidence does not confirm a CLI target, and CLI evidence does not confirm an MCP target. Verify
the target again through the interface that will perform the mutation.

## 2. Inventory the live implementation

Inspect the organizations, applications, users, roles, models, integrations, connections, skills,
agents, and runs relevant to the request. Distinguish four states for every capability:

1. available in the catalog;
2. installed in the organization;
3. enabled for the application;
4. connected and tested for the relevant user.

Record local and cloud differences explicitly. Neither environment is an implicit copy of the other.
Use [references/verification-matrix.md](references/verification-matrix.md) to structure the audit.

## 3. Design the rollout

Define the teams, use cases, Appstrate applications, access boundaries, and operational owners. Start
with one representative, measurable workflow. Expand only after that workflow has been proven.

Keep ownership clear:

- an integration provides access to a service;
- a skill owns a reusable method;
- an agent combines methods, access, and deployment-specific configuration;
- an application distributes that system to a user group.

Read [references/deployment-lifecycle.md](references/deployment-lifecycle.md) when moving from pilot to
production.

## 4. Load the right companion skill

The Appstrate Skills collection contains independent skills that can be installed together or alone:

| Need | Skill to load |
| --- | --- |
| Discover and prioritize automations with a user | `appstrate-copilot` |
| Choose between integrations or access modes | `appstrate-connector-choice` |
| Create, update, or validate an Appstrate agent | `appstrate-agent-authoring` |
| Create or improve a reusable method | `appstrate-skill-authoring` |
| Run web research through Appstrate | `appstrate-web-search` |
| Configure Google Workspace MCP and Google Cloud access | `appstrate-google-workspace` |

In Appstrate, find the accessible skill with the matching unscoped name, then resolve its canonical
`@scope/name` identifier before loading it. In a coding agent, use the local skill catalog. When a
companion is missing, report the dependency to install instead of inventing its content or scope.

## 5. Install and distribute skills

Keep portable source folders with a standard `SKILL.md` and relative resources. Import each skill ZIP
separately into Appstrate so `SKILL.md` sits at the archive root. The target organization assigns its
scope during import.

For a coding agent, install the complete folder in the supported skill directory. In Appstrate,
attach the relevant skills to the applications or agents that consume them. Discover visibility and
activation features from the target instance instead of relying on an experimental marker.

Read [references/skill-portability.md](references/skill-portability.md) before sharing skills across
organizations or environments.

## 6. Configure, then prove

Validate every artifact against the current schema before persistence. Grant only the permissions
required by the use case and keep secrets in the supported connection surfaces.

Test in three stages:

1. a read-only operation with no external effect;
2. a real run with representative input;
3. inspection of persisted state, output, and logs.

A successful technical status is insufficient when the business output contains an error. A local
configuration does not prove cloud behavior. Repeat the controls on every requested target.

## 7. Deliver the deployment record

Report the verified targets, installed package versions, tested connections, proven agents, covered
users or applications, remaining human decisions, and risks. Call a capability functional only when
an observable test passed on the stated target.

The implementation is complete when the organization can reproduce the installation, identify the
owner of every component, and run at least one representative workflow end to end.
