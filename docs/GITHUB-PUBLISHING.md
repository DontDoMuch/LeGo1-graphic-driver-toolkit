# GitHub publishing guide

## Repository identity

Repository URL remains:

```text
DontDoMuch/LeGo1-graphic-driver-toolkit
```

Public Beta v4.5.1 deliberately keeps that historical URL while the repository serves as the multi-device public-beta proving ground.

## Publish Public Beta v4.5.1

1. Start from the reviewed `main` snapshot at `b7c703e4d5cc60eedc84cc02e7050ce3cffe60f9`.
2. Create branch `release/public-beta-v4.5.1`.
3. Preserve **all** historical release records unchanged, including every byte under `releases/public-beta-v4.5/**`.
4. Apply only the reviewed 18-file v4.5.1 documentation/publication-record delta.
5. Regenerate `REPOSITORY-SHA256-MANIFEST.txt` after all documentation changes.
6. Confirm the GitHub Release asset bytes exactly match `910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75` and `132857` bytes.
7. Do **not** copy the executable toolkit into `releases/public-beta-v4.5.1/`; that folder is documentation-only.
8. Confirm `docs/COMPATIBILITY.md` still lists only the three exact supported HWIDs.
9. Confirm `docs/VALIDATION.md` distinguishes inherited v4.5 physical results from v4.5.1 hotfix/recovery validation and does not claim a missing final volunteer evidence ZIP.
10. Confirm no private volunteer package, evidence archive, certificate, key, log, workflow state, AMD binary, or installer is committed/uploaded.
11. Open PR `Publish Public Beta v4.5.1 hotfix` targeting `main`. Do not merge without separate approval.
12. After an approved merge, publish the GitHub Release as a pre-release and attach the exact frozen ZIP separately.

Suggested publication commit:

```text
Publish Public Beta v4.5.1 hotfix
```

## GitHub Release

Tag:

```text
public-beta-v4.5.1
```

Title:

```text
Legion Go AMD 26.8.1 — Public Beta v4.5.1
```

Mark as:

```text
Pre-release: Yes
```

Attach exactly one custom toolkit asset:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
```

Required SHA-256:

```text
910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
```

Required size:

```text
132857 bytes
```

Do not upload AMD's official installer; users download it directly from AMD and the toolkit verifies its exact required bytes.

Use `releases/public-beta-v4.5.1/RELEASE-NOTES.md` as the factual base for the GitHub Release description.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs, workflow state, or field evidence archives;
- private Go S / Go 2 volunteer packages;
- internal regression/evidence archives;
- development snapshots presented as the public release.

## Provenance

The public asset identity is frozen at `910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75` / `132857` bytes. It contains the v4.5.1 catalog-prestate fix, final rollback re-proof, fresh workflow namespace, and corrected CMD target. It does not contain a `PSModulePath` sanitizer. Public Beta v4.5 remains immutable historical evidence.
