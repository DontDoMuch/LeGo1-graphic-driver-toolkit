# Changelog

All notable public releases are documented here.

## Public Beta v1.0 — 2026-07-07

First public beta release of the four-script workflow.

### Added

- Hardware-gated original Legion Go validation
- Exact AMD 26.6.2 `-c` installer identity verification
- Reproducible corrected 125-file driver-package construction
- Readable plain-text PowerShell sources
- Per-installation local catalog signing and trust validation
- Temporary Test Signing workflow with explicit restart handling
- Corrected display-driver binding and normal-signing persistence checks
- Official AMD Microsoft-signed catalog registration and kernel-policy validation
- Native AMD Software `.2099` and RSXCM `22.10.0.0`
- Legacy `.2089` MSI/AppX retirement
- Lenovo extension, AMDUWP, CN metadata, and ReleaseVersion preservation
- Safe shell-association refresh without terminating Explorer
- Live-state checks that prevent stale JSON from skipping required work
- Read-only final persistence audit and desktop report
- SHA-256 manifest for all release files

### Validated result

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

### Release integrity

```text
LegionGo-AMD-26.6.2-Public-Beta-v1.0.zip
SHA-256:
46B9F4FE778B7661E984008A20961A8FF5B3E7B6596FF9E2EB927AF80AA16469
```
