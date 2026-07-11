# Verification

## Public Beta v2.0 release asset

```text
LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip
Size: 133,793 bytes
SHA-256:
D2DA30DD76B9460C14D96FB09824D727D13B7D24BA327263E6FAA8ACC751CBD4
```

```powershell
Get-FileHash ".\LegionGo1-Graphics-Driver-Toolkit-Public-Beta-v2.0.zip" -Algorithm SHA256
```

The ZIP contains exactly one `LeGo-toolkit` root folder with four scripts and `Instructions.txt`.

## Public Beta v2.0 file hashes

| File | SHA-256 |
|---|---|
| `01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1` | `C70BA0B4AEEF103AD46D163FEDCC137C68FF327331CEC9AE172F215C30937E2F` |
| `02-Install-Driver-And-Verify-Normal-Signing.ps1` | `C0C16CB4285BD69CD9EF0B23A54E551F903511A197DA364F7973EB458ED45174` |
| `03-Install-AMD-Software-And-Reboot.ps1` | `A8CDAC8CD6639F0572DA56D6B08EFD7650D86895C8C3569BDFC00D797EBDEB5A` |
| `04-Final-Persistence-Audit.ps1` | `8377151D2D618258AE3E3F9B69AC893B0F9DE875A0F9250479C8EBA41C726F5B` |
| `Instructions.txt` | `19BEA25563356048BD2F3F6BB01F5D90EB9FAF9A80D25D6D1AFB9FD76CEABE88` |


Verify the scripts:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\LeGo-toolkit\*.ps1" -Algorithm SHA256
```

## AMD installer reference

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
Size: 890,946,264 bytes
SHA-256:
E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
```

Public Beta v2.0 also verifies the AMD signature, file/product version, and exact extracted target payload.

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
