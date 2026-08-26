# Compatibility

## Hardware scope

Public Beta v4.0 is designed only for the original Lenovo Legion Go:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Windows 11 is the officially supported and validated platform. Windows 10 is intentionally not hard-blocked but is unvalidated/unsupported. Legion Go S, other Legion Go variants, eGPU configurations, and unrelated AMD systems are outside this release's validated scope.

## Starting-origin model

Public Beta v4.0 classifies the live physical Legion Go GPU and its Driver Store architecture before destructive work. PnP health and actual hardware applicability are authoritative; filenames alone are not.

### Microsoft Basic Display Adapter

The physical target may be bound to Microsoft's in-box Basic Display driver. The classifier requires Microsoft provider/service identity and never attempts to delete the in-box `display.inf` / Basic Display package.

### Lenovo OEM graphics

A healthy Lenovo OEM Display stack with applicable Lenovo `amduw23e` lineage material is supported. Multiple historical generations may coexist. Applicable members must be Extension-class packages that actually target the original Go and belong to the validated Lenovo-derived ExtensionId lineage:

```text
{07A2A561-D001-4503-B239-EF2FE0379EFB}
```

Recognized Go-applicable lineage members are individually exported for rollback before removal. Multiple distinct **applicable** ExtensionIds remain ambiguous and fail closed.

### Prior public toolkit releases

Exact known Public Beta 26.6.2 and 26.6.4 architectures retain standalone Lenovo extension lineage material and have explicit compatibility handling. Healthy merged 26.7.1 is recognized through its embedded Lenovo marker family. Exact installed 26.8.1 is also recognized for resume/idempotent verification paths.

### Healthy third-party AMD Display origins

v4.0 no longer assumes that every staged `amduw23e.inf` sharing a familiar filename/class/ExtensionId belongs to the Legion Go.

All staged `amduw23e` packages are inventoried. **Only a readable INF whose actual model directive targets `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA` enters the Go 1 lineage/export/removal path.**

Therefore:

- proven foreign/non-applicable packages are preserved;
- foreign packages may share the historical Lenovo-derived ExtensionId without becoming Go-owned;
- unreadable hardware scope fails closed;
- a foreign ExtensionId that actually targets the Go remains fail-closed rather than being ignored.

This behavior was field-validated with a real ASUS ROG Ally Z1 Extreme graphics stack. Its `amduw23e.inf` shared the historical ExtensionId but targeted ASUS `...1043` subsystem IDs, not `381217AA`; the extension was preserved while v4.0 successfully transitioned the active Display package to 26.8.1.

The ASUS version/hash is evidence, **not an acceptance whitelist**. Other third-party AMD origins are evaluated by the same structural health and hardware-applicability contract.

## Dirty mixed-origin field case

A further field test installed the ASUS graphics package and then Lenovo graphics **without rebooting between those two installs**, followed by Public Beta v4.0. The v4.0 / 26.8.1 transition completed successfully. This demonstrates tolerance of a realistic mixed Driver Store history, not permission to bypass fail-closed origin checks.

## Final merged 26.8.1 architecture

The final v4.0 Display package incorporates the required Lenovo semantics. Standalone **Go-applicable** Lenovo extension material is therefore absent after a clean final transition, while proven foreign/non-Go extension packages may remain staged by design.

## Scope limits

A different AMD release cannot be substituted merely because it can bind to the GPU. New AMD releases require separate source inspection, exact payload identities, Lenovo semantic delta work, catalog validation, and regression testing.

No support claim is made for unvalidated external driver projects or other handheld hardware IDs.
