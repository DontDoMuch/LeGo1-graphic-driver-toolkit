# FAQ

## Is this for Legion Go S, Legion Go 2, or other models?

No. Public Beta v4.0 is validated only for the original Legion Go / Legion Go 1 hardware identity:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Changing a device ID is not considered a validated port. Other variants need their own OEM/extension/INF/catalog and hardware-scope analysis.

## Why can foreign `amduw23e` packages remain after a successful install?

Because filename, class, and ExtensionId are not sufficient proof that a package belongs to the Legion Go.

v4.0 inventories all staged `amduw23e` packages. Only packages whose readable INF model directives actually target the original Go enter the Go extension lineage. Proven foreign packages are preserved.

This was field-proven with an ASUS ROG Ally extension sharing the historical ExtensionId while targeting ASUS subsystem IDs rather than `381217AA`.

## Can multiple Go-applicable `amduw23e` generations be present before installation?

Yes. Windows can retain multiple versions from one Lenovo-derived lineage. v4.0 retains the v3.1 logic that treats same-lineage, Go-applicable generations as version history and exports each recognized member before removal.

Multiple distinct **Go-applicable** ExtensionIds remain fail-closed.

## Why are there two catalogs in v4.0?

The merged Display package requires the locally generated/signed catalog for the adapted INF. During 26.8.1 testing, the exact original Microsoft WHCP catalog was also found necessary to preserve the expected user-mode trust path for the unchanged AMD kernel/UMD payload.

v4.0 therefore requires both catalogs to cover all 14 frozen targets. The official Microsoft catalog is registered under the managed name `LegionGo-AMD-26.8.1-Official-WHCP.cat`.

## Does this fix the Gears 5 / BattlEye problem seen in early 26.8.1 testing?

The dual-catalog correction was physically tested: Gears 5 resumed normal AMD Direct3D operation and the observed Destiny 2 BattlEye block of `amdxx64.dll` was removed. This is evidence for the specific trust regression encountered during development, not a guarantee about every game's future anti-cheat policy.

## Can I start from a third-party AMD driver?

Healthy third-party AMD Display origins can be accepted when they satisfy the structural safety contract and the original Legion Go can be identified unambiguously. A real ASUS origin was field-validated end to end.

This is not a blanket whitelist for arbitrary modified packages. Unhealthy, unreadable, or genuinely ambiguous Go-applicable states still fail closed.

## What happens if the installer fails after Test Signing was enabled?

The managed launcher normalizes boot-integrity settings, removes automatic resume authorization, and uses transaction-aware checkpoints. Safe pre-destructive failures re-enter through managed Test Signing preparation on the next main-launcher run. Unproven destructive rollback remains recovery-only.

Do not directly invoke Stage 2 to bypass that logic.

## What if I double-click the installer twice?

v4.0 uses a machine-wide single-instance guard. The second v4.0 launcher is rejected before persistent workflow mutation.

## What if the workflow already says Complete?

The launcher performs the full Stage 4 final audit read-only. It does not reinstall or automatically repair drift.

## Why may the frozen ZIP still contain internal engineering identifiers?

Some internal class/type names and regression identifiers are part of the exact field-tested package. Broad renaming previously demonstrated that it can break parser/type contracts. Public filenames, release metadata, documentation, and user-facing release identity use **Public Beta v4.0**; protected internal identifiers are retained where byte identity or tested implementation contracts require it.

## Can I use a different AMD release?

No. Each AMD release requires separate adaptation and validation. Do not substitute a different installer.

## Does v4.0 spoof Radeon Software `ReleaseVersion`?

No.

## How many prompts are there?

The normal public launcher asks exactly two Y/N questions at the beginning. Required managed reboots afterward are automatic.
