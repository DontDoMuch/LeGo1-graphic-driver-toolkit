# Support

## Supported release

**Public Beta v4.0 / AMD 26.8.1 is the current supported release.** Earlier releases are retained as historical publication records and may receive best-effort troubleshooting support, but new installs should use v4.0 unless a maintainer specifically requests an older build for regression testing.

## Before opening an issue

- Stop at the first hard failure; do not repeatedly force the failed stage.
- Verify the release ZIP and required AMD installer hashes.
- Preserve the complete console output and generated failure-evidence bundle/folder.
- Record Windows version/build, starting display driver version/INF, Secure Boot state, and whether the system had been modified by another graphics-driver project.
- If the failure mentions `amduw23e`, include the staged package inventory rather than manually deleting packages.
- State whether the run began from Microsoft Basic, Lenovo OEM, a previous public toolkit release, or a third-party AMD graphics stack.
- Remove personal information, recovery keys, and private certificate material before sharing evidence.

Managed logs are stored under:

```text
C:\ProgramData\LegionGo-AMD-26.8.1-Public-Beta-v4.0\Logs
```

Final and failure evidence is also written under Downloads.

## Scope

The supported hardware target is the original Legion Go / Legion Go 1:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

Windows 11 is the officially validated platform. Windows 10 is not officially supported and is intentionally not hard-blocked. eGPU and other Legion Go variants remain unvalidated.
