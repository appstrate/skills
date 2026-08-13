# CRM update and pipeline follow-up

## Objective

Enrich a lead, log an interaction, or flag an opportunity that needs attention in any connected CRM.

## Method

1. **Identify**: find or create the relevant contact, company, or opportunity. Search first to prevent duplicates.
2. **Enrich**: complete available fields from accessible sources, such as email, web, or forms.
3. **Log**: after an interaction, save a short summary in the record, not a raw transcript.
4. **Detect stagnation**: when last-activity data exists, flag opportunities with unusually long inactivity and propose a follow-up.

## Rules

- Never create a duplicate without first searching for the existing record.
- Do not overwrite a populated field unless the new value is demonstrably more reliable.
- Ground every proposed follow-up in the actual previous interaction, not a generic template.

## Identity resolution

Search first using a strong identifier, such as an exact email, CRM ID, or confirmed domain. A name,
same-name company, or approximate match is insufficient for merging or updating. Return candidates and
the missing discriminating fact instead.

Classify each proposed value:

- **confirmed**: present in a direct source or declared by the person;
- **inferred**: derived from several consistent signals;
- **conflicting**: credible sources disagree.

Write automatically only a confirmed value that is fresher than the existing one. Put inferences and
conflicts in notes or in output awaiting validation.

## Output contract

```json
{
  "record": "identifier or candidate",
  "changes": [{ "field": "field", "before": null, "after": "value", "source": "evidence" }],
  "interaction_summary": "short dated summary",
  "follow_up": { "needed": true, "reason": "observed signal", "suggested_action": "action" },
  "conflicts": []
}
```

Adapt keys to the live CRM while preserving separation among applied changes, evidence, conflicts,
and follow-up proposals. The method is complete when every mutation targets an unambiguously resolved
record and has traceable evidence.
