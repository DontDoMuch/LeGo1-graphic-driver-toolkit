# GitHub publishing guide

## Repository identity

Repository:

```text
LeGo1-graphic-driver-toolkit
```

Description:

```text
Compatibility-focused AMD graphics-driver toolkit for the original Lenovo Legion Go (Legion Go 1).
```

## Publish Public Beta v4.0

1. Preserve all existing historical release records unchanged.
2. Apply only the reviewed v4.0 documentation/publication-record patch.
3. Confirm the GitHub Release asset bytes exactly match the frozen Public Beta v4.0 SHA-256.
4. Do **not** copy the executable toolkit into the repository's `releases/public-beta-v4.0/` directory; that folder is documentation-only for this release.
5. Confirm the required official AMD source identity in `docs/VERIFICATION.md`.
6. Replace `REPOSITORY-SHA256-MANIFEST.txt` with the regenerated publication manifest supplied in the docs patch; it is repository-integrity metadata and contains no executable changes.
7. Confirm repository documentation identifies Public Beta v4.0 / AMD 26.8.1 as current.
8. Publish the GitHub Release as a pre-release while the project remains in Public Beta.

Suggested documentation commit:

```text
Publish Public Beta v4.0 documentation for AMD 26.8.1
```

## GitHub Release

Tag:

```text
public-beta-v4.0
```

Title:

```text
Legion Go 1 Graphics Driver Toolkit — Public Beta v4.0
```

Mark as:

```text
Pre-release: Yes
```

Attach exactly the custom toolkit asset:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip
```

Required SHA-256:

```text
8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
```

Do not upload AMD's official installer; users download it directly from AMD and the toolkit verifies its exact required bytes.

Use `releases/public-beta-v4.0/RELEASE-NOTES.md` as the factual base for the GitHub Release description. The publication bundle also provides a ready-to-paste release body with a fail-closed verification block and BitLocker / Device Encryption warning.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs, workflow state, or field evidence archives;
- internal audit/test archives;
- development snapshots presented as the public release.

## Provenance

The public asset is the exact field-validated final v4.0 candidate bytes under the public filename. Protected package-internal engineering identifiers are intentionally left untouched where changing them would invalidate tested byte identity or parser/type contracts.
