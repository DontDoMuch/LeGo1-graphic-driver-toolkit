# Releases

## Naming convention

Public releases continue the existing sequence:

```text
Public Beta v1.0
Public Beta v1.1
Public Beta v2.0
Public Beta v2.1
Public Beta v3.0
Public Beta v3.1
```

Release tags use lowercase:

```text
public-beta-v3.1
```

Internal engineering labels such as RC2zk and RC2zp are not public release names.

## Current release

**Public Beta v3.1** is current. It targets AMD 26.7.1 and supersedes Public Beta v3.0.

## Release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip
SHA-256: ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
```

The AMD target belongs in release metadata and asset naming while the permanent repository identity remains Legion Go 1 Graphics Driver Toolkit.

## Publication records

Directories under `releases/` are immutable publication records.

Public Beta v3.1 uses:

```text
releases/public-beta-v3.1/
  README.md
  RELEASE-NOTES.md
  VALIDATION-SUMMARY.md
  PUBLIC-BETA-v3.1-ZIP-SHA256.txt
  TOOLKIT-SHA256SUMS.txt
  toolkit/
```

`toolkit/` contains the exact frozen Public Beta v3.1 executable and package-documentation snapshot. Required internal implementation/provenance identifiers are preserved where changing them would invalidate the tested package.

All earlier publication records, including `releases/public-beta-v3.0/`, remain unchanged.

## Rules

- Never edit a published executable in place.
- Functional corrections require a new public version and new hashes.
- Documentation-only clarification may be corrected when it does not alter or misrepresent the release asset.
- Do not commit AMD installers or extracted AMD binaries.
- Do not upload private logs, workflow state, evidence, certificates, or keys as release assets.
