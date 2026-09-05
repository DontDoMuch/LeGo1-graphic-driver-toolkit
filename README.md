<div align="center">

# Lenovo Legion Go AMD 26.8.1 Toolkit

### Public Beta v4.5 — one compatibility-focused workflow for three exact validated hardware profiles

![Release](https://img.shields.io/badge/release-Public%20Beta%20v4.5-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.8.1-ED1C24?style=for-the-badge)
![Profiles](https://img.shields.io/badge/validated%20profiles-3-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify AMD 26.8.1 while preserving the OEM integration required by each validated Legion Go profile.**

[Latest release](../../releases/tag/public-beta-v4.5) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v4.5.** It targets AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004` and expands the v4 engine from the original Legion Go to three exact validated hardware profiles.
>
> v4.5 uses one automatic exact-HWID resolver with no manual profile override. The physical Go 1 combined-package run passed **78/78**, the Go S Z1 Extreme field run passed **81/81**, and the Go 2 Z2 Extreme field run passed **79/79**, all with zero failed checks and zero warnings. The exact final package also passed the real Windows PowerShell 5.1 entry gate and a 43-check all-profile source-backed regression with zero failures.

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, AMD Software, scheduled tasks, and temporary Windows Test Signing configuration. Back up important data and **preserve your BitLocker or Device Encryption recovery key before disabling Secure Boot or starting the workflow**.

## Exact supported hardware

Public Beta v4.5 supports only these exact hardware IDs:

| Device | Exact HWID | AMD family | Active DDInstall | Final audit |
|---|---|---|---|---:|
| Lenovo Legion Go 1 Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGo` | 78/78 |
| Lenovo Legion Go S Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGoS` | 81/81 |
| Lenovo Legion Go 2 Z2 Extreme | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | Strix | `ati2mtag_Strix_LegionGo2` | 79/79 |

The resolver fails closed on every other hardware ID. In particular, Go 2 `REV_C4` is a tested negative fixture.

Not validated by v4.5: non-Extreme Go 1 variants, non-Z1-Extreme Go S variants, Go 2 AI Extreme, other Go 2 revisions/variants, eGPU paths, and unrelated AMD systems.

## What Public Beta v4.5 includes

| Area | Public Beta v4.5 behavior |
|---|---|
| AMD target | Adrenalin 26.8.1 / display `32.0.31041.1004` |
| Public workflow | One command, exactly two initial Y/N confirmations, automatic required reboot/resume boundaries |
| Hardware selection | Exact immutable HWID profiles; automatic resolver; no manual profile override |
| Starting stacks | Microsoft Basic, Lenovo OEM, prior public toolkit architectures, exact/healthy AMD 26.8.1 states, and healthy structurally compatible third-party AMD Display origins |
| Third-party origins | Existing healthy AMD/ROG Ally-style Display packages do not need to be replaced with Lenovo OEM first; the active Display package is preserved as verified rollback material |
| `amduw23e` scope | All packages are inventoried; destructive handling is limited to readable packages that actually target the selected hardware profile |
| Foreign extensions | Proven non-applicable packages are preserved even when filename, class, or ExtensionId overlap known Lenovo lineage |
| Per-device OEM semantics | Exact frozen profile-specific INF/DAT outputs; Go S preserves 30 ordered OEM directives; Go 2 preserves 28 ordered OEM directives |
| Catalog trust | Active locally signed merged catalog plus exact original Microsoft WHCP `u0203304.cat`, with frozen target coverage required from each |
| Rollback | Starting Display material and every applicable recognized Lenovo extension member are exported before destructive transition |
| Recovery | Failed checkpoints are transaction-aware; unproven rollback stays recovery-only; no failed destructive stage automatically retries |
| Concurrency | Machine-wide installer mutex plus fail-closed detection of other registered Legion Go AMD resume workflows |
| Boot policy | Secure Boot front-gated; temporary Test Signing must finish OFF; `nointegritychecks` must finish OFF |
| Evidence | Final/failure evidence is preserved; v4.5 adds direct .NET ZIP packaging rather than relying on optional archive cmdlets |

Compatibility does not mean an arbitrary AMD release can be substituted. Each AMD release needs separate payload inspection, semantic delta work, exact identities, and regression validation.

## Frozen installed identities

Common release identities:

```text
DriverVersion: 32.0.31041.1004
Kernel SHA-256: 92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
Official WHCP catalog SHA-256: 23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48
```

Per-profile output identities:

| Profile | Final INF SHA-256 | Final `amdgcf.dat` SHA-256 |
|---|---|---|
| Go 1 Z1 Extreme | `F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42` | `83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953` |
| Go S Z1 Extreme | `1C17657B1550AAB3BE0A981864122B3A2E852E3F90DA3EEF1413AB33561FE6EA` | `83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953` |
| Go 2 Z2 Extreme | `BE67AD0E09147A7C33AA9688533F0BE99842F0E2FE14F8C79EB35CB6BA3F45CC` | `B85E600A892480BD5F15A4BC1C9B2993FF0717E95A81F480586A8B9653F514A8` |

## Existing third-party AMD drivers

You do **not** need to restore Lenovo OEM graphics before running v4.5 when the current AMD Display stack is healthy and structurally classifiable.

The v4 origin/rollback architecture was physically field-validated from a real ASUS/ROG Ally graphics origin on the original Legion Go. v4.5 preserves that logic and generalizes hardware applicability to the selected profile. Existing third-party Display material is retained as rollback input; foreign/non-applicable `amduw23e` material is preserved rather than blindly deleted.

ROG Ally-origin migration is field-proven on Go 1. The same profile-aware third-party-origin contract is present for Go S and Go 2, but an Ally-origin transition has not been separately field-run on those two devices.

## Download and verify

Release asset:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.zip
```

SHA-256:

```text
B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C
```

Size: `132499 bytes`.

The AMD installer is **not** included. Download AMD's official 26.8.1 package and keep it somewhere under your Downloads folder:

https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-7000-series/amd-ryzen-7-7840u.html (Might have to check previous versions if its not on this page)

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

Use the fail-closed verify/unblock/extract/run block in [Installation](docs/INSTALLATION.md).

## Field validation highlights

- Combined v4.5 engine on physical Go 1 Z1 Extreme: **78/78 PASS**, zero failures, zero warnings. That destructive run used the immediate pre-auto-evidence candidate; the final candidate changes only top-level evidence-ZIP packaging/manifest identity and preserves the field-proven Stage 1-4/device path.
- Go S Z1 Extreme profile on volunteer hardware: **81/81 PASS**, zero failures, zero warnings.
- Go 2 Z2 Extreme profile on volunteer hardware: **79/79 PASS**, zero failures, zero warnings.
- Exact final v4.5 ZIP: real Windows PowerShell 5.1 entry gate PASS plus **43/43** all-profile source-backed preflight and direct .NET ZIP smoke PASS.
- All three profile INF/DAT pairs rebuild byte-exact from the frozen AMD 26.8.1 source.
- Real Go 1 ASUS/ROG Ally Display origin migration remains field-proven through the inherited v4 origin/rollback architecture.

Private volunteer packages and private evidence archives are not public release assets.

## Release history

- [Public Beta v4.5](releases/public-beta-v4.5/) — current release, AMD 26.8.1, exact three-profile support
- [Public Beta v4.0](releases/public-beta-v4.0/) — AMD 26.8.1, original Go 1 release
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
- Stop at a hard failure and preserve the generated evidence instead of repeatedly forcing the failed stage.
- Do not substitute a different AMD installer or graphics release.
- Preserve BitLocker / Device Encryption recovery information before changing Secure Boot settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, ASUS, GitHub, or game/anti-cheat vendors.

Original project code and documentation are released under the [MIT License](LICENSE). Third-party software and trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
