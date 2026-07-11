# Security policy

## Supported versions

| Release | Security support |
|---|---|
| Public Beta v2.0 | Yes |
| Public Beta v1.1 | Best-effort historical support |
| Public Beta v1.0 | No; superseded |
| Modified or unpublished builds | No |

## Reporting a security issue

Do not publish recovery keys, private certificate material, account secrets, or personal information in an issue. Describe the affected public release, script, trust boundary, and reproducible behavior with sensitive values removed.

The toolkit intentionally modifies certificate trust, catalog registration, driver packages, AppX state, and boot-signing configuration. A behavior is not automatically a vulnerability merely because it is privileged; reports should identify an unintended trust, validation, or privilege boundary failure.
