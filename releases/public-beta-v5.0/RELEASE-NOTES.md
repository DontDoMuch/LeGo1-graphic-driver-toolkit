# Public Beta v5.0 release notes

Public Beta v5.0 moves the toolkit to AMD Adrenalin 26.9.2 while retaining the exact three-profile, fail-closed transaction/recovery architecture established by the v4.5 lineage.

## AMD target

```text
AMD Adrenalin: 26.9.2
Display driver: 32.0.32015.2008
Official INF: u0204590.inf
```

## Supported hardware

Public Beta v5.0 supports exactly these three hardware profiles:

- Lenovo Legion Go 1 Z1 Extreme — `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04`
- Lenovo Legion Go S Z1 Extreme — `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04`
- Lenovo Legion Go 2 Z2 Extreme — `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5`

All other hardware fails closed before mutation. Go 2 `REV_C4` remains an explicit negative fixture.

## What is included

- deterministic AMD 26.9.2 INF/DAT builders for all three supported profiles;
- exact immutable HWID profile selection with no manual profile override;
- preservation of healthy supported third-party AMD Display origins as rollback material;
- selected-profile-aware `amduw23e` handling that preserves proven foreign/non-applicable packages;
- dual catalog trust using the local merged catalog plus exact Microsoft WHCP `u0204590.cat`;
- transaction-aware rollback/recovery and versioned persistent workflow state;
- machine-wide concurrency protection and fail-closed detection of other registered resume workflows;
- Secure Boot front gate, temporary Test Signing, and required final `nointegritychecks` OFF / Test Signing OFF state;
- public entry-gate package-manifest verification, Windows PowerShell 5.1 parser gate, and read-only preflight before mutation;
- optional `-OfficialInfPath` / `-OfficialDatPath` arguments are forwarded to preflight only when non-empty, so normal launches use the standard static package-preflight path;
- final/failure evidence preservation with direct .NET ZIP packaging.

The public workflow identity is `Public-Beta-v5.0`, with persistent state under:

```text
C:\ProgramData\LegionGo-AMD-26.9.2-MultiDevice-v5.0\<Profile>
```

## Validation boundary

Go 1 has physical AMD 26.9.2 end-to-end validation with final audit **78/78**, zero failures, zero warnings, Test Signing OFF, `nointegritychecks` OFF, and **14/14 + 14/14** critical local/official catalog coverage.

Go S and Go 2 have exact deterministic AMD 26.9.2 source/build proof. Their device-profile physical evidence is inherited from the physically validated v4.5.1 lineage; this release does **not** claim new physical 26.9.2 field runs for those two devices.

The package release scope records an exact-source three-profile rebuild preflight of **45 checks / 0 failures**.

## Exact public asset

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
ZIP entries: 24
PACKAGE-MANIFEST: 23/23 exact length/SHA-256 verified
ZIP CRC: PASS
```
