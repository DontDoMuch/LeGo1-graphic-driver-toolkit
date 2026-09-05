# Validation

## Public Beta v4.5.1

Public Beta v4.5.1 is a targeted hotfix over v4.5. AMD 26.8.1, the three exact supported HWIDs, the frozen per-profile INF/DAT outputs, and the final-audit contracts are unchanged.

## Physical profile baseline inherited unchanged from v4.5

| Device/profile | Exact HWID | Result | Failures | Warnings |
|---|---|---:|---:|---:|
| Legion Go 1 Z1 Extreme / `LegionGo1` | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | **78/78 PASS** | 0 | 0 |
| Legion Go S Z1 Extreme / `LegionGoS-Z1Extreme` | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | **81/81 PASS** | 0 | 0 |
| Legion Go 2 Z2 Extreme / `LegionGo2-Z2Extreme` | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | **79/79 PASS** | 0 | 0 |

These results establish the unchanged device/profile baseline. v4.5.1 does not claim that all three destructive final-audit runs were repeated solely for this hotfix.

## Field catalog-prestate failure and proven recovery

A v4.5 Go 2 field run reached Stage 2 with this official-catalog state:

```text
OfficialCatalogs = 1
Covered          = 14
ManagedExists    = False
ManagedExact     = False
```

v4.5 treated that state as unsafe/ambiguous even though the exact Microsoft catalog already covered all 14 frozen targets. The workflow failed closed, invoked recovery, and recorded a proven rollback result with a healthy GPU (`Status=OK`, problem code `0`, AMD display `32.0.31041.1004`) while Test Signing and `nointegritychecks` were normalized OFF. This proved the recovery path worked and isolated the catalog decision as the false-negative gate.

v4.5.1 corrects only that safe additive case: when one or more exact Microsoft catalog copies already cover every frozen target and the managed-name copy is absent, `ApplyPreservingExisting` registers the exact managed copy while preserving the preexisting exact Microsoft copy/copies. Partial coverage, non-exact identity, or ambiguous unsafe states still fail closed.

The Stage 2 recovery code also now performs a final PnP rescan and re-proves the restored Display identity/health **after** extension restoration before `Get-LegionGoRollbackOutcomeStatus` accepts the rollback outcome.

## v4.5.1 preflight results

A real Windows PowerShell 5.1 regression on the v4.5.1 hotfix line completed with:

```text
Actual public entry gate: ExitCode 0
Package manifest:         23/23
PowerShell parser:        13 files / 0 errors
Static preflight:         32/32 PASS
Source-backed preflight:  43/43 PASS
FailedChecks:             0
.NET ZIP smoke:           PASS
```

The source-backed pass rebuilt all three frozen profile outputs byte-exact and proved exact HWID -> DDInstall binding while rejecting Go 2 `REV_C4`.

The final public asset is:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
SHA-256: 910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
Size: 132857 bytes
```

That exact final asset contains the corrected CMD target and was successfully run from a clean Windows PowerShell 5.1 environment during field recovery. It uses the fresh namespace `C:\ProgramData\LegionGo-AMD-26.8.1-MultiDevice-v4.5.1\<Profile>` so it does not consume the prior v4.5 workflow state.

## PowerShell-host boundary

The final successful run used clean Windows PowerShell 5.1. A separate test showed that a Windows PowerShell 5.1 child launched from PowerShell 7 can inherit a PowerShell-7-oriented `PSModulePath` and fail while resolving `Microsoft.PowerShell.Security`. No `PSModulePath` sanitizer exists in the final v4.5.1 bytes. The supported launch path is Explorer/Command Prompt or a clean Windows PowerShell 5.1 context.

## Frozen profile outputs

```text
Go 1 Z1 Extreme
INF: F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42
DAT: 83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953

Go S Z1 Extreme
INF: 1C17657B1550AAB3BE0A981864122B3A2E852E3F90DA3EEF1413AB33561FE6EA
DAT: 83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953

Go 2 Z2 Extreme
INF: BE67AD0E09147A7C33AA9688533F0BE99842F0E2FE14F8C79EB35CB6BA3F45CC
DAT: B85E600A892480BD5F15A4BC1C9B2993FF0717E95A81F480586A8B9653F514A8
```

## Evidence boundary

The repository does **not** claim a missing final v4.5.1 volunteer evidence ZIP. The field recovery outcome above is documented from the preserved handoff/evidence trail, while private volunteer packages, private evidence archives, certificates, keys, logs, and workflow state remain non-public.

Windows 11 x64 on the three exact hardware IDs above remains the supported field scope. Windows 10, eGPU, other Legion Go variants/revisions, and arbitrary third-party driver projects are not certified by this release.
