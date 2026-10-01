# Troubleshooting

## Unsupported hardware

Public Beta v5.0 supports only:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04  Legion Go 1 Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04  Legion Go S Z1 Extreme
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5  Legion Go 2 Z2 Extreme
```

A resolver rejection on another revision is expected fail-closed behavior. Do not override the profile manually.

## Windows PowerShell 5.1 module-load failure

`Start-LegionGo-AMD-26.9.2.cmd` explicitly invokes Windows PowerShell 5.1 with `-NoProfile`, but child processes still inherit environment variables. A PowerShell 7 parent can supply a PowerShell-7-oriented `PSModulePath`, causing the 5.1 host to resolve an incompatible module location.

The exact v5.0 release asset does **not** contain a `PSModulePath` sanitizer. Supported workaround:

- close the PowerShell 7 parent;
- launch `Start-LegionGo-AMD-26.9.2.cmd` from File Explorer or Command Prompt, or from a fresh Windows PowerShell 5.1 session.

## Entry gate mentions OfficialInfPath / OfficialDatPath

Public Beta v5.0 forwards optional source-path parameters only when non-empty. Verify that the ZIP hash is exactly:

```text
4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
```

If your local v5.0 ZIP does not match this exact hash, replace it with the published v5.0 package instead of editing the runner locally.

## Foreign `amduw23e` package remains staged

This can be correct. v5.0 inventories all such packages and only enters destructive extension handling when a readable INF actually targets the **selected exact hardware profile**. Proven foreign/non-applicable packages are intentionally preserved.

Unreadable scope or conflicting selected-profile-applicable lineages fail closed.

## AMD installer not found or hash mismatch

Required source:

```text
whql-amd-software-adrenalin-edition-26.9.2-win11-c.exe
SHA-256: 72E368AE264F36E89CA0FE1DAB1CAD926047C2D6B0A3EFED9745D8D99780FE58
```

Keep exactly one matching copy somewhere under Downloads. A same-named file with different bytes is not accepted.

## Secure Boot

Secure Boot must be disabled for this local-catalog signing architecture. Enabled or unknown Secure Boot state is a hard front gate.

**Preserve the BitLocker / Device Encryption recovery key before changing Secure Boot.**

## Evidence ZIP was not created

Preserve the evidence folder itself. v5.0 uses direct .NET ZIP packaging after the audit. A packaging-only failure must not be treated as permission to reinstall the driver or manually rerun destructive stages.

## Rerunning after Complete

A saved `Complete` workflow reruns the selected-profile Stage 4 audit read-only to detect live-system drift. A drift failure reports evidence; it does not automatically repair the machine.

## Why do some paths still say v4.0 during a v5.0 run?

Some protected engine identifiers intentionally retain v4.0 naming as implementation lineage. The runner and ProgramData workflow namespace correctly use `Public-Beta-v5.0` for the current release.

Do not rename or delete those paths. Verify the v5.0 package hash and selected profile instead.

## Should I use DDU?

DDU is not part of the normal Public Beta v5.0 workflow. Do not insert it into a normal upgrade/repair run unless a documented recovery procedure specifically calls for it.
