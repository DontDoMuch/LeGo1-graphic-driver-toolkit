# Installation

This guide covers **Public Beta v2.1** for the original Lenovo Legion Go / Legion Go 1.

## Required files

Download and verify:

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
SHA-256: DE3A7FD534BB136881D8685F17AD5F7FD3CCDC46597487465D0966C2A365038C
```

Extract it so this folder exists:

```text
C:\Users\<YOUR USERNAME>\Downloads\LeGo-toolkit
```

The extracted folder contains four scripts, `Instructions.txt`, and `SHA256SUMS.txt`.

Place the supported official AMD Windows 11 installer beside the six release files:

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
SHA-256: E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
```

Read `Instructions.txt` completely before starting.

## Verify the release files

From inside the extracted `LeGo-toolkit` folder:

```powershell
Get-FileHash .\*.ps1, .\Instructions.txt -Algorithm SHA256
Get-Content .\SHA256SUMS.txt
```

Compare every result with `SHA256SUMS.txt` before running Script 1.

## Run order

Open **Windows PowerShell as Administrator** and run:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1"
```

Follow Script 1's restart and rerun instructions. Continue only when it reports readiness for Script 2.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\02-Install-Driver-And-Verify-Normal-Signing.ps1"
```

Follow Script 2's restart and rerun instructions. Continue only when it reports `Ready for Script 3: True`.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\03-Install-AMD-Software-And-Reboot.ps1"
```

Follow Script 3's restart instructions. Continue only when it reports readiness for Script 4.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\04-Final-Persistence-Audit.ps1"
```

The installation is complete only when Script 4 reports:

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## Do not

Do not use DDU, skip stages, delete state, manually replace packages, edit release files, or change Test Signing between script runs. Stop at the first failure and preserve the full output.
