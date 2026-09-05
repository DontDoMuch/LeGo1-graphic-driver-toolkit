# Support

## Supported release

**Public Beta v4.5 / AMD 26.8.1 is the current supported release.** Earlier releases remain historical publication records and may receive best-effort troubleshooting support, but new installs should use v4.5 unless a maintainer specifically requests an older build for regression work.

## Supported hardware

Only these exact v4.5 targets are supported:

```text
Legion Go 1 Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04

Legion Go S Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04

Legion Go 2 Z2 Extreme
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
```

Do not assume support from the marketing model name alone. Other revisions and variants remain unsupported until separately validated.

## Before opening an issue

- Stop at the first hard failure; do not repeatedly force the failed stage.
- Verify the v4.5 ZIP and required AMD installer hashes.
- Preserve the complete console output and generated final/failure evidence bundle or folder.
- Record the exact hardware ID, selected profile, Windows version/build, starting display-driver version/INF, Secure Boot state, and whether another graphics-driver project was previously used.
- If the failure mentions `amduw23e`, include the staged package inventory rather than manually deleting packages.
- State whether the run began from Microsoft Basic, Lenovo OEM, a previous public toolkit release, or a third-party AMD/ROG Ally-style graphics stack.
- Remove personal information, recovery keys, and private certificate material before sharing evidence.

Protected field-proven engine identifiers may still contain `Public-Beta-v4.0` in internal state/schema/log paths. Do not rename or delete those paths manually. Use the exact evidence/log locations printed by the launcher.

Final and failure evidence is also written under Downloads; v4.5 attempts to package it automatically as a ZIP.

## Platform

Windows 11 x64 is the officially validated platform. Windows 10 is not officially supported and is intentionally not hard-blocked.
