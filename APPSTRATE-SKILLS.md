# Appstrate Skills

This collection helps AI architects design, configure, and deploy Appstrate inside an organization.
It contains seven independent, portable skills.

## Contents

1. `skill-authoring`, including 14 embedded method references
2. `connector-choice`
3. `web-search`
4. `appstrate-google-workspace`
5. `agent-authoring`
6. `copilot`
7. `appstrate-builder`

This import order makes the specialized guides available before the routing skills look for them.
It is not a package dependency graph.

## Why methods remain references

The method library covers code review, content writing, CRM updates, customer research, data
analysis, document extraction, email replies, incremental digests, meeting preparation, meeting
minutes, grounded answers, web research, sprint reports, and ticket triage.

These methods are starting points for organization-owned skills. Shipping all 14 as standalone
skills would expose generic methods even when they do not match an organization's processes, access,
or quality criteria. `skill-authoring` loads only the relevant reference, adapts it, and creates an
organization-owned skill only when no suitable method already exists.

## Import into Appstrate

Build the distributable archive:

```bash
bash scripts/build-appstrate-skills.sh
```

Extract the outer ZIP. Import each ZIP in its `packages` directory separately through the Appstrate
interface, MCP server, or CLI, according to the operations exposed by the target instance. Confirm
the target before every mutation and record the organization scope assigned during import.

The outer ZIP is a sharing bundle, not a single skill package. Only the ZIP files inside `packages`
are directly importable as individual skills.

## Install in a coding agent

Copy each desired folder from `skills` into the coding agent's supported skill directory. Preserve
the complete folder so references, scripts, licenses, and notices remain available.

## Resolve companion skills

The guides refer to companion skills by unscoped name. In Appstrate, resolve the accessible skill
and then retain its canonical `@scope/name` identifier. In a coding agent, use the local skill
catalog. No guide assumes the `@appstrate` scope exists.

## Compatibility

Every skill uses the standard `SKILL.md` format and discovers live contracts through the Appstrate
MCP server or the CLI API client. The collection does not depend on experimental assistant-skill
markers or on a distinction between system skills and ordinary skills.
