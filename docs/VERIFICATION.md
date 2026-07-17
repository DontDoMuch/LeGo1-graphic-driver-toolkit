# Verification

## Public Beta v2.1 release asset

```text
LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip
SHA-256:
DE3A7FD534BB136881D8685F17AD5F7FD3CCDC46597487465D0966C2A365038C
```

```powershell
Get-FileHash ".\LegionGo-AMD-26.6.4-Public-Beta-v2.1.zip" -Algorithm SHA256
```

The ZIP contains exactly one `LeGo-toolkit` root folder with four scripts, `Instructions.txt`, and `SHA256SUMS.txt`.

## Public Beta v2.1 file hashes

| File | SHA-256 |
|---|---|
| `01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1` | `A2122D471B99FDAF680935BB724792BA06D9337204BEFA59499685CB3178854B` |
| `02-Install-Driver-And-Verify-Normal-Signing.ps1` | `86615E66A6B95FB25A6869F86B00D875A28F791514F7B7B0EA3EA28BD6AD5002` |
| `03-Install-AMD-Software-And-Reboot.ps1` | `9614C68902C64E08D4746EC9842D5A26AB5D227CC5FDA00713E0966A3195D83C` |
| `04-Final-Persistence-Audit.ps1` | `8377151D2D618258AE3E3F9B69AC893B0F9DE875A0F9250479C8EBA41C726F5B` |
| `Instructions.txt` | `04CADD2E26F64DAF690E3460F7F60E44731A4B3654CD4BDAB4D59B0F1AEDA3A0` |
| `SHA256SUMS.txt` | `0A1F72D83AF8EE28D7D542DA3C1B052A5DD4DEA07A11E79A54DE3938E1C7DDA7` |

Verify the release files from inside `LeGo-toolkit`:

```powershell
Get-FileHash .\*.ps1, .\Instructions.txt, .\SHA256SUMS.txt -Algorithm SHA256
```

`SHA256SUMS.txt` lists the four scripts and `Instructions.txt`. Its own hash is documented above.

## AMD installer reference

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
Size: 890,946,264 bytes
SHA-256:
E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
File/Product version: 26.6.4.0
Signer: Advanced Micro Devices
```

Public Beta v2.1 also verifies the AMD signature, reported version, extraction result, and exact target payload.

## Expected installed identities

| Item | Expected value |
|---|---|
| Display driver | `32.0.31021.5001` |
| Corrected INF SHA-256 | `73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034` |
| `amdkmdag.sys` SHA-256 | `3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F` |
| Official AMD catalog SHA-256 | `F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C` |
| Native RSXCM | `22.10.0.0` |

The locally generated catalog and certificate hashes are unique per installation and must match the state recorded by Script 1.

## Final verification

Script 4 is the authoritative installed-state audit. Success requires:

```text
SCRIPT 4 PASS: True
Failed checks: 0
TOOLKIT COMPLETE: True
```

## Historical Public Beta v2.0 asset

Public Beta v2.0 is superseded. Its historical release asset was:

```text
LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip
Size: 133,793 bytes
SHA-256: D2DA30DD76B9460C14D96FB09824D727D13B7D24BA327263E6FAA8ACC751CBD4
```

Do not use v2.0 for a new installation.
