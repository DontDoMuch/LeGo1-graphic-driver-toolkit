# Public Beta v4.5.1 release notes

Public Beta v4.5.1 is a targeted hotfix over v4.5. It does **not** change the AMD 26.8.1 target, hardware scope, profile INF/DAT outputs, or 78/81/79 final-audit contracts.

## Hotfix changes

- Accepts the safe additive official-catalog pre-state where exact Microsoft catalog copies already cover all 14 frozen targets but the toolkit-managed filename is absent. The new `ApplyPreservingExisting` path registers the exact managed copy and preserves preexisting exact Microsoft copies.
- Re-proves the restored Display identity and health after applicable extension restoration plus the final PnP rescan before a rollback outcome can be accepted.
- Uses fresh persistent state under `C:\ProgramData\LegionGo-AMD-26.8.1-MultiDevice-v4.5.1\<Profile>` instead of reusing v4.5 state.
- Corrects `Start-LegionGo-AMD-26.8.1.cmd` to target the v4.5.1 validated runner.
- Documents the PowerShell 7 -> Windows PowerShell 5.1 inherited-`PSModulePath` edge case. No `PSModulePath` sanitizer is present in the released bytes.

## Validation boundary

The unchanged physical baseline remains:

```text
Go 1 Z1 Extreme: 78/78 PASS, 0 failures, 0 warnings
Go S Z1 Extreme: 81/81 PASS, 0 failures, 0 warnings
Go 2 Z2 Extreme: 79/79 PASS, 0 failures, 0 warnings
```

The v4.5 catalog-prestate failure failed closed and recovered to a proven healthy GPU/boot-policy state. A v4.5.1 Windows PowerShell 5.1 regression on the hotfix line passed 23/23 package manifest, 13 files / 0 parser errors, 32/32 static preflight, and 43/43 source-backed preflight. The exact final `910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75` bytes were successfully run from a clean Windows PowerShell 5.1 environment. No missing final volunteer evidence ZIP is claimed.

## Release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.1.zip
SHA-256: 910613864EED31EEA38143E639C0203B0E4F6E4EA38B95FBEC66494053F7CA75
Size: 132857 bytes
```
