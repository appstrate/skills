# Appstrate Skills

This repository publishes portable skills for people who design, configure, and operate Appstrate
inside an organization. The same source folders work in coding agents and can be imported into an
Appstrate organization.

These skills are optional. An Appstrate instance does not need to ship them by default. Each
organization can install the skills it needs under its own scope.

## Available skills

| Skill | Purpose |
| --- | --- |
| [`appstrate-builder`](skills/appstrate-builder/) | Audit, design, deploy, and validate an Appstrate implementation |
| [`copilot`](skills/copilot/) | Discover useful automations with users and choose the right execution form |
| [`connector-choice`](skills/connector-choice/) | Select the best access path for a service |
| [`agent-authoring`](skills/agent-authoring/) | Create, update, and prove an Appstrate agent |
| [`skill-authoring`](skills/skill-authoring/) | Create or improve a reusable method |
| [`web-search`](skills/web-search/) | Run source-backed web research through Appstrate |
| [`appstrate-google-workspace`](skills/appstrate-google-workspace/) | Configure and diagnose Google Workspace MCP servers |

## Why business methods remain references

The 14 business methods included in this repository are internal references of `skill-authoring`.
They cover code review, content writing, CRM updates, customer research, data analysis, document
extraction, email replies, incremental digests, meeting preparation, meeting minutes, grounded
answers, web research, sprint reports, and request triage.

They are starting points for organization-owned skills, not standalone packages. `skill-authoring`
loads only the relevant reference and adapts it when no suitable organizational method exists. This
avoids installing generic methods that do not match the organization's processes, access, or quality
criteria.

## Install in a coding agent

The installer installs one skill at a time:

```bash
curl -fsSL https://raw.githubusercontent.com/appstrate/skills/main/install.sh \
  | bash -s appstrate-builder
```

Options are available for Codex, Claude Code, Cursor, Google Antigravity, and a universal project
path. Run `bash install.sh --help` from a local clone for the complete usage reference.

## Import into Appstrate

Build the distributable collection:

```bash
bash scripts/build-appstrate-skills.sh
```

Extract the generated outer ZIP, then import each ZIP from its `packages` directory separately. Every
package places `SKILL.md` at its archive root and can be imported independently through the Appstrate
interface, MCP server, or CLI. The outer ZIP is a sharing bundle and is not itself an importable skill.

Confirm the target organization before every mutation and retain the organization scope assigned to
each imported package.

## Companion skills and compatibility

The guides refer to companion skills by unscoped name. In Appstrate, resolve the accessible skill and
retain its canonical scoped identifier. In a coding agent, use the local skill catalog.

Every skill uses the standard `SKILL.md` format and discovers current contracts through the Appstrate
MCP server or CLI API client. The collection does not depend on a distinction between system skills
and ordinary skills.

## Contributing

Open an issue before proposing a new first-party skill so its scope can be aligned with the existing
collection. A first-party skill should cover an Appstrate primitive or a reusable method that does not
already have an owner. Test representative triggering, near-misses, and every documented command
before opening a pull request.

Before creating a method, `skill-authoring` searches the organization, official external collections,
and community directories for a reusable skill. Community packages remain in their own repositories
under their own licenses and are reviewed before import instead of being copied into a static root
catalog.

See [external skill discovery](skills/skill-authoring/references/external-skill-discovery.md) for the
maintained search order, preferred official sources, and candidate review criteria.

## License and provenance

First-party skills use the Apache 2.0 license. Adapted components retain the notices stored in their
skill directory.
