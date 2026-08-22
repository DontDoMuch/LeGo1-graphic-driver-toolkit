# Validation

## Public Beta v3.0

Public Beta v3.0 targets AMD 26.7.1.

## Final field regression: Public Beta v2.1 / 26.6.4 → v3.0 / 26.7.1

Starting state:

```text
DriverVersion:
  32.0.31021.5001

Active original INF:
  u0202082.inf

INF SHA-256:
  73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034

Origin:
  VerifiedPriorToolkitWithStandaloneExtension
```

The workflow proved:
- target GPU healthy before mutation;
- exact 26.6.4 base identity;
- compatible attached Lenovo extension despite expected cross-version DriverVer;
- current 26.6.4 display exported for rollback;
- Lenovo extension exported for rollback;
- standalone extension removed for the merged 26.7.1 target;
- exact 26.7.1 package staged and bound;
- normal signing policy restored after reboot;
- matching AMD Software sealed;
- final persistence audit completed.

Result:

```text
Stage 2 = Passed
Stage 3 = Passed
Stage 4 = Passed
FailedChecks = 0
Final Audit = 65/65 PASS
Workflow Stage = Complete
```

Audit archive SHA-256:

```text
B9ECEB363EE353076E9F16A869A7BBB8DF39FAA598B0929045C7D9A622978508
```

## Lenovo OEM → 26.7.1

The clean Lenovo OEM → 26.7.1 path was physically field-proven immediately
before the final 26.6.x classifier expansion using the same frozen target
payload and retained OEM-origin logic:

```text
Final Audit = 65/65 PASS
```

## Public Beta v1.1 / 26.6.2 → 26.7.1

v3.0 contains exact-identity acceptance and rejection fixtures for:

```text
DriverVersion: 32.0.31021.1015
INF SHA-256:   39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E
```

with the required standalone Lenovo extension.

The project does not claim that this exact v3.0 transition received a
separate physical field run.

## Final target

```text
DriverVersion: 32.0.31035.1003
GPU Status: OK
ProblemCode: 0
HasProblem: False
Final audit: 65/65 PASS
```

## Provenance

The public toolkit snapshot is byte-identical to the final field-proven
`v3.0-RC2zk` candidate. RC2zk remains only as an internal provenance label.
