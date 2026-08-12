# Skill portability

A portable skill contains a `SKILL.md` with an unscoped name and a triggering description. Its
relative links remain inside its directory. It assumes no organizational scope, application
identifier, or experimental operation.

## In a coding agent

Install the complete directory in the agent's recognized skill catalog. Keep references and scripts
relative to `SKILL.md`. Verify discovery with a representative trigger request.

## In Appstrate

Create one archive per skill with `SKILL.md` at its root. Import the archive into the target
organization, then record its assigned `@scope/name` identifier. Assign the skill to agents or
applications that need it through operations exposed by the instance.

## Across organizations

Share sources or archives without secrets, tokens, internal identifiers, or company-specific
configuration. Each organization imports under its own scope and recreates its connections. A skill
can describe an access requirement but does not carry OAuth identifiers or grants.

## Companion skills

Refer to another skill by its unscoped name. At runtime, resolve the candidate that is actually
accessible and retain its canonical identifier. A missing companion skill is a dependency to install,
not permission to invent its content.
