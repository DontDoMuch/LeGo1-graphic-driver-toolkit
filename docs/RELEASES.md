# Releases

## Naming convention

Public releases use one simple sequence:

```text
Public Beta v1.0
Public Beta v1.1
Public Beta v2.0
```

The release tag and repository snapshot folder use the lowercase form:

```text
public-beta-v2.0
```

Internal development labels are not public release names.

## Current release

**Public Beta v2.0** is the current release. It uses AMD 26.6.4 and represents a major compatibility-focused workflow update over the AMD 26.6.2 public betas.

## Release assets

Release ZIP names identify the project and public version:

```text
LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip
```

The target AMD version belongs in the release notes and verification documentation rather than defining the permanent repository identity.

## Immutability

Files under `releases/public-beta-vX.Y/` are publication snapshots. Do not edit an existing public snapshot in place. Corrections to executable files require a new public version, new hashes, and new release notes.
