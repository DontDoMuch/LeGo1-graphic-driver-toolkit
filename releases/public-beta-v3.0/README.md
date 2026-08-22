# Public Beta v3.0 — AMD 26.7.1

Public Beta v3.0 is the current Legion Go 1 Graphics Driver Toolkit release.

## Release asset

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.0.zip
SHA-256: E946D1F981A435B9C8F8E94542649FA48970F7C56F85138E399411E5C2496DAF
```

The AMD installer is not redistributed.

Required official AMD source:

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

## Executable snapshot

`toolkit/` contains the exact executable/documentation snapshot used to build
the release asset.

The snapshot retains the internal engineering identifier `RC2zk` in several
filenames and runtime schemas. That identifier is preserved solely because
these files are byte-identical to the final field-proven candidate.

**RC2zk is not the public version.** The public version is **Public Beta v3.0**.

Frozen candidate archive SHA-256:

```text
4E55DEF4E892A6BA4314911B2797018A03E871F83EFB4D95022CB1FD90EC4B4A
```

## Field result

Final Public 26.6.4 → AMD 26.7.1 regression:

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Final Audit: 65/65 PASS
Workflow: Complete
```

Final audit archive SHA-256:

```text
B9ECEB363EE353076E9F16A869A7BBB8DF39FAA598B0929045C7D9A622978508
```

See `RELEASE-NOTES.md` and `VALIDATION-SUMMARY.md`.
