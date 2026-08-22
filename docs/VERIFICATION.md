# Verification

## Public Beta v3.0 release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip
SHA-256: E946D1F981A435B9C8F8E94542649FA48970F7C56F85138E399411E5C2496DAF
```

PowerShell:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip" -Algorithm SHA256
```

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
GPU Status           = OK
ProblemCode          = 0
HasProblem           = False
standalone amduw23e  = absent
Test Signing         = OFF
nointegritychecks    = OFF
ShowRSOverlay        = true
ColorVibrance_ENABLE_DEF = 1
```

## Executable provenance

The executable files in `releases/public-beta-v3.0/toolkit/` are the exact
final field-proven RC2zk candidate snapshot.

Candidate archive SHA-256:

```text
4E55DEF4E892A6BA4314911B2797018A03E871F83EFB4D95022CB1FD90EC4B4A
```

Internal RC2zk names are provenance identifiers, not the public release name.
