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

## Publish Public Beta v3.0

1. Back up or clone the current repository.
2. Apply the Public Beta v3.0 repository update while preserving history.
3. Confirm `README.md` identifies Public Beta v3.0 / AMD 26.7.1 as current.
4. Confirm all historical release records remain present.
5. Confirm `releases/public-beta-v3.0/toolkit/` matches `TOOLKIT-SHA256SUMS.txt`.
6. Confirm `REPOSITORY-SHA256-MANIFEST.txt`.
7. Commit and push.

Suggested commit:

```text
Publish Public Beta v3.0 for AMD 26.7.1
```

## GitHub Release

Tag:

```text
public-beta-v3.0
```

Title:

```text
Legion Go 1 Graphics Driver Toolkit — Public Beta v3.0
```

Attach:

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip
```

SHA-256:

```text
E946D1F981A435B9C8F8E94542649FA48970F7C56F85138E399411E5C2496DAF
```

Use `releases/public-beta-v3.0/RELEASE-NOTES.md` as the release description
base and set it as the repository's latest release.

Keep the release marked as a **pre-release** while the project remains in the
Public Beta sequence.

## Do not upload

- AMD's installer or extracted AMD binaries;
- Driver Store copies;
- private keys or local certificates;
- private logs/evidence;
- unvalidated development snapshots presented as public releases.

## Provenance note

Several files inside the v3.0 executable snapshot retain `RC2zk` internally.
Do not rename them in the published executable snapshot. The public tag,
release title, asset name, and documentation all use Public Beta v3.0.
