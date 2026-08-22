<div align="center">

# Legion Go 1 Graphics Driver Toolkit

### A compatibility-focused AMD graphics-driver workflow for the original Lenovo Legion Go

![Release](https://img.shields.io/badge/release-Public%20Beta%20v3.0-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.7.1-ED1C24?style=for-the-badge)
![Device](https://img.shields.io/badge/device-Legion%20Go%201-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify newer AMD graphics packages while preserving the Lenovo-specific integration required by the Legion Go 1.**

[Latest release](../../releases/latest) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v3.0.** It targets AMD 26.7.1 and supersedes Public Beta v2.1.
>
> The final 26.6.4 → 26.7.1 regression completed the full one-command workflow with **65/65 final-audit checks passing**. The clean Lenovo OEM → 26.7.1 path was also physically field-proven immediately before the final upgrade-path hardening.

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, AMD Software, scheduled tasks, and temporary Windows Test Signing configuration. Back up important data, preserve the BitLocker or Device Encryption recovery key, and read the included instructions before starting.

## Project identity

This repository is built for the **original Lenovo Legion Go**, referred to here as **Legion Go 1**:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

It is not a generic AMD installer and is not intended for Legion Go S.

## What Public Beta v3.0 includes

| Area | Public Beta v3.0 behavior |
|---|---|
| AMD target | Adrenalin 26.7.1 / display `32.0.31035.1003` |
| Public workflow | One command, exactly two initial Y/N confirmations, automatic required reboot/resume boundaries |
| Starting stacks | Microsoft Basic, Lenovo OEM, exact Public Beta v1.1 / 26.6.2, exact Public Beta v2.1 / 26.6.4, exact final 26.7.1 |
| Lenovo integration | Lenovo-required graphics semantics are merged into the final 26.7.1 display package |
| Standalone `amduw23e` | Preserved/exported as rollback material for older architectures, then removed when the merged 26.7.1 target supersedes it |
| Catalog handling | Resolves the catalog declared by the active Driver Store INF; fails closed on missing/ambiguous/invalid declarations |
| Rollback | Preserves the starting display package and applicable Lenovo extension before destructive transition |
| AMD Software | Installs and validates the matching AMD Settings/DVR runtime |
| Boot policy | Secure Boot front-gated; temporary Test Signing must finish OFF; `nointegritychecks` must finish OFF |
| Final audit | 65 persistent-state checks |

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
| Final field audit | `65/65 PASS` |

## Download and verify

Release asset:

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip
```

SHA-256:

```text
E946D1F981A435B9C8F8E94542649FA48970F7C56F85138E399411E5C2496DAF
```

Verify in PowerShell:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip" -Algorithm SHA256
```

The AMD installer is not included. Download AMD's official package:

https://www.amd.com/en/support/downloads/previous-drivers.html/processors/ryzen/ryzen-7000-series/amd-ryzen-7-7840u.html - locate the 26.7.1 and download

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

## Run

Download ZIP

Right-click ZIP → Properties → Unblock

Extract ZIP

Run Start-LegionGo-AMD-26.7.1.cmd

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

- [Public Beta v3.0](releases/public-beta-v3.0/) — current release, AMD 26.7.1
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
| [Validation](docs/VALIDATION.md) | Public Beta v3.0 field and regression evidence |
| [Technical notes](docs/TECHNICAL-NOTES.md) | Driver architecture, rollback, signing, and origin classifier |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Safe recovery guidance |
| [FAQ](docs/FAQ.md) | Common questions |
| [Releases](docs/RELEASES.md) | Public versioning and release rules |

## Important rules

- Do not use DDU as part of the documented workflow unless a future release explicitly requires it.
- Do not manually run numbered stages during the normal managed workflow.
- Do not manually replace the INF, MSI, catalog, certificate, or workflow state.
- Do not manually toggle Test Signing while a managed run is active.
- Keep the Legion Go connected to AC power.
- Preserve BitLocker or Device Encryption recovery information before changing boot-security settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, or GitHub.

Original project code and documentation are released under the [MIT License](LICENSE). AMD, Lenovo, Microsoft, and other third-party software or trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
