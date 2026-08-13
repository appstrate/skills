# Contributing

Two ways to contribute.

## 1. Link your skill in `COMMUNITY.md`

If your skill lives in your own repo (anywhere), just add a line to [`COMMUNITY.md`](./COMMUNITY.md):

1. Fork this repo
2. Add one line under the right section, following the format: `- [your-repo-path](https://github.com/…): one-sentence description`
3. Open a PR

Rules:

- The skill must be related to Appstrate (drives agents via its API, authors AFPS packages, pairs with the runtime, etc.) or be a general-purpose skill that's useful alongside Appstrate.
- The linked repo must contain a valid `SKILL.md` (YAML frontmatter + markdown body).
- Keep the description factual. No adjectives like "amazing", "powerful", "revolutionary".

We do not gate-keep content. PRs get merged unless the link is broken or the description is marketing fluff.

## 2. Add a first-party skill under `skills/`

First-party skills are maintained by the Appstrate team and ship under Apache 2.0. Bar is higher: we commit to keeping them up-to-date as the platform evolves.

Open an issue **before** writing a new first-party skill so we can align on scope. Typical first-party scope: covers an Appstrate primitive (CLI, AFPS packaging, multi-tenancy) that most users will hit.

### Skill folder layout

```
skills/<name>/
├── SKILL.md          # required: YAML frontmatter + instructions
├── references/       # optional: deep-dive docs loaded on demand
│   ├── setup.md
│   └── ...
├── scripts/          # optional: executable helpers
│   └── pack.sh
└── templates/        # optional: scaffolding files
    └── manifest.json
```

### `SKILL.md` frontmatter

```markdown
---
name: <short-machine-name>
description: <long, keyword-rich description. Names CLI commands, API routes, file formats, and any trigger terms. Max ~400 chars. The agent reads this to decide when to load the skill.>
---

# <Human title>

<one-paragraph summary>

## <sections: see existing skills for structure>
```

### Tone

- Second-person imperative ("Run `appstrate api …`", "Append a tag to the list"). Not first-person ("I would recommend").
- Link to `references/<file>.md` for anything longer than a short section. The agent loads references only when relevant, which saves context.
- Keep examples copy-pasteable. Prefer real command output over synthetic mockups.

### Testing

Before opening a PR, drop the skill folder into your own agent's skills directory and verify:

- The agent picks it up (you see the skill name in `/skills` or equivalent).
- The description triggers loading on a representative prompt.
- Each documented command actually works on a current Appstrate instance.

## License

By contributing, you agree your contribution is licensed under Apache 2.0 (for first-party skills in this repo). Community skills keep their own license; we only link to them.
