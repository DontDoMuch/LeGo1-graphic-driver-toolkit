<div align="center">

# Lenovo Legion Go AMD 26.9.2 Toolkit

### Public Beta v5.0 — AMD 26.9.2 for three exact supported Legion Go profiles

![Release](https://img.shields.io/badge/release-Public%20Beta%20v5.0-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.9.2-ED1C24?style=for-the-badge)
![Profiles](https://img.shields.io/badge/supported%20profiles-3-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify AMD 26.9.2 while preserving the OEM integration required by each supported Legion Go profile.**

[Latest release](../../releases/tag/public-beta-v5.0) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v5.0.** It targets AMD Adrenalin 26.9.2 / display driver `32.0.32015.2008` and retains the exact three-profile hardware scope established by v4.5.
>
> Public Beta v5.0 includes conditional public entry-gate handling for optional `-OfficialInfPath` / `-OfficialDatPath` arguments: they are forwarded only when non-empty, so normal launches use the standard static package preflight path.

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, AMD Software, scheduled tasks, and temporary Windows Test Signing configuration. Back up important data and **preserve your BitLocker or Device Encryption recovery key before disabling Secure Boot or starting the workflow**.

## Exact supported hardware

Public Beta v5.0 supports only these exact hardware IDs:

| Device | Exact HWID | AMD family | Active DDInstall | Final audit contract |
|---|---|---|---|---:|
| Lenovo Legion Go 1 Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGo` | 78 |
| Lenovo Legion Go S Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGoS` | 81 |
| Lenovo Legion Go 2 Z2 Extreme | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | Strix | `ati2mtag_Strix_LegionGo2` | 79 |

The resolver fails closed on every other hardware ID. Go 2 `REV_C4` remains an explicit negative fixture.

Not supported by v5.0: non-Extreme Go 1 variants, non-Z1-Extreme Go S variants, Go 2 AI Extreme, other Go 2 revisions/variants, eGPU paths, and unrelated AMD systems.

## What Public Beta v5.0 includes

| Area | Public Beta v5.0 behavior |
|---|---|
| AMD target | Adrenalin 26.9.2 / display `32.0.32015.2008` |
| Public workflow | One command, exactly two initial Y/N confirmations, automatic required reboot/resume boundaries |
| Hardware selection | Exact immutable HWID profiles; automatic resolver; no manual profile override |
| Starting stacks | Microsoft Basic, Lenovo OEM, prior public toolkit architectures, exact/healthy AMD states, and healthy structurally compatible third-party AMD Display origins |
| Foreign extensions | All `amduw23e` packages are inventoried; proven non-applicable packages are preserved |
| Per-device OEM semantics | Exact frozen profile-specific INF/DAT outputs; Go S preserves 30 ordered OEM directives; Go 2 preserves 28 ordered OEM directives |
| Catalog trust | Locally signed merged catalog plus exact original Microsoft WHCP `u0204590.cat`, with frozen critical target coverage independently required |
| Rollback | Starting Display material and applicable recognized Lenovo extension members are exported before destructive transition |
| Recovery | Failed checkpoints are transaction-aware; unproven rollback stays recovery-only; failed destructive stages do not automatically retry |
| Concurrency | Machine-wide installer mutex plus fail-closed detection of other registered Legion Go AMD resume workflows |
| Boot policy | Secure Boot front-gated; temporary Test Signing must finish OFF; `nointegritychecks` must finish OFF |
| Evidence | Final/failure evidence is preserved and packaged with direct .NET ZIP handling |

Compatibility does not mean an arbitrary AMD release can be substituted. Each AMD release requires separate payload inspection, semantic delta work, exact identities, and regression validation.

## Frozen release identities

Common AMD 26.9.2 identities:

```text
DriverVersion: 32.0.32015.2008
Official INF: u0204590.inf
Official INF SHA-256: 8E000BB2DDEC7E948D225B383FC867B4857F06387AA4A2B2A1EA1CF1819669F2
Official DAT SHA-256: C0AF3662075989517CC5A5C1B6417682525B7707EAE1B95DD9AB3F263AD8D2F4
Kernel SHA-256: 432AF310FE3FD129065E844548251CC49B969060A9478D543AC40ED59F318774
Official WHCP catalog SHA-256: E960CA26A2A0EA877976850204522719077FB02162754009D443220080F681F5
```

Per-profile deterministic outputs:

| Profile | Final INF SHA-256 | Final `amdgcf.dat` SHA-256 |
|---|---|---|
| Go 1 Z1 Extreme | `381E6122577AB273ED1ED8EE7BEB4B66CB89DA4B8BEFABA64B064416E778E1BF` | `2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223` |
| Go S Z1 Extreme | `8F2AF5D9CC3CAB28CDE2D96499A655B579AC9BC6C62A215961DA66B360C83136` | `2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223` |
| Go 2 Z2 Extreme | `F6EED28F18EA658FCB7B62F28ECC2FE9DE1ED24EF46CFA47AC5870211622F7D2` | `DCBD6E683B6EDCA86DF0F5D22A1E09299391B5AF45759D750367AC38AD919EF4` |

## Existing third-party AMD drivers

You do **not** need to restore Lenovo OEM graphics first when the current AMD Display stack is healthy and structurally classifiable.

The v4 origin/rollback architecture was physically field-validated from a real ASUS/ROG Ally graphics origin on the original Legion Go. v5.0 retains that selected-profile-aware architecture. Existing healthy third-party Display material is retained as rollback input; foreign/non-applicable `amduw23e` material is preserved rather than blindly deleted.

ROG Ally-origin migration is field-proven on Go 1. The same profile-aware contract is present for Go S and Go 2, but Ally-origin transitions have not been separately field-run on those two devices.

## Download and verify

Release asset:

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
```

The AMD installer is **not** included. Required source installer: https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-9-2.html

```text
whql-amd-software-adrenalin-edition-26.9.2-win11-c.exe
SHA-256: 72E368AE264F36E89CA0FE1DAB1CAD926047C2D6B0A3EFED9745D8D99780FE58
```

Download AMD's installer from AMD Support, then use the fail-closed verify/unblock/extract/run block in [Installation](docs/INSTALLATION.md).

## Validation highlights

- **Go 1:** physical AMD 26.9.2 validation completed on the v5.0 line, followed by a full one-command/resume/idempotent end-to-end run. Final audit: **78/78 PASS**, `FailedChecks=0`, `Warnings=0`, Test Signing OFF, `nointegritychecks` OFF, local + official critical catalog coverage **14/14 + 14/14**.
- **Go S / Go 2:** deterministic AMD 26.9.2 source/build contracts are frozen and source-rebuild validation is recorded. Device-specific physical profile evidence is inherited from the v4.5.1 lineage; **no new physical 26.9.2 run is claimed for those two devices**.
- The package release scope records a deterministic three-profile exact-source rebuild preflight of **45 checks / 0 failures**.
- The exact v5.0 ZIP contains **24 files**; `PACKAGE-MANIFEST.json` covers the other **23**, and publication verification confirmed **23/23** exact length/SHA-256 matches plus a clean ZIP CRC scan.
- The public entry gate forwards optional source-path arguments only when non-empty. The workflow identity is `Public-Beta-v5.0`, including `C:\ProgramData\LegionGo-AMD-26.9.2-MultiDevice-v5.0\<Profile>`.

Private volunteer packages and private evidence archives are not public release assets.

## Release history

- [Public Beta v5.0](releases/public-beta-v5.0/) — current AMD 26.9.2 release; three exact supported profiles
- [Public Beta v4.5.1](releases/public-beta-v4.5.1/) — AMD 26.8.1 compatibility/recovery hotfix
- [Public Beta v4.5](releases/public-beta-v4.5/) — AMD 26.8.1 multi-device release
- [Public Beta v4.0](releases/public-beta-v4.0/) — AMD 26.8.1 original Go 1 release
- [Public Beta v3.1](releases/public-beta-v3.1/) — AMD 26.7.1 bugfix
- [Public Beta v3.0](releases/public-beta-v3.0/) — AMD 26.7.1
- [Public Beta v2.1](releases/public-beta-v2.1/) — AMD 26.6.4
- Public Beta v2.0 — superseded AMD 26.6.4 release
- [Public Beta v1.1](releases/public-beta-v1.1/) — AMD 26.6.2
- [Public Beta v1.0](releases/public-beta-v1.0/) — AMD 26.6.2

Published release assets are immutable. Corrections to executable behavior require a new public version and new hashes.

## Important rules

- Do not manually select or override a hardware profile.
- Do not manually run numbered stages during the normal managed workflow.
- Do not manually delete staged `amduw23e` packages to bypass origin classification.
- Do not manually edit workflow state or toggle Test Signing while a managed run is active.
- Stop at a hard failure and preserve generated evidence instead of repeatedly forcing the failed stage.
- Do not substitute a different AMD installer or graphics release.
- Preserve BitLocker / Device Encryption recovery information before changing Secure Boot settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, ASUS, GitHub, or game/anti-cheat vendors.

Original project code and documentation are released under the [MIT License](LICENSE). Third-party software and trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
