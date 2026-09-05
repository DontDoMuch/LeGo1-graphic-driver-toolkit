# Public Beta v4.5 release notes

Public Beta v4.5 keeps AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004` and expands the v4 architecture to three exact Lenovo Legion Go hardware profiles behind one automatic resolver.

## Supported hardware

```text
Legion Go 1 Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04
Phoenix -> ati2mtag_Phoenix_LegionGo

Legion Go S Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04
Phoenix -> ati2mtag_Phoenix_LegionGoS

Legion Go 2 Z2 Extreme
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
Strix -> ati2mtag_Strix_LegionGo2
```

All other hardware IDs fail closed. There is no manual profile override.

## Highlights

- One shared AMD 26.8.1 engine with exact immutable per-device profiles.
- Selected profile/fingerprint/HWID/family persisted and revalidated across reboot boundaries.
- Exact profile-specific INF/DAT construction and final audit counts.
- Go S preserves 30 exact ordered Lenovo OEM directives with Lenovo AddReg after AMD DelReg.
- Go 2 uses `%AMD150E.517%`, 28 exact ordered Lenovo OEM directives, and Lenovo-proven exact C5 -> Strix mapping.
- Selected-profile `amduw23e` ownership replaces broad filename/class/ExtensionId cleanup; proven foreign packages remain preserved.
- Healthy third-party AMD Display starting states remain supported by the inherited v4 origin/rollback model; ROG Ally-origin migration remains field-proven on Go 1.
- Production Windows PowerShell 5.1 compatibility no longer depends on `Get-FileHash` or `Import-PowerShellDataFile`.
- Final/failure evidence ZIP packaging uses direct .NET ZIP APIs.

## Physical validation

```text
Go 1 Z1 Extreme: 78/78 PASS, 0 failures, 0 warnings
Go S Z1 Extreme: 81/81 PASS, 0 failures, 0 warnings
Go 2 Z2 Extreme: 79/79 PASS, 0 failures, 0 warnings
```

The Go 1 destructive result used the immediate pre-auto-evidence combined v4.5 candidate. The final candidate changes only top-level evidence-ZIP packaging/manifest identity, leaves Stage 1-4/device logic unchanged, and passed the final Regression v5 rather than triggering another destructive reinstall. Go S and Go 2 results came from private volunteer packages whose exact profiles and Stage 1-4 scripts are preserved in v4.5; shared helper compatibility fixes were exercised by the final regression. Those private packages/evidence are not release assets.

## Exact final-package regression

The exact final v4.5 bytes passed the real Windows PowerShell 5.1 entry gate and a 43-check source-backed all-profile regression with zero failures. The same run rebuilt all three profile outputs byte-exact, rejected the Go 2 `REV_C4` negative fixture, and passed the direct .NET evidence-ZIP create/open smoke test.

## Release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.5.zip
SHA-256: B773EEFE02560A47BB6A4AE109E21D4E967CD526A2198955EC4BBD788D13930C
Size: 132499 bytes
```

Required AMD source:

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

## Platform

Officially validated: Windows 11 x64 on the three exact hardware IDs above.

Windows 10 is not officially supported and is intentionally not hard-blocked. eGPU and unlisted Legion Go variants/revisions remain unvalidated.

## Developer Notes

After downloading the zip file, right click it -> properties -> unblock -> ok