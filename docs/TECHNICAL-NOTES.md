# Technical Notes

## Design goal

The toolkit reproduces a narrowly validated AMD 26.6.2 stack for the original Lenovo Legion Go without distributing AMD binaries and without replacing the Lenovo integration layer that supports device-specific behavior.

It is intentionally fail-closed: expected hardware IDs, package identities, hashes, signatures, signer trust, driver versions, reboot boundaries, and live system state must agree.

## Source model

The user supplies the exact official AMD 26.6.2 Windows 11 `-c` installer. Scripts 1 and 3 independently verify it before extracting required source material.

The project repository contains only original PowerShell and documentation.

## Corrected display package

Script 1 reconstructs the validated corrected 125-file package and produces a corrected INF for the original Legion Go hardware identity. The package is cataloged and signed with a locally generated per-installation certificate.

Temporary Test Signing allows Windows to install and bind that locally catalog-signed package. Script 2 then disables Test Signing and verifies the post-reboot state.

## Two catalog roles

The workflow validates two distinct catalog roles:

1. The locally signed corrected-driver catalog authenticates the modified package and exact file set.
2. AMD's official Microsoft-signed catalog is registered and used to verify the loaded AMD kernel binary under Windows kernel policy.

Scripts 2 and 4 verify that the official catalog remains registered in CatRoot and validates the loaded kernel.

## Lenovo integration retained

The validated final stack intentionally retains:

- Lenovo display extension `32.0.23017.1001`
- AMDUWP `32.2530.0.0`
- Lenovo-compatible CN metadata `25.30.17.01 / 32.0.23017.1001`
- Stable Lenovo ReleaseVersion values on active targets

The toolkit does not treat the AMD display driver as the only component of the device graphics stack.

## AMD Software model

Script 3 extracts and verifies the native AMD Settings `.2099` MSI from the exact AMD installer, installs native CNext and RSXCM `22.10.0.0`, and retires conflicting legacy `.2089` MSI/AppX state.

The validated state is Store-free:

- Native `.2099` dashboard
- Native packaged context-menu handler
- Legacy `.2089` package absent and unprovisioned
- Exactly one desktop context-menu entry
- No Microsoft Store dependency

## Safe shell refresh

Script 3 uses `SHChangeNotify` to refresh shell associations. It does not terminate Explorer and does not force-close applications during restart.

## State and idempotency

State files are stored under `C:\ProgramData\LegionGo-AMD-26.6.2`.

Saved JSON is never sufficient by itself to skip critical work. Public Scripts 2 and 3 compare saved results with live driver, kernel, software, package, metadata, boot, and signing state.

## Final audit

Script 4 is read-only. It checks the complete handoff after the Script 3 reboot, including driver, INF, kernel, GPU health, local and official catalogs, registered CatRoot catalog verification, Lenovo extension and AMDUWP, native MSI/CNext/RSXCM, legacy AppX absence, Lenovo metadata, DxDiag, event logs, and visible dashboard/context menu.

It atomically writes the final JSON state and desktop report.
