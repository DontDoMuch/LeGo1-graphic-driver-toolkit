# Public Beta v4.0 release notes

Public Beta v4.0 moves the original Legion Go target to AMD Adrenalin 26.8.1 / display driver `32.0.31041.1004`.

## Highlights

- Hardware-scoped `amduw23e` ownership: only packages whose readable model directives actually target `SUBSYS_381217AA` enter Go 1 cleanup/rollback handling; proven foreign packages are preserved.
- Real ASUS/ROG Ally third-party origin field-validated end to end, including preservation of its foreign-only `amduw23e` package.
- Dirty ASUS → Lenovo installation without an intervening reboot also transitioned successfully to v4.0 / 26.8.1.
- Dual-catalog trust: exact original Microsoft WHCP `u0203304.cat` is registered alongside the locally signed merged catalog, with 14/14 target coverage required from both.
- The dual-catalog correction physically resolved the Gears 5 Direct3D/WARP regression and the observed Destiny 2 BattlEye AMD-UMD block from the earlier 26.8.1 build.
- Transaction-aware failure normalization and proof-derived rollback states prevent failed/unproven recovery from silently becoming a normal reinstall.
- Machine-wide v4.0 single-instance guard plus fail-closed detection of other registered Legion Go AMD resume workflows.
- Saved `Complete` state now reruns the entire 72-check Stage 4 audit read-only instead of blindly reporting completion.
- AMD defaults `ColorVibrance_ENABLE_DEF=1` and `ShowRSOverlay=true` remain intentionally preserved.

## Exact target identities

```text
DriverVersion:     32.0.31041.1004
Final INF SHA-256: F882C8E66D6EFC42AB9254D55E1B7DD7C3A23E772E854897C0EB9BFB1A214C42
Final DAT SHA-256: 83C3A9D7A3E524135FFCA89A3971A788670CDF14898C85FD504B2ED284C61953
Kernel SHA-256:    92A83D34ADB17A8C419A153B62E94E2CF3C478E260571AF6699574800AF3F3DF
Official CAT SHA:  23D62651554AA6AF3A9194457AC84B9881649E7C4E34BD7A0CBD51512A484A48
```

## Release asset

```text
LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip
SHA-256: 8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
Size: 154588 bytes
```

Required AMD source:

```text
whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe
SHA-256: 47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

## Platform

Officially validated: Windows 11 x64 on the original Legion Go / Legion Go 1 (`PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA`).

Windows 10 is not officially supported and is intentionally not hard-blocked. eGPU and other Legion Go variants remain unvalidated.
