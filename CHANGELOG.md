
# Changelog

## Public Beta v3.0 — AMD 26.7.1

- Added the one-command managed installer with exactly two initial consent prompts.
- Added bounded automatic reboot/resume orchestration and invocation-bound stage contracts.
- Moved Lenovo-required graphics semantics into the merged 26.7.1 display package.
- Added exact Lenovo OEM, Public 26.6.2, and Public 26.6.4 origin architectures.
- Added rollback export for the starting display package and applicable Lenovo extension.
- Replaced fixed catalog-name assumptions with active-INF catalog resolution.
- Preserved AMD `ColorVibrance_ENABLE_DEF=1` and `ShowRSOverlay=true`.
- Removed live `ReleaseVersion` spoofing from the architecture.
- Added temporary Test Signing recovery normalization and fail-closed failure evidence.
- Final Public 26.6.4 → 26.7.1 regression completed 65/65 final checks successfully.
- Clean Lenovo OEM → 26.7.1 path also completed 65/65 in the immediate predecessor.
- Published the exact final RC2zk executable snapshot under the Public Beta v3.0 identity.

## Public Beta v2.1 — 2026-07-17

### Corrected public release

- Superseded Public Beta v2.0 after external users reported safe Script 1 integrity-check stops.
- Published the corrected and revalidated AMD 26.6.4 workflow as Public Beta v2.1.
- Confirmed the final release artifact through two complete regression paths:
  - Fresh Lenovo OEM graphics installation → AMD 26.6.4.
  - Fresh Lenovo OEM → Public Beta v1.1 / AMD 26.6.2 → Public Beta v2.1 / AMD 26.6.4.
- Confirmed Script 4 completed with `SCRIPT 4 PASS: True`, `Failed checks: 0`, and `TOOLKIT COMPLETE: True`.
- Retained support for safe repair and idempotent reruns from an existing validated AMD 26.6.4 state.
- Added `SHA256SUMS.txt` to the release artifact for direct file verification.
- Updated repository documentation, issue forms, support policy, release metadata, and manifests to identify v2.1 as current.

## Public Beta v2.0 — 2026-07-10

### Major changes

- Moved the validated target from AMD 26.6.2 to AMD 26.6.4.
- Reframed the repository around the Legion Go 1 hardware and workflow rather than a single AMD version.
- Replaced one exact starting-driver requirement with healthy compatible starting-stack validation.
- Replaced exact Lenovo extension version/hash gating with semantic validation and exact active-device attachment checks.
- Added support for healthy structurally compatible Microsoft-signed AMDUWP packages.
- Replaced one exact outer AMD installer filename/hash gate with signature, version, extraction, and exact target-payload validation.
- Changed the extracted source-tree file count from a hard gate to telemetry while retaining exact canonical dependency and output contracts.
- Added capability-based Windows Kit discovery for a functional Inf2Cat and SignTool pair.
- Preserved strict Legion Go 1 hardware gating, exact target identities, catalog verification, normal-signing restoration, and final persistence auditing.
- Completed the full workflow from a fresh Lenovo OEM graphics installation with zero failed final-audit checks.

## Public Beta v1.1 — 2026-07-06

- Published the coherent AMD 26.6.2 public-beta update.
- Improved the installation and final-audit workflow over v1.0.

## Public Beta v1.0 — 2026-07-05

- First public-beta repository release of the four-script Legion Go workflow.
