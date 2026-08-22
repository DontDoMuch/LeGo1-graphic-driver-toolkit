# Troubleshooting

## First rule: stop at a hard failure

Do not repeatedly rerun a failed stage or manually delete workflow state.

Preserve the generated failure-evidence folder/ZIP under Downloads and the
visible console error.

## Test Signing after a failure

Managed hard-failure recovery inspects the current boot policy. When required,
it configures Test Signing and `nointegritychecks` OFF, removes resume
authorization, and reboots without retrying the failed stage.

If the machine has rebooted after recovery, verify current state before
attempting another release candidate or manual repair.

## Unknown starting driver

Public Beta v3.0 intentionally fails closed on arbitrary AMD display origins.
Do not bypass the origin classifier by manually editing state or metadata.

Supported origins are documented in `COMPATIBILITY.md`.

## AMD installer not found or rejected

Required source:

```text
whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe
SHA-256: 116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D
```

Leave it under your Downloads folder. A same-named but different file is not
accepted.

## Secure Boot

Secure Boot must be disabled for this local-catalog signing architecture.
Enabled or unknown Secure Boot state is a hard front gate.

## Final audit folder exists but ZIP does not

The final evidence directory is authoritative. Some runs may leave the
complete audit directory without an automatically packaged ZIP. This does not
by itself indicate audit failure; Stage 4 result status and `FailedChecks`
remain authoritative.

## Should I use DDU?

DDU is not part of the documented Public Beta v3.0 workflow. Do not insert it
into a normal upgrade/repair run unless a future documented recovery path
explicitly calls for it.

## Code 43

Do not try to repair Code 43 by spoofing `ReleaseVersion`. Preserve evidence
and restore a known-good package/state. Public Beta v3.0 deliberately avoids
that older metadata workaround.
