# Installation

## Current release

Public Beta v5.0 targets AMD Adrenalin 26.9.2 on three exact Lenovo Legion Go hardware profiles. The installer resolves the profile automatically from the physical hardware ID; there is no manual profile override.

Public Beta v5.0 uses the `Public-Beta-v5.0` runner/workflow namespace. The entry gate forwards optional source paths only when non-empty.

## Requirements

One of these exact supported targets:

```text
Legion Go 1 Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04

Legion Go S Z1 Extreme
PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04

Legion Go 2 Z2 Extreme
PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5
```

Also required:

- Windows 11 x64 (officially supported target)
- Administrator access
- AC power recommended
- Secure Boot disabled
- **BitLocker / Device Encryption recovery information preserved before changing Secure Boot**

Windows 10 is not officially supported. The installer intentionally does not hard-block it, but such runs are unvalidated.

## Required downloads

1. `LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip`
2. AMD's official `whql-amd-software-adrenalin-edition-26.9.2-win11-c.exe`

Toolkit ZIP identity:

```text
SHA-256: 4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E
Size: 135755 bytes
```

AMD installer SHA-256:

```text
72E368AE264F36E89CA0FE1DAB1CAD926047C2D6B0A3EFED9745D8D99780FE58
```

Keep one exact AMD installer somewhere under Downloads. It is not included in the toolkit release asset.

## Existing graphics driver

You do not need to restore Lenovo OEM graphics first if the current AMD Display stack is healthy and structurally classifiable. The workflow can preserve a third-party AMD Display package as rollback material. ROG Ally-origin migration is field-proven on Go 1.

Unhealthy, unreadable, or ambiguous selected-profile states fail closed before destructive transition.

## Recommended fail-closed verify, unblock, extract, and run

Open **Windows PowerShell 5.1** (`powershell.exe`), not PowerShell 7 / `pwsh`, and run:

```powershell
$ErrorActionPreference = 'Stop'

$Downloads = Join-Path $env:USERPROFILE 'Downloads'
$Zip = Join-Path $Downloads 'LegionGo-AMD-26.9.2-Public-Beta-v5.0.zip'
$ExpectedZip = '4CB55F1EC556E9EEAE37E0BE37167D2352505A172D19BFF601D1F9ABA9EA9E7E'
$AmdName = 'whql-amd-software-adrenalin-edition-26.9.2-win11-c.exe'
$ExpectedAmd = '72E368AE264F36E89CA0FE1DAB1CAD926047C2D6B0A3EFED9745D8D99780FE58'
$Root = Join-Path $Downloads 'LegionGo-AMD-26.9.2-Public-Beta-v5.0'

function Get-SHA256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file not found: $Path"
    }

    $Sha = [Security.Cryptography.SHA256]::Create()
    $Stream = $null
    try {
        $Stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        return ([BitConverter]::ToString($Sha.ComputeHash($Stream))).Replace('-','').ToUpperInvariant()
    }
    finally {
        if ($null -ne $Stream) { $Stream.Dispose() }
        $Sha.Dispose()
    }
}

$ActualZip = Get-SHA256Hex -Path $Zip
if ($ActualZip -cne $ExpectedZip) {
    throw "Toolkit ZIP SHA256 mismatch.`nExpected: $ExpectedZip`nActual:   $ActualZip"
}
Write-Host '[PASS] Toolkit ZIP SHA256 verified.' -ForegroundColor Green

$AmdMatches = @(
    Get-ChildItem -LiteralPath $Downloads -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Name -ieq $AmdName }
)
if ($AmdMatches.Count -ne 1) {
    throw "Expected exactly one $AmdName under Downloads; found $($AmdMatches.Count)."
}

$ActualAmd = Get-SHA256Hex -Path $AmdMatches[0].FullName
if ($ActualAmd -cne $ExpectedAmd) {
    throw "AMD installer SHA256 mismatch.`nExpected: $ExpectedAmd`nActual:   $ActualAmd"
}
Write-Host '[PASS] Official AMD 26.9.2 installer SHA256 verified.' -ForegroundColor Green

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
}
catch {
    if (-not ('System.IO.Compression.ZipFile' -as [type])) { throw }
}

if (Test-Path -LiteralPath $Root) {
    Remove-Item -LiteralPath $Root -Recurse -Force
}

[IO.Compression.ZipFile]::ExtractToDirectory($Zip,$Root)

$Unblock = Get-Command Unblock-File -ErrorAction SilentlyContinue
if ($null -ne $Unblock) {
    Unblock-File -LiteralPath $Zip
    Unblock-File -LiteralPath $AmdMatches[0].FullName
    Get-ChildItem -LiteralPath $Root -Recurse -File | Unblock-File
}

$Launcher = Join-Path $Root 'Start-LegionGo-AMD-26.9.2.cmd'
if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
    throw "Launcher missing after extraction: $Launcher"
}

Write-Host '[PASS] Verified and extracted. Starting Public Beta v5.0.' -ForegroundColor Green
& $Launcher
```

## Windows PowerShell 5.1 launch environment

The shipped `Start-LegionGo-AMD-26.9.2.cmd` explicitly starts Windows PowerShell 5.1 with `-NoProfile` and invokes `Run-Validated-LegionGo-AMD-26.9.2-Public-Beta-v5.0.ps1`.

For the supported path, launch the CMD from **File Explorer**, **Command Prompt**, or a clean Windows PowerShell 5.1 session. Avoid launching it from inside `pwsh` / PowerShell 7.

The exact v5.0 asset does not sanitize inherited `PSModulePath`. If Windows PowerShell 5.1 fails while resolving a PowerShell module after being launched from PowerShell 7, close the PowerShell 7 parent and relaunch from Explorer/Command Prompt or a fresh Windows PowerShell 5.1 context.

## What the managed workflow does

After the independent entry gate resolves the exact supported profile and both initial confirmations are accepted, the workflow handles:

- package/parser/public-scope preflight;
- exact profile selection and fingerprint persistence;
- dependency preparation;
- exact AMD 26.9.2 source extraction and hashing;
- deterministic profile-specific INF/DAT construction;
- merged catalog build/signing plus original Microsoft WHCP catalog preservation/registration;
- temporary Test Signing configuration;
- required reboot/resume boundaries;
- selected-profile origin classification and rollback export;
- selected-profile `amduw23e` ownership while preserving proven foreign extensions;
- exact target binding;
- return to normal boot-signing policy;
- matching AMD Software / DVR installation;
- profile-aware final persistence audit;
- final/failure evidence packaging.

## Expected final audit count

```text
Legion Go 1 Z1 Extreme: 78/78
Legion Go S Z1 Extreme: 81/81
Legion Go 2 Z2 Extreme: 79/79
```

A successful run also requires `FailedChecks = 0`, `Warnings = 0`, GPU problem code `0`, Test Signing OFF, `nointegritychecks` OFF, and workflow Stage `Complete`.

## Failure and retry behavior

Public Beta v5.0 does not automatically retry a failed destructive stage. Do not manually run numbered stages or edit workflow state to force progress.

Preserve returned evidence. Unproven rollback remains recovery-only rather than silently becoming another install attempt.

## Existing Complete installation

If the saved workflow is already `Complete`, rerunning the public launcher performs the selected-profile Stage 4 audit read-only. It reports live-system drift but does not automatically repair or reinstall the driver.
