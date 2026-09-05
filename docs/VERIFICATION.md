# Verification

## Public Beta v4.5.1 release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
SHA-256: 910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
Size: 132857 bytes
```

The exact public ZIP contains 24 entries. `PACKAGE-MANIFEST.json` governs the other 23 files. Independent release-prep verification of the uploaded final bytes confirmed **23/23** manifest length/SHA-256 matches and a clean ZIP CRC scan.

The exact CMD entrypoint inside these bytes resolves to:

```text
Run-Validated-LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.ps1
```

The package also contains the v4.5.1 fresh workflow root, additive exact-catalog handling, and final rollback re-proof ordering. It does **not** contain a `PSModulePath` sanitizer.

## Official AMD source

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
Version: 26.8.1.0
```

The AMD installer is not redistributed by this repository.

## Official source identities

```text
Display INF: u0203304.inf
INF SHA-256: F47B47014525C5D9A29DC6ECAC5A91C4E7B8EF6699CEB1D886BCCB0F208B25FA

Source DAT: B026373\amdgcf.dat
DAT SHA-256: 205E22588E619FE197E5D864F6834A71ECCEF2C76317CBC38157B860F1D3FD24

Kernel amdkmdag.sys SHA-256:
92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF

Official Microsoft WHCP catalog u0203304.cat SHA-256:
23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48
```

## Exact supported profile outputs

### Legion Go 1 Z1 Extreme

```text
HWID: PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04
Active DDInstall: ati2mtag_Phoenix_LegionGo
INF SHA-256: F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42
DAT SHA-256: 83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953
Expected final audit: 78/78
```

### Legion Go S Z1 Extreme

```text
HWID: PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04
Active DDInstall: ati2mtag_Phoenix_LegionGoS
INF SHA-256: 1C17657B1550AAB3BE0A981864122B3A2E852E3F90DA3EEF1413AB33561FE6EA
DAT SHA-256: 83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953
Expected final audit: 81/81
```

### Legion Go 2 Z2 Extreme

```text
HWID: PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
Active DDInstall: ati2mtag_Strix_LegionGo2
INF SHA-256: BE67AD0E09147A7C33AA9688533F0BE99842F0E2FE14F8C79EB35CB6BA3F45CC
DAT SHA-256: B85E600A892480BD5F15A4BC1C9B2993FF0717E95A81F480586A8B9653F514A8
Expected final audit: 79/79
```

## Required final policy state

```text
GPU Status          = OK
ProblemCode         = 0
HasProblem          = False
Selected profile    = exact HWID match
Applicable amduw23e = absent after clean transition
Foreign amduw23e    = permitted/preserved
Test Signing        = OFF
nointegritychecks   = OFF
Stage 2/3/4         = Passed
FailedChecks        = 0
Warnings            = 0
Workflow Stage      = Complete
```

## v4.5.1 validation gates

A Windows PowerShell 5.1 v4.5.1 regression on the hotfix line proved:

```text
Actual public entry gate: ExitCode 0
Package manifest:         23/23
PowerShell parser:        13 files / 0 errors
Static preflight:         32/32 PASS
Source-backed preflight:  43/43 PASS
FailedChecks:             0
.NET ZIP smoke:           PASS
```

The exact final `910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75` package was then frozen with the corrected CMD target. Release-prep inspection reverified its 23/23 manifest, CRC, v4.5.1 workflow namespace, `ApplyPreservingExisting` catalog contract, and final rollback-proof ordering. The field handoff records a successful run of these exact final bytes in a clean Windows PowerShell 5.1 environment.

The physical Go 1 / Go S / Go 2 final-audit baseline remains the unchanged v4.5 profile baseline: **78/78**, **81/81**, and **79/79** respectively. v4.5.1 does not change those device profiles or frozen output identities. No missing final volunteer evidence ZIP is represented as if it existed.
