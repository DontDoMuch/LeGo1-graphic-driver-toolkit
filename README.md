<div align="center">

# Legion Go 1 Graphics Driver Toolkit

### A compatibility-focused AMD graphics-driver workflow for the original Lenovo Legion Go

![Release](https://img.shields.io/badge/release-Public%20Beta%20v3.1-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.7.1-ED1C24?style=for-the-badge)
![Device](https://img.shields.io/badge/device-Legion%20Go%201-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify newer AMD graphics packages while preserving the Lenovo-specific integration required by the Legion Go 1.**

[Latest release](../../releases/tag/public-beta-v3.1) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v3.1.** It targets AMD 26.7.1 and supersedes Public Beta v3.0.
>
> v3.1 corrects valid Lenovo OEM histories containing multiple generations of the same original-Legion-Go `amduw23e` ExtensionId lineage. The dirty Lenovo OEM multi-generation path and the final Public Beta v3.1 merged-to-merged regression both completed Stages 2, 3, and 4 with **zero failed final checks**. The corrected public package also passed its independent **16/16 static audit**.

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, AMD Software, scheduled tasks, and temporary Windows Test Signing configuration. Back up important data, preserve the BitLocker or Device Encryption recovery key, and read the included instructions before starting.

## Project identity

This repository is built for the **original Lenovo Legion Go**, referred to here as **Legion Go 1**:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

It is not a generic AMD installer and is not intended for Legion Go S.

## What Public Beta v3.1 includes

| Area | Public Beta v3.1 behavior |
|---|---|
| AMD target | Adrenalin 26.7.1 / display `32.0.31035.1003` |
| Public workflow | One command, exactly two initial Y/N confirmations, automatic required reboot/resume boundaries |
| Starting stacks | Microsoft Basic, Lenovo OEM, exact Public Beta v1.1 / 26.6.2, exact Public Beta v2.1 / 26.6.4, and exact merged 26.7.1 states |
| Lenovo extension lineage | One or more structurally valid original-Go `amduw23e` generations sharing ExtensionId `{07A2A561-D001-4503-B239-EF2FE0379EFB}` are treated as one versioned lineage |
| Standalone `amduw23e` | Every recognized lineage member is exported as rollback material before removal when the merged 26.7.1 target supersedes it; distinct applicable ExtensionIds remain fatal |
| Catalog handling | Resolves the catalog declared by the active Driver Store INF; fails closed on missing/ambiguous/invalid declarations |
| Rollback | Preserves the starting display package and every applicable validated Lenovo extension member before destructive transition |
| AMD Software | Installs and validates the matching AMD Settings/DVR runtime |
| Boot policy | Secure Boot front-gated; temporary Test Signing must finish OFF; `nointegritychecks` must finish OFF |
| Final audit | Stage 2/3/4 result contracts must pass and `FailedChecks` must equal `0` |

Compatibility does not mean an arbitrary AMD release can be substituted. New AMD releases require their own payload inspection, semantic delta, exact identities, and regression validation.

## Validated final state

| Component | Result |
|---|---|
| Display driver | `32.0.31035.1003` |
| GPU health | `OK`, problem code `0`, `HasProblem=False` |
| Final INF SHA-256 | `9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409` |
| `amdgcf.dat` SHA-256 | `DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766` |
| Loaded `amdkmdag.sys` SHA-256 | `D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5` |
| Standalone Lenovo extension | Absent in final merged architecture |
| AMD Settings | `2026.0716.2129.2099` |
| AMD DVR | `26.10.26197.2124` |
| RSXCM | `22.10.0.0` |
| `ColorVibrance_ENABLE_DEF` | `1` |
| `ShowRSOverlay` | `true` |
| Test Signing after completion | Off |
| `nointegritychecks` after completion | Off |
| Final Public Beta v3.1 run | Stages 2/3/4 PASS; `FailedChecks=0` |
| Corrected package audit | `16/16 PASS` |

## Download and verify

Release asset:

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip
```

SHA-256:

```text
ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
```

Verify in PowerShell:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip" -Algorithm SHA256
```

The AMD installer is not included. Download AMD's official package:

https://www.amd.com/en/support/downloads/previous-drivers.html/processors/ryzen/ryzen-7000-series/amd-ryzen-7-7840u.html - locate 26.7.1 and download

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

## Run

Download ZIP

Right-click ZIP → Properties → Unblock

Extract ZIP

Run `Start-LegionGo-AMD-26.7.1.cmd`

The launcher asks exactly two initial Y/N questions. Once accepted, the managed workflow handles preparation, temporary signing configuration, driver changes, matching AMD Software, required reboots, resume, and final audit.

## Completion condition

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow Stage: Complete
```

## Release history

- [Public Beta v3.1](releases/public-beta-v3.1/) — current release, AMD 26.7.1 bugfix
- [Public Beta v3.0](releases/public-beta-v3.0/) — AMD 26.7.1
- [Public Beta v2.1](releases/public-beta-v2.1/) — AMD 26.6.4
- [Public Beta v2.0](../../releases/tag/public-beta-v2.0) — superseded AMD 26.6.4 release
- [Public Beta v1.1](releases/public-beta-v1.1/) — AMD 26.6.2
- [Public Beta v1.0](releases/public-beta-v1.0/) — AMD 26.6.2

Published release assets are immutable. Corrections to executable behavior require a new public version and new hashes.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Required files, one-command workflow, and reboot behavior |
| [Compatibility](docs/COMPATIBILITY.md) | Supported origins, hardware scope, and fail-closed rules |
| [Verification](docs/VERIFICATION.md) | Release, source-installer, and installed-state hashes |
| [Validation](docs/VALIDATION.md) | Public Beta v3.1 field, package, and regression evidence |
| [Technical notes](docs/TECHNICAL-NOTES.md) | Driver architecture, rollback, signing, and origin classifier |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Safe recovery guidance |
| [FAQ](docs/FAQ.md) | Common questions |
| [Releases](docs/RELEASES.md) | Public versioning and release rules |

## Important rules

- Do not use DDU as part of the documented workflow unless a future release explicitly requires it.
- Do not manually run numbered stages during the normal managed workflow.
- Do not manually replace the INF, MSI, catalog, certificate, or workflow state.
- Do not manually delete staged `amduw23e` generations to bypass origin classification.
- Do not manually toggle Test Signing while a managed run is active.
- Keep the Legion Go connected to AC power.
- Preserve BitLocker or Device Encryption recovery information before changing boot-security settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, or GitHub.

Original project code and documentation are released under the [MIT License](LICENSE). AMD, Lenovo, Microsoft, and other third-party software or trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
