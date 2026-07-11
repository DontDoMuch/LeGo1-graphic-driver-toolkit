# Troubleshooting

## Stop at the first failure

Do not skip ahead, delete state, run a later script, use DDU, or manually replace packages. Preserve the first failed check and terminating error.

## Confirm the release

Use Public Beta v2.0 and verify the ZIP and script hashes in [Verification](VERIFICATION.md). Edited scripts are outside the validated release contract.

## Hardware rejection

The toolkit supports only:

```text
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA
```

A different subsystem ID is a hard stop.

## Starting stack rejected

Public Beta v2.0 accepts multiple healthy starting versions, but it still requires a healthy active GPU and a compatible Lenovo extension attached to that exact live GPU instance. A stale package merely present in the Driver Store does not qualify.

## AMD installer rejected

The installer must be AMD-signed, report version `26.6.4.0`, extract successfully, and contain the exact target dependencies. Renaming another AMD release cannot make it compatible.

## Missing prerequisites

Script 1 requires PowerShell 7.4 or newer, 7-Zip, and a functional paired x86 Inf2Cat and x64 SignTool installation. The listed SDK/WDK packages are fallback installers, not the only acceptable kit build.

## Secure Boot and Test Signing

Secure Boot may need to be disabled manually in UEFI before temporary Test Signing can activate. Do not toggle Test Signing yourself between runs. Script 2 must turn it off and verify the next normal-signing boot.

## Script 3 software failure

Do not manually reinstall legacy `.2089` MSI or Store AppX packages. Preserve the Script 3 output and logs.

## Final audit failure

Script 4 is read-only and does not repair drift. Its failed check identifies the state that did not persist.

Useful locations:

```text
C:\ProgramData\LegionGo-AMD-26.6.4\Logs
C:\ProgramData\LegionGo-AMD-26.6.4\final-audit-result.json
C:\Users\<YOUR USERNAME>\Desktop\LegionGo-AMD-26.6.4-Final-Report.txt
```
