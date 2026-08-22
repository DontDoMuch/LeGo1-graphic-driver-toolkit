# Compatibility

## Hardware scope

Public Beta v3.0 is designed only for the original Lenovo Legion Go:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Legion Go S and unrelated AMD systems are outside this release's scope.

## Supported starting architectures

The v3.0 origin classifier explicitly recognizes:

### Microsoft Basic Display Adapter
The physical target GPU may be bound to Microsoft's in-box Basic Display
driver. The classifier requires Microsoft provider/service identity and does
not attempt to delete the in-box package.

### Lenovo OEM graphics
A healthy Lenovo OEM display stack with the compatible standalone Lenovo
`amduw23e` extension is supported. The display/extension pair is validated
before transition.

### Public Beta v1.1 / AMD 26.6.2
Exact display identity:

```text
DriverVersion: 32.0.31021.1015
INF SHA-256:   39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E
```

This architecture intentionally uses the Lenovo standalone extension.
v3.0 requires that compatible extension to be present before accepting the
origin.

### Public Beta v2.1 / AMD 26.6.4
Exact display identity:

```text
DriverVersion: 32.0.31021.5001
INF SHA-256:   73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034
```

This architecture also intentionally uses the Lenovo standalone extension.

### Exact Public Beta v3.0 / AMD 26.7.1 target
The exact final target is supported for repair/idempotent reruns when its
package identity and health are consistent.

## Why the extension versions do not match 26.6.x

Public Beta v1.1 and v2.1 intentionally retain Lenovo's OEM-generation
standalone `amduw23e` while running a newer AMD base display driver. That is
a known toolkit architecture, not automatically "stale residue."

Public Beta v3.0 recognizes that cross-version pairing only for the exact
known 26.6.2/26.6.4 bases and a semantically compatible attached Lenovo
extension.

The same mismatch on an unknown AMD base remains fatal.

## 26.7.1 merged transition

v3.0 exports the prior display and applicable Lenovo extension as rollback
material first. The standalone extension is then removed because its required
semantics are incorporated into the verified 26.7.1 merged target.

## Unsupported origins

An arbitrary side-loaded AMD display package is not considered compatible
merely because it can bind to the GPU. Unknown, unhealthy, or inconsistent
origins fail closed.

New AMD releases require separate source inspection, semantic delta work,
exact identity definitions, and regression validation.
