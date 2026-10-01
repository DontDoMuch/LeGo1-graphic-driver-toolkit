# FAQ

## Which devices does Public Beta v5.0 support?

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

## What changed in v5.0?

Only the public entry gate. A normal launch could forward empty `-OfficialInfPath` / `-OfficialDatPath` arguments to preflight. v5.0 adds those parameters only when non-empty. Stage 1-4 logic, deterministic builders, profile identities, signing/rollback behavior, and the internal `Public-Beta-v5.0` workflow namespace are unchanged.

## Can I start from an ROG Ally or another third-party AMD driver?

A healthy structurally classifiable third-party AMD Display origin can be accepted. You do not need to restore Lenovo OEM first merely because the current active Display package came from another AMD handheld package.

The active starting Display package is preserved as verified rollback material. ROG Ally-origin migration is physically field-proven on Go 1 through the inherited v4 origin/rollback architecture. The same selected-profile-aware contract is present for Go S and Go 2, but Ally-origin migration has not been separately field-run on those two devices.

## Why can foreign `amduw23e` packages remain after a successful install?

Because filename, class, and ExtensionId are not sufficient proof that a package belongs to the selected Legion Go profile.

v5.0 inventories all staged `amduw23e` packages. Only packages whose readable INF model directives actually target the selected exact hardware profile enter that profile's extension handling. Proven foreign/non-applicable packages are preserved.

## Can multiple applicable Lenovo extension generations be present before installation?

Yes, when they are recognized members of one supported lineage. Each applicable recognized member is exported before removal. Multiple distinct selected-profile-applicable ExtensionIds remain fail-closed.

## Why are there two catalogs?

The adapted Display package requires the locally generated/signed catalog. The unchanged AMD 26.9.2 kernel/UMD payload is additionally covered by the exact original Microsoft WHCP `u0204590.cat`. Both catalog paths are independently audited.

## Why does Go 2 use Strix?

Lenovo OEM material establishes the exact `DEV_150E / SUBSYS_381C17AA / REV_C5` mapping used by the profile-specific Strix adaptation. v5.0 builds the dedicated `ati2mtag_Strix_LegionGo2` section and freezes its deterministic output identity.

This is not the same as claiming the exact Lenovo C5 ID is natively enumerated by every AMD release.

## Why do some internal names still say v4.0 or v5.0?

Two separate compatibility choices exist:

- some protected engine contracts still retain v4.0 lineage names because broad cosmetic renaming previously created parser/type risk;
- v5.0 uses the internal `Public-Beta-v5.0` runner/workflow namespace, and optional entry-gate source paths are forwarded only when non-empty.

The outer public package, release metadata, and asset identity are v5.0.

## What if the installer fails after Test Signing was enabled?

The managed launcher uses transaction-aware checkpoints and rollback/recovery logic. Do not directly invoke a later numbered stage to bypass it. Stop at the failure, preserve evidence, and rerun only through the documented main launcher or a maintainer-directed recovery path.

## What if I double-click the installer twice?

The engine uses a machine-wide single-instance guard and also checks for other registered Legion Go AMD resume workflows. A second active workflow should fail closed rather than interleave destructive operations.

## Can I use a different AMD release?

No. v5.0 is frozen to AMD 26.9.2. Each AMD release requires separate adaptation and validation.

## Which devices have new physical 26.9.2 validation?

Go 1 has new physical AMD 26.9.2 end-to-end validation on the v5.0 line. Go S and Go 2 have deterministic AMD 26.9.2 source/build proof, while their device-profile physical evidence is inherited from the v4.5.1 lineage. The public release does not claim new Go S or Go 2 physical 26.9.2 runs.
