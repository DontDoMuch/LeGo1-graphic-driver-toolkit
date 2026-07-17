# Compatibility

## Supported hardware

The toolkit supports only the original Lenovo Legion Go / Legion Go 1 with this GPU identity:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

A different Legion model, subsystem ID, or AMD device is outside the supported contract.

## Supported starting states in Public Beta v2.1

Public Beta v2.1 supports these starting states:

- Fresh Lenovo OEM graphics installation on the original Lenovo Legion Go.
- A validated Public Beta v1.1 / AMD 26.6.2 toolkit installation.
- An existing validated AMD 26.6.4 toolkit installation for repair or idempotent reruns.

The final v2.1 artifact completed end-to-end regression testing through the first two paths on July 17, 2026.

## Compatibility validation

Public Beta v2.1 validates required characteristics instead of assuming one exact host configuration:

- The active starting display stack may use different healthy driver versions and published INF names when the state meets the release contract.
- The Lenovo extension may vary in version and file hash when it remains Microsoft hardware-signed, targets the correct GPU, carries the required extension identity and directives, and is attached to the active GPU instance.
- AMDUWP may vary when it remains Microsoft hardware-signed, healthy, and structurally compatible.
- A functional paired x86 Inf2Cat and x64 SignTool installation is accepted by capability rather than one required Windows Kit version.

## AMD source contract

The supported reference installer is:

```text
whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe
SHA-256: E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29
```

The toolkit also verifies the AMD signature, reported version, extraction behavior, and exact target payload. Renaming or substituting a different AMD release does not make it compatible.

## What remains exact

Compatibility is not the removal of safety checks. Public Beta v2.1 still requires:

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
