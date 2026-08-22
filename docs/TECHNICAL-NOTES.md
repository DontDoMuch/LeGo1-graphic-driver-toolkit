# Technical notes

## v3.1 architecture

Public Beta v3.1 retains the v3.0 merged AMD 26.7.1 architecture and corrects starting-origin classification for valid Lenovo extension history.

The architecture separates:

1. the active AMD base display package;
2. Lenovo-specific integration semantics;
3. Radeon Software / CN metadata.

The active Driver Store package and physical target-device binding are the primary authority. CN metadata is supplemental and is never used to spoof a newer driver identity.

## Starting-origin classifier

The classifier is architecture-aware.

- Lenovo OEM expects applicable Lenovo standalone extension lineage material as part of the OEM architecture.
- Public 26.6.2 and 26.6.4 are exact known toolkit architectures that also intentionally retain OEM-generation Lenovo extension material.
- Public 26.7.1 moves required Lenovo semantics into the merged display package and removes the standalone extension lineage after rollback capture.
- Unknown AMD bases do not inherit exceptions from known origins.

### ExtensionId lineage authority

Raw staged-package count is not origin authority. Windows may retain several versions of the same extension lineage.

v3.1 groups applicable `amduw23e` packages by ExtensionId and accepts multiple generations only when they all belong to the validated original-Go Lenovo-derived lineage:

```text
{07A2A561-D001-4503-B239-EF2FE0379EFB}
```

Each member must be an Extension-class package applicable to the exact original Legion Go hardware. The authoritative member is selected by version/date ordering, but every recognized member is preserved in provenance evidence and exported for rollback.

A different applicable ExtensionId, missing/unparseable lineage identity, or package that does not target the exact Go remains fatal. Historical `DriverVer` and semantic-marker differences inside the structurally validated lineage are evidence, not automatic origin failure.

## Rollback

Before a destructive Stage 2 transition, the workflow records and exports the starting display package. When the starting architecture includes Lenovo standalone extension lineage material, every recognized lineage member is individually exported.

The prior display package is retained rather than globally purged. This makes rollback origin-aware and avoids assuming there should be only one AMD Display-class package in the Driver Store.

## Catalog resolution

The active catalog is resolved from the active Driver Store INF rather than by hardcoding the final target catalog filename while inspecting older origins.

On x64 Windows, an applicable `CatalogFile.NTamd64` declaration takes precedence. Missing, conflicting, path-traversing, non-CAT, or physically absent catalog declarations fail closed.

## Signing

The final merged display catalog is locally signed. The workflow temporarily enables Test Signing only after validating the exact built package and its catalog/INF membership.

Final completion requires:

- Test Signing OFF;
- `nointegritychecks` OFF;
- active catalog/signature identity matching the Stage 2 checkpoint.

## Payload preservation

The build protects a frozen 190-file unchanged manifest, restores all nine field-observed official AMD companion catalogs after Inf2Cat, and rehashes protected content after build/signing operations.

Public Beta v3.1 does not change the frozen merged AMD 26.7.1 INF, DAT, or kernel target hashes from v3.0.

## AMD defaults

v3.1 intentionally preserves:

```text
ColorVibrance_ENABLE_DEF = 1
ShowRSOverlay            = true
```

## Internal provenance identifiers

The corrected public package deliberately retains required RC2zp C#/PowerShell type names and some internal audit/provenance tokens. A broad substitution changed those type identifiers in an unpublished package attempt and was rejected immediately by the independent parser gate.

## No ReleaseVersion spoofing

Live registry `ReleaseVersion` spoofing is not part of v3.1. Earlier testing demonstrated that making live Radeon Software metadata claim an identity that did not match the installed display package could lead to Code 43 after reboot. v3.1 instead makes the driver package and software stack internally consistent.
