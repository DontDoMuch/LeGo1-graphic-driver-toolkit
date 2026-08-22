# FAQ

## Is this for the Legion Go S?

No. Public Beta v3.1 is for the original Legion Go / Legion Go 1 hardware identity documented in `COMPATIBILITY.md`.

## Why can more than one Lenovo amduw23e package be present?

Windows can retain multiple generations from the same Lenovo extension lineage after OEM installation. Public Beta v3.1 treats them as one versioned lineage only when every applicable package is structurally scoped to the original Legion Go and shares the validated Lenovo-derived ExtensionId.

Every recognized lineage member is exported before removal. Distinct applicable ExtensionIds still fail closed.

## Does the extension DriverVer need to match the active Lenovo display driver?

Not by itself. Historical Lenovo generations can have a different `DriverVer` while still belonging to the same exact-Go ExtensionId lineage. v3.1 validates class, hardware applicability, lineage identity, attachment/origin structure, and package evidence instead of treating a version mismatch alone as fatal.

## Why does v3.1 still contain RC2zp references?

RC2zp is an internal implementation/provenance token retained in some class names, preflight check identifiers, comments, cache paths, and diagnostic text.

The first unpublished public transformation attempted a broad RC-to-public substitution and modified internal type identifiers, causing an immediate parser failure. The corrected package preserves those tested internal identifiers. Public filenames, workflow/result schemas, signer identity, evidence names, and primary release headers use Public Beta v3.1.

## Does v3.1 need Lenovo's standalone amduw23e extension in the final state?

No. Lenovo OEM and the public 26.6.2/26.6.4 toolkit releases use standalone Lenovo extension lineage material. v3.1 validates and exports every applicable recognized member for rollback, then removes the lineage because the final 26.7.1 package incorporates the required Lenovo semantics.

## Can I use a different AMD release?

No. A different AMD release needs separate analysis, adaptation, and validation. Do not substitute a different installer.

## Does v3.1 spoof Radeon Software ReleaseVersion?

No.

## How many prompts are there?

The normal public launcher asks exactly two Y/N questions at the beginning. Required managed reboots afterward are automatic.

## What proves success?

Stage 2/3/4 must pass, `FailedChecks` must be zero, and workflow state must be `Complete`. The final installed hashes and policy state are listed in `VERIFICATION.md`.
