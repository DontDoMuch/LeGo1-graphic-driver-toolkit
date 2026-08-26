# Public Beta v4.0 validation summary

## Final package gates

The exact release bytes passed the Windows PowerShell 5.1 package/parser preflight with:

```text
Passed:       True
FailedChecks: 0
ExitCode:     0
```

All final hardening fixtures, package hashes, payload identities, origin-classifier fixtures, catalog checks, reboot/resume contracts, and public workflow gates passed.

## Final Stage 4 state

The finalized live installation completed the full read-only audit:

```text
72/72 checks PASS
FailedChecks = 0
Warnings = 0
WorkflowStage = Complete
Test Signing = OFF
nointegritychecks = OFF
Local catalog coverage = 14/14
Official catalog coverage = 14/14
```

## Origin field proof

- Healthy merged 26.7.1 → 26.8.1 completed Stage 2/3/4 successfully.
- Real ASUS/ROG Ally `32.0.31007.6002` Display origin → 26.8.1 completed Stage 2/3/4 successfully; the ASUS-only extension remained staged unchanged because it did not target `SUBSYS_381217AA`.
- Dirty ASUS install → Lenovo install without reboot → 26.8.1 completed successfully.

The ASUS version/hash is an evidence fixture, not an acceptance whitelist.

## Dual-catalog proof

The original Microsoft WHCP `u0203304.cat` was registered under the managed catalog name and survived reboot. Both the active local catalog and official Microsoft catalog covered 14/14 frozen kernel/UMD targets. Physical game testing confirmed the specific early-26.8.1 Gears 5 and Destiny 2/BattlEye trust regression was corrected.

## Hardening physical proof

### Machine-wide single instance

A second v4.0 launcher was started while the exact global mutex was deliberately held. It exited with code `4` and reported that another session was active. Workflow-state hash, log count, ProgramData workflow file inventory, and resume-task inventory remained unchanged.

### Saved Complete revalidation

A saved `Complete` installation was rerun through the public launcher. Stage 4 executed read-only and passed 72/72. The workflow-state file remained byte-identical, GPU identity and BCD code-integrity state were unchanged, and no resume task was created.

## Scope limits

Windows 11 on the original Legion Go is the supported field target. Windows 10, eGPU, other Legion Go models, and every possible external driver project are not certified by this release.
