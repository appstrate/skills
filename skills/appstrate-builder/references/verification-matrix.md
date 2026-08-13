# Verification matrix

Complete one row per target and important capability.

| Target | Component | Available | Installed | Enabled | Connected | Real test | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| local or cloud | package or service | yes or no | version | application | identity | result | run ID or check |

## Minimum evidence

- Identity: instance, organization, application, user, and role confirmed in the interface used.
- Package: canonical identifier, version, and expected files reread after import.
- Integration: required tools visible, minimum scopes, and correct account connected.
- Agent: resolved dependencies, representative input, terminal state, business output, and logs inspected.
- Parity: the same checks executed separately on local and cloud targets.

An untested item remains "configured" or "to verify," never "functional."
