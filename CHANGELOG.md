# Changelog

## Public Beta v4.5 — 2026-09-04

- Expanded the AMD 26.8.1 v4 architecture from one original-Legion-Go target to three exact install-capable profiles selected automatically by exact hardware ID.
- Added Lenovo Legion Go 1 Z1 Extreme `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` -> Phoenix -> `ati2mtag_Phoenix_LegionGo`.
- Added Lenovo Legion Go S Z1 Extreme `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` -> Phoenix -> `ati2mtag_Phoenix_LegionGoS`.
- Added Lenovo Legion Go 2 Z2 Extreme `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` -> Strix -> `ati2mtag_Strix_LegionGo2`.
- Kept unvalidated hardware fail-closed; the tested Go 2 `REV_C4` fixture is rejected.
- Preserved the proven Go S ordering rule that Lenovo OEM AddReg directives must be applied after AMD DelReg; all 30 frozen Go S OEM directives are audited.
- Added the exact Go 2 `%AMD150E.517%` model binding and 28 frozen Lenovo OEM directives. AMD 26.8.1 has DEV_150E Strix coverage, while the exact Lenovo C5 mapping is OEM-proven adaptation rather than native exact-C5 AMD enumeration.
- Generalized origin, extension ownership, rollback, recovery, and final audit handling to the selected immutable profile while preserving the field-proven v4 engine.
- Retained support for healthy third-party AMD Display starting states. The ROG Ally-origin transition remains field-proven on Go 1; foreign/non-applicable `amduw23e` packages are preserved by hardware applicability rather than filename/class/ExtensionId assumptions.
- Removed production dependence on `Get-FileHash` and `Import-PowerShellDataFile` after real Windows PowerShell 5.1 host failures; production hashing now uses direct .NET SHA-256 and the release contract uses a narrow static parser.
- Corrected Windows PowerShell 5.1 `${Variable}:` parsing incompatibilities in the release-contract loader.
- Added automatic final/failure evidence ZIP packaging through direct .NET `System.IO.Compression.ZipFile`, avoiding optional archive-cmdlet dependency.
- Physical combined-package Go 1 validation completed **78/78**, zero failed checks, zero warnings on the immediate pre-auto-evidence candidate. The final candidate changes only top-level evidence-ZIP packaging/manifest identity and was not destructively reinstalled solely for that post-audit packaging change.
- Go S Z1 Extreme volunteer hardware completed **81/81**, zero failed checks, zero warnings.
- Go 2 Z2 Extreme volunteer hardware completed **79/79**, zero failed checks, zero warnings.
- Exact final v4.5 bytes passed the real Windows PowerShell 5.1 entry gate and 43/43 all-profile source-backed regression with zero failures, including a direct .NET ZIP create/open smoke test.
- Final public release asset: `LegionGo-AMD-26.8.1-Public-Beta-v4.5.zip`, SHA-256 `B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C`, size `132499` bytes.

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
