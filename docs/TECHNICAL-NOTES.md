# Technical notes

## v4.5.1 architecture

Public Beta v4.5.1 keeps the field-proven AMD 26.8.1 v4 engine and retains the exact multi-device profile layer introduced by v4.5:

1. exact AMD 26.8.1 release contract;
2. exact immutable hardware profiles;
3. automatic exact-HWID resolver with no manual override;
4. deterministic profile-specific INF/DAT construction;
5. selected-profile origin/extension/rollback/recovery handling;
6. shared AMD Software Stage 3;
7. selected-profile final audit;
8. fail-closed unsupported-hardware behavior.

## v4.5.1 hotfix delta

The device profiles and deterministic outputs are unchanged from v4.5. v4.5.1 changes three workflow/recovery details:

1. **Additive exact-catalog handling.** `Register-LegionGoOfficialCatalogTrust` recognizes `ApplyPreservingExisting` when at least one exact Microsoft catalog is already present, all 14 frozen targets are covered, and the managed-name copy is absent. It registers the exact managed copy without removing the preexisting exact Microsoft catalog copy/copies. Incomplete or ambiguous coverage still stops.
2. **Final rollback re-proof.** After prior Display restoration and applicable extension restoration, Stage 2 performs a final device rescan, re-queries the GPU, and revalidates the expected prior INF hash/health before rollback outcome is accepted.
3. **Fresh persistent namespace.** Workflow state, rollback material, toolkit copy, logs, and resume-task identity are rooted under `C:\ProgramData\LegionGo-AMD-26.8.1-MultiDevice-v4.5.1\<Profile>`, preventing v4.5 state from being consumed by the hotfix.

The public CMD entrypoint also now targets the v4.5.1 runner explicitly.

## Exact profiles

```text
Go 1 Z1 Extreme
15BF / 381217AA / REV_04
Phoenix -> ati2mtag_Phoenix_LegionGo

Go S Z1 Extreme
15BF / 380C17AA / REV_04
Phoenix -> ati2mtag_Phoenix_LegionGoS

Go 2 Z2 Extreme
150E / 381C17AA / REV_C5
Strix -> ati2mtag_Strix_LegionGo2
```

The selected profile ID, fingerprint, exact HWID, AMD family, base DDInstall, and release-contract fingerprint are persisted and revalidated across reboot boundaries.

## Profile-specific INF/DAT construction

Go 1 and Go S both use Phoenix but have separate dedicated install sections and separate INF identities. Go 1 and Go S intentionally share the frozen 15BF/REV_04 `amdgcf.dat` output.

Go S preserves 30 exact ordered Lenovo OEM directives. The Lenovo AddReg block must remain after AMD DelReg.

Go 2 uses Strix, `%AMD150E.517%`, 28 exact ordered Lenovo OEM directives, and its own final DAT. AMD 26.8.1 has DEV_150E Strix coverage but not native enumeration of the exact Lenovo C5 ID; Lenovo OEM provenance establishes exact C5 -> Strix for this controlled adaptation.

## Hardware-scoped extension ownership

All staged `amduw23e.inf` packages are inventoried, but filename/class/ExtensionId do not prove ownership. Destructive extension handling is based on readable INF model directives targeting the **selected exact profile**.

This is the generalized form of the v4.0 Go 1 rule that preserved a field-observed ASUS ROG Ally extension sharing the same filename/class/ExtensionId while targeting ASUS subsystem IDs.

Applicable recognized selected-profile lineage members are exported before removal. Proven foreign/non-applicable packages are preserved. Unreadable applicability or conflicting applicable lineages fail closed.

## Third-party Display origins and rollback

A healthy unrecognized AMD Display package can classify as an acceptable `ThirdPartyDisplay / GenericAmd` origin. Before destructive Stage 2 work, the exact active Display INF identity is recorded, hashed, and exported for rollback.

The prior Display package is retained rather than globally purged. Recovery first prefers the exact prior Driver Store INF and can restage the verified exported INF if required.

ROG Ally-origin migration is field-proven on Go 1. v4.5.1 carries the same origin/rollback mechanism into the selected-profile architecture.

## Recovery state machine

The v4 transaction model remains intact:

- pre-destructive failures can return through managed preparation;
- `DriverTransactionInProgress` remains rollback/recovery territory;
- a proven installed-pre-reboot target is not rebound blindly;
- rollback outcome is proof-derived;
- unproven rollback remains recovery-only;
- no failed destructive stage automatically retries;
- machine-wide concurrency protection remains active.

## Windows PowerShell 5.1 compatibility

Production v4.5.1 intentionally avoids dependencies that failed on the real target host:

- no production `Get-FileHash` dependency;
- no `Import-PowerShellDataFile` dependency;
- `${Variable}:`-safe interpolation where required.

Hashing uses direct .NET SHA-256 streams. The release contract is loaded with a narrow static parser for the exact verified data-file grammar. The v4.5.1 asset does **not** sanitize inherited `PSModulePath`; a PowerShell 7 parent can therefore poison a Windows PowerShell 5.1 child module path. Explorer/Command Prompt or a clean Windows PowerShell 5.1 context is the supported launch environment.

## Evidence packaging

The final v4.5.1 launcher uses direct `.NET System.IO.Compression.ZipFile` for final/failure evidence ZIP creation rather than relying on `Compress-Archive`. The exact API path passed a create/open smoke test on the real Windows PowerShell 5.1 host.

## Protected v4.0 internal identifiers

Some field-proven internal state/schema/log identifiers still contain `v4.0`. They are implementation lineage, not hardware selection or public-release identity. They are intentionally not mass-renamed solely for cosmetics.

## Frozen common payload

```text
Driver:       32.0.31041.1004
Kernel SHA:   92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
Official CAT: 23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48
```
