# Installation

This page summarizes the tested Public Beta v1.0 workflow. The authoritative release guide is [`releases/Public-Beta-v1.0/Instructions.txt`](../releases/Public-Beta-v1.0/Instructions.txt).

## Before starting

- Use only an original Lenovo Legion Go.
- Start from Lenovo OEM display driver `32.0.23017.1001`.
- Connect AC power.
- Back up important files.
- Preserve the BitLocker or Device Encryption recovery key.
- Ensure at least 12 GB free space.
- Do not use DDU.
- Do not manually change Test Signing during the workflow.
- Do not skip scripts.

## Required AMD source

Place this exact official AMD installer beside the four scripts:

```text
whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe
Size: 1,630,707,976 bytes
SHA-256:
3FD0073C74E0D043558087511F5624ED42D1241E852C2A9ED5AC5C80F158F893
```

The installer is not included in this project.

## Open an elevated shell

Open **Windows PowerShell 5.1 as Administrator**.

Do not use the script right-click action **Run with PowerShell**. The documented command supplies a process-only execution-policy override and does not permanently change the computer's execution policy.

## Script 1

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1"
```

Script 1 checks the device, Windows build, free space, prerequisites, exact AMD source, package construction, catalog, certificate, and Test Signing readiness.

It may offer to install these missing prerequisites through WinGet:

- `Microsoft.PowerShell`
- `7zip.7zip`
- `Microsoft.WindowsSDK.10.0.28000`
- `Microsoft.WindowsWDK.10.0.28000`

If Secure Boot is enabled, Script 1 may ask to restart into UEFI. Disable Secure Boot manually, save, boot Windows, and rerun Script 1.

When Script 1 asks to restart Windows to activate Test Signing, save work and approve the restart. After sign-in, rerun Script 1.

Continue only after:

```text
SCRIPT 1 PASS: True
Ready for Script 2: True
```

## Script 2

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\02-Install-Driver-And-Verify-Normal-Signing.ps1"
```

Approve corrected-driver installation when prompted. The display may briefly flash or reset while Windows binds the driver.

Approve the restart after saving work. After sign-in, rerun Script 2. The second run verifies that the corrected driver, kernel, catalogs, Lenovo extension, AMDUWP, and healthy GPU state survived with Test Signing off.

Continue only after:

```text
SCRIPT 2 PASS: True
Ready for Script 3: True
```

## Script 3

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\03-Install-AMD-Software-And-Reboot.ps1"
```

Approve installed-system changes when prompted.

Script 3 installs native AMD Software `.2099`, verifies native RSXCM `22.10.0.0`, retires legacy `.2089` state, restores Lenovo-compatible metadata, and refreshes shell associations without terminating Explorer.

When AMD Software opens, check both conditions:

1. The normal dashboard is visible.
2. The desktop right-click menu has exactly one **AMD: Radeon Software** entry.

Type the complete word `YES` only when both conditions are true.

Approve the restart. After sign-in, rerun Script 3.

Continue only after:

```text
SCRIPT 3 PASS: True
Ready for Script 4: True
```

## Script 4

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\LeGo-toolkit\04-Final-Persistence-Audit.ps1"
```

Script 4 is read-only. It repeats the final driver, catalog, software, AppX, metadata, event-log, and visual checks.

Confirm the dashboard and exactly one context-menu entry with `YES`.

Success is:

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## Normal run count

With Secure Boot already disabled:

- Script 1: two launches
- Script 2: two launches
- Script 3: two launches
- Script 4: one launch
- Three Windows restarts

If Secure Boot is initially enabled, Script 1 may add one UEFI restart and one additional Script 1 launch.

## After completion

Secure Boot may be re-enabled manually if desired. After doing so, boot Windows and rerun Script 4. Test Signing must remain off.
