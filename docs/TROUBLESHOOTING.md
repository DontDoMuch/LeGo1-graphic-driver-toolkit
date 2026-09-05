# Troubleshooting

## First rule: stop at a hard failure

Do not repeatedly force a failed numbered stage, manually delete workflow state, manually override the selected profile, or manually remove staged `amduw23e` packages to bypass classification.

Preserve the visible console error plus the generated parser/final/failure evidence folder or ZIP under Downloads.

## Unsupported hardware / profile resolution failure

Public Beta v4.5 supports only:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
```

Do not edit a profile or hardware ID to bypass the gate. Other revisions/variants require separate validation.

## Test Signing after a failure

Managed hard-failure recovery uses transaction-aware checkpoints and normalizes boot-integrity settings according to the proven state. It removes automatic resume authorization and never automatically retries a failed destructive stage.

Rerun the main public launcher only when the workflow/evidence says the state is safe for a normal rerun. Do not directly invoke Stage 2 to bypass recovery routing.

If rollback after a destructive failure cannot be proven, the workflow remains recovery-only.

## Another installer session is already active

The v4 engine uses a machine-wide named mutex. A second manual/resume session is rejected before persistent workflow mutation. A conflicting registered `LegionGo-AMD-*-Resume` workflow also fails closed.

## Starting GPU origin is not acceptable

Do not infer ownership from `amduw23e.inf` alone.

v4.5 inventories all such packages and only enters destructive extension handling when the readable INF actually targets the **selected exact hardware profile**. Proven foreign/non-applicable packages are intentionally preserved. Unreadable scope or conflicting selected-profile-applicable lineages fail closed.

A healthy third-party AMD Display package can be an accepted starting origin; an unhealthy or ambiguous one cannot.

## AMD installer not found or rejected

Required source:

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

Keep exactly one matching copy somewhere under Downloads. A same-named file with different bytes is not accepted.

## Secure Boot

Secure Boot must be disabled for this local-catalog signing architecture. Enabled or unknown Secure Boot state is a hard front gate.

**Preserve the BitLocker / Device Encryption recovery key before changing Secure Boot.**

## Evidence ZIP was not created

Preserve the evidence folder itself. v4.5 uses direct .NET ZIP packaging after the audit. A packaging-only failure must not be treated as permission to reinstall the driver or manually rerun destructive stages.

## Rerunning after Complete

A saved `Complete` workflow reruns the selected-profile Stage 4 audit read-only to detect live-system drift. A drift failure reports evidence; it does not automatically repair the machine.

## Why do paths say v4.0 during a v4.5 run?

Some protected internal v4 engine identifiers intentionally retain v4.0 naming. Do not rename or delete them. Verify the outer v4.5 package hash and the selected profile instead.

## Should I use DDU?

DDU is not part of the normal Public Beta v4.5 workflow. Do not insert it into a normal upgrade/repair run unless a documented recovery procedure specifically calls for it.
