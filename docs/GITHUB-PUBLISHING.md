# GitHub Publishing Guide

This repository package is prepared for a normal multi-file upload or a local Git push.

## Recommended repository name

```text
LeGo-AMD-driver-toolkit
```

## Repository description

```text
Community PowerShell toolkit for installing and validating AMD 26.6.2 on the original Lenovo Legion Go.
```

## Suggested topics

```text
legion-go
amd
radeon
powershell
windows-11
driver
handheld-gaming
```

## Initial publication

1. Create an empty public repository without an auto-generated README, license, or `.gitignore`.
2. Upload the complete contents of this repository folder, preserving all paths.
3. Commit with: `Publish Legion Go AMD 26.6.2 Public Beta v1.0`.
4. Confirm that `README.md` renders and local documentation links work.
5. Enable GitHub private vulnerability reporting when available.

## Create the release

Tag:

```text
public-beta-v1.0
```

Release title:

```text
Legion Go AMD 26.6.2 Toolkit — Public Beta v1.0
```

Use `releases/Public-Beta-v1.0/RELEASE-NOTES.md` as the release description.

Attach:

```text
LegionGo-AMD-26.6.2-Public-Beta-v1.0.zip
```

Published SHA-256:

```text
46B9F4FE778B7661E984008A20961A8FF5B3E7B6596FF9E2EB927AF80AA16469
```

Also attach or paste the standalone ZIP hash record.

## Do not upload

- AMD's installer
- Extracted AMD binaries
- Driver Store copies
- Local certificates or private keys
- Logs containing private information
- Development snapshots not intended for release
