# Troubleshooting

## First rule: stop at a hard failure

Do not repeatedly force a failed numbered stage, manually delete workflow state, or manually remove staged `amduw23e` packages to bypass classification.

Preserve the visible console error plus the generated parser transcript or failure-evidence folder/ZIP under Downloads.

## Test Signing after a failure

Managed hard-failure recovery inspects BCD and, when required, configures Test Signing and `nointegritychecks` OFF before recovery completes. It removes automatic resume authorization and never automatically retries a failed destructive stage.

Public Beta v4.0 also normalizes safe pre-destructive retry checkpoints back through the managed Test Signing preparation path. You should rerun the **main public launcher**, not Stage 2 directly.

If rollback after a destructive failure cannot be proven, the workflow remains on an explicit recovery-only path rather than silently treating the machine as ready for another install.

## Another installer session is already active

v4.0 uses a machine-wide named mutex. If another v4.0 manual/resume session is already active, the new launcher exits before persistent workflow mutation.

If a different registered `LegionGo-AMD-*-Resume` workflow is detected, v4.0 fails closed rather than racing another release. Resolve the older workflow instead of deleting tasks/state blindly.

## Starting GPU origin is not acceptable

Do not infer ownership from the filename `amduw23e.inf` alone.

v4.0 inventories all such packages and only enters Go 1 extension handling when the readable INF actually targets:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Proven foreign/non-applicable packages are intentionally preserved. Unreadable scope or conflicting Go-applicable lineages fail closed. Preserve evidence so the exact package can be classified safely.

## AMD installer not found or rejected

Required source:

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

Keep one exact copy somewhere under Downloads. A same-named file with different bytes is not accepted.

## Gears 5 reports Basic Display / Destiny 2 blocks an AMD DLL

Public Beta v4.0 includes the dual-catalog correction for the 26.8.1 user-mode trust failure discovered during development. A correct final install must show:

```text
Local frozen-target coverage    = 14/14
Official WHCP target coverage   = 14/14
```

Do not manually copy catalogs into CatRoot. Preserve Stage 4/failure evidence so the managed official-catalog state can be inspected.

## Secure Boot

Secure Boot must be disabled for this local-catalog signing architecture. Enabled or unknown Secure Boot state is a hard front gate.

**Preserve the BitLocker / Device Encryption recovery key before changing Secure Boot.**

## Rerunning after Complete

A saved `Complete` workflow no longer performs another installation. v4.0 reruns the full Stage 4 audit read-only to detect live-system drift. A drift failure reports evidence; it does not automatically repair the machine.

## Should I use DDU?

DDU is not part of the normal Public Beta v4.0 installation workflow. Do not insert it into a normal upgrade/repair run unless a documented recovery procedure specifically calls for it.

## Code 43

Do not attempt to repair Code 43 by spoofing Radeon Software `ReleaseVersion`. v4.0 keeps the driver package and software identities internally consistent and does not use that workaround.
