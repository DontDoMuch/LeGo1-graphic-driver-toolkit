# Technical notes

## Hardware-first design

The workflow is gated to the original Legion Go GPU identity. Repository branding is version-neutral, while each public release defines its own validated AMD target and installed-state contract.

## Compatibility validation

Public Beta v2.0 records the live starting display stack and validates required properties instead of comparing every host component to one frozen package identity. This applies to the starting display driver, Lenovo extension, AMDUWP component, AMD installer container, and Windows Kit discovery.

## Exact target construction

Flexible input validation does not weaken the output contract. The canonical dependency manifest, rebuilt INF, generated `amdgcf.dat`, expected kernel, package structure, official AMD catalog, and final installed identities remain exact for the release target.

## Catalog model

The corrected local catalog is generated and signed with a unique per-installation certificate. Its hash therefore differs between installations. AMD's official Microsoft-signed catalog is separately registered and verified for kernel-policy continuity.

## Reboot boundaries

Scripts 1, 2, and 3 each write state before a restart and then compare it with the next live boot. Saved state alone is never accepted as proof that the operation persisted.

## Release-specific state roots

Public Beta v2.0 uses:

```text
C:\AMD\LegionGo-26.6.4
C:\ProgramData\LegionGo-AMD-26.6.4
```

Those are implementation paths for this release, not the permanent name of the project.
