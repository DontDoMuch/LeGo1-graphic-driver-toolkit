# GitHub publishing guide

## Repository identity

Repository URL remains:

```text
DontDoMuch/LeGo1-graphic-driver-toolkit
```

Public Beta v5.0 keeps that historical repository URL while the project serves as the multi-device public-beta proving ground.

## Publish Public Beta v5.0

1. Start from reviewed `main`.
2. Create branch `release/public-beta-v5.0`.
3. Preserve **all** historical release records unchanged.
4. Update current documentation and add the documentation-only v5.0 publication record under `releases/public-beta-v5.0/`.
5. Regenerate `REPOSITORY-SHA256-MANIFEST.txt` after all repository changes.
6. Confirm the GitHub Release asset bytes exactly match `4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E` and `135755` bytes.
7. Do **not** copy the executable toolkit into `releases/public-beta-v5.0/`; that folder is documentation-only.
8. Confirm `docs/COMPATIBILITY.md` lists only the three exact supported HWIDs.
9. Confirm `docs/VALIDATION.md` distinguishes Go 1 physical AMD 26.9.2 validation from Go S / Go 2 deterministic 26.9.2 build proof plus inherited v4.5.1 device-profile evidence.
10. Confirm the release notes include the final conditional optional source-path forwarding behavior and the `Public-Beta-v5.0` workflow identity.
11. Confirm no private volunteer package, evidence archive, certificate, key, log, workflow state, AMD binary, or installer is committed/uploaded.
12. Open PR `Publish Public Beta v5.0` targeting `main`; merge only after review/approval.
13. Publish the GitHub Release as a pre-release and attach the exact frozen ZIP separately.

Suggested publication commit:

```text
Publish Public Beta v5.0
```

## GitHub Release

Tag:

```text
public-beta-v5.0
```

Title:

```text
Legion Go AMD 26.9.2 — Public Beta v5.0
```

Mark as:

```text
Pre-release: Yes
```

Attach exactly one custom toolkit asset:

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
```

Required SHA-256:

```text
4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
```

Required size:

```text
135755 bytes
```

Do not upload AMD's official installer; users download it directly from AMD and the toolkit verifies its exact required bytes.

Use `releases/public-beta-v5.0/RELEASE-NOTES.md` as the factual base for the GitHub Release description.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs, workflow state, or field evidence archives;
- private volunteer packages;
- internal regression/evidence archives;
- development snapshots presented as the public release.

## Provenance

The public asset identity is frozen at `4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E` / `135755` bytes. It contains the final v5.0 public entry-gate behavior together with the v5.0 Stage 1-4 workflow identity. Public Beta v4.5.1 and all earlier release records remain immutable historical evidence.
