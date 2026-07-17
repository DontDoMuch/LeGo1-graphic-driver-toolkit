<div align="center">

# Legion Go 1 Graphics Driver Toolkit

### A compatibility-focused AMD graphics-driver workflow for the original Lenovo Legion Go

![Release](https://img.shields.io/badge/release-Public%20Beta%20v2.1-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.6.4-ED1C24?style=for-the-badge)
![Device](https://img.shields.io/badge/device-Legion%20Go%201-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify newer AMD graphics packages while preserving the Lenovo-specific integration required by the Legion Go 1.**

[Latest release](../../releases/latest) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v2.1.** It targets AMD 26.6.4 and supersedes Public Beta v2.0. Use v2.1 for all new installations and repair runs.
>
> The final v2.1 artifact passed the complete workflow and final persistence audit through both validated regression paths on July 17, 2026:
> - Fresh Lenovo OEM graphics installation → AMD 26.6.4
> - Fresh Lenovo OEM → Public Beta v1.1 / AMD 26.6.2 → Public Beta v2.1 / AMD 26.6.4

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, catalog registration, AMD Software, AppX state, Lenovo compatibility metadata, and temporary Windows Test Signing configuration. Back up important data, preserve the BitLocker or Device Encryption recovery key, and read the included instructions before starting.

## Project identity

This repository is built for the **original Lenovo Legion Go**, referred to here as **Legion Go 1**:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

The project is intentionally identified by the hardware and workflow rather than one AMD version. Each public release documents the AMD target it has actually validated.

## What Public Beta v2.1 includes

Public Beta v2.1 is the corrected and revalidated successor to v2.0.

| Area | Public Beta v2.1 behavior |
|---|---|
| Starting display stack | Supports a fresh Lenovo OEM state, a validated Public Beta v1.1 / AMD 26.6.2 state, or an existing validated AMD 26.6.4 state for repair and idempotent reruns |
| Lenovo extension | Validates required semantics, signature state, target identity, and active attachment instead of relying on one fixed published INF name |
| AMDUWP | Accepts a healthy, structurally compatible Microsoft-signed component |
| AMD source | Uses the validated AMD 26.6.4 Windows 11 installer and proves the exact extracted target payload before continuing |
| Windows Kit | Finds a functional Inf2Cat and SignTool pair by capability instead of requiring one installed kit version |
| Safety boundaries | Retains exact hardware gating, signature checks, payload verification, reboot boundaries, and final auditing |

Compatibility does not mean an arbitrary AMD version can be substituted. A different AMD release requires separate inspection, adaptation, and end-to-end validation.

## Validated final state

| Component | Result |
|---|---|
| Display driver | `32.0.31021.5001` |
| GPU health | `OK`, problem code `0` |
| Corrected INF SHA-256 | `73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034` |
| Loaded `amdkmdag.sys` SHA-256 | `3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F` |
| Lenovo display extension | Compatible and preserved |
| AMD Software | Native `.2099` |
| RSXCM | Native `22.10.0.0` |
| Legacy `.2089` state | Removed system-wide |
| Microsoft Store dependency | None |
| Test Signing after completion | Off |
| Final audit | Passed with zero failed checks |

## Download and verify

Download the latest release asset:

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
```

SHA-256:

```text
DE3A7FD534BB136881D8685F17AD5F7FD3CCDC46597487465D0966C2A365038C
```

Verify it in PowerShell:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip" -Algorithm SHA256
```

The AMD installer is not included. The supported reference installer is:

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
SHA-256: E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
```

Obtain it from AMD's official support site and place it beside the toolkit scripts. 

https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-7000-series/amd-ryzen-7-7840u.html

## Four-stage workflow

| Stage | Script | Purpose |
|:--:|---|---|
| **1** | `01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1` | Validate hardware, source, tools, and the starting stack; build and sign the corrected package; prepare temporary Test Signing |
| **2** | `02-Install-Driver-And-Verify-Normal-Signing.ps1` | Install and bind the corrected driver, register the official AMD catalog, turn Test Signing off, and verify the next boot |
| **3** | `03-Install-AMD-Software-And-Reboot.ps1` | Install native AMD Software, preserve compatible components, retire conflicting legacy state, and verify the next boot |
| **4** | `04-Final-Persistence-Audit.ps1` | Perform the final read-only driver, software, catalog, metadata, event-log, and visual audit |

Follow the restart and rerun instructions printed by each script. Do not advance until the current script reports that the next stage is ready.

## Completion condition

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## Release history

- [Public Beta v2.1](releases/public-beta-v2.1/) — current corrected release, AMD 26.6.4
- [Public Beta v2.0](../../releases/tag/public-beta-v2.0) — superseded AMD 26.6.4 release
- [Public Beta v1.1](releases/public-beta-v1.1/) — AMD 26.6.2
- [Public Beta v1.0](releases/public-beta-v1.0/) — AMD 26.6.2

Published release assets are immutable. Corrections to executable files require a new public version and new hashes.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Required files, commands, run order, and restart boundaries |
| [Compatibility](docs/COMPATIBILITY.md) | Supported starting states, exact safety gates, and hardware scope |
| [Verification](docs/VERIFICATION.md) | Release, script, installer, and installed-state hashes |
| [Validation](docs/VALIDATION.md) | Public Beta v2.1 regression results |
| [Technical notes](docs/TECHNICAL-NOTES.md) | Package architecture and implementation details |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Safe recovery guidance |
| [FAQ](docs/FAQ.md) | Common project and compatibility questions |
| [Releases](docs/RELEASES.md) | Public versioning and release rules |

## Important rules

- Do not use DDU as part of the documented workflow.
- Do not skip stages or advance before the current script reports readiness.
- Do not manually replace the INF, MSI, AppX, catalog, or certificate.
- Do not delete workflow state merely to force a rerun.
- Keep the Legion Go connected to AC power.
- Preserve BitLocker or Device Encryption recovery information before changing boot-security settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, or GitHub.

Original project code and documentation are released under the [MIT License](LICENSE). AMD, Lenovo, Microsoft, and other third-party software or trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
