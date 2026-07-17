# Validation

The final Public Beta v2.1 artifact completed end-to-end validation on the original Lenovo Legion Go on July 17, 2026.

## Validated regression paths

| Starting state | Target | Result |
|---|---|---|
| Fresh Lenovo OEM graphics installation | Public Beta v2.1 / AMD 26.6.4 | Passed |
| Fresh Lenovo OEM → Public Beta v1.1 / AMD 26.6.2 | Public Beta v2.1 / AMD 26.6.4 | Passed |

## Final installed state

| Check | Result |
|---|---|
| Script 4 | `PASS` |
| Failed checks | `0` |
| Toolkit complete | `True` |
| GPU status | `OK`, problem code `0` |
| Display driver | `32.0.31021.5001` |
| Corrected INF SHA-256 | `73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034` |
| Loaded `amdkmdag.sys` SHA-256 | `3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F` |
| Lenovo extension | Compatible and preserved |
| AMDUWP | Healthy and Microsoft hardware-signed |
| AMD Software | Native `.2099` |
| RSXCM | Native `22.10.0.0` |
| Legacy `.2089` state | Absent system-wide |
| Microsoft Store dependency | None |
| Test Signing after installation | Off |
| Relevant GPU or Code Integrity errors since boot | `0` |

Validation on one physical device and the documented starting states does not guarantee identical behavior on every Windows installation. The scripts remain fail-closed when the live state does not meet the release contract.
