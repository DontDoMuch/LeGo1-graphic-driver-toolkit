# Legion Go 1 Graphics Driver Toolkit — Public Beta v2.1

Released: July 17, 2026

## Status

Public Beta v2.1 is the current corrected AMD 26.6.4 release. It supersedes Public Beta v2.0 after external users reported safe Script 1 integrity-check stops.

The final v2.1 artifact passed the complete workflow and final post-restart persistence audit through both documented regression paths:

- Fresh Lenovo OEM graphics installation → AMD 26.6.4.
- Fresh Lenovo OEM → Public Beta v1.1 / AMD 26.6.2 → Public Beta v2.1 / AMD 26.6.4.

Final result:

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## What this release does

- Supports the original Lenovo Legion Go hardware identity.
- Accepts fresh OEM, validated AMD 26.6.2 toolkit, and existing validated AMD 26.6.4 starting states.
- Verifies the user-supplied AMD 26.6.4 installer and exact extracted target payload.
- Reconstructs and locally signs the corrected display-driver package.
- Installs and verifies display driver `32.0.31021.5001`.
- Returns Windows to normal signing with Test Signing off.
- Registers and verifies AMD's official Microsoft-signed catalog.
- Preserves a semantically compatible Lenovo extension and healthy Microsoft-signed AMDUWP component.
- Installs or repairs native AMD Software `.2099` and RSXCM `22.10.0.0`.
- Retires conflicting legacy `.2089` MSI/AppX state.
- Produces a final read-only persistence report.

## Release asset

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
SHA-256:
DE3A7FD534BB136881D8685F17AD5F7FD3CCDC46597487465D0966C2A365038C
```

The ZIP contains exactly one `LeGo-toolkit` root folder with:

- `01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1`
- `02-Install-Driver-And-Verify-Normal-Signing.ps1`
- `03-Install-AMD-Software-And-Reboot.ps1`
- `04-Final-Persistence-Audit.ps1`
- `Instructions.txt`
- `SHA256SUMS.txt`

## Required external installer

Not included:

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
Size: 890,946,264 bytes
SHA-256:
E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
```

## Important

Read `Instructions.txt` completely. Do not edit the release files, skip stages, use DDU, or manually replace packages. This release is intended only for the original Lenovo Legion Go and the documented hardware identity.
