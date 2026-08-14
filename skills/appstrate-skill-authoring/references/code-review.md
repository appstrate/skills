# Structured code review

## Objective

Review a code change and produce actionable feedback categorized by severity, not a general judgment.

## Method

1. **Read**: understand the change's intent from the pull request and linked issue before judging the code.
2. **Analyze**: find likely bugs, security risks, regressions, project convention violations, and useful simplifications. Ignore pure style when a formatter or linter already owns it.
3. **Report**: group comments by severity, locate each by file and line, and explain the reason rather than only requesting a change.

## Rules

- Always name the concrete risk and scenario. A comment without them is not useful.
- Do not block on stylistic preferences unsupported by a project convention.
- Explicitly report missing tests for risky changes without inventing test results.

## Two required passes

Perform two distinct reads so compliance and usefulness remain separate:

1. **Contract**: does the change satisfy the request, including edge cases and expected evidence?
2. **Standards**: does it follow explicit repository rules and the boundaries of affected modules?

A repository rule is blocking only when written or demonstrated by a stable convention. Personal
preference remains a suggestion.

## Severity

- **Blocking**: corruption, vulnerability, data loss, broken primary contract, or impossible deployment.
- **Must fix**: incorrect behavior in a realistic scenario, regression, or debt that makes the next change unsafe.
- **Suggestion**: useful simplification without an observable defect today.

Every finding follows this pattern: `severity`, `file:line`, reproducible scenario, consequence,
minimum correction. If no finding survives this test, explicitly say the review found none.

## Output contract

```text
Verdict: ready | changes required

Blocking
- [file:line] Scenario, consequence, correction.

Must fix
- ...

Evidence checked
- tests run;
- untested surfaces and reason.
```

The review is complete when every changed file is connected to the need, each finding describes a
concrete failure, and executed checks are distinguished from assumptions.
