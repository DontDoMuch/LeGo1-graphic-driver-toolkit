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

## Publish Public Beta v3.1

1. Preserve the existing repository and all historical release records.
2. Add only `releases/public-beta-v3.1/` for the new executable publication record.
3. Update current-version documentation from Public Beta v3.0 to v3.1 where required.
4. Confirm `releases/public-beta-v3.1/toolkit/` is byte-identical to the frozen release ZIP contents.
5. Confirm `TOOLKIT-SHA256SUMS.txt` and the ZIP's internal `SHA256SUMS.txt`.
6. Regenerate and confirm `REPOSITORY-SHA256-MANIFEST.txt`.
7. Commit and push as one atomic publication change.

Commit:

```text
Publish Public Beta v3.1 for AMD 26.7.1
```

## GitHub Release

Tag:

```text
public-beta-v3.1
```

Title:

```text
Legion Go 1 Graphics Driver Toolkit — Public Beta v3.1
```

Attach exactly one custom asset:

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip
```

SHA-256:

```text
ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
```

Use `releases/public-beta-v3.1/RELEASE-NOTES.md` as the release-description base. Add the download hash, required official AMD source, launch steps, hardware scope, and validation summary from the v3.1 publication record.

Publish the release rather than leaving it as a draft. Keep it marked as a **pre-release** while the project remains in the Public Beta sequence.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs, workflow state, or field evidence;
- internal publication-audit archives;
- unvalidated development snapshots presented as public releases.

## Provenance note

The corrected v3.1 package preserves required RC2zp implementation identifiers. The first unpublished broad substitution attempt changed internal type identifiers and was rejected by the independent parser gate before the launcher or any driver stage ran.

Public entrypoint filenames, workflow/result schemas, signer identity, evidence names, tag, release title, asset name, and repository documentation use Public Beta v3.1.
