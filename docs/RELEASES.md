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
```

Current release tag:

```text
public-beta-v4.5.1
```

Internal engineering labels are not public release names.

## Current release

**Public Beta v4.5.1** is current. It is a compatibility/recovery hotfix over v4.5, targets AMD Adrenalin 26.8.1 / display `32.0.31041.1004`, and supports exactly the same three validated profiles: Go 1 Z1 Extreme, Go S Z1 Extreme, and Go 2 Z2 Extreme.

## Release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
SHA-256: 910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
Size: 132857 bytes
```

The AMD target belongs in release metadata and asset naming. The existing repository URL remains `LeGo1-graphic-driver-toolkit` for continuity during the multi-device public-beta phase; long-term project branding is intentionally not frozen by v4.5.1.

## Publication record

Public Beta v4.5.1 uses a documentation-only repository record:

```text
releases/public-beta-v4.5.1/
  README.md
  RELEASE-NOTES.md
  VALIDATION-SUMMARY.md
  PUBLIC-BETA-v4.5.1-ZIP-SHA256.txt
```

The executable toolkit is distributed as the immutable GitHub Release asset rather than duplicated under the repository release folder.

Public Beta v4.5 remains an immutable historical release record at `releases/public-beta-v4.5/**`; it is not rewritten by the v4.5.1 publication. All earlier release directories remain unchanged as well.

## Rules

- Never edit a published executable asset in place.
- Functional corrections require a new public version and new hash.
- Documentation clarification must not misrepresent the frozen asset.
- Do not commit AMD installers or extracted AMD binaries.
- Do not upload private volunteer packages, private logs, workflow state, evidence archives, private certificates, or keys as public release assets.
