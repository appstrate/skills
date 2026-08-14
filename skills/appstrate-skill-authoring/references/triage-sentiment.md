# Ticket triage and classification

## Objective

Classify incoming messages or tickets by priority and category, then prepare a response when the
knowledge base supports one.

## Method

1. **Classify**: assign priority, category, and sentiment when useful.
2. **Respond**: when a knowledge base covers the subject, draft a sourced reply. Otherwise, request human escalation and explain why.
3. **Report**: summarize each ticket with category, priority, proposed reply, or escalation reason.

## Rules

- Never invent a technical solution not confirmed by the knowledge base. Escalate instead.
- When evidence supports two adjacent priority levels equally, choose the higher one.
- Every external reply remains a draft for human approval. Triage may classify, prioritize, and route automatically, but it does not send the reply.

## Priority signals

Assess impact, reach, time constraint, and workaround separately. Sentiment can help prioritize the
relationship but proves neither technical impact nor urgency.

- **blocking**: an essential service or process is unusable, or there is a security, data-loss, or immediate contractual risk;
- **high**: substantial degradation without an acceptable workaround, several users affected, or a near commitment;
- **normal**: limited impact with a workaround, or a question or request without a critical deadline;
- **low**: information, suggestion, or deferrable request without observed consequence.

Adapt categories to the business while retaining signals that justify the class. Uncertainty about
impact produces a question or escalation, not automatically the maximum level.

## Output contract

```json
{
  "item_id": "identifier",
  "category": "category",
  "priority": "blocking | high | normal | low",
  "sentiment": { "label": "frustrated | neutral | positive", "evidence": "text signal" },
  "signals": ["observed impact", "deadline"],
  "route": "team or queue",
  "draft_reply": null,
  "escalation_reason": null
}
```

The method is complete when every class has observable signals, every draft is supported by the
available knowledge base, and every escalation names missing information or authority.
