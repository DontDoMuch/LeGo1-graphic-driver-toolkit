# Public Beta v4.5.1 validation summary

## Exact final asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
SHA-256: 910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
Size: 132857 bytes
ZIP entries: 24
PACKAGE-MANIFEST: 23/23 verified
ZIP CRC: PASS
```

## Hotfix-line Windows PowerShell 5.1 preflight

```text
Actual public entry gate: ExitCode 0
Package manifest:         23/23
PowerShell parser:        13 files / 0 errors
Static preflight:         32/32 PASS
Source-backed preflight:  43/43 PASS
FailedChecks:             0
.NET ZIP smoke:           PASS
```

## Field recovery rationale

v4.5 encountered a Go 2 Stage 2 state with one exact Microsoft official catalog covering all 14 frozen targets while the managed-name copy was absent. The old logic failed closed. Recovery re-proved a healthy GPU/previous driver state and normalized Test Signing / `nointegritychecks` OFF. v4.5.1 converts only that exact safe state to additive `ApplyPreservingExisting` behavior and re-proves rollback after extension restore/final rescan.

The final v4.5.1 bytes use a fresh ProgramData namespace and were successfully run in a clean Windows PowerShell 5.1 environment. No separate final volunteer evidence ZIP is claimed.

## Unchanged physical profile baseline

```text
Legion Go 1 Z1 Extreme: 78/78 PASS
Legion Go S Z1 Extreme: 81/81 PASS
Legion Go 2 Z2 Extreme: 79/79 PASS
```

The three exact supported HWIDs and all frozen profile output identities are unchanged from v4.5.
