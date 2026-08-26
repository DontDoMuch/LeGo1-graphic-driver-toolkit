# Technical notes

## v4.0 architecture

Public Beta v4.0 moves the merged Legion Go target to AMD 26.8.1 while retaining the architecture developed through the 26.7.1 public releases:

1. exact AMD base display payload;
2. Lenovo-required integration semantics merged into the target INF/DAT architecture;
3. explicit origin/rollback modeling;
4. separately validated Radeon Software runtime;
5. fail-closed signing/catalog/persistence contracts.

The physical target-device binding and active Driver Store package remain primary authority. CN/Radeon metadata is supplemental and is never used to spoof a driver identity.

## Hardware-scoped extension ownership

A major v4.0 correction is the separation of **inventory** from **destructive ownership**.

All staged `amduw23e.inf` packages are inventoried, but filename/class/ExtensionId do not prove that the package belongs to the original Go. A package enters the Go 1 lineage only when its readable INF model directive actually targets:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

This matters because the field-observed ASUS ROG Ally package used the same `amduw23e.inf` filename, `Class=Extension`, and historical ExtensionId while targeting ASUS `...1043` subsystem IDs. v4.0 preserves that foreign package.

Applicable same-lineage historical Go generations remain supported; distinct applicable ExtensionIds or unreadable applicability fail closed.

## Rollback

Before destructive Stage 2 work, the workflow records and exports the starting Display package. When the starting architecture contains Go-applicable standalone Lenovo extension lineage material, each recognized member is individually exported.

The prior Display package is retained rather than globally purged. Rollback therefore remains origin-aware and does not require the Driver Store to contain only one AMD Display package.

Rollback outcome status is derived from proof of prior Display restoration plus any required extension-lineage restoration. An unproven rollback stays on a recovery-only route.

## Recovery state machine

Final v4.0 hardening adds explicit transaction-aware behavior:

- pre-driver Test Signing boundary failures and pre-destructive `ReadyForInstall` failures can rewind to `SignedPackageReady` for a fresh managed re-arm;
- `DriverTransactionInProgress` remains reserved for rollback recovery;
- `DriverInstalledPreReboot` remains preserved so target binding cannot repeat;
- interrupted recovery is evaluated before the ordinary Test Signing prerequisite;
- proven rollback cannot fall straight back into normal Stage 2;
- if rollback proof was saved but parent checkpoint normalization was interrupted, the public launcher self-heals back to `SignedPackageReady`;
- no failed destructive stage automatically retries.

## Concurrency

All v4.0 public/resume entry routes share the machine-wide named mutex:

```text
Global\LegionGo-AMD-Driver-Toolkit-Installer
```

A second v4.0 session is rejected before persistent workflow mutation. Registered `LegionGo-AMD-*-Resume` tasks belonging to another release are also a fail-closed conflict.

## Dual-catalog trust

The adapted Display INF requires its locally generated/signed catalog. The unchanged AMD 26.8.1 kernel/UMD payload is additionally covered by the exact original Microsoft WHCP catalog:

```text
u0203304.cat
SHA-256: 23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48
```

Stage 2 registers that catalog through Windows catalog-management APIs under the managed name:

```text
LegionGo-AMD-26.8.1-Official-WHCP.cat
```

Both local and official catalogs must cover all 14 frozen targets. Registration is idempotent for the exact managed catalog, rechecked after reboot, and independently audited by Stage 4.

## Frozen payload preservation

The build protects a frozen 190-file unchanged manifest and exact v4 INF/DAT builders. The final deterministic identities are:

```text
Driver:       32.0.31041.1004
INF SHA-256:  F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42
DAT SHA-256:  83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953
Kernel SHA:   92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
```

## AMD defaults

v4.0 intentionally preserves:

```text
ColorVibrance_ENABLE_DEF = 1
ShowRSOverlay            = true
```

## Complete-state revalidation

A saved `Complete` checkpoint is not blindly trusted forever. Rerunning the public launcher executes the full Stage 4 audit read-only. Drift produces evidence/failure without automatic repair or state clearing.

## No ReleaseVersion spoofing

Live Radeon Software `ReleaseVersion` spoofing is not part of v4.0. The driver package and software stack are validated against their real exact identities.
