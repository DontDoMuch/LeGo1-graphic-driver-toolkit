# Validation

## Public Beta v4.5

Public Beta v4.5 keeps the AMD 26.8.1 / display `32.0.31041.1004` release target and expands the v4 engine to three exact hardware profiles.

## Physical field results

| Device/profile | Exact HWID | Result | Failures | Warnings |
|---|---|---:|---:|---:|
| Legion Go 1 Z1 Extreme / `LegionGo1` | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | **78/78 PASS** | 0 | 0 |
| Legion Go S Z1 Extreme / `LegionGoS-Z1Extreme` | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | **81/81 PASS** | 0 | 0 |
| Legion Go 2 Z2 Extreme / `LegionGo2-Z2Extreme` | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | **79/79 PASS** | 0 | 0 |

The Go 1 destructive result was produced by the immediate pre-auto-evidence combined v4.5 candidate and therefore physically proves the new exact-HWID resolver -> Go 1 profile -> shared managed workflow path. The final candidate changes only the top-level evidence-ZIP packaging/manifest identity; Stage 1-4 and device/profile logic remain unchanged, and the exact final bytes passed Regression v5 instead of triggering an unnecessary destructive reinstall.

Go S and Go 2 were physically field-validated with private volunteer packages whose exact profiles and Stage 1-4 scripts are preserved in v4.5. Shared helper changes after those runs are limited to the Windows PowerShell 5.1 compatibility fixes and were exercised by the final all-profile regression. Those private volunteer packages/evidence are not public release assets.

## Exact final-package regression

The final v4.5 package with SHA-256:

```text
B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C
```

passed the real Windows PowerShell 5.1 regression on the Go 1 host with:

```text
Actual public entry gate: ExitCode 0
PowerShell parser:        13 files / 0 errors
Package manifest:         23/23
Source-backed preflight:  43/43 PASS
FailedChecks:             0
.NET ZIP smoke:           PASS
Auto-evidence contract:   PASS
```

The regression rebuilt all three profile outputs byte-exact from the frozen AMD 26.8.1 source and proved each exact HWID -> DDInstall binding. Go 2 `REV_C4` remained rejected.

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

Common loaded kernel SHA-256:

```text
92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
```

## Third-party AMD origin proof

The v4 origin architecture was physically field-validated on Go 1 from a real ASUS ROG Ally graphics package. The active ASUS Display package was exported for rollback; its ASUS-only `amduw23e` remained staged because its model directives did not target the Go 1 hardware ID; the transition completed successfully.

v4.5 preserves that origin/rollback model and replaces Go-1-specific applicability with selected-profile applicability. This supports healthy structurally classifiable third-party AMD starting states without globally deleting foreign extensions.

ROG Ally-origin migration is field-proven on Go 1. No claim is made that an Ally-origin transition has been separately field-run on Go S or Go 2.

## Go S proof

The Go S field result verified the exact profile, Phoenix base mapping, `ati2mtag_Phoenix_LegionGoS`, exact frozen INF/DAT/kernel, both catalog paths, normal boot-integrity state, AMD Software/runtime/tasks, and all 30 frozen Lenovo OEM registry directives.

## Go 2 proof

The Go 2 field result verified exact `REV_C5`, Strix mapping, `ati2mtag_Strix_LegionGo2`, `%AMD150E.517%`, exact frozen INF/DAT/kernel, both catalog paths, normal boot-integrity state, AMD Software/runtime/tasks, and all 28 frozen Lenovo OEM registry directives.

AMD 26.8.1 does not natively enumerate exact Lenovo C5; Lenovo OEM provenance proves the exact C5 -> Strix mapping used by the controlled public adaptation.

## Evidence ZIP change

The final v4.5 launcher adds direct .NET success/failure evidence ZIP creation. The production source contract and the exact `.NET ZipFile::CreateFromDirectory` + `OpenRead` path passed on the real Windows PowerShell 5.1 host. The destructive driver installation was not repeated solely to traverse this post-audit packaging-only line.

## Scope limits

Windows 11 x64 on the three exact hardware IDs above is the supported field scope. Windows 10, eGPU, other Legion Go variants/revisions, and arbitrary third-party driver projects are not certified by this release.
