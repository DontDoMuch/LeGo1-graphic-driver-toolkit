# Installation

## Current release

Public Beta v4.0 targets AMD Adrenalin 26.8.1 on the original Lenovo Legion Go.

## Requirements

- Original Legion Go / Legion Go 1: `PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA`
- Windows 11 x64 (officially supported target)
- Administrator access
- AC power recommended
- Secure Boot disabled
- **BitLocker / Device Encryption recovery information preserved before changing Secure Boot**

Windows 10 is not officially supported by this project. The installer intentionally does not hard-block it, but such runs are unvalidated.

## Required downloads

1. `LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip`
2. AMD's official `whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe`

Toolkit ZIP SHA-256:

```text
8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07
```

AMD installer SHA-256:

```text
47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3
```

Keep the AMD installer somewhere under your Downloads folder. It is not included in the toolkit release asset.

## Recommended fail-closed verify, unblock, extract, and run

The block below verifies **both** downloaded files before launching anything. A hash mismatch throws and stops.

```powershell
$ErrorActionPreference = 'Stop'

$Downloads = "$env:USERPROFILE\Downloads"
$Zip = Join-Path $Downloads 'LegionGo-AMD-26.8.1-Public-Beta-v4.0.zip'
$ExpectedZip = '8AC6A3A0ADE321860D20C958B47053EBC4BEB27A94EB177E30EC59450EEA2B07'
$AmdName = 'whql-amd-software-adrenalin-edition-26.8.1-win11-b.exe'
$ExpectedAmd = '47272E13BD537C5796F1C760AF036D011B41684737BCDAF30B158D3BAB6740F3'
$Root = Join-Path $Downloads 'LegionGo-AMD-26.8.1-Public-Beta-v4.0'

if (-not (Test-Path -LiteralPath $Zip -PathType Leaf)) {
    throw "Toolkit ZIP not found: $Zip"
}

$ZipHash = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToUpperInvariant()
if ($ZipHash -ne $ExpectedZip) {
    throw "Toolkit ZIP hash mismatch. Expected=$ExpectedZip Actual=$ZipHash"
}
Write-Host '[PASS] Toolkit ZIP SHA256 verified.' -ForegroundColor Green

$AmdMatches = @(
    Get-ChildItem -LiteralPath $Downloads -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Name -ieq $AmdName }
)
if ($AmdMatches.Count -ne 1) {
    throw "Expected exactly one $AmdName under Downloads; found $($AmdMatches.Count)."
}

$AmdHash = (Get-FileHash -LiteralPath $AmdMatches[0].FullName -Algorithm SHA256).Hash.ToUpperInvariant()
if ($AmdHash -ne $ExpectedAmd) {
    throw "AMD installer hash mismatch. Expected=$ExpectedAmd Actual=$AmdHash"
}
Write-Host '[PASS] Official AMD 26.8.1 installer SHA256 verified.' -ForegroundColor Green

Unblock-File -LiteralPath $Zip
if (Test-Path -LiteralPath $Root) {
    Remove-Item -LiteralPath $Root -Recurse -Force
}
Expand-Archive -LiteralPath $Zip -DestinationPath $Downloads -Force
Get-ChildItem -LiteralPath $Root -Recurse -File | Unblock-File

$Launcher = Join-Path $Root 'Start-LegionGo-AMD-26.8.1.cmd'
if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
    throw "Launcher missing after extraction: $Launcher"
}

Write-Host '[PASS] Verified and extracted. Starting Public Beta v4.0.' -ForegroundColor Green
& $Launcher
```

## What the managed workflow does

The supported public workflow asks exactly two Y/N questions at the beginning. After both are accepted it automatically handles:

- independent package/parser preflight;
- lightweight dependency preparation;
- exact AMD source extraction and hashing;
- merged catalog build/signing;
- original Microsoft WHCP catalog preservation/registration;
- temporary Test Signing configuration;
- required reboot/resume boundaries;
- starting-origin classification and rollback export;
- hardware-scoped `amduw23e` ownership so foreign non-Go extensions are preserved;
- exact 26.8.1 target binding;
- return to normal boot-signing policy;
- matching AMD Software / DVR installation;
- final 72-check persistence audit.

## Failure and retry behavior

Public Beta v4.0 does not automatically retry a failed destructive stage.

The launcher uses transaction-aware recovery checkpoints. Pre-destructive failures return through the managed Test Signing preparation path, interrupted/in-progress driver transactions enter explicit rollback recovery, and any rollback that is not proven remains recovery-only instead of becoming a normal reinstall attempt.

Do not manually run numbered stages or edit workflow state to force progress.

## Existing Complete installation

If the saved workflow is already `Complete`, rerunning the public launcher performs the full Stage 4 audit **read-only**. It reports live-system drift but does not automatically repair or reinstall the driver.

## Success

A complete installation ends with:

```text
Stage 2: Passed
Stage 3: Passed
Stage 4: Passed
FailedChecks: 0
Workflow Stage: Complete
Test Signing: OFF
nointegritychecks: OFF
```
