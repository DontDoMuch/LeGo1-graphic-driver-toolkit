# Compatibility

## Supported hardware

The toolkit supports only the original Lenovo Legion Go / Legion Go 1 with this GPU identity:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

A different Legion model, subsystem ID, or AMD device is outside the supported contract.

## What became more compatible in Public Beta v2.0

Public Beta v2.0 validates required characteristics instead of assuming one exact host configuration:

- The active starting display stack may use different healthy driver versions and INF names.
- The Lenovo extension may vary in version and file hash when it remains Microsoft hardware-signed, targets the correct GPU, carries the required extension identity and directives, and is actually attached to the active GPU instance.
- AMDUWP may vary when it remains Microsoft hardware-signed, healthy, and structurally compatible.
- The outer AMD 26.6.4 installer may vary in filename, size, and hash when it is AMD-signed, reports the required version, and extraction proves the exact validated target dependencies.
- The Windows SDK/WDK version may vary when a functional paired x86 Inf2Cat and x64 SignTool installation is available.

## What remains exact

Compatibility is not the removal of safety checks. Public Beta v2.0 still requires:

- The Legion Go 1 hardware identity.
- Windows 11 x64 build 22000 or newer.
- A healthy live GPU state.
- Valid Microsoft and AMD signatures where required.
- The exact AMD 26.6.4 target payload used by this release.
- Exact rebuilt INF and kernel identities.
- Exact canonical package dependencies and output contracts.
- A coherent saved-to-live state handoff across every restart.
- Test Signing off before completion.
- A passing final read-only audit.

## Future AMD versions

The repository itself is not tied to AMD 26.6.4. A future public release can target a later AMD package without renaming the project. That future target must still be inspected, adapted, and validated before it can be claimed as supported.
