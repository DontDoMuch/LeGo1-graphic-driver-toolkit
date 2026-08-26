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
Public Beta v4.0
```

Release tags use lowercase:

```text
public-beta-v4.0
```

Internal engineering labels are not public release names.

## Current release

**Public Beta v4.0** is current. It targets AMD Adrenalin 26.8.1 / display `32.0.31041.1004` and supersedes Public Beta v3.1.

## Release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip
SHA-256: 8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
Size: 154588 bytes
```

The AMD target belongs in release metadata and asset naming while the permanent repository identity remains **Legion Go 1 Graphics Driver Toolkit**.

## Publication record

Public Beta v4.0 uses a documentation-only repository record:

```text
releases/public-beta-v4.0/
  README.md
  RELEASE-NOTES.md
  VALIDATION-SUMMARY.md
  PUBLIC-BETA-v4.0-ZIP-SHA256.txt
```

The executable toolkit is distributed as the immutable GitHub Release asset rather than duplicated under the repository release folder. The package's own internal `SHA256SUMS.txt`, package audit, release notes, and validation summary remain inside that exact ZIP.

All historical release directories remain unchanged.

## Rules

- Never edit a published executable asset in place.
- Functional corrections require a new public version and new hash.
- Documentation clarification must not misrepresent the frozen asset.
- Do not commit AMD installers or extracted AMD binaries.
- Do not upload private logs, workflow state, evidence archives, private certificates, or keys as release assets.
