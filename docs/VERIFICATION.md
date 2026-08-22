# Verification

## Public Beta v3.1 release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip
SHA-256: ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
Size: 124377 bytes
```

PowerShell:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip" -Algorithm SHA256
```

The ZIP contains one top-level `LegionGo-AMD-26.7.1-Public-Beta-v3.1` directory with 18 files. Its internal `SHA256SUMS.txt` contains 17 entries and verifies every other packaged file.

## Official AMD source

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

## Final installed identities

```text
DriverVersion:
  32.0.31035.1003

Final INF SHA-256:
  9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409

Final amdgcf.dat SHA-256:
  DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766

Loaded amdkmdag.sys SHA-256:
  D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5
```

## Matching AMD Software

```text
AMD Settings product:
  {4BB6B15D-DFAB-4FD1-8DA6-07DD594939BF}

AMD Settings version:
  2026.0716.2129.2099

AMD DVR product:
  {94D923DB-3F51-406F-A477-445876B3D70A}

AMD DVR version:
  26.10.26197.2124

RSXCM:
  22.10.0.0
```

## Required final policy state

```text
GPU Status                = OK
ProblemCode               = 0
HasProblem                = False
standalone amduw23e       = absent
Test Signing              = OFF
nointegritychecks         = OFF
ShowRSOverlay             = true
ColorVibrance_ENABLE_DEF  = 1
Stage 2/3/4               = Passed
FailedChecks              = 0
Workflow Stage            = Complete
```

## Executable provenance

The 18 files in `releases/public-beta-v3.1/toolkit/` are byte-identical to the contents of the frozen release ZIP.

The corrected package audit records:

```text
Static audit: 16/16 PASS
```

Required internal RC2zp class/type identifiers remain intact. Public entrypoints, workflow/result schemas, signer identity, evidence names, and primary release headers use Public Beta v3.1.

The package's internal file hashes are published in:

```text
releases/public-beta-v3.1/TOOLKIT-SHA256SUMS.txt
```
