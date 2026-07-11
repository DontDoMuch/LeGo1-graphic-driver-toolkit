# Contributing

Contributions are welcome when they improve safety, reproducibility, documentation, diagnostics, or future validated releases for the documented hardware target.

## Project boundary

The repository identity is version-neutral, but each executable release is target-specific. Do not describe a release as compatible with a new AMD version merely because its starting-state checks are flexible.

## Release immutability

Files under `releases/` are frozen source snapshots. Do not alter an existing release in place.

A change to executable behavior, expected hashes, target payload, supported platform, prerequisites, state contracts, or audit criteria belongs in a new release directory and changelog entry.

## Before opening a pull request

- Open an issue first for behavioral changes.
- Explain the exact problem and safety impact.
- Keep hardware checks fail-closed.
- Preserve explicit user confirmation before system changes or restarts.
- Preserve readable source; do not add encoded executable payloads.
- Do not add automatic AMD installer downloads.
- Do not add AMD, Lenovo, Microsoft, or other proprietary binaries.
- Do not weaken hash, signature, signer, catalog, device-ID, or reboot-boundary validation.
- Do not add untested compatibility claims.
- Do not add game- or anti-cheat-specific claims to public documentation.
- Update documentation, release notes, and manifests together.

## Testing expectations

1. PowerShell parsing and static checks
2. Embedded or reconstructed payload identity checks
3. Non-destructive preflight paths
4. Interrupted-run and rerun behavior
5. Reboot-boundary behavior
6. Live original-Legion-Go validation
7. Fresh-OEM end-to-end end-to-end validation
8. Final read-only persistence audit

A build is not release-ready until the complete numbered workflow passes end to end on the documented hardware.
