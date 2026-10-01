# Public Beta v5.0 validation summary

## Exact final asset

```text
LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
ZIP entries: 24
PACKAGE-MANIFEST: 23/23 verified
ZIP CRC: PASS
PowerShell files: 13
```

## Deterministic source/build validation

The public release scope records:

```text
Basis: RC2 GateOnly deterministic rebuild from exact AMD 26.9.2 official INF/DAT sources
Preflight checks: 45
Failed checks: 0
Launcher started: false
```

Frozen outputs:

```text
Go 1 INF: 381E6122577AB273ED1ED8EE7BEB4B66CB89DA4B8BEFABA64B064416E778E1BF
Go 1 DAT: 2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223

Go S INF: 8F2AF5D9CC3CAB28CDE2D96499A655B579AC9BC6C62A215961DA66B360C83136
Go S DAT: 2E477E3DD0C9C88C09831AB116EDBD27FB4FBE5396BB408EE89354A383FEF223

Go 2 INF: F6EED28F18EA658FCB7B62F28ECC2FE9DE1ED24EF46CFA47AC5870211622F7D2
Go 2 DAT: DCBD6E683B6EDCA86DF0F5D22A1E09299391B5AF45759D750367AC38AD919EF4
```

## Physical validation boundary

```text
Go 1 Z1 Extreme / AMD 26.9.2:
78/78 PASS, FailedChecks=0, Warnings=0,
Test Signing OFF, nointegritychecks OFF,
critical catalog coverage 14/14 local + 14/14 official.
```

Go S and Go 2 do not have new physical 26.9.2 field-run claims in this release. Their profile-specific physical evidence is inherited from v4.5.1:

```text
Go S Z1 Extreme: 81/81 PASS baseline
Go 2 Z2 Extreme: 79/79 PASS baseline
```

## Public entry-gate behavior

The v5.0 runner builds preflight arguments conditionally:

- `-OfficialInfPath` is added only when non-empty;
- `-OfficialDatPath` is added only when non-empty;
- a normal launch therefore enters `STATIC_PACKAGE_PREFLIGHT`;
- exact-source validation can still supply explicit source paths when required.

Stage 1-4 scripts, deterministic builders, profile identities, signing, rollback, and the workflow identity all remain part of the same Public Beta v5.0 release.
