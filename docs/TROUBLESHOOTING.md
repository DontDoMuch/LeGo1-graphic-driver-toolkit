# Troubleshooting

## General rule

Stop at the current numbered script. Do not skip ahead.

The scripts reuse valid work and compare saved state with the live system. Rerun the same script after correcting the reported problem.

Logs:

```text
C:\ProgramData\LegionGo-AMD-26.6.2\Logs
```

Workflow state:

```text
C:\ProgramData\LegionGo-AMD-26.6.2
```

Driver build and extracted source data:

```text
C:\AMD\LegionGo-26.6.2
```

## The script does not start

Use an elevated Windows PowerShell 5.1 window and the exact documented command. Do not use **Run with PowerShell**.

## AMD installer not found or rejected

Confirm that the installer is beside the scripts and has the exact filename, size, and SHA-256:

```text
whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe
1,630,707,976 bytes
3FD0073C74E0D043558087511F5624ED42D1241E852C2A9ED5AC5C80F158F893
```

Verify it:

```powershell
Get-FileHash ".\whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe" -Algorithm SHA256
```

A different suffix, build, size, hash, or invalid signature is not supported.

## Missing prerequisite

Script 1 lists the missing tool and asks before using WinGet. Approve only when internet access is available and the listed package IDs are correct.

After installation, allow Script 1 to rescan. Do not manually substitute unrelated SDK or WDK versions.

## Secure Boot is enabled

Script 1 cannot disable Secure Boot itself. Approve the UEFI restart, turn Secure Boot off in firmware, save, start Windows, and rerun Script 1.

Have the BitLocker or Device Encryption recovery key available first.

## Script 1 says Test Signing is not active

A Windows restart is required after Test Signing is configured. Save work, approve the restart, sign in, and rerun Script 1.

## The display flashes during Script 2

A brief display reset can occur when Windows binds the corrected driver. Do not power the device off merely because the display flashes.

If the display does not recover, allow Windows time to complete the operation. After recovery or reboot, rerun Script 2 and preserve its log.

## Script 2 rerun does not report readiness

Script 2 requires a real reboot after its installation phase. Confirm that Windows restarted rather than only signing out or closing the terminal. Rerun Script 2 after sign-in.

The script checks the live driver, INF, kernel, GPU health, Test Signing, catalogs, extension, and AMDUWP; saved JSON alone cannot force a pass.

## AMD Software does not show the normal dashboard

Do not type `YES`.

Leave the terminal open, record what the window shows, and capture the Script 3 log. Close AMD Software only when safe, then rerun Script 3.

## More than one desktop context-menu entry appears

Do not type `YES`.

The supported state is exactly one **AMD: Radeon Software** desktop entry. Preserve the output and report the legacy AppX, RSXCM, and context-menu sections from Script 3 or Script 4.

## AppX or RSXCM error

Do not manually install a Microsoft Store package or a legacy `.2089` package. Preserve the exact error and rerun the same script after a normal reboot when instructed.

Manual package substitutions can create a state the public beta does not validate.

## Script 4 reports failed checks

Script 4 is read-only. The failure describes drift or an incomplete prior state; Script 4 does not repair it.

Review the first failed check, then return to the numbered script responsible for that component:

- Driver, kernel, catalog, Test Signing: Script 2
- AMD Software, RSXCM, legacy AppX, metadata: Script 3
- Source/package preparation: Script 1

Do not edit `final-audit-result.json` to create a pass.

## Reporting a problem

Include the Public Beta version, failed script number, exact command, full terminal output near the failure, relevant transcript, Windows build, active driver version and INF, and Secure Boot/Test Signing state.

Redact usernames or personal paths if desired. Never post recovery keys, private certificates, or account secrets.
