# Appstrate Skills, archive

This repository no longer distributes an active Appstrate agent skill. The former `appstrate` skill is retained under `_archives/appstrate` for historical reference only and must not be installed or exposed.

**License:** Apache 2.0 (first-party skills). Community links on this page point to their own licenses.

## Active skills

None. The installer remains in the repository for historical compatibility, but there is no supported skill to install.

## Community skills

A curated awesome-list of skills that work well alongside Appstrate, maintained by the community: **[COMMUNITY.md](./COMMUNITY.md)**.

Open a PR editing that file to add yours — no gate-keeping, just keep it related and linkable.

## Supported coding agents

| Agent | Install path (per-user) | Install path (per-project) |
|---|---|---|
| [Claude Code](https://docs.claude.com/en/docs/claude-code) | `~/.claude/skills/<name>/` | `.claude/skills/<name>/` |
| [Cursor](https://cursor.com/docs/skills) | — | `.cursor/skills/<name>/` |
| [Google Antigravity](https://antigravity.google/docs/skills) | `~/.gemini/antigravity/skills/<name>/` | `.agent/skills/<name>/` |
| Windsurf, Aider, any AGENTS.md-aware agent | — | `.agent/skills/<name>/` (via [OpenSkills](https://github.com/numman-ali/openskills)) |

## What is an Agent Skill?

A directory with a `SKILL.md` file. The markdown has YAML frontmatter (`name`, `description`) that tells your agent when to use it, followed by instructions, references, and scripts the agent can load on demand. Standard introduced by [Anthropic](https://github.com/anthropics/skills); now supported (with minor path variations) by every major coding agent.

The `description` field matters: that's what your agent reads to decide whether to load the skill for a given request. Keep it rich, keyword-dense, and specific to triggers.

## Contributing

See **[CONTRIBUTING.md](./CONTRIBUTING.md)** — two paths: add a first-party skill (PR a folder under `skills/`) or link your own repo (PR a line in `COMMUNITY.md`).
