# Validation

## Public Beta v3.1

Public Beta v3.1 targets AMD 26.7.1 and preserves the frozen merged target payload from v3.0.

## Dirty Lenovo OEM multi-generation origin

The corrected classifier mechanics were physically field-run from a Lenovo OEM display stack with two applicable `amduw23e` generations still staged.

Starting display:

```text
DriverVersion: 32.0.23017.1001
PreviousOriginKind: LegacyStandaloneExtension
PreviousStandaloneExtensionCount: 2
PreviousExtensionDisposition: ExportThenRemove
```

Both extension packages targeted the original Legion Go and shared:

```text
ExtensionId: {07A2A561-D001-4503-B239-EF2FE0379EFB}
```

Observed lineage generations:

```text
32.0.23017.1001 — 2026-01-08
31.0.24028.1001 — 2024-04-22
```

Both packages were individually exported for rollback before removal.

Result:

```text
Stage 2 = Passed
Stage 3 = Passed
Stage 4 = Passed
FailedChecks = 0
Workflow Stage = Complete
```

## Merged 26.7.1 → corrected Public Beta v3.1

The final corrected public package was then physically run from the exact merged AMD 26.7.1 state.

Starting state:

```text
PreviousOriginKind: MergedEmbedded
PreviousDriverVersion: 32.0.31035.1003
PreviousInfHash: 9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409
PreviousStandaloneExtensionCount: 0
```

The workflow retained the exact healthy pre-existing merged package as the active binding while exercising the public v3.1 parser, package, workflow, software, reboot/resume, and final-audit contracts.

Result:

```text
Release = Public-Beta-v3.1
Stage 2 = Passed
Stage 3 = Passed
Stage 4 = Passed
FailedChecks = 0
Workflow Stage = Complete
```

## Public packaging correction

The first unpublished v3.1 transformation performed a broad RC-to-public text substitution that modified internal C#/PowerShell type identifiers. The independent parser gate rejected it before the launcher or any driver stage started.

The corrected package:

- preserves the field-proven RC2zp internal class/type identifiers;
- uses Public Beta v3.1 for public entrypoints, workflow/result schemas, signer identity, evidence names, and primary headers;
- writes a Downloads transcript if the pre-launch parser gate fails;
- passed the corrected package static audit `16/16`.

## Final target

```text
DriverVersion: 32.0.31035.1003
GPU Status: OK
ProblemCode: 0
HasProblem: False
Final INF SHA-256: 9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409
Final amdgcf.dat SHA-256: DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766
Loaded amdkmdag.sys SHA-256: D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5
```

## Validated scope

The validated hardware scope is the original Legion Go 83E1 internal Radeon 780M path. eGPU configurations and external driver projects remain unvalidated.

Private field logs, workflow state, certificates, and evidence archives are not release assets.
