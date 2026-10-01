# Technical notes

## v5.0 architecture

Public Beta v5.0 moves the frozen AMD target to 26.9.2 / display `32.0.32015.2008` while retaining the multi-device transaction/recovery architecture proven through v4.5.1.

The package layers are:

1. exact AMD 26.9.2 release contract;
2. exact-HWID profile resolver with no manual override;
3. deterministic per-profile INF/DAT builders;
4. selected-profile origin classifier and rollback export;
5. local merged-catalog signing plus original Microsoft WHCP catalog preservation;
6. reboot/resume transaction state;
7. matching native AMD Software / DVR normalization;
8. profile-aware final persistence audit;
9. public package/parser/preflight entry gate.

## v5.0 public entry-gate behavior

The v5.0 public runner builds optional source-path arguments conditionally. `OfficialInfPath` and `OfficialDatPath` are appended to the preflight command line only when non-empty.

The following remain unchanged from the v5.0 base release line:

- Stage 1-4 scripts and behavior;
- deterministic builders;
- three profile definitions and frozen outputs;
- signing and rollback model;
- `Public-Beta-v5.0` internal schema/runner identity;
- `C:\ProgramData\LegionGo-AMD-26.9.2-MultiDevice-v5.0\<Profile>` workflow root.

The public package, runner, and workflow identity all use `v5.0`.

## Exact AMD 26.9.2 release contract

```text
ReleaseId: AMD-26.9.2
DriverVersion: 32.0.32015.2008
Installer: whql-amd-software-adrenalin-edition-26.9.2-win11-c.exe
Installer SHA-256: 72E368AE264F36E89CA0FE1DAB1CAD926047C2D6B0A3EFED9745D8D99780FE58
Official INF: u0204590.inf
Official INF SHA-256: 8E000BB2DDEC7E948D225B383FC867B4857F06387AA4A2B2A1EA1CF1819669F2
Official DAT SHA-256: C0AF3662075989517CC5A5C1B6417682525B7707EAE1B95DD9AB3F263AD8D2F4
Kernel SHA-256: 432AF310FE3FD129065E844548251CC49B969060A9478D543AC40ED59F318774
Official catalog SHA-256: E960CA26A2A0EA877976850204522719077FB02162754009D443220080F681F5
```

The unchanged-file manifest remains 190 entries and the official critical catalog-target manifest remains 14 entries.

## Profile identity persistence

The selected profile ID, fingerprint, exact HWID, AMD family, base DDInstall, and release-contract fingerprint are persisted and revalidated across reboot boundaries. Unsupported or changed hardware identity fails closed.

## Go S and Go 2 OEM semantics

Go S uses Phoenix and preserves 30 exact ordered Lenovo OEM directives. Go 2 uses Strix and preserves 28 exact ordered Lenovo OEM directives. Their deterministic AMD 26.9.2 outputs are frozen in the package profile contracts.

Physical 26.9.2 validation differs by profile: Go 1 has a full v5.0-line physical run; Go S and Go 2 use new deterministic 26.9.2 source/build proof with physical device-profile evidence inherited from v4.5.1.

## Origin classification and rollback

The classifier treats live selected-profile applicability as authoritative. Applicable recognized Lenovo extension lineage is exported and handled as transaction material. Proven foreign/non-applicable `amduw23e` packages are preserved.

ROG Ally-origin migration remains field-proven on Go 1. That result proves the architecture can preserve a third-party Display origin as rollback input without treating every familiar extension filename as selected-profile-owned.

## Catalog model

The adapted INF requires a local per-machine signer/catalog. The unchanged AMD payload also retains exact Microsoft WHCP coverage through `u0204590.cat`. Final audit independently verifies the relevant local and official catalog contracts.

The Go 1 physical AMD 26.9.2 validation recorded critical coverage of 14/14 under both catalog paths.

## Windows PowerShell 5.1 compatibility

Production code intentionally avoids dependencies that failed on real target hosts, including production reliance on `Get-FileHash` and `Import-PowerShellDataFile`. Hashing uses direct .NET SHA-256 streams and release-contract parsing is narrow/static.

The package does not contain a `PSModulePath` sanitizer. Launching Windows PowerShell 5.1 as a child of PowerShell 7 can therefore inherit a PowerShell-7-oriented module path. Explorer, Command Prompt, or a clean Windows PowerShell 5.1 context remains the supported launch environment.

## Evidence packaging

Final/failure evidence uses direct `.NET System.IO.Compression.ZipFile` packaging. A packaging-only failure does not authorize bypassing state checks or rerunning destructive stages manually.

## Internal lineage names

Some protected state/schema/log identifiers still contain `v4.0`. They are implementation lineage, not the public release identity. The `v5.0` runner/workflow namespace is the current release identity. Neither should be mass-renamed solely for cosmetics.
