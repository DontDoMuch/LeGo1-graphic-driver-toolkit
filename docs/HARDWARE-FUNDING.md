# Hardware Testing Tracker

Public Beta v4.5.1 has three exact released hardware profiles. A marketing-family name alone is not enough to establish support.

A device is not supported unless its status explicitly says **Released** and its exact hardware ID is documented.

## Status definitions

| Status | Meaning |
|---|---|
| Proposed | Community interest recorded; no active acquisition/test plan |
| Funding | Funds are being collected toward access to the exact device |
| Acquired | Exact device is physically available for testing |
| Research | OEM packages, hardware IDs, recovery, and driver behavior are being analyzed |
| Validation | The workflow is undergoing full reboot-to-reboot validation |
| Released | Exact device profile passed the complete final audit and is included in a public release |
| Paused | Work cannot currently continue |
| Not feasible | Safe or maintainable public support was not practical |

## Released hardware

| Device | Exact HWID | Status | Validation note |
|---|---|---|---|
| Legion Go 1 Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04` | Released | Current in v4.5.1; v4.5 physical baseline 78/78 |
| Legion Go S Z1 Extreme | `PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04` | Released | Current in v4.5.1; v4.5 volunteer baseline 81/81 |
| Legion Go 2 Z2 Extreme | `PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5` | Released | Current in v4.5.1; v4.5 volunteer baseline 79/79 |

Private volunteer packages and evidence remain private; only the validated profile/engine results are represented in the public release.

## Not currently released

Examples include non-Extreme Go 1 variants, non-Z1-Extreme Go S variants, Go 2 AI Extreme, and other Go 2 revisions. Go 2 `REV_C4` is explicitly rejected by the v4.5.1 public resolver fixture.

Ryzen Z1/Z2 branding alone does not prove shared device IDs, OEM extensions, firmware behavior, metadata, power controls, sensors, or recovery requirements. Each exact model/revision requires separate analysis and physical validation.

## Funding boundary

Donations can fund access to hardware and testing resources. They do not guarantee support, a successful technical result, or a release date.
