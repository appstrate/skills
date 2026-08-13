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

The 14 business methods included in this repository are internal references of `skill-authoring`.
They provide authoring material when an organization needs a method. They are not distributed as
standalone skills.

See [`APPSTRATE-SKILLS.md`](APPSTRATE-SKILLS.md) for installation and packaging instructions.

## Install in a coding agent

The installer installs one skill at a time:

```bash
curl -fsSL https://raw.githubusercontent.com/appstrate/skills/main/install.sh \
  | bash -s appstrate-builder
```

Options are available for Codex, Claude Code, Cursor, Google Antigravity, and a universal project
path. Run `bash install.sh --help` from a local clone for the complete usage reference.

## Import into Appstrate

Build the collection, then import each ZIP from the generated `packages` directory. Every package
places `SKILL.md` at the archive root and can be imported independently into the target organization.

```bash
bash scripts/build-appstrate-skills.sh
```

## Community skills

See [`COMMUNITY.md`](COMMUNITY.md) for community-maintained skills that work with Appstrate.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) to propose a first-party skill or list a community skill.

First-party skills use the Apache 2.0 license. Adapted components retain the notices stored in their
skill directory.
