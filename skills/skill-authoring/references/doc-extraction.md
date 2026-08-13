# Structured field extraction

## Objective

Extract relevant fields from a document into structured data while flagging uncertainty and omissions.

## Method

1. **Read**: use the agent's current document extraction or reading capability. If none makes the document readable, report the missing prerequisite instead of inventing content.
2. **Extract**: collect fields appropriate to the document type, such as vendor, amount, currency, due date, and number for invoices.
3. **Verify**: flag detectable inconsistencies, such as totals that do not match line items, duplicate numbers, or unusual dates when history is available.
4. **Report**: return a structured object plus anomalies and missing fields. Never fill a gap with an invented value.

## Rules

- Leave an unreadable or absent field empty and give the reason.
- Always report confidence for ambiguous fields.
- Never silently accept a detected anomaly. Include it in output.

## Extraction schema

Define expected fields before reading. Keep four elements per field: normalized value, source text or
region, status, and confidence. Allowed statuses are `present`, `absent`, `illegible`, and `conflict`.
Confidence never repairs an absent status.

```json
{
  "field": "total_due",
  "value": { "amount": "1250.00", "currency": "CAD" },
  "evidence": "Total due $1,250.00",
  "status": "present",
  "confidence": "high"
}
```

Normalize dates, numbers, and currencies in `value`, then preserve the read form in `evidence`. Add a
page or location for multi-page documents. Verify calculable invariants, such as subtotal plus taxes
equaling total within the currency's rounding tolerance.

## Output contract

Return document identity, structured fields, anomalies, and fields requiring human validation. Keep
both conflicting values with their evidence rather than overwriting either.

Extraction is complete when every requested field has an explicit status, every ambiguous value
includes evidence, and all applicable arithmetic checks have run.
