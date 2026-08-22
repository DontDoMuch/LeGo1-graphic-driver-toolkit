# FAQ

## Is this for the Legion Go S?

No. Public Beta v3.0 is for the original Legion Go / Legion Go 1 hardware
identity documented in `COMPATIBILITY.md`.

## Why does the ZIP contain a few filenames that say RC2zk?

RC2zk is the internal identifier of the final field-proven candidate. Those
executable files were deliberately kept byte-identical when publishing
Public Beta v3.0. RC2zk is provenance, not the public release name.

## Why not rename those internal scripts?

Renaming/relabeling the tested executable set would require another package
mutation and another full field certification for cosmetic gain. The public
entrypoint, release asset, GitHub tag, documentation, and repository record
all use Public Beta v3.0.

## Does v3.0 need Lenovo's amduw23e extension?

It depends on the starting architecture.

Lenovo OEM and the public 26.6.2/26.6.4 toolkit releases use the standalone
Lenovo extension. v3.0 validates and exports it for rollback, then removes it
because the final 26.7.1 package incorporates the required Lenovo semantics.

## Does the extension version need to match the 26.6.x display driver?

No. For the exact known public 26.6.2/26.6.4 toolkit architectures, the
OEM-generation standalone extension is intentional. v3.0 recognizes this
only for the exact known base identities and a compatible attached extension.

## Can I use a different AMD release?

No. A different AMD release needs separate analysis, adaptation, and
validation. Do not substitute a different installer.

## Does v3.0 spoof Radeon Software ReleaseVersion?

No.

## How many prompts are there?

The normal public launcher asks exactly two Y/N questions at the beginning.
Required managed reboots afterward are automatic.

## What proves success?

Stage 2/3/4 must pass, `FailedChecks` must be zero, and workflow state must be
`Complete`. The final installed hashes/policy state are listed in
`VERIFICATION.md`.
