# Installation

This guide covers **Public Beta v2.0** for the original Lenovo Legion Go / Legion Go 1.

## Required files

Download and verify: 

LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip 

SHA-256: D2DA30DD76B9460C14D96FB09824D727D13B7D24BA327263E6FAA8ACC751CBD4



Extract it so this folder exists:

C:\Users\<YOUR USERNAME>\Downloads\LeGo-toolkit

Place one official AMD-signed Windows 11 installer for AMD 26.6.4 beside the four scripts. The validated reference container is:


whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe 

SHA-256: E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29


Read `Instructions.txt` completely before starting.

## Run order

Open **Windows PowerShell 5.1 as Administrator** and run:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1"
```

After its requested restart, run Script 1 again. Continue only when it reports readiness for Script 2.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\02-Install-Driver-And-Verify-Normal-Signing.ps1"
```

After its requested restart, run Script 2 again. Continue only when it reports `Ready for Script 3: True`.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\03-Install-AMD-Software-And-Reboot.ps1"
```

After its requested restart, run Script 3 again. Continue only when it reports `Ready for Script 4: True`.

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\04-Final-Persistence-Audit.ps1"
```

The installation is complete only when Script 4 reports:


SCRIPT 4 PASS: True 

Failed checks: 0 

TOOLKIT COMPLETE: True 


## Do not

Do not use DDU, skip stages, delete state, manually replace packages, or change Test Signing between script runs. Stop at the first failure and preserve the full output.
