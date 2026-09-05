# Verification

## Public Beta v4.5 release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.zip
SHA-256: B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C
Size: 132499 bytes
```

The exact public ZIP contains 24 entries. `PACKAGE-MANIFEST.json` governs the other 23 files and passed 23/23 integrity verification. ZIP CRC validation passed, and independent builds of the final candidate were byte-identical.

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

## Final release validation gates

The exact final bytes passed:

- real Windows PowerShell 5.1 package/parser/entry-gate execution;
- `PACKAGE_MANIFEST` 23/23;
- PowerShell parser 13 files / 0 errors;
- 43/43 all-profile source-backed preflight with zero failures;
- exact reconstruction of all three profile INF/DAT outputs;
- exact HWID -> DDInstall binding for all three supported profiles;
- negative Go 2 `REV_C4` rejection;
- direct .NET evidence-ZIP create/open smoke test;
- physical Go 1 combined-engine 78/78 final audit on the immediate pre-auto-evidence candidate;
- physical Go S 81/81 final audit;
- physical Go 2 79/79 final audit.

The exact final `B773...` candidate was not destructively reinstalled solely to traverse the post-audit evidence-ZIP addition. Its Stage 1-4/device logic is unchanged from the Go 1 field-success candidate, while the exact final bytes passed the real-host entry gate, 43/43 all-profile regression, and direct .NET ZIP smoke test.

The package itself remains the executable source of truth. Private volunteer packages and private field evidence are not public release artifacts.
