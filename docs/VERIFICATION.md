# Verification

## Public Beta v4.0 release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip
SHA-256: 8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
Size: 154588 bytes
```

The public-named ZIP is the exact validated release bytes; only the outer filename differs from the final engineering-candidate filename used during field testing.

The ZIP contains one top-level `LegionGo-AMD-26.8.1-Public-Beta-v4.0` directory with 20 files. Its internal `SHA256SUMS.txt` contains 19 entries and verifies every other packaged file.

## Official AMD source

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
Size: 930653064 bytes
Version: 26.8.1.0
```

The AMD installer is not redistributed by this repository.

## Final installed identities

```text
DriverVersion:
  32.0.31041.1004

Final INF SHA-256:
  F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42

Final amdgcf.dat SHA-256:
  83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953

Loaded amdkmdag.sys SHA-256:
  92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
```

## Dual-catalog identities

The merged Driver Store package uses the locally generated/signed active catalog. v4.0 also registers the exact original Microsoft AMD WHCP catalog for the frozen kernel/UMD payload:

```text
Official source catalog: u0203304.cat
SHA-256:
  23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48

Managed CatRoot name:
  LegionGo-AMD-26.8.1-Official-WHCP.cat

Signer:
  Microsoft Windows Hardware Compatibility Publisher

Required coverage:
  Local catalog    14/14
  Official catalog 14/14
```

Three critical frozen targets include `amdkmdag.sys`, `amdxc64.dll`, and `amdxx64.dll`.

## Matching AMD Software

```text
AMD Settings product:
  {2516E7E8-BAB4-42B7-BAEA-CB34B96275FF}

AMD Settings version:
  2026.0811.2128.2099

AMD DVR product:
  {82B67D1C-33CB-46FF-A3DC-E7BE6902D38A}

AMD DVR version:
  26.10.26223.2125

RSXCM expected:
  22.10.0.0
```

RSXCM is ancillary/audited. Absence or version drift produces evidence warnings but is not by itself a failed driver/software seal.

## Required final policy state

```text
GPU Status                = OK
ProblemCode               = 0
HasProblem                = False
Go-applicable amduw23e    = absent
Foreign amduw23e          = permitted/preserved
Test Signing              = OFF
nointegritychecks         = OFF
ShowRSOverlay             = true
ColorVibrance_ENABLE_DEF  = 1
Stage 2/3/4               = Passed
FailedChecks              = 0
Workflow Stage            = Complete
```

## Final release validation gates

The exact final bytes passed:

- Windows PowerShell 5.1 package/parser preflight with `Passed=True`, `FailedChecks=0`, exit code `0`;
- physical machine-wide mutex rejection of a second launcher before persistent mutation;
- physical saved-`Complete` read-only Stage 4 revalidation;
- 72/72 Stage 4 checks with zero failures and zero warnings on the finalized field state.

The package itself remains the executable source of truth. The documentation-only repository publication record does not duplicate or rewrite those executable files.
