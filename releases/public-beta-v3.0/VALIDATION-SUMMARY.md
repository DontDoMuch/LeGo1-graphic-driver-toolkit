# Public Beta v3.0 Validation Summary

## Final 26.6.4 → 26.7.1 field regression

Starting state captured by the workflow:

```text
PreviousOriginKind:
  VerifiedPriorToolkitWithStandaloneExtension

PreviousDriverVersion:
  32.0.31021.5001

PreviousInfHash:
  73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034

PreviousStandaloneExtensionPresent:
  True

PreviousStandaloneExtensionSemanticPass:
  True

PreviousStandaloneExtensionVersionCoherent:
  False

PreviousExtensionDisposition:
  ExportThenRemoveForMergedTarget
```

Rollback material captured:
- starting `u0202082.inf` display package;
- Lenovo `amduw23e.inf` extension.

Final result:

```text
Stage 2 = Passed / ExitCode 0
Stage 3 = Passed / ExitCode 0
Stage 4 = Passed / ExitCode 0
FailedChecks = 0
Workflow Stage = Complete
Final Audit = 65/65 PASS
```

Final audit ZIP SHA-256:

```text
B9ECEB363EE353076E9F16A869A7BBB8DF39FAA598B0929045C7D9A622978508
```

## Frozen executable provenance

Final field candidate archive:

```text
LegionGo-AMD-26.7.1-v3.0-RC2zk-validation.zip
SHA-256: 4E55DEF4E892A6BA4314911B2797018A03E871F83EFB4D95022CB1FD90EC4B4A
```

The public `toolkit/` snapshot is byte-identical to the files from that
candidate. The RC2zk identifier is an internal provenance label only.
