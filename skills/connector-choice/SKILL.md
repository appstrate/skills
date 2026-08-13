---
name: connector-choice
description: Choose how an agent should connect to a service. Load this guide when multiple connectors or access modes are plausible, or when no adequate connector is installed. It compares live candidates by required coverage, connection effort, provenance, and least privilege.
---

# Choose a connector

Select the access path that covers the real requirement with the least configuration and privilege.
The live catalog owns technical details. This guide owns the decision.

When this guide recommends another skill, resolve its unscoped name in the accessible skill catalog.
Do not assume that it is installed by default or belongs to the `@appstrate` scope.

## 1. Define the requirement

List the required actions, data read or written, account, and frequency. Separate mandatory
capabilities from conveniences. A connector that covers nine actions out of ten still fails when the
tenth action produces the required outcome.

This step is complete when every mandatory capability can be tested against a candidate.

## 2. Compare live candidates

Discover available integrations, then describe the plausible candidates. Evaluate them in this order:

1. coverage of mandatory actions;
2. connection or activation state for the application;
3. permissions and destinations actually exposed;
4. user effort to connect and maintain access;
5. connector provenance and maintenance.

Prefer a provider-maintained remote MCP integration when it covers the requirement and avoids a
customer-managed developer application. Prefer an API integration when it exposes a mandatory
capability missing from MCP or offers a materially better permission boundary. A package name is not
proof of transport, capabilities, or trust.

This step is complete when one candidate dominates on mandatory capabilities and no unresolved
difference would change the choice.

## 3. Decide or ask

Choose directly when one candidate clearly dominates. Present at most two options when the answer
depends on a human preference, such as faster connection versus broader coverage. State the concrete
tradeoff and recommend one.

Then follow the connection workflow exposed by Appstrate. Enter secrets only in the hosted connection
surface. If no connector fits, define the gap as a separate package requirement. Load an authoring
guide only when it exists in the accessible skill catalog. Otherwise propose the package work without
inventing a guide, operation, or capability.

The decision is complete when the selected connector and rationale are explicit, or when a precise
human decision or missing capability blocks the next step.
