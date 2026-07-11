# Legion Go AMD 26.6.2 Toolkit — Public Beta v1.0

Released: July 7, 2026

## Status

Public Beta v1.0 completed a full fresh-OEM end-to-end run and final post-restart persistence audit on an original Lenovo Legion Go.

Final result:

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## What this release does

- Validates the original Legion Go hardware and supported OEM baseline
- Verifies the exact user-supplied AMD 26.6.2 `-c` installer
- Reconstructs and signs the validated corrected display-driver package
- Installs and verifies driver `32.0.31021.1015`
- Returns Windows to normal signing with Test Signing off
- Registers and verifies AMD's official Microsoft-signed catalog
- Preserves the Lenovo extension, AMDUWP, and compatibility metadata
- Installs native AMD Software `.2099` and RSXCM `22.10.0.0`
- Retires legacy `.2089` MSI/AppX state
- Produces a final read-only persistence report

## Release ZIP

```text
LegionGo-AMD-26.6.2-Public-Beta-v1.0.zip
SHA-256:
46B9F4FE778B7661E984008A20961A8FF5B3E7B6596FF9E2EB927AF80AA16469
```

## Required external installer

Not included:

```text
whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe
Size: 1,630,707,976 bytes
SHA-256:
3FD0073C74E0D043558087511F5624ED42D1241E852C2A9ED5AC5C80F158F893
```

## Important

Read `Instructions.txt` completely. This release is intended only for the original Lenovo Legion Go and the documented hardware identity and OEM baseline. Use at your own risk.
