# GitHub publishing guide

## Repository identity

Repository URL remains:

```text
DontDoMuch/LeGo1-graphic-driver-toolkit
```

Public Beta v4.5 deliberately keeps that historical URL while the repository serves as the multi-device public-beta proving ground. Long-term project/display branding is not finalized by this release.

## Publish Public Beta v4.5

1. Preserve all historical release records unchanged, especially `releases/public-beta-v4.0/**`.
2. Apply only the reviewed v4.5 documentation/publication-record patch.
3. Regenerate `REPOSITORY-SHA256-MANIFEST.txt` for the resulting repository tree.
4. Confirm the GitHub Release asset bytes exactly match the frozen v4.5 SHA-256.
5. Do **not** copy the executable toolkit into `releases/public-beta-v4.5/`; that folder is documentation-only.
6. Confirm `docs/COMPATIBILITY.md` lists only the three exact supported HWIDs and explicitly rejects inferred variants.
7. Confirm `docs/VERIFICATION.md` contains the exact AMD source and per-profile output identities.
8. Confirm no private Go S/Go 2 volunteer package, private evidence, certificate, key, or AMD binary is committed or uploaded.
9. Publish the GitHub Release as a pre-release while the project remains in Public Beta.

Suggested publication commit:

```text
Publish Public Beta v4.5 multi-device support
```

## GitHub Release

Tag:

```text
public-beta-v4.5
```

Title:

```text
Legion Go AMD 26.8.1 — Public Beta v4.5
```

Mark as:

```text
Pre-release: Yes
```

Attach exactly one custom toolkit asset:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.zip
```

Required SHA-256:

```text
B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C
```

Required size:

```text
132499 bytes
```

Do not upload AMD's official installer; users download it directly from AMD and the toolkit verifies its exact required bytes.

Use `releases/public-beta-v4.5/RELEASE-NOTES.md` as the factual base for the GitHub Release description.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs, workflow state, or field evidence archives;
- private Go S / Go 2 volunteer packages;
- internal regression/evidence archives;
- development snapshots presented as the public release.

## Provenance

The public asset is the exact final v4.5 candidate that passed the real Windows PowerShell 5.1 regression after the evidence-ZIP change. Protected package-internal v4.0 lineage identifiers are intentionally retained where changing them would add risk without changing public profile selection or release identity.
