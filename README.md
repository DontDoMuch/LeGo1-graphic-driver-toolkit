<div align="center">

# Legion Go 1 Graphics Driver Toolkit

### A compatibility-focused AMD graphics-driver workflow for the original Lenovo Legion Go

![Release](https://img.shields.io/badge/release-Public%20Beta%20v4.0-2EA44F?style=for-the-badge)
![Target](https://img.shields.io/badge/current%20target-AMD%2026.8.1-ED1C24?style=for-the-badge)
![Device](https://img.shields.io/badge/device-Legion%20Go%201-111111?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Build, install, and verify AMD 26.8.1 while preserving the Lenovo-specific integration required by the original Legion Go.**

[Latest release](../../releases/tag/public-beta-v4.0) · [Installation](docs/INSTALLATION.md) · [Compatibility](docs/COMPATIBILITY.md) · [Verification](docs/VERIFICATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

> [!IMPORTANT]
> **Current release: Public Beta v4.0.** It targets AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004` and supersedes Public Beta v3.1.
>
> v4.0 adds hardware-scoped handling of standalone `amduw23e` packages, dual-catalog trust for the original Microsoft WHCP catalog, and final recovery/concurrency hardening. The finalized package passed its Windows PowerShell 5.1 preflight with **zero failed checks**, physically passed the machine-wide single-instance test, and physically revalidated a saved `Complete` installation through the full **72/72 read-only final audit**.

> [!WARNING]
> This toolkit changes the display-driver package, Driver Store, certificate trust, AMD Software, scheduled tasks, and temporary Windows Test Signing configuration. Back up important data and **preserve your BitLocker or Device Encryption recovery key before disabling Secure Boot or starting the workflow**.

## Project identity

This repository is built for the **original Lenovo Legion Go**, referred to here as **Legion Go 1**:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

It is not a generic AMD installer. Legion Go S, Legion Go 2 / other future variants, unrelated AMD systems, and eGPU configurations are not validated by this release.

## What Public Beta v4.0 includes

| Area | Public Beta v4.0 behavior |
|---|---|
| AMD target | Adrenalin 26.8.1 / display `32.0.31041.1004` |
| Public workflow | One command, exactly two initial Y/N confirmations, automatic required reboot/resume boundaries |
| Starting stacks | Microsoft Basic, Lenovo OEM, exact prior public toolkit architectures, healthy merged 26.7.1, exact installed 26.8.1, and healthy structurally compatible third-party AMD Display origins |
| `amduw23e` scope | All packages are inventoried; only readable model directives that actually target `SUBSYS_381217AA` enter the Go 1 lineage/export/removal path |
| Foreign extensions | Proven non-Go packages are preserved even when filename, class, or ExtensionId overlap the historical Go lineage |
| Catalog trust | Active locally signed merged catalog **plus** exact original Microsoft WHCP `u0203304.cat`, with 14/14 frozen target coverage required from each |
| Rollback | Starting Display material and every applicable recognized Go extension member are exported before destructive transition |
| Recovery | Failed checkpoints are transaction-aware; unproven rollback stays recovery-only; no failed destructive stage automatically retries |
| Concurrency | Machine-wide installer mutex plus fail-closed detection of other registered Legion Go AMD resume workflows |
| AMD Software | Exact matching AMD Settings/DVR runtime is installed and validated; RSXCM is audited as ancillary |
| Boot policy | Secure Boot front-gated; temporary Test Signing must finish OFF; `nointegritychecks` must finish OFF |
| Final audit | 72 hard checks; rerunning a saved `Complete` workflow performs read-only drift revalidation rather than reinstalling |

Compatibility does not mean an arbitrary AMD release can be substituted. Each new AMD release needs separate payload inspection, semantic delta work, exact identities, and regression validation.

## Validated final state

| Component | Public Beta v4.0 result |
|---|---|
| Display driver | `32.0.31041.1004` |
| GPU health | `OK`, problem code `0`, `HasProblem=False` |
| Final INF SHA-256 | `F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42` |
| `amdgcf.dat` SHA-256 | `83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953` |
| Loaded `amdkmdag.sys` SHA-256 | `92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF` |
| Official WHCP catalog SHA-256 | `23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48` |
| Local catalog coverage | `14/14` frozen targets |
| Official catalog coverage | `14/14` frozen targets |
| AMD Settings | `2026.0811.2128.2099` |
| AMD DVR | `26.10.26223.2125` |
| RSXCM | `22.10.0.0` expected; ancillary/warning-only |
| `ColorVibrance_ENABLE_DEF` | `1` |
| `ShowRSOverlay` | `true` |
| Test Signing after completion | Off |
| `nointegritychecks` after completion | Off |
| Final persistence audit | `72/72 PASS`, zero warnings on the finalized field state |

## Download and verify

Release asset:

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip
```

SHA-256:

```text
8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
```

The AMD installer is **not** included. Download AMD's official 26.8.1 package and keep it somewhere under your Downloads folder:

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

Use the fail-closed verify/unblock/extract/run block in [Installation](docs/INSTALLATION.md) rather than relying on visual hash comparison alone.

## Completion condition

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow Stage: Complete
Test Signing: OFF
nointegritychecks: OFF
```

A later rerun from saved `Complete` state performs the full Stage 4 audit read-only and reports drift without automatically repairing or reinstalling anything.

## Field evidence highlights

- Original Legion Go → AMD 26.8.1 complete workflow: PASS.
- Dual-catalog correction physically restored Gears 5 Direct3D operation and removed the observed BattlEye UMD block in Destiny 2.
- Real ASUS/ROG Ally graphics origin → v4.0: Stage 2/3/4 PASS while the foreign ASUS-only `amduw23e` remained staged and untouched.
- Dirty ASUS install → Lenovo install **without an intervening reboot** → v4.0 / 26.8.1: successful transition.
- Machine-wide second-launch rejection: physical PASS with no workflow/log/task mutation.
- Saved `Complete` → full 72-check Stage 4 revalidation: physical PASS with workflow state, GPU identity, BCD policy, and resume-task inventory unchanged.

See [Validation](docs/VALIDATION.md) for scope and evidence details.

## Release history

- [Public Beta v4.0](releases/public-beta-v4.0/) — current release, AMD 26.8.1
- [Public Beta v3.1](releases/public-beta-v3.1/) — AMD 26.7.1 bugfix
- [Public Beta v3.0](releases/public-beta-v3.0/) — AMD 26.7.1
- [Public Beta v2.1](releases/public-beta-v2.1/) — AMD 26.6.4
- Public Beta v2.0 — superseded AMD 26.6.4 release
- [Public Beta v1.1](releases/public-beta-v1.1/) — AMD 26.6.2
- [Public Beta v1.0](releases/public-beta-v1.0/) — AMD 26.6.2

Published release assets are immutable. Corrections to executable behavior require a new public version and new hashes.

## Important rules

- Do not manually run numbered stages during the normal managed workflow.
- Do not manually delete staged `amduw23e` packages to bypass origin classification.
- Do not manually edit workflow state or toggle Test Signing while a managed run is active.
- Stop at a hard failure and preserve the generated evidence instead of repeatedly forcing the failed stage.
- Do not substitute a different AMD installer or graphics release.
- Preserve BitLocker / Device Encryption recovery information before changing Secure Boot settings.

## Independence and license

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, ASUS, GitHub, or game/anti-cheat vendors.

Original project code and documentation are released under the [MIT License](LICENSE). Third-party software and trademarks remain subject to their own terms. See [Third-party notices](THIRD-PARTY-NOTICES.md).
