# Releases

## Naming convention

Public releases use one simple sequence:

```text
Public Beta v1.0
Public Beta v1.1
Public Beta v2.0
Public Beta v2.1
```

The release tag and repository record use the lowercase form:

```text
public-beta-v2.1
```

Internal development labels are not public release names.

## Current release

**Public Beta v2.1** is the current release. It uses AMD 26.6.4 and supersedes Public Beta v2.0.

## Release assets

The current release asset is:

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
```

The target AMD version belongs in release notes and verification documentation rather than defining the permanent repository identity.

## Publication records

Directories under `releases/` are publication records. They may contain exact immutable executable snapshots or a historical pointer to the authoritative GitHub Release asset.

- Never place unverified or mislabeled executable files under a public release path.
- Never edit a published executable file in place.
- A correction to executable behavior requires a new public version, new hashes, and new release notes.
- Documentation-only metadata may be corrected when it does not alter or misrepresent the published asset.
