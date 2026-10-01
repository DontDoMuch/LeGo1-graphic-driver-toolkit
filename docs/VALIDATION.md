# Validation

## Public Beta v5.0

Public Beta v5.0 targets AMD 26.9.2 and includes the final public entry-gate behavior, deterministic builders, profile identities, signing/rollback behavior, and `Public-Beta-v5.0` workflow namespace as one release.

## Exact public asset integrity

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
ZIP entries: 24
PACKAGE-MANIFEST entries: 23
Publication manifest verification: 23/23 exact length + SHA-256
ZIP CRC: PASS
PowerShell files in package: 13
```

## Go 1 physical AMD 26.9.2 validation

The v5.0 release line records a physical Go 1 AMD 26.9.2 validation followed by a full RC1 one-command/resume/idempotent end-to-end run:

```text
Profile: LegionGo1
Final audit: 78/78 PASS
FailedChecks: 0
Warnings: 0
Test Signing: OFF
nointegritychecks: OFF
Local catalog critical coverage: 14/14
Official catalog critical coverage: 14/14
```

The validated v5.0 package forwards `OfficialInfPath` / `OfficialDatPath` only when non-empty while preserving the validated Stage 1-4 contract.

## Go S and Go 2 validation boundary

The v5.0 package freezes deterministic AMD 26.9.2 source/build contracts for all three profiles. Its public release scope records an exact-source rebuild preflight of **45 checks / 0 failures** with these outputs:

| Profile | Deterministic INF SHA-256 | Deterministic DAT SHA-256 |
|---|---|---|
| Go 1 | `381E6122577AB273ED1ED8EE7BEB4B66CB89DA4B8BEFABA64B064416E778E1BF` | `2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223` |
| Go S | `8F2AF5D9CC3CAB28CDE2D96499A655B579AC9BC6C62A215961DA66B360C83136` | `2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223` |
| Go 2 | `F6EED28F18EA658FCB7B62F28ECC2FE9DE1ED24EF46CFA47AC5870211622F7D2` | `DCBD6E683B6EDCA86DF0F5D22A1E09299391B5AF45759D750367AC38AD919EF4` |

For **Go S and Go 2**, device-specific physical profile evidence is inherited from the physically validated v4.5.1 lineage. This release **does not claim new physical AMD 26.9.2 field runs on those two devices**.

Historical physical profile baseline retained as device-profile evidence:

```text
Legion Go S Z1 Extreme: 81/81 PASS, 0 failures, 0 warnings
Legion Go 2 Z2 Extreme: 79/79 PASS, 0 failures, 0 warnings
```

## Public entry-gate behavior

The v5.0 runner now builds preflight arguments conditionally:

- `-OfficialInfPath` is added only when non-empty;
- `-OfficialDatPath` is added only when non-empty;
- a normal launch therefore enters `STATIC_PACKAGE_PREFLIGHT` instead of forwarding empty path arguments;
- Stage 1-4 scripts, builders, profiles, release contract, signing, rollback, and internal workflow identity remain unchanged from v5.0.

## Required final policy state

A successful installed profile must finish with:

```text
GPU Status          = OK
ProblemCode         = 0
HasProblem          = False
Selected profile    = exact HWID match
Applicable amduw23e = absent after clean transition
Foreign amduw23e    = permitted/preserved
Test Signing        = OFF
nointegritychecks   = OFF
Stage 2/3/4         = Passed
FailedChecks        = 0
Warnings            = 0
Workflow Stage      = Complete
```

## Evidence boundary

Private volunteer packages, evidence archives, certificates, keys, logs, and workflow state are not public release assets. Public documentation distinguishes exact package/source proof from physical device proof and does not promote inherited evidence into a new 26.9.2 field-run claim.
