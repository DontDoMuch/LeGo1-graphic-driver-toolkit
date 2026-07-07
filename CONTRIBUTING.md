# Contributing

Contributions are welcome when they improve safety, reproducibility, documentation, diagnostics, or support for the explicitly documented target.

## Release immutability

Files under `releases/Public-Beta-v1.0/` are the exact frozen and tested release. Do not alter them in place.

A change to executable behavior, expected hashes, supported platforms, prerequisites, state contracts, or audit criteria belongs in a new future release directory and changelog entry.

## Before opening a pull request

- Open an issue first for behavioral changes.
- Explain the exact problem and intended safety impact.
- Keep hardware checks fail-closed.
- Preserve explicit user confirmation before system changes or restarts.
- Preserve readable source; do not add encoded executable payloads.
- Do not add automatic downloads of AMD installers.
- Do not add AMD, Lenovo, Microsoft, or other proprietary binaries.
- Do not weaken hash, signature, signer, catalog, device-ID, or reboot-boundary validation.
- Do not add compatibility claims that have not been directly tested.
- Do not add game-specific compatibility claims to public documentation.
- Keep PowerShell compatible with the documented runtime for the affected script.
- Update documentation, release notes, and manifests together.

## Testing expectations

Script changes should be evaluated in layers:

1. PowerShell parsing and static checks
2. Embedded or reconstructed payload identity checks
3. Non-destructive preflight paths
4. Interrupted-run and rerun behavior
5. Reboot-boundary behavior
6. Live original-Legion-Go validation from the documented OEM baseline
7. Final read-only persistence audit

A script should not be described as release-ready until the complete numbered workflow has passed end to end.

## Bug reports

Use the bug-report issue form and include the failed script number, exact command, full terminal output, relevant transcript, Windows build, active driver version and INF, and Secure Boot/Test Signing state.

Remove personal information before posting logs publicly.
