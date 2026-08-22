# Technical notes

## v3.0 architecture

Public Beta v3.0 separates three concepts that older iterations tended to
blur together:

1. the active AMD base display package;
2. Lenovo-specific integration semantics;
3. Radeon Software / CN metadata.

The active Driver Store package and physical target-device binding are the
primary authority. CN metadata is supplemental and is never used to spoof a
newer driver identity.

## Starting-origin classifier

The classifier is architecture-aware.

- Lenovo OEM expects the Lenovo standalone extension as part of the OEM pair.
- Public 26.6.2 and 26.6.4 are exact known toolkit architectures that also
  intentionally retain the OEM-generation Lenovo extension.
- Public 26.7.1 moves required Lenovo semantics into the merged display
  package and removes the standalone extension after rollback capture.
- Unknown AMD bases do not inherit the 26.6.x mismatch exception.

## Rollback

Before a destructive Stage 2 transition, the workflow records and exports
the starting display package. When the starting architecture includes the
Lenovo standalone extension, that extension is also exported.

The prior display package is retained rather than globally purged. This makes
rollback origin-aware and avoids assuming there should be only one AMD
Display-class package in the Driver Store.

## Catalog resolution

The active catalog is resolved from the active Driver Store INF rather than
by hardcoding the final target catalog filename while inspecting older
origins.

On x64 Windows, an applicable `CatalogFile.NTamd64` declaration takes
precedence. Missing, conflicting, path-traversing, non-CAT, or physically
absent catalog declarations fail closed.

## Signing

The final merged display catalog is locally signed. The workflow temporarily
enables Test Signing only after validating the exact built package and its
catalog/INF membership.

Final completion requires:
- Test Signing OFF;
- `nointegritychecks` OFF;
- active catalog/signature identity matching the Stage 2 checkpoint.

## Payload preservation

The build protects a frozen 190-file unchanged manifest, restores all nine
field-observed official AMD companion catalogs after Inf2Cat, and rehashes
protected content after build/signing operations.

## AMD defaults

v3.0 intentionally preserves:

```text
ColorVibrance_ENABLE_DEF = 1
ShowRSOverlay            = true
```

## No ReleaseVersion spoofing

Live registry `ReleaseVersion` spoofing is not part of v3.0. Earlier testing
demonstrated that making the live Radeon Software metadata claim an identity
that did not match the installed display package could lead to Code 43 after
reboot. v3.0 instead makes the driver package and software stack internally
consistent.
