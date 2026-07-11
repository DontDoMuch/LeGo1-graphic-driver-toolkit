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

## Publish the repository overhaul

1. Back up or clone the current repository.
2. Replace the repository contents with the contents of the overhaul ZIP, preserving all paths.
3. Confirm `README.md` renders correctly.
4. Confirm the frozen `public-beta-v1.0` and `public-beta-v1.1` snapshots remain present.
5. Confirm `releases/public-beta-v2.0/` and the SHA-256 manifests are present.
6. Commit and push the update.

Suggested commit message:

```text
Publish Public Beta v2.0 compatibility workflow
```

## Create the GitHub release

Tag:

```text
public-beta-v2.0
```

Release title:

```text
Legion Go 1 Graphics Driver Toolkit — Public Beta v2.0
```

Attach:

```text
LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip
```

Published SHA-256:

```text
D2DA30DD76B9460C14D96FB09824D727D13B7D24BA327263E6FAA8ACC751CBD4
```

Use `releases/public-beta-v2.0/RELEASE-NOTES.md` as the release description. Mark the release as a **pre-release** because the project is still in public beta, and set it as the repository's latest release.

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
