# Legion Go AMD 26.6.2 Toolkit

A community-built, hardware-gated PowerShell workflow for installing the AMD Software: Adrenalin Edition 26.6.2 display stack on the **original Lenovo Legion Go** while retaining the validated Lenovo integration layer.

> [!WARNING]
> This is **Public Beta v1.1**, not a universal AMD driver installer. It modifies the display-driver package, Drier Store, certificate trust, catalog registration, AppX state, AMD Software, compatibility metadata, and temporary Windows Test Signing configuration. Read the complete installation guide and back up important data before starting.

## Project status

Public Beta v1.1 completed a full fresh-OEM, end-to-end installation and post-restart persistence test on an original Legion Go on **July 8, 2026**.

The validated final state included:

- AMD display driver `32.0.31021.1015`
- Healthy GPU status with problem code `0`
- Test Signing disabled after installation
- AMD's official Microsoft-signed catalog registered and verified
- Lenovo display extension `32.0.23017.1001`
- AMDUWP `32.2530.0.0`
- Native AMD Software `.2099`
- Native RSXCM `22.10.0.0`
- Legacy `.2089` MSI/AppX state absent
- Normal AMD Software dashboard
- Exactly one desktop context-menu entry
- No Microsoft Store dependency
- Zero relevant GPU or Code Integrity errors in the final audit

Validation on one device does not guarantee the same result on every Windows installation.

## Supported target

Public Beta v1.1 is intentionally restricted to:

- Original Lenovo Legion Go
- GPU hardware identity `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA`
- 64-bit Windows 11 build 22000 or newer
- Validated Lenovo OEM display-driver baseline `32.0.23017.1001`
- At least 12 GB free space
- The exact official AMD 26.6.2 Windows 11 `-c` installer

Do not use this toolkit on another Legion model, another AMD device, or a different GPU hardware identity.

## AMD installer is not included

This repository does **not** host or redistribute AMD's installer or AMD binaries. Users must obtain the exact installer from an official AMD source:

```text
whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe
Size:   1,630,707,976 bytes
SHA-256:
3FD0073C74E0D043558087511F5624ED42D1241E852C2A9ED5AC5C80F158F893

You can grab the installer from the official AMD webpage here https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-6-2.html
```

Scripts 1 and 3 independently verify the installer's filename, size, SHA-256, and digital signature.

## Start here

1. Download the `Public Beta v1.1` release asset.
2. Verify its SHA-256: `CF315CB840D2AD914405B312965F01C6F643BE1AF2D06912B1941834C2F82413`.
3. Extract it to `C:\Users\<YOUR USERNAME>\Downloads\LeGo-toolkit`.
4. Place the exact AMD installer beside the four scripts.
5. Read `Instructions.txt` completely.
6. Run the scripts in numbered order from an elevated Windows PowerShell 5.1 window.

Full guide: [Installation](docs/INSTALLATION.md)

## Four-script workflow

| Script | Purpose |
|---|---|
| `01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1` | Validate the platform and source, reproduce the corrected driver package, sign its catalog, and prepare temporary Test Signing |
| `02-Install-Driver-And-Verify-Normal-Signing.ps1` | Install and bind the corrected driver, register the official AMD catalog, disable Test Signing, and verify persistence after reboot |
| `03-Install-AMD-Software-And-Reboot.ps1` | Install native AMD Software `.2099`, native RSXCM, retire legacy `.2089` state, and verify post-restart persistence |
| `04-Final-Persistence-Audit.ps1` | Perform the final read-only driver, catalog, software, AppX, metadata, event-log, and visual audit |

With Secure Boot already disabled, the validated path normally uses seven script launches and three Windows restarts. If Secure Boot is initially enabled, Script 1 may add a UEFI restart and one additional Script 1 run.

## Frozen release files

The exact Public Beta v1.1 sources are preserved under [`releases/Public-Beta-v1.1`](releases/Public-Beta-v1.1/).

Release files are immutable. Proposed changes should target a future version rather than silently modifying v1.1.


## Help fund testing on more handhelds

Public Beta v1.1 was developed and validated on hardware personally available
to the project. Expanding support to another Ryzen Z1 Extreme handheld requires
access to that exact device for package analysis, recovery testing, repeated
reboots, and a complete end-to-end validation run.

Donations can help fund:

- Additional handhelds for dedicated testing
- Storage, adapters, replacement parts, and recovery media
- Shipping and other direct hardware-testing expenses
- Continued driver research and validation work

A donation does **not** purchase support for a device, guarantee compatibility,
establish a release date, or create priority access. A model will be described
as supported only after the complete workflow has passed on that exact
hardware.

Devices acquired with project funds remain available as project test hardware
so later driver releases and regressions can be evaluated on them.

See [Funding and donations](FUNDING.md) and the
[hardware funding tracker](docs/HARDWARE-FUNDING.md).

**Support hardware testing on Ko-fi:**
[ko-fi.com/dontdomuch](https://ko-fi.com/dontdomuch)

GitHub also displays this Ko-fi page through the repository's **Sponsor**
button.

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Verification and hashes](docs/VERIFICATION.md)
- [Technical notes](docs/TECHNICAL-NOTES.md)
- [Frequently asked questions](docs/FAQ.md)
- [Support policy](SUPPORT.md)
- [Security policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## Important operating rules

- Do not use DDU as part of this procedure.
- Do not skip scripts or advance before the current script reports readiness for the next one.
- Do not manually replace the INF, MSI, AppX, catalog, or certificate.
- Do not delete workflow state merely to force a rerun.
- Do not use the script right-click action **Run with PowerShell**.
- Keep the device connected to AC power.
- Preserve BitLocker or Device Encryption recovery information before changing Secure Boot or boot configuration.

## Independence and trademarks

This is an independent community project. It is not produced, endorsed, or supported by Lenovo, AMD, Microsoft, or GitHub.

Lenovo, Legion, AMD, Radeon, Microsoft, Windows, PowerShell, and GitHub are trademarks of their respective owners. See [Third-party notices](THIRD-PARTY-NOTICES.md).

## License

Original project code and documentation are released under the [MIT License](LICENSE). That license does not grant rights to third-party software, drivers, installers, trademarks, or other proprietary material.
