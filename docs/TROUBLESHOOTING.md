# Troubleshooting

## First rule: stop at a hard failure

Do not repeatedly rerun a failed stage, manually delete workflow state, or manually remove staged `amduw23e` generations.

Preserve the generated parser transcript or failure-evidence folder/ZIP under Downloads and the visible console error.

## Parser gate closes immediately

Public Beta v3.1 runs an independent PowerShell parser gate before the main launcher. If it fails before launcher logging exists, it writes:

```text
LegionGo-AMD-26.7.1-Public-Beta-v3.1-Parser-Gate-YYYYMMDD-HHMMSS.txt
```

under Downloads and keeps the failure console open until Enter is pressed. Preserve that transcript and do not start the numbered scripts manually.

## Test Signing after a failure

Managed hard-failure recovery inspects the current boot policy. When required, it configures Test Signing and `nointegritychecks` OFF, removes resume authorization, and reboots without retrying the failed stage.

If the machine has rebooted after recovery, verify current state before attempting another public release or manual repair.

## Unknown or ambiguous starting driver

Public Beta v3.1 intentionally fails closed on arbitrary AMD display origins and multiple distinct applicable ExtensionId lineages. Do not bypass the origin classifier by manually editing state, metadata, or Driver Store contents.

v3.1 specifically corrects the v3.0 false failures caused by multiple generations of the same validated Lenovo-derived ExtensionId lineage or by historical extension `DriverVer` mismatch alone.

Supported origins are documented in `COMPATIBILITY.md`.

## AMD installer not found or rejected

Required source:

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

Leave it under your Downloads folder. A same-named but different file is not accepted.

## Secure Boot

Secure Boot must be disabled for this local-catalog signing architecture. Enabled or unknown Secure Boot state is a hard front gate.

## Final audit folder exists but ZIP does not

The final evidence directory is authoritative. Some runs may leave the complete audit directory without an automatically packaged ZIP. This does not by itself indicate audit failure; Stage 4 result status and `FailedChecks` remain authoritative.

## Should I use DDU?

DDU is not part of the documented Public Beta v3.1 workflow. Do not insert it into a normal upgrade/repair run unless a future documented recovery path explicitly calls for it.

## Code 43

Do not try to repair Code 43 by spoofing `ReleaseVersion`. Preserve evidence and restore a known-good package/state. Public Beta v3.1 deliberately avoids that older metadata workaround.
