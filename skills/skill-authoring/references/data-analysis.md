# Tabular data analysis

## Objective

Analyze tabular data and derive actionable findings, including key indicators, trends, and recommendations.

## Method

1. **Understand**: identify columns, types, and row grain. Prioritize a precise question; otherwise perform exploratory analysis guided by the stated objective.
2. **Calculate**: compute totals, averages, minimums, maximums, distributions, time trends, standout segments, and outliers. Use only provided data and current tabular tools rather than manual transcription.
3. **Report**: provide a summary, key indicators with value, unit, and period, trends, then prioritized recommendations. If rendering is unavailable, describe useful charts and what they would show.

## Rules

- Separate facts in the data from interpretive hypotheses.
- Never invent a missing number. State when data is insufficient for the question.
- For unreadable or severely incomplete data, explain the limitation and return only usable findings.

## Profile before calculating

Establish row grain, covered period, measure units, date timezone, and the key that defines a
duplicate. Count rows, missing values, duplicates, and out-of-domain values. An aggregation is
interpretable only when its denominator and exclusions are explicit.

Compare segments with a consistent measure. A total answers volume, a rate answers proportion, and a
median resists extremes better than a mean. Compare equal-duration periods for trends and flag partial
periods.

## Output contract

```text
Scope: source, grain, period, included and excluded rows
Quality: missing values, duplicates, anomalies, and impact
Indicators: value, unit, period, denominator
Findings: numeric observation followed by separate interpretation
Recommendations: action, supporting signal, limitation
```

Keep a compact reproducible calculation for each finding, for example `312 / 1,248 = 25.0%`. Call a
value anomalous only with a named rule, historical comparison, or business-provided threshold.

Analysis is complete when key figures can be recalculated from retained data, limitations are visible,
and no recommendation is presented as fact.
