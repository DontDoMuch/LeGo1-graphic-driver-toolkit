# Hardware Funding and Validation Tracker

This page tracks hardware considered for future hands-on support.

Public Beta v1.0 supports only the original Lenovo Legion Go configuration
documented in the repository. A device listed below is **not supported**
unless its status explicitly says `Released`.

## Status definitions

| Status | Meaning |
|---|---|
| Proposed | Community interest has been recorded, but no funding target is active |
| Funding | The project is collecting toward acquiring the device |
| Acquired | The exact device is physically available for testing |
| Research | OEM packages, hardware IDs, recovery options, and driver behavior are being analyzed |
| Validation | A candidate workflow is undergoing full reboot-to-reboot testing |
| Released | A device-specific public workflow completed the required validation |
| Paused | Work cannot currently continue |
| Not feasible | Testing found that a safe or maintainable public workflow is not practical |

## Current targets

No additional device target has been formally selected yet.

| Device | Status | Approximate goal | Acquired | Current note |
|---|---:|---:|---:|---|
| To be announced | Proposed | — | No | Donation platform and first target still need to be selected |

## How a device moves toward support

1. Confirm the exact model, GPU hardware identity, OEM graphics package,
   recovery path, and available source installer.
2. Acquire the physical device.
3. Capture a complete untouched OEM baseline.
4. Analyze device-specific INF, extension, AppX, firmware, and metadata
   dependencies.
5. Develop a device-specific candidate without weakening hardware gates.
6. Test interruption, rerun, recovery, and reboot boundaries.
7. Complete a fresh-OEM end-to-end run.
8. Publish support only after the final persistence audit passes.

## Important limitation

Ryzen Z1 Extreme branding alone does not prove that two handhelds use the
same device IDs, OEM extensions, firmware behavior, package metadata, power
controls, sensors, or recovery requirements. Each model must be treated as
a separate hardware target until testing proves otherwise.

## Suggesting a target

Use a GitHub discussion or feature request after those channels are
enabled. Include the exact model name, regional variant, OEM driver
package, GPU hardware ID when available, and why the device has meaningful
community demand.

Do not describe a proposed, funded, or acquired device as supported before
the tracker reaches `Released`.
