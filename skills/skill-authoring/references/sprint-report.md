# Team progress report

## Objective

Produce a structured status report covering progress, blockers, and next steps from tickets, pull
requests, and tasks in a defined period.

## Method

1. **Scope**: determine the period and project or team. Use the previous working day for a standup or the current sprint for a sprint report.
2. **Collect**: retrieve closed, active, and blocked tickets plus open and merged pull requests through available integrations.
3. **Synthesize**: prioritize impact and blockers over a flat ticket list. Identify recurring blockers.
4. **Report**: structure the output as completed, in progress, blocked, and next steps.

## Rules

- Keep a standup report readable in under a minute.
- Name a blocker's cause when known instead of only saying "waiting."
- Do not infer status unsupported by data. Inactivity alone does not prove a blocker.

## Normalization

Fix the window with exact dates and define scope by team, project, or sprint. Link a pull request to its
ticket through stable references to avoid counting the same result twice. A closed ticket measures
activity, not necessarily delivered impact. Describe impact only when a source connects it to a user,
metric, or objective.

Classify an item as:

- **completed** when the source confirms a terminal state within the window;
- **in progress** when activity or current state confirms it;
- **blocked** only when a blocker or dependency is explicitly reported;
- **needs clarification** when sources conflict or are too old.

## Output contract

```text
Scope: team, project, period, consulted sources
Delivered outcomes: outcome, known impact, references
In progress: next step and known owner
Blockers: cause, duration, decision or help required
Risks and variances: affected objective, evidence
Next period: no more than three priorities
```

Add status counts only when scope and deduplication are reliable. The method is complete when every
reported item has a source reference, no work is counted twice, and blockers remain separate from
mere inactivity.
