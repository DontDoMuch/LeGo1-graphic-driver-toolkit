# Public Beta v4.5 validation summary

## Final package gates

The exact final release bytes passed the real Windows PowerShell 5.1 regression with:

```text
Public entry gate exit:     0
Preflight exit:             0
Package manifest:           23/23
PowerShell parser:          13 files / 0 errors
Source-backed checks:       43/43 PASS
FailedChecks:               0
.NET evidence ZIP smoke:    PASS
Auto-evidence source gate:  PASS
```

All three supported profile outputs were rebuilt byte-exact from the frozen AMD 26.8.1 source. Exact HWID -> DDInstall binding passed for all three profiles, while Go 2 `REV_C4` remained rejected.

## Physical final-audit state

The Go 1 destructive run used the immediate pre-auto-evidence combined v4.5 candidate. The final public candidate changes only top-level evidence-ZIP packaging/manifest identity and was validated non-destructively with the real-host Regression v5.

```text
Legion Go 1 Z1 Extreme
78/78 PASS
FailedChecks = 0
Warnings = 0
WorkflowStage = Complete
Test Signing = OFF
nointegritychecks = OFF

Legion Go S Z1 Extreme
81/81 PASS
FailedChecks = 0
Warnings = 0
Test Signing = OFF
nointegritychecks = OFF

Legion Go 2 Z2 Extreme
79/79 PASS
FailedChecks = 0
Warnings = 0
Test Signing = OFF
nointegritychecks = OFF
```

## Per-profile proof

- Go 1: exact `REV_04`, Phoenix, `ati2mtag_Phoenix_LegionGo`, frozen INF/DAT/kernel, catalog trust, AMD Software/runtime/tasks.
- Go S: exact `REV_04`, Phoenix, `ati2mtag_Phoenix_LegionGoS`, frozen INF/DAT/kernel, all 30 OEM registry directives, catalog trust, AMD Software/runtime/tasks.
- Go 2: exact `REV_C5`, Strix, `ati2mtag_Strix_LegionGo2`, `%AMD150E.517%`, frozen INF/DAT/kernel, all 28 OEM registry directives, catalog trust, AMD Software/runtime/tasks.

## Third-party-origin proof

The inherited v4 origin/rollback architecture was physically proven on Go 1 from a real ASUS ROG Ally Display origin. The prior Display package was preserved for rollback and the ASUS-only extension remained staged because it did not target Go 1.

v4.5 generalizes that hardware-applicability decision to the selected profile. Ally-origin migration is field-proven on Go 1; it has not been separately field-run on Go S or Go 2.

## Evidence boundary

Private Go S/Go 2 volunteer packages, private evidence archives, certificates, keys, and internal regression archives are not public release assets.
