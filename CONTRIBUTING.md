# Contributing

Contributions are welcome when they improve safety, reproducibility, documentation, diagnostics, or future validated releases for the documented hardware targets.

## Project boundary

The repository URL retains its historical `LeGo1-graphic-driver-toolkit` name during the multi-device public-beta phase, but Public Beta v4.5 supports exactly three immutable hardware profiles. Do not broaden support from family names or similar device IDs.

Every executable release is both AMD-release-specific and hardware-profile-specific. Do not describe a release as compatible with a new AMD version, device revision, or handheld merely because an INF can be made to bind.

## Release immutability

Published executable assets are frozen byte-for-byte. Do not alter an existing release asset or historical release record in place.

Documentation-only release metadata may be corrected when it does not alter or misrepresent the published asset. A change to executable behavior, expected hashes, target payload, supported hardware, prerequisites, state contracts, or audit criteria belongs in a new public version.

## Non-regression rules

- Exact HWID scope only; hardware chooses the profile.
- No manual profile override.
- Preserve fail-closed package/parser/preflight gates before mutation.
- Preserve selected-profile extension ownership; do not globally purge `amduw23e`.
- Preserve the Go S rule that Lenovo OEM AddReg is applied after AMD DelReg.
- Preserve Go 2 `%AMD150E.517%` and the distinction between Lenovo-proven exact C5 mapping and AMD's broader DEV_150E Strix support.
- Preserve transaction-aware rollback/recovery and no destructive-stage auto-retry.
- Preserve direct Windows PowerShell 5.1 compatibility; do not add dependencies on optional cmdlets/modules without a proven fallback.
- Do not add AMD, Lenovo, Microsoft, ASUS, or other proprietary binaries.
- Do not publish private volunteer packages, private field logs/evidence, certificates, or keys.
- Do not add untested compatibility claims.

## Before opening a pull request

- Open an issue first for behavioral changes.
- Explain the exact problem and safety impact.
- Keep hardware checks fail-closed.
- Preserve explicit user confirmation before system changes or restarts.
- Preserve readable source; do not add encoded executable payloads.
- Do not add automatic AMD installer downloads.
- Do not weaken hash, signature, signer, catalog, exact-HWID, or reboot-boundary validation.
- Update documentation, release notes, and manifests together.

## Testing expectations

1. Windows PowerShell 5.1 parsing and static checks
2. Exact release-source and payload identity checks
3. Exact hardware resolver fixtures, including negative revisions
4. Deterministic per-profile INF/DAT reconstruction
5. Non-destructive preflight and entry-gate paths
6. Interrupted-run, rollback, rerun, and concurrency behavior
7. Reboot-boundary behavior
8. Physical validation on each newly supported exact hardware profile
9. Final read-only persistence audit with the profile-specific expected check count

A new hardware profile is not release-ready from static analysis alone. Physical field evidence and a complete final audit are required before public support is claimed.
