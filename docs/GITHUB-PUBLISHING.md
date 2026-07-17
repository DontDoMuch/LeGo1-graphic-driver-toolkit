# GitHub publishing guide

## Repository identity

Recommended repository name:

```text
LeGo1-graphic-driver-toolkit
```

Recommended description:

```text
Compatibility-focused AMD graphics-driver toolkit for the original Lenovo Legion Go (Legion Go 1).
```

Suggested topics:

```text
legion-go
legion-go-1
amd
radeon
powershell
windows-11
graphics-driver
handheld-gaming
```

## Publish the Public Beta v2.1 repository update

1. Back up or clone the current repository.
2. Replace the repository contents with the cleaned repository ZIP, preserving all paths.
3. Confirm `README.md` renders correctly and identifies Public Beta v2.1 as current.
4. Confirm the frozen `public-beta-v1.0` and `public-beta-v1.1` snapshots remain present.
5. Confirm `releases/public-beta-v2.0/README.md` is a historical pointer and contains no mislabeled executable files.
6. Confirm `releases/public-beta-v2.1/` contains the exact released scripts, instructions, checksum file, and release metadata.
7. Verify `REPOSITORY-SHA256-MANIFEST.txt` against the repository files.
8. Commit and push the update.

Suggested commit message:

```text
Publish Public Beta v2.1 and refresh repository documentation
```

## Create the GitHub release

Tag:

```text
public-beta-v2.1
```

Release title:

```text
Legion Go 1 Graphics Driver Toolkit — Public Beta v2.1
```

Attach:

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
```

Published SHA-256:

```text
DE3A7FD534BB136881D8685F17AD5F7FD3CCDC46597487465D0966C2A365038C
```

Use `releases/public-beta-v2.1/RELEASE-NOTES.md` as the release description. Mark the release as a **pre-release** because the project remains in public beta, and set it as the repository's latest release.

Do not commit the release ZIP into the source tree unless there is a deliberate archival reason. GitHub Releases is the appropriate location for the downloadable asset.

## Repository settings

- Keep Issues enabled.
- Enable private vulnerability reporting.
- Add the recommended topics.
- Confirm `.github/FUNDING.yml` resolves correctly if funding is enabled.
- Enable Discussions only when support capacity exists.

## Do not upload

- AMD's installer or extracted AMD binaries
- Driver Store copies
- Local certificates or private keys
- Logs containing private information
- Unvalidated development snapshots presented as public releases
