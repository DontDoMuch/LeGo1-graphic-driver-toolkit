# Compatibility

## Hardware scope

Public Beta v3.1 is designed only for the original Lenovo Legion Go:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Legion Go S, eGPU configurations, and unrelated AMD systems are outside this release's validated scope.

## Supported starting architectures

The v3.1 origin classifier explicitly recognizes:

### Microsoft Basic Display Adapter

The physical target GPU may be bound to Microsoft's in-box Basic Display driver. The classifier requires Microsoft provider/service identity and does not attempt to delete the in-box package.

### Lenovo OEM graphics

A healthy Lenovo OEM display stack with applicable standalone Lenovo `amduw23e` lineage material is supported.

Windows may retain multiple generations of `amduw23e` after Lenovo OEM installation. v3.1 accepts them as one versioned lineage only when every applicable member:

- is an Extension-class package;
- targets the original Legion Go hardware;
- has a parseable ExtensionId;
- shares the validated Lenovo-derived ExtensionId `{07A2A561-D001-4503-B239-EF2FE0379EFB}`.

The authoritative member is selected by version/date ordering. Historical `DriverVer` differences and semantic-marker differences are retained as provenance evidence rather than treated alone as proof of an invalid origin.

Every recognized lineage member is individually exported for rollback before removal. Multiple distinct applicable ExtensionIds remain genuinely ambiguous and fail closed.

### Public Beta v1.1 / AMD 26.6.2

Exact display identity:

```text
DriverVersion: 32.0.31021.1015
INF SHA-256:   39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E
```

This architecture intentionally uses Lenovo standalone extension lineage material. v3.1 requires the applicable packages to be structurally scoped to the original Go and validated lineage before accepting the origin.

### Public Beta v2.1 / AMD 26.6.4

Exact display identity:

```text
DriverVersion: 32.0.31021.5001
INF SHA-256:   73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034
```

This architecture also intentionally uses Lenovo standalone extension lineage material.

### Exact merged AMD 26.7.1 target

The exact final Public Beta v3.0/v3.1 merged target is supported for repair or idempotent reruns when its package identity, embedded Lenovo semantics, and GPU health are consistent:

```text
DriverVersion: 32.0.31035.1003
INF SHA-256:   9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409
```

## 26.7.1 merged transition

v3.1 exports the prior display and every applicable validated Lenovo extension member as rollback material first. The standalone extension lineage is then removed because its required semantics are incorporated into the verified 26.7.1 merged target.

## Unsupported origins

An arbitrary side-loaded AMD display package is not considered compatible merely because it can bind to the GPU. Unknown, unhealthy, structurally inconsistent, or multi-lineage origins fail closed.

No compatibility or support claim is made for unvalidated external driver projects.

New AMD releases require separate source inspection, semantic delta work, exact identity definitions, and regression validation.
