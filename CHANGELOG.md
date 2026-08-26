# Changelog

## Public Beta v4.0 — 2026-08-25

- Moved the validated target to AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004`.
- Added exact frozen 26.8.1 INF, DAT, kernel, source-installer, AMD Settings, DVR, runtime, and catalog identities.
- Added dual-catalog trust: the exact original Microsoft WHCP `u0203304.cat` is registered alongside the locally signed merged catalog, and both must cover all 14 frozen kernel/UMD targets.
- Corrected the 26.8.1 UMD trust regression that caused Gears 5 to fall back to software/WARP and caused BattlEye to block `amdxx64.dll`; the managed official catalog survived reboot and is idempotently revalidated.
- Changed `amduw23e` ownership from filename/class/ExtensionId assumptions to actual original-Legion-Go hardware applicability. Proven foreign packages are preserved; unreadable or actually Go-applicable foreign lineages fail closed.
- Field-validated a real ASUS/ROG Ally `32.0.31007.6002` origin through Stage 2/3/4 with zero failed checks while retaining the ASUS-only extension.
- Successfully exercised a dirty ASUS → Lenovo origin installed without an intervening reboot before the v4.0 transition.
- Added transaction-aware failed-checkpoint normalization, proof-derived rollback outcome states, recovery-only handling for unproven rollback, and startup self-heal for proven rollback checkpoints whose parent normalization was interrupted.
- Added a machine-wide installer mutex and fail-closed detection of other registered `LegionGo-AMD-*-Resume` workflows.
- Added read-only full Stage 4 revalidation when a saved workflow is already `Complete`; physical revalidation passed 72/72 with state/GPU/BCD/task invariants unchanged.
- Preserved AMD defaults `ColorVibrance_ENABLE_DEF=1` and `ShowRSOverlay=true`.
- Final public release asset: `LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip`, SHA-256 `8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07`.

## Public Beta v3.1 — 2026-08-22

- Published the corrected AMD 26.7.1 bugfix release over Public Beta v3.0 without changing the frozen merged target payload.
- Corrected valid Lenovo OEM origins that previously failed with `Multiple standalone Lenovo amduw23e packages are present; origin is ambiguous.`
- Corrected valid historical Lenovo extension generations that previously failed solely because their `DriverVer` differed from the active OEM display package.
- Treats multiple exact-Go `amduw23e` generations sharing ExtensionId `{07A2A561-D001-4503-B239-EF2FE0379EFB}` as one versioned Lenovo lineage.
- Exports every recognized same-lineage member before removal for the merged 26.7.1 target while continuing to fail closed on distinct applicable ExtensionIds.
- Field-validated the dirty Lenovo OEM two-generation origin through Stages 2, 3, and 4 with zero failed final checks.
- Regressed the corrected Public Beta v3.1 package from exact merged 26.7.1 to exact merged 26.7.1 through Stages 2, 3, and 4 with zero failed final checks.
- Rejected an unpublished broad RC-to-public substitution attempt at the independent parser gate before any launcher or driver stage ran.
- Preserved required internal RC2zp class/type identifiers and passed the corrected public-package static audit 16/16.
- Published `LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip` with SHA-256 `ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328`.

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
