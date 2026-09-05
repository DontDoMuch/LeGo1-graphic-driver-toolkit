# Compatibility

## Public Beta v4.5 hardware scope

Public Beta v4.5 supports exactly three Lenovo Legion Go hardware profiles:

| Profile | Exact HWID | Family | Active DDInstall |
|---|---|---|---|
| Legion Go 1 Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGo` |
| Legion Go S Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | Phoenix | `ati2mtag_Phoenix_LegionGoS` |
| Legion Go 2 Z2 Extreme | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | Strix | `ati2mtag_Strix_LegionGo2` |

Windows 11 x64 is the officially supported and validated platform. Windows 10 is intentionally not hard-blocked but remains unvalidated/unsupported.

The resolver has no manual profile override. A device must match one exact supported hardware ID. Go 2 `REV_C4` is a tested negative fixture and is rejected.

Unsupported by v4.5 include non-Extreme Go 1 variants, non-Z1-Extreme Go S variants, Go 2 AI Extreme, other Go 2 revisions/variants, eGPU configurations, and unrelated AMD systems.

## Starting-origin model

v4.5 classifies the live physical target GPU and its Driver Store architecture before destructive work. PnP health and actual selected-profile hardware applicability are authoritative; filenames alone are not.

### Microsoft Basic Display Adapter

A supported physical target may be bound to Microsoft's in-box Basic Display driver. The classifier never attempts to delete the in-box `display.inf` package.

### Lenovo OEM graphics

Healthy Lenovo OEM Display stacks are supported. Applicable standalone Lenovo extension material is identified by readable model directives that target the **selected exact profile**, exported for rollback, and then handled according to the selected profile's frozen architecture.

Multiple historical same-lineage generations may coexist. Conflicting selected-profile-applicable ExtensionIds remain ambiguous and fail closed.

### Prior public toolkit releases

Known prior toolkit architectures remain classifiable where the field-proven v4 origin model supports them. Protected internal v4.0 state/schema identifiers may persist in the v4.5 engine and are not evidence that the wrong public package is running.

### Healthy third-party AMD Display origins

A healthy structurally classifiable third-party AMD Display package can be an accepted starting origin. The current active Display INF is preserved as verified rollback material before the destructive transition.

All staged `amduw23e` packages are inventoried. Only a readable INF whose actual model directive targets the selected exact v4.5 profile enters that profile's extension ownership/export/removal path.

Therefore:

- proven foreign/non-applicable packages are preserved;
- foreign packages may share a familiar filename/class/ExtensionId without becoming selected-profile-owned;
- unreadable hardware scope fails closed;
- an unexpected lineage that actually targets the selected profile remains fail-closed rather than being ignored.

The original v4 architecture was physically field-validated from a real ASUS ROG Ally Z1 Extreme graphics origin on Go 1. Its extension targeted ASUS subsystem IDs and was preserved while the Go 1 transition completed. v4.5 keeps that field-proven behavior and generalizes applicability to the selected profile.

ROG Ally-origin migration is field-proven on Go 1. The same generalized third-party-origin contract is present for Go S and Go 2, but an Ally-origin transition has not been separately field-run on those devices.

## Go S profile specifics

Go S Z1 Extreme uses Phoenix and the dedicated `ati2mtag_Phoenix_LegionGoS` section. Its 30 exact ordered Lenovo OEM directives are frozen. Lenovo OEM AddReg must remain after AMD DelReg or required Lenovo values can be deleted.

## Go 2 profile specifics

Go 2 Z2 Extreme uses Strix and the dedicated `ati2mtag_Strix_LegionGo2` section with `%AMD150E.517%`.

Official AMD 26.8.1 contains DEV_150E Strix coverage but does **not** natively enumerate the exact Lenovo `381C17AA / REV_C5` target. Lenovo OEM material proves exact C5 -> Strix, and v4.5 performs a controlled profile-specific adaptation. Do not describe exact C5 support as native AMD enumeration.

## Scope limits

A different AMD release cannot be substituted merely because it can bind to a supported GPU. New AMD releases require separate source inspection, exact payload identities, OEM semantic delta work, catalog validation, and regression testing.
