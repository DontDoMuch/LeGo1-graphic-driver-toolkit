# Validation

## Public Beta v4.0

Public Beta v4.0 targets AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004` on the original Legion Go 83E1 internal Radeon 780M path.

## Core target-device proof

The 26.8.1 candidate completed the managed workflow on the original Legion Go from a healthy merged 26.7.1 origin:

```text
Stage 2 = Passed
Stage 3 = Passed
Stage 4 = Passed
FailedChecks = 0
Workflow Stage = Complete
```

The final device state proved the exact 26.8.1 INF, DAT, kernel, AMD Software, normal-signing, and persistence contracts.

## Dual-catalog trust field proof

The first 26.8.1 install exposed a user-mode trust regression despite a healthy Device Manager state:

- Gears 5 loaded AMD's `amdxc64.dll`, then hit `0x8007045A` and fell back to software/WARP;
- Destiny 2 / BattlEye blocked `amdxx64.dll` from the 26.8.1 Driver Store repository.

The causal correction separately registered the exact original Microsoft WHCP `u0203304.cat`. Field evidence changed official catalog coverage from `0/14` to `14/14` while local coverage remained `14/14`. The managed catalog survived reboot and the registration path proved idempotent.

After the correction, Gears 5 and Destiny 2 were physically retested successfully. The integrated workflow then completed the final 72-check audit with:

```text
Local catalog coverage    = 14/14
Official catalog coverage = 14/14
FailedChecks              = 0
Warnings                  = 0
```

## Third-party ASUS-origin proof

A real ASUS ROG Ally Z1 Extreme graphics package, version `32.0.31007.6002`, was examined and then installed on the Legion Go for field validation.

Its `amduw23e.inf`:

- is `Class=Extension`;
- shares ExtensionId `{07A2A561-D001-4503-B239-EF2FE0379EFB}` with the historical Go lineage;
- targets ASUS subsystem IDs (`...1043`);
- does **not** target Legion Go `SUBSYS_381217AA`.

Extracted ASUS extension SHA-256:

```text
52AE97D82E973058A0F47512346982BE9C6861CDF509C8F4CE257779A28D75D9
```

The live origin classified as `ThirdPartyDisplay / GenericAmd / Acceptable=True`. Public Beta v4.0 exported the active ASUS Display package for rollback, installed 26.8.1, completed Stage 2/3/4 with zero failed checks, and left the ASUS-only extension staged unchanged. This physically proves the foreign/non-applicable preservation path.

The ASUS identity is a field fixture, not a whitelist.

## Dirty ASUS → Lenovo mixed-origin proof

A later stress case installed the ASUS graphics package and then Lenovo graphics **without rebooting between those installs**, then launched the 26.8.1 v4.0 workflow. The transition completed successfully.

This test strengthens confidence in the hardware-scoped origin model when Driver Store history contains mixed vendor material. It does not weaken fail-closed behavior for unreadable or actually Go-applicable foreign lineages.

## Recovery and concurrency hardening proof

The final release candidate underwent a dedicated state-machine audit and Windows PowerShell 5.1 preflight covering:

- transaction-aware failed-checkpoint normalization;
- interrupted Stage 2 recovery before the ordinary Test Signing prerequisite;
- proof-derived rollback success/failure states;
- recovery-only routing for unproven rollback;
- prevention of direct Stage 2 bypass after proven rollback;
- startup self-heal if parent checkpoint normalization was interrupted;
- foreign resume-task detection;
- machine-wide mutex identity;
- saved-`Complete` read-only revalidation.

The exact final package then passed Windows PowerShell 5.1 with `Passed=True`, `FailedChecks=0`, and process exit `0`.

### Physical mutex test

A test process deliberately held the exact machine-wide installer mutex while a second v4.0 launcher was started.

Observed result:

```text
[BLOCKED] Another Legion Go AMD installer session is already active. No changes were made.
Second launcher exit code: 4
```

The workflow-state hash, workflow log count, ProgramData workflow file inventory, and resume-task inventory were unchanged.

### Physical Complete-state revalidation

With the saved workflow already `Complete`, the final launcher reran Stage 4 read-only.

Observed result:

```text
Launcher exit code: 0
Stage 4 Status: Passed
Stage 4 FailedChecks: 0
Audit ReadOnly: True
Audit checks: 72
Audit failed: 0
WorkflowStage: Complete
```

The workflow-state file remained byte-identical; GPU identity and BCD code-integrity policy were unchanged; no resume task was created.

## Scope limits

Windows 11 is the officially supported platform. Windows 10 is not officially supported and is intentionally not hard-blocked. eGPU and other Legion Go variants remain unvalidated. No generic certification is claimed for every historical third-party AMD package.
