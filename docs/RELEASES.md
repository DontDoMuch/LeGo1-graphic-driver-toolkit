# Releases

## Naming convention

Public releases continue the existing sequence:

```text
Public Beta v1.0
Public Beta v1.1
Public Beta v2.0
Public Beta v2.1
Public Beta v3.0
```

Release tags use lowercase:

```text
public-beta-v3.0
```

Internal engineering labels such as RC2zk are not public release names.

## Current release

**Public Beta v3.0** is current. It targets AMD 26.7.1 and supersedes Public
Beta v2.1.

## Release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip
```

The AMD target belongs in release metadata and asset naming while the
permanent repository identity remains Legion Go 1 Graphics Driver Toolkit.

## Publication records

Directories under `releases/` are immutable publication records.

Public Beta v3.0 uses:

```text
releases/public-beta-v3.0/
  README.md
  RELEASE-NOTES.md
  VALIDATION-SUMMARY.md
  PUBLIC-BETA-v3.0-ZIP-SHA256.txt
  TOOLKIT-SHA256SUMS.txt
  toolkit/
```

`toolkit/` contains the byte-identical final executable snapshot. Internal
candidate labels are preserved only where required for provenance.

## Rules

- Never edit a published executable in place.
- Functional corrections require a new public version and new hashes.
- Documentation-only clarification may be corrected when it does not alter or
  misrepresent the release asset.
- Do not commit AMD installers or extracted AMD binaries.
