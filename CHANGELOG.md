# Changelog

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
