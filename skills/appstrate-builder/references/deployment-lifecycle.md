# Appstrate deployment lifecycle

## Framing

Define the sponsor, AI architects, target teams, authorized data, and a measurable outcome. Choose a
use case frequent enough to produce a signal but bounded enough to test safely.

## Pilot

Create an application limited to a small group. Install required integrations and skills, assemble
the agent, then test it with representative data. Document permissions, limits, and the owner of each
component.

## Preproduction

Test access errors, missing data, realistic volumes, and retries. Inspect logs, costs, external
effects, and the rollback procedure. Obtain human approval before autonomous writes or recurring
scheduling.

## Deployment

Assign the application to the intended teams, train users on the expected outcome and escalation path,
then monitor the first runs. Retain the exact versions deployed.

## Operations

Periodically review connections, permissions, errors, costs, and usage. Correct the shared method when
a rule is reusable. Correct the agent when a parameter belongs only to its deployment.
