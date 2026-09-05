# FAQ

## Which devices does Public Beta v4.5.1 support?

Exactly these three:

```text
Legion Go 1 Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04

Legion Go S Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04

Legion Go 2 Z2 Extreme
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
```

Other revisions and variants are not supported by inference. The public resolver chooses the profile automatically and has no manual override.

## Can I start from an ROG Ally or another third-party AMD driver?

A healthy structurally classifiable third-party AMD Display origin can be accepted. You do not need to restore Lenovo OEM first merely because the current active Display package came from another AMD handheld package.

The active starting Display package is preserved as verified rollback material. ROG Ally-origin migration is physically field-proven on Go 1 through the inherited v4 origin/rollback architecture. The same selected-profile-aware contract is present for Go S and Go 2, but Ally-origin migration has not been separately field-run on those two devices.

## Why can foreign `amduw23e` packages remain after a successful install?

Because filename, class, and ExtensionId are not sufficient proof that a package belongs to the selected Legion Go profile.

v4.5.1 inventories all staged `amduw23e` packages. Only packages whose readable INF model directives actually target the selected exact hardware profile enter that profile's extension handling. Proven foreign/non-applicable packages are preserved.

## Can multiple applicable Lenovo extension generations be present before installation?

Yes, when they are recognized members of one supported lineage. Each applicable recognized member is exported before removal. Multiple distinct selected-profile-applicable ExtensionIds remain fail-closed.

## Why are there two catalogs?

The adapted Display package requires the locally generated/signed catalog. The unchanged AMD 26.8.1 kernel/UMD payload is additionally covered by the exact original Microsoft WHCP `u0203304.cat`. Both catalog paths are independently audited.

## Why does Go 2 use Strix if AMD does not list the exact Lenovo C5 ID?

AMD 26.8.1 contains DEV_150E Strix coverage. Lenovo's OEM package proves the exact `DEV_150E / SUBSYS_381C17AA / REV_C5` mapping to Strix. v4.5.1 inserts that exact target through a controlled profile-specific adaptation using `%AMD150E.517%`.

That is not the same as claiming AMD natively enumerates the exact Lenovo C5 hardware ID.

## Why do some internal paths or schema names still say v4.0?

The multi-device v4.5.1 package intentionally preserves some field-proven v4.0 engine contracts and identifiers. Broad cosmetic renaming previously created parser/type risk. Public filenames, public release metadata, exact profile selection, and package identity are v4.5.1; protected internal lineage identifiers may remain v4.0.

## What if the installer fails after Test Signing was enabled?

The managed launcher uses transaction-aware checkpoints and rollback/recovery logic. Do not directly invoke a later numbered stage to bypass it. Stop at the failure, preserve evidence, and rerun only through the documented main launcher or a maintainer-directed recovery path.

## What if I double-click the installer twice?

The v4 engine uses a machine-wide single-instance guard. A second launcher is rejected before persistent workflow mutation.

## What if the workflow already says Complete?

The launcher reruns the full selected-profile Stage 4 audit read-only. It does not reinstall or automatically repair drift.

## Can I use a different AMD release?

No. v4.5.1 is frozen to AMD 26.8.1. Each AMD release requires separate adaptation and validation.

## How many prompts are there?

The normal public launcher asks exactly two Y/N questions at the beginning. Required managed reboots afterward are automatic.

## Inside of AMD Adrenalin software there is the "manage updates" button and some updates show, can I install them?

These should be considered if your device has performance issues. If installing them causes issues, uninstall the update and install the one provided on the website to revert changes.
