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
Public Beta v4.5
Public Beta v4.5.1
Public Beta v5.0
```

Current release tag:

```text
public-beta-v5.0
```

## Current release

**Public Beta v5.0** is current. It targets AMD Adrenalin 26.9.2 / display `32.0.32015.2008`, supports the three exact hardware profiles established by v4.5, and includes conditional handling of optional public entry-gate source-path parameters.

## Release asset

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
```

The AMD target belongs in release metadata and asset naming. The existing repository URL remains `LeGo1-graphic-driver-toolkit` for continuity during the multi-device public-beta phase.

## Publication record

Public Beta v5.0 uses a documentation-only repository record:

```text
releases/public-beta-v5.0/
  README.md
  RELEASE-NOTES.md
  VALIDATION-SUMMARY.md
  PUBLIC-BETA-v5.0-ZIP-SHA256.txt
```

The executable toolkit is distributed as the immutable GitHub Release asset rather than duplicated under the repository release folder.

All prior release directories remain immutable historical records.

## Rules

- Never edit a published executable asset in place.
- Functional corrections require a new public version and new hash.
- Documentation clarification must not misrepresent the frozen asset.
- Do not commit AMD installers or extracted AMD binaries.
- Do not upload private volunteer packages, private logs, workflow state, evidence archives, private certificates, or keys as public release assets.
