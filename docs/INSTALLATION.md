# Installation

## Current release

Public Beta v3.1 targets AMD Adrenalin 26.7.1 on the original Lenovo Legion Go.

## Requirements

- Original Legion Go / Legion Go 1:
  `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA`
- Windows 11 x64
- Administrator access
- AC power recommended
- Secure Boot disabled
- BitLocker / Device Encryption recovery information preserved

## Required downloads

1. `LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip`
2. AMD's official `whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe`

Required toolkit ZIP SHA-256:

```text
ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
```

Required AMD installer SHA-256:

```text
116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

Leave the AMD installer anywhere under `Downloads`.

## Verify the toolkit ZIP

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip" -Algorithm SHA256
```

The required result must exactly match the hash above and the GitHub Release.

## Run

Unblock and extract the toolkit ZIP, then run:

```text
Start-LegionGo-AMD-26.7.1.cmd
```

The supported public workflow asks exactly two Y/N questions at the beginning.

After both are accepted, the workflow automatically handles:

- package and independent parser preflight;
- lightweight dependency preparation;
- exact source extraction and hashing;
- local catalog build/signing;
- temporary Test Signing configuration;
- required reboot/resume boundaries;
- starting-origin classification and rollback export;
- exact 26.7.1 binding;
- return to normal boot-signing policy;
- matching AMD Software / DVR installation;
- final persistence audit.

If the independent parser gate fails before launcher logging begins, v3.1 writes a `LegionGo-AMD-26.7.1-Public-Beta-v3.1-Parser-Gate-*.txt` transcript under Downloads and keeps the failure console open until Enter is pressed.

## Do not

During a managed run:

- do not manually run the numbered stage scripts;
- do not remove Driver Store packages;
- do not manually delete staged `amduw23e` generations;
- do not delete workflow state;
- do not toggle Test Signing yourself;
- do not rerun a failed stage repeatedly.

## Success

A complete workflow ends with:

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow Stage: Complete
```

The final audit evidence is written under Downloads. The evidence directory is authoritative even if a ZIP wrapper is not automatically produced.

## Failure

Stop at the first hard failure and preserve the generated parser transcript or failure-evidence bundle/folder. The managed launcher removes resume authorization and returns boot-integrity policy to normal when recovery requires it. It does not automatically retry a failed stage.
