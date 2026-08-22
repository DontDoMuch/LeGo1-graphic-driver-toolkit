# Public Beta v3.1 — AMD 26.7.1

Public Beta v3.1 is the current Legion Go 1 Graphics Driver Toolkit release.

It is a bugfix release over Public Beta v3.0. The frozen merged AMD 26.7.1 target payload is unchanged.

## Release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1.zip
SHA-256: ECAED23350E6C58139FDBE6C587BF30F4F931AD5086CBBD33A46B33E68107328
Size: 124377 bytes
```

The AMD installer is not redistributed.

Required official AMD source:

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

## Corrected origin handling

v3.1 fixes valid Lenovo OEM histories that v3.0 could reject when Windows retained multiple applicable generations of `amduw23e` or when a historical extension `DriverVer` differed from the active Lenovo display package.

Multiple generations are accepted only when every applicable member targets the original Legion Go and shares the validated Lenovo-derived ExtensionId:

```text
{07A2A561-D001-4503-B239-EF2FE0379EFB}
```

Every recognized lineage member is individually exported before removal. Distinct applicable ExtensionIds remain fail-closed.

## Executable snapshot

`toolkit/` contains the exact 18-file snapshot used to build the release asset. `TOOLKIT-SHA256SUMS.txt` verifies every packaged file other than the self-referential hash list.

The corrected public transformation retains required RC2zp internal implementation/provenance identifiers while public entrypoints and workflow contracts use Public Beta v3.1.

## Validation

Dirty Lenovo OEM with two same-ExtensionId `amduw23e` generations:

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow: Complete
```

Final corrected Public Beta v3.1 merged-to-merged regression:

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow: Complete
```

Corrected package audit:

```text
16/16 PASS
```

See `RELEASE-NOTES.md`, `VALIDATION-SUMMARY.md`, and `toolkit/PACKAGE-AUDIT.md`.
