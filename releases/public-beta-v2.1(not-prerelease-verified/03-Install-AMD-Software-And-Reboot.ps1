#requires -Version 5.1
<#
.SYNOPSIS
    Script 3 of the Legion Go 1 Graphics Driver Toolkit Public Beta v2.0 workflow.

.DESCRIPTION
    Installs and validates the exact native AMD Software .2099 arrangement
    without requiring Microsoft Store or the legacy .2089 AMD Software AppX
    package.

    Required files:
      - this PowerShell script; and
      - the same AMD-signed 26.6.4 installer container recorded by Script 1.

    The script revalidates that recorded container, extracts and verifies the
    exact native CNext MSI, installs or
    repairs native AMD Software .2099 when needed, validates native RSXCM
    22.10.0.0, retires the conflicting legacy .2089 MSI and Store AppX state,
    restores Lenovo-compatible metadata, refreshes the shell without
    terminating Explorer, opens the native dashboard for confirmation, and
    prepares the post-restart handoff to Script 4.

    The script never contacts Microsoft Store. It does not require the legacy
    .2089 installer, legacy .2089 AppX/MSIX, or any external toolkit asset
    folder.

    Script 3 can modify installed AMD Software, AppX registration and
    provisioning, AMD/Lenovo compatibility metadata, the current user's AMD
    CN cache, and the current user's shell-extension block list. It requires
    explicit approval before those changes and before restarting Windows.

.NOTES
    Public Beta v2.0. Includes live-state stale-result protection, safe
    shell refresh, explicit install and restart confirmations, non-forced
    restart behavior, and compatibility-aware source validation.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WorkflowRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'
$StatePath = Join-Path $WorkflowRoot 'workflow-state.json'
$PrerequisiteStatePath = Join-Path $WorkflowRoot 'prerequisite-state.json'
$Stage04ResultPath = Join-Path $WorkflowRoot 'post-testsigning-validation.json'
$ResultPath = Join-Path $WorkflowRoot 'amd-software-install-result.json'
$LogRoot = Join-Path $WorkflowRoot 'Logs'
$AssetRoot = Join-Path $WorkflowRoot 'Extracted-Assets'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogPath = Join-Path $LogRoot "03-Install-Native-2099-Store-Free-$Timestamp.log"
$ExtractionProvenancePath = Join-Path $AssetRoot 'native-2099-extraction-provenance.json'
$PreservedNativeMsiPath = Join-Path $AssetRoot 'AMD-CNext-26.6.4-ccc-next64.msi'
$LegacyStoreRetirementPath = Join-Path $WorkflowRoot 'legacy-store-retirement-result.json'

$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$SourceAuditPath = Join-Path $WorkflowRoot 'source-package-audit.json'
$ExpectedOfficialInstallerVersion = '26.6.4.0'

$ExpectedDriverVersion = '32.0.31021.5001'
$ExpectedInfHash =
    '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'
$ExpectedKernelHash =
    '3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F'
$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'

$ExpectedNativeMsiLength = [int64]152641536
$ExpectedNativeMsiHash =
    '6E44F1C9048C3990EA146DCAEB5C7A7C6373994D344498C14D8C233D01074B7E'
$ExpectedNativeMsiDisplayVersion = '2026.0626.1637.2099'
$ExpectedNativeMsiProductCode = '{DA10E1F9-4EFE-46EB-9B71-54BD5676D810}'
$ExpectedNativeDesktopRadeonLength = [int64]29045008
$ExpectedNativeDesktopRadeonVersion = '10,01,02,2099'
$ExpectedNativeDesktopRadeonHash =
    'E24586BA9B07CC2CE217AC6B11B1618C7F134264EF8B534EC77C2645CF92342B'

$ExpectedLegacyMsiDisplayVersion = '2026.0309.1733.2089'
$ExpectedLegacyMsiProductCode = '{AA16A900-8FCB-442D-969E-8A3EA516B506}'
$LegacyStoreAppxName = 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'

$ExpectedRsxcmName = 'AdvancedMicroDevicesInc-RSXCM'
$ExpectedRsxcmVersion = '22.10.0.0'
$ExpectedNativeRsxPackageHash =
    '1B8EFAE7FECA03E10CA15C88527F2E9C1F8B48E688F5C5565B04D759A7D8BB88'
$LegacyContextMenuClsid = '{6767B3BC-8FF7-11EC-B909-0242AC120002}'
$NativeContextMenuClsid = '{FDADFEE3-02D1-4E7C-A511-380F4C98D73B}'
$ShellBlockedPath =
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'

$FallbackUwppairInfHash =
    '2910267F4608F15FB8714157EFE9FC8A279205E1A4F4B475C7719F9C5F7021EB'
$FallbackAmduwpVersion = '32.2530.0.0'

$ExpectedFinalCNVersion = ''
$ExpectedFinalCNDriverVersion = ''
$ExpectedStableRelease = ''
$ExpectedLenovoExtensionVersion = ''
$ExpectedLenovoExtensionInfSHA256 = ''
$ExpectedLenovoExtensionCatalogSHA256 = ''

$LegacyLauncherPath =
    'C:\Program Files\LegionGo-AMD-26.6.4\Launch-AMD-Software.ps1'
$LegacyShortcutPath =
    'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\AMD Software (Legion Go 26.6.4).lnk'

function Confirm-UserAction {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    while ($true) {
        $Answer = [string](Read-Host "$Prompt [Y/N]")

        if ($Answer -match '^(?i:y|yes)$') {
            return $true
        }

        if ($Answer -match '^(?i:n|no)$') {
            return $false
        }

        Write-Host 'Enter Y or N.' -ForegroundColor Yellow
    }
}

function Get-CurrentBootTime {
    return (
        Get-CimInstance `
            Win32_OperatingSystem `
            -ErrorAction Stop
    ).LastBootUpTime
}

function Invoke-ShellAssociationRefresh {
    if (-not ('LegionGoShellRefresh.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace LegionGoShellRefresh
{
    public static class NativeMethods
    {
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(
            uint wEventId,
            uint uFlags,
            IntPtr dwItem1,
            IntPtr dwItem2
        );
    }
}
'@
    }

    $ShcneAssocChanged = [uint32]0x08000000
    $ShcnfIdList = [uint32]0x0000

    [LegionGoShellRefresh.NativeMethods]::SHChangeNotify(
        $ShcneAssocChanged,
        $ShcnfIdList,
        [IntPtr]::Zero,
        [IntPtr]::Zero
    )

    Write-Host (
        '[PASS] Windows shell association refresh was requested without ' +
        'terminating Explorer.'
    )
}

function Request-FinalPersistenceRestart {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    Write-Host ''
    Write-Host (
        'A Windows restart is required before Script 4 can perform the final ' +
        'persistence audit.'
    ) -ForegroundColor Yellow
    Write-Host (
        'Save your work and close open applications before continuing.'
    ) -ForegroundColor Yellow

    $RestartNow =
        Confirm-UserAction `
            -Prompt 'Restart Windows now?'

    if (-not $RestartNow) {
        Write-Host ''
        Write-Host '[INFO] Windows restart was not scheduled.' `
            -ForegroundColor Yellow
        Write-Host (
            'Restart Windows manually before running Script 4. To recheck ' +
            'Script 3 first, run:'
        )
        Write-Host (
            'PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
            $ScriptPath +
            '"'
        ) -ForegroundColor Cyan
        return $false
    }

    & shutdown.exe `
        /r `
        /t 10 `
        /c (
            'Legion Go AMD 26.6.4: restarting for Script 4 final ' +
            'persistence validation.'
        )

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to schedule Windows restart: $LASTEXITCODE"
    }

    Write-Host '[PASS] Windows restart scheduled for 10 seconds.' `
        -ForegroundColor Green
    Write-Host 'After sign-in, run Script 4.' -ForegroundColor Green
    return $true
}

function Test-IsAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal =
        New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Quote-NativeArgument {
    param([Parameter(Mandatory)][string]$Value)

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Restart-Elevated {
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        throw 'Cannot self-elevate because PSCommandPath is unavailable.'
    }

    $Arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        (Quote-NativeArgument -Value $PSCommandPath)
    )

    Write-Host (
        'Administrative elevation is required. Opening a UAC prompt.'
    ) -ForegroundColor Cyan

    Start-Process `
        -FilePath $WindowsPowerShell `
        -Verb RunAs `
        -ArgumentList ($Arguments -join ' ') |
        Out-Null
}

function Get-SHA256 {
    param([Parameter(Mandatory)][string]$LiteralPath)

    return (
        Get-FileHash `
            -LiteralPath $LiteralPath `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()
}

function Get-PropertyValue {
    param(
        [AllowNull()]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $Property = $Object.PSObject.Properties[$Name]

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        return $null
    }

    try {
        return (
            Get-Content -LiteralPath $LiteralPath -Raw |
                ConvertFrom-Json
        )
    }
    catch {
        return $null
    }
}

function Get-LenovoCompatibilityContract {
    $Result = Read-JsonFile -LiteralPath $Stage04ResultPath

    if (
        $null -eq $Result -or
        -not [bool](Get-PropertyValue -Object $Result -Name 'Validated') -or
        -not [bool](Get-PropertyValue -Object $Result -Name 'LenovoExtensionSemanticCompatible')
    ) {
        throw (
            'Script 2 did not record a passing semantic Lenovo extension ' +
            "contract: $Stage04ResultPath"
        )
    }

    $Contract = [pscustomobject]@{
        ExtensionVersion = [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionVersion')
        ExtensionInfSHA256 = [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionInfSHA256')
        ExtensionCatalogSHA256 = [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionCatalogSHA256')
        CNVersion = [string](Get-PropertyValue -Object $Result -Name 'LenovoCNVersion')
        CNDriverVersion = [string](Get-PropertyValue -Object $Result -Name 'LenovoCNDriverVersion')
        StableReleaseVersion = [string](Get-PropertyValue -Object $Result -Name 'LenovoStableReleaseVersion')
    }

    foreach ($Name in @(
        'ExtensionVersion'
        'ExtensionInfSHA256'
        'ExtensionCatalogSHA256'
        'CNVersion'
        'CNDriverVersion'
        'StableReleaseVersion'
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$Contract.$Name)) {
            throw "Script 2 Lenovo compatibility field is missing: $Name"
        }
    }

    if ($Contract.CNDriverVersion -ne $Contract.ExtensionVersion) {
        throw 'Recorded CN DriverVersion does not match the Lenovo extension.'
    }

    if (
        -not $Contract.StableReleaseVersion.StartsWith(
            $Contract.CNVersion + '-',
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        $Contract.StableReleaseVersion -notmatch '(?i)-Lenovo$'
    ) {
        throw 'Recorded Lenovo ReleaseVersion provenance is invalid.'
    }

    return $Contract
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$LiteralPath,
        [ValidateRange(2, 30)][int]$Depth = 12
    )

    $Directory = Split-Path -Parent $LiteralPath
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null

    $TemporaryPath =
        $LiteralPath + '.tmp-' + [guid]::NewGuid().ToString('N')

    try {
        $Value |
            ConvertTo-Json -Depth $Depth |
            Set-Content `
                -LiteralPath $TemporaryPath `
                -Encoding UTF8

        Move-Item `
            -LiteralPath $TemporaryPath `
            -Destination $LiteralPath `
            -Force
    }
    finally {
        Remove-Item `
            -LiteralPath $TemporaryPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Test-Stage04Complete {
    $Result = Read-JsonFile -LiteralPath $Stage04ResultPath

    if ($null -eq $Result) {
        return $false
    }

    return (
        [bool](Get-PropertyValue -Object $Result -Name 'Validated') -and
        [bool](Get-PropertyValue -Object $Result -Name 'RebootAfterStage03Confirmed') -and
        -not [bool](Get-PropertyValue -Object $Result -Name 'TestSigningEnabled') -and
        [string](Get-PropertyValue -Object $Result -Name 'DriverVersion') -eq
            $ExpectedDriverVersion -and
        [string](Get-PropertyValue -Object $Result -Name 'ActiveInfSHA256') -eq
            $ExpectedInfHash -and
        [string](Get-PropertyValue -Object $Result -Name 'KernelSHA256') -eq
            $ExpectedKernelHash -and
        [bool](Get-PropertyValue -Object $Result -Name 'LenovoExtensionAttached') -and
        [bool](Get-PropertyValue -Object $Result -Name 'LenovoExtensionSemanticCompatible') -and
        [bool](Get-PropertyValue -Object $Result -Name 'AMDUWPHealthy')
    )
}

function Resolve-KernelPath {
    param([Parameter(Mandatory)][string]$RawPath)

    $Resolved = $RawPath.Trim('"')
    $Resolved = $Resolved -replace '^(?i)\\SystemRoot', $env:windir
    $Resolved = $Resolved -replace '^(?i)System32\\', "$env:windir\System32\"
    $Resolved = $Resolved -replace '^(?i)\\\?\?\\', ''
    return $Resolved
}

function Get-GpuSnapshot {
    $Driver = Get-CimInstance Win32_PnPSignedDriver |
        Where-Object DeviceID -Like $GpuPattern |
        Select-Object -First 1

    $Device = Get-CimInstance Win32_PnPEntity |
        Where-Object DeviceID -Like $GpuPattern |
        Select-Object -First 1

    if ($null -eq $Driver -or $null -eq $Device) {
        throw 'The Legion Go AMD GPU was not found.'
    }

    $InfPath = Join-Path $env:windir "INF\$($Driver.InfName)"
    $EnumPath =
        "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\$($Device.DeviceID)"
    $KernelService =
        [string](Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop).Service

    $Service = Get-CimInstance Win32_SystemDriver |
        Where-Object Name -EQ $KernelService |
        Select-Object -First 1

    if ($null -eq $Service) {
        throw "GPU kernel service was not found: $KernelService"
    }

    $KernelPath = Resolve-KernelPath -RawPath ([string]$Service.PathName)

    return [pscustomobject]@{
        DeviceName      = [string]$Device.Name
        DeviceID        = [string]$Device.DeviceID
        ActiveINF       = [string]$Driver.InfName
        DriverVersion   = [string]$Driver.DriverVersion
        ActiveInfSHA256 = Get-SHA256 -LiteralPath $InfPath
        Status          = [string]$Device.Status
        ProblemCode     = [int]$Device.ConfigManagerErrorCode
        KernelService   = $KernelService
        KernelState     = [string]$Service.State
        KernelPath      = $KernelPath
        KernelSHA256    = Get-SHA256 -LiteralPath $KernelPath
    }
}

function Assert-GpuSnapshot {
    param([Parameter(Mandatory)]$Snapshot)

    if ($Snapshot.DriverVersion -ne $ExpectedDriverVersion) {
        throw "Unexpected GPU driver version: $($Snapshot.DriverVersion)"
    }

    if ($Snapshot.ActiveInfSHA256 -ne $ExpectedInfHash) {
        throw "Unexpected active INF hash: $($Snapshot.ActiveInfSHA256)"
    }

    if ($Snapshot.KernelSHA256 -ne $ExpectedKernelHash) {
        throw "Unexpected running kernel hash: $($Snapshot.KernelSHA256)"
    }

    if (
        $Snapshot.Status -ne 'OK' -or
        $Snapshot.ProblemCode -ne 0 -or
        $Snapshot.KernelState -ne 'Running'
    ) {
        throw 'The corrected AMD display driver is not healthy.'
    }
}

function Get-TestSigningEnabled {
    $Output = & bcdedit.exe /enum '{current}' 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read current BCD state.'
    }

    $Line = $Output |
        Where-Object {
            $_ -match '(?i)^testsigning\s+'
        } |
        Select-Object -First 1

    if ($null -eq $Line) {
        return $false
    }

    return $Line -match '(?i)\bYes\b|\bOn\b|\bTrue\b'
}

function Get-SecureBootEnabled {
    try {
        return [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
    }
    catch {
        return $false
    }
}

function Resolve-SevenZipPath {
    $Candidates = @()
    $PrerequisiteState = Read-JsonFile -LiteralPath $PrerequisiteStatePath

    if ($null -ne $PrerequisiteState) {
        $Dependencies =
            Get-PropertyValue -Object $PrerequisiteState -Name 'Dependencies'
        $SevenZipState =
            Get-PropertyValue -Object $Dependencies -Name 'SevenZip'
        $RecordedPath =
            [string](Get-PropertyValue -Object $SevenZipState -Name 'Path')

        if (-not [string]::IsNullOrWhiteSpace($RecordedPath)) {
            $Candidates += $RecordedPath
        }
    }

    $Candidates += @(
        "$env:ProgramFiles\7-Zip\7z.exe"
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )

    $Command = Get-Command 7z.exe -ErrorAction SilentlyContinue

    if ($null -ne $Command) {
        $Candidates += $Command.Source
    }

    foreach ($Candidate in @($Candidates | Select-Object -Unique)) {
        if (
            -not [string]::IsNullOrWhiteSpace($Candidate) -and
            (Test-Path -LiteralPath $Candidate -PathType Leaf)
        ) {
            return $Candidate
        }
    }

    throw '7-Zip is required but 7z.exe was not found.'
}

function Resolve-OfficialInstaller {
    if (-not (Test-Path -LiteralPath $SourceAuditPath -PathType Leaf)) {
        throw @"
Script 1 source-package audit was not found:
$SourceAuditPath

Complete Script 1 before running Script 3.
"@
    }

    $Audit = Read-JsonFile -LiteralPath $SourceAuditPath

    if (
        $null -eq $Audit -or
        -not [bool](Get-PropertyValue -Object $Audit -Name 'AuditPassed')
    ) {
        throw 'Script 1 source-package audit does not report AuditPassed=true.'
    }

    $InstallerRecord = Get-PropertyValue -Object $Audit -Name 'Installer'

    if ($null -eq $InstallerRecord) {
        throw 'Script 1 source-package audit has no Installer record.'
    }

    $RecordedPath = [string](
        Get-PropertyValue -Object $InstallerRecord -Name 'FullName'
    )
    $RecordedLength = [int64](
        Get-PropertyValue -Object $InstallerRecord -Name 'Length'
    )
    $RecordedHash = [string](
        Get-PropertyValue -Object $InstallerRecord -Name 'SHA256'
    )
    $RecordedFileVersion = [string](
        Get-PropertyValue -Object $InstallerRecord -Name 'FileVersion'
    )
    $RecordedProductVersion = [string](
        Get-PropertyValue -Object $InstallerRecord -Name 'ProductVersion'
    )
    $CompatibilityProperty =
        $InstallerRecord.PSObject.Properties['CompatibleSignedContainer']
    $CompatibilityState = if ($null -eq $CompatibilityProperty) {
        'LegacyAuditSchema'
    }
    elseif ([bool]$CompatibilityProperty.Value) {
        'RecordedCompatible'
    }
    else {
        'RecordedIncompatible'
    }

    if (
        $CompatibilityState -eq 'RecordedIncompatible' -or
        [string]::IsNullOrWhiteSpace($RecordedHash) -or
        $RecordedLength -le 0 -or
        $RecordedFileVersion -ne $ExpectedOfficialInstallerVersion -or
        $RecordedProductVersion -ne $ExpectedOfficialInstallerVersion
    ) {
        throw 'Script 1 did not record a usable AMD 26.6.4 installer identity.'
    }

    $CandidatePaths = @()

    if (Test-Path -LiteralPath $RecordedPath -PathType Leaf) {
        $CandidatePaths += (Resolve-Path -LiteralPath $RecordedPath).Path
    }

    if (Test-Path -LiteralPath $PSScriptRoot -PathType Container) {
        $CandidatePaths += @(
            Get-ChildItem `
                -LiteralPath $PSScriptRoot `
                -Filter '*.exe' `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Where-Object { [int64]$_.Length -eq $RecordedLength } |
                Select-Object -ExpandProperty FullName
        )
    }

    $ValidatedInstallers = @()

    foreach ($Path in @($CandidatePaths | Select-Object -Unique)) {
        $Item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue

        if ($null -eq $Item -or [int64]$Item.Length -ne $RecordedLength) {
            continue
        }

        $ActualHash = Get-SHA256 -LiteralPath $Item.FullName

        if ($ActualHash -ne $RecordedHash) {
            continue
        }

        $Signature = Get-AuthenticodeSignature -LiteralPath $Item.FullName
        $FileVersion = [string]$Item.VersionInfo.FileVersion
        $ProductVersion = [string]$Item.VersionInfo.ProductVersion

        if (
            $Signature.Status -ne 'Valid' -or
            $null -eq $Signature.SignerCertificate -or
            [string]$Signature.SignerCertificate.Subject -notmatch
                '^CN=Advanced Micro Devices,' -or
            $FileVersion -ne $ExpectedOfficialInstallerVersion -or
            $ProductVersion -ne $ExpectedOfficialInstallerVersion
        ) {
            continue
        }

        $ValidatedInstallers += [pscustomobject]@{
            Item = $Item
            SHA256 = $ActualHash
            SignatureStatus = [string]$Signature.Status
            Signer = [string]$Signature.SignerCertificate.Subject
            RecordedPathMatch = [bool]($Item.FullName -ieq $RecordedPath)
            AuditCompatibilityState = $CompatibilityState
        }
    }

    if ($ValidatedInstallers.Count -eq 0) {
        throw @"
The AMD 26.6.4 installer container recorded and audited by Script 1 could not
be found unchanged. Keep the same installer with the toolkit throughout the
workflow, then rerun Script 3.

Recorded path:   $RecordedPath
Recorded length: $RecordedLength
Recorded SHA256: $RecordedHash
"@
    }

    $Preferred = @(
        $ValidatedInstallers |
            Sort-Object `
                @{Expression={ if ($_.RecordedPathMatch) { 0 } else { 1 } }},
                @{Expression={$_.Item.FullName.Length}},
                @{Expression={$_.Item.FullName}}
    )[0]

    $Preferred | Add-Member `
        -NotePropertyName DuplicateRecordedMatchCount `
        -NotePropertyValue $ValidatedInstallers.Count

    return $Preferred
}

function Invoke-SevenZipExtract {
    param(
        [Parameter(Mandatory)][string]$SevenZipPath,
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$DestinationPath,
        [Parameter(Mandatory)][string]$Description
    )

    New-Item `
        -ItemType Directory `
        -Path $DestinationPath `
        -Force |
        Out-Null

    Write-Host "Extracting $Description..."

    & $SevenZipPath `
        x `
        -y `
        "-o$DestinationPath" `
        -- `
        $ArchivePath |
        Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "$Description extraction failed with exit code $LASTEXITCODE."
    }
}

function Find-ExactNativeMsiInTree {
    param([Parameter(Mandatory)][string]$Root)

    $NamedCandidates = @(
        Get-ChildItem `
            -LiteralPath $Root `
            -Filter 'ccc-next64.msi' `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    $LengthCandidates = @(
        Get-ChildItem `
            -LiteralPath $Root `
            -Filter '*.msi' `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                [int64]$_.Length -eq $ExpectedNativeMsiLength
            }
    )

    foreach ($Candidate in @(
        (@($NamedCandidates) + @($LengthCandidates)) |
            Sort-Object FullName -Unique
    )) {
        if ([int64]$Candidate.Length -ne $ExpectedNativeMsiLength) {
            continue
        }

        if ((Get-SHA256 -LiteralPath $Candidate.FullName) -eq $ExpectedNativeMsiHash) {
            return $Candidate
        }
    }

    return $null
}

function Assert-ExtractionSpace {
    $TempRootPath = [IO.Path]::GetPathRoot([IO.Path]::GetTempPath())
    $DriveName = $TempRootPath.TrimEnd('\').TrimEnd(':')
    $Drive = Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue

    if ($null -eq $Drive) {
        return
    }

    $RequiredBytes = [int64](8GB)

    if ([int64]$Drive.Free -lt $RequiredBytes) {
        throw (
            'At least 8 GiB of free space is required to extract the exact ' +
            "official installer. Available bytes: $($Drive.Free)"
        )
    }
}

function Get-OrExtractNativeMsi {
    param(
        [Parameter(Mandatory)]$OfficialInstaller,
        [Parameter(Mandatory)][string]$SevenZipPath
    )

    New-Item -ItemType Directory -Path $AssetRoot -Force | Out-Null

    if (Test-Path -LiteralPath $PreservedNativeMsiPath -PathType Leaf) {
        $Existing = Get-Item -LiteralPath $PreservedNativeMsiPath

        if (
            [int64]$Existing.Length -eq $ExpectedNativeMsiLength -and
            (Get-SHA256 -LiteralPath $Existing.FullName) -eq
                $ExpectedNativeMsiHash
        ) {
            Write-Host '[PASS] Preserved exact native .2099 MSI already exists.'
            return [pscustomobject]@{
                Item = $Existing
                NestedSource = [string](
                    Get-PropertyValue `
                        -Object (Read-JsonFile -LiteralPath $ExtractionProvenancePath) `
                        -Name 'NestedSource'
                )
                ExtractedThisRun = $false
            }
        }
    }

    Assert-ExtractionSpace

    $TemporaryRoot = Join-Path `
        ([IO.Path]::GetTempPath()) `
        "LegionGo-AMD2664-Native-MSI-$Timestamp"
    $OuterRoot = Join-Path $TemporaryRoot 'Official-Installer'
    $NativeMsi = $null
    $NestedSource = ''

    try {
        Invoke-SevenZipExtract `
            -SevenZipPath $SevenZipPath `
            -ArchivePath $OfficialInstaller.Item.FullName `
            -DestinationPath $OuterRoot `
            -Description 'the recorded compatible AMD 26.6.4 installer container'

        $NativeMsi = Find-ExactNativeMsiInTree -Root $OuterRoot

        if ($null -eq $NativeMsi) {
            $NestedInstallers = @(
                Get-ChildItem `
                    -LiteralPath $OuterRoot `
                    -Filter 'ccc2_install.exe' `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue |
                    Sort-Object `
                        @{Expression={
                            if ($_.FullName -match '(?i)\\B026218\\') {
                                0
                            }
                            else {
                                1
                            }
                        }},
                        FullName
            )

            if ($NestedInstallers.Count -eq 0) {
                throw (
                    'The recorded AMD installer extraction did not contain ' +
                    'any ccc2_install.exe payload to inspect.'
                )
            }

            $Layer = 0

            foreach ($NestedInstaller in $NestedInstallers) {
                $Layer++
                $NestedRoot = Join-Path `
                    $TemporaryRoot `
                    ('Nested-CCC2-' + $Layer.ToString('D2'))

                Invoke-SevenZipExtract `
                    -SevenZipPath $SevenZipPath `
                    -ArchivePath $NestedInstaller.FullName `
                    -DestinationPath $NestedRoot `
                    -Description "nested AMD ccc2 payload $Layer"

                $NativeMsi = Find-ExactNativeMsiInTree -Root $NestedRoot

                if ($null -ne $NativeMsi) {
                    $NestedSource = $NestedInstaller.FullName.Substring(
                        $OuterRoot.Length
                    ).TrimStart('\')
                    break
                }
            }
        }

        if ($null -eq $NativeMsi) {
            throw (
                'The exact native .2099 CNext MSI was not found after ' +
                'extracting every ccc2 payload in the exact official installer.'
            )
        }

        Copy-Item `
            -LiteralPath $NativeMsi.FullName `
            -Destination $PreservedNativeMsiPath `
            -Force

        $Preserved = Get-Item -LiteralPath $PreservedNativeMsiPath

        if (
            [int64]$Preserved.Length -ne $ExpectedNativeMsiLength -or
            (Get-SHA256 -LiteralPath $Preserved.FullName) -ne
                $ExpectedNativeMsiHash
        ) {
            throw 'The preserved native .2099 MSI failed post-copy verification.'
        }

        $Provenance = [ordered]@{
            SchemaVersion = 1
            CapturedAt = (Get-Date).ToString('o')
            OfficialInstallerPath = $OfficialInstaller.Item.FullName
            OfficialInstallerLength = [int64]$OfficialInstaller.Item.Length
            OfficialInstallerSHA256 = $OfficialInstaller.SHA256
            OfficialInstallerSigner = $OfficialInstaller.Signer
            NestedSource = $NestedSource
            PreservedNativeMsiPath = $Preserved.FullName
            NativeMsiLength = [int64]$Preserved.Length
            NativeMsiSHA256 = $ExpectedNativeMsiHash
        }

        Write-JsonFile `
            -Value $Provenance `
            -LiteralPath $ExtractionProvenancePath `
            -Depth 6

        Write-Host '[PASS] Exact native .2099 MSI extracted from the official installer.'

        return [pscustomobject]@{
            Item = $Preserved
            NestedSource = $NestedSource
            ExtractedThisRun = $true
        }
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryRoot) {
            Write-Host 'Removing temporary installer extraction data...'
            Remove-Item `
                -LiteralPath $TemporaryRoot `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Get-MsiProperty {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Property
    )

    $Installer = $null
    $Database = $null
    $View = $null
    $Record = $null

    try {
        $Installer = New-Object -ComObject WindowsInstaller.Installer
        $Database = $Installer.OpenDatabase($LiteralPath, 0)
        $Query =
            "SELECT `Value` FROM `Property` WHERE `Property`='$Property'"
        $View = $Database.OpenView($Query)
        $View.Execute()
        $Record = $View.Fetch()

        if ($null -eq $Record) {
            return $null
        }

        return [string]$Record.StringData(1)
    }
    finally {
        foreach ($Object in @($Record, $View, $Database, $Installer)) {
            if ($null -ne $Object) {
                try {
                    [void][Runtime.InteropServices.Marshal]::ReleaseComObject(
                        $Object
                    )
                }
                catch {
                }
            }
        }
    }
}

function Assert-NativeMsiIdentity {
    param([Parameter(Mandatory)][string]$LiteralPath)

    $Item = Get-Item -LiteralPath $LiteralPath

    if ([int64]$Item.Length -ne $ExpectedNativeMsiLength) {
        throw "Unexpected native MSI length: $($Item.Length)"
    }

    if ((Get-SHA256 -LiteralPath $LiteralPath) -ne $ExpectedNativeMsiHash) {
        throw 'Unexpected native MSI SHA-256.'
    }

    $ProductCode = Get-MsiProperty `
        -LiteralPath $LiteralPath `
        -Property 'ProductCode'
    $ProductVersion = Get-MsiProperty `
        -LiteralPath $LiteralPath `
        -Property 'ProductVersion'

    if ($ProductCode -ine $ExpectedNativeMsiProductCode) {
        throw "Unexpected native MSI ProductCode: $ProductCode"
    }

    if ([string]::IsNullOrWhiteSpace($ProductVersion)) {
        throw 'The native MSI ProductVersion property is missing.'
    }

    $Signature = Get-AuthenticodeSignature -LiteralPath $LiteralPath

    if (
        $Signature.Status -ne 'Valid' -or
        $null -eq $Signature.SignerCertificate -or
        [string]$Signature.SignerCertificate.Subject -notmatch
            'Advanced Micro Devices'
    ) {
        throw 'The exact native MSI does not have the expected valid AMD signature.'
    }

    return [pscustomobject]@{
        ProductCode = $ProductCode
        ProductVersion = $ProductVersion
        SignatureStatus = [string]$Signature.Status
        Signer = [string]$Signature.SignerCertificate.Subject
    }
}

function Get-AmdSettingsRecords {
    $Records = @()

    foreach ($Root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )) {
        foreach ($Key in @(
            Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue
        )) {
            $Record = Get-ItemProperty `
                -LiteralPath $Key.PSPath `
                -ErrorAction SilentlyContinue
            $Name =
                [string](Get-PropertyValue -Object $Record -Name 'DisplayName')

            if ($Name -ne 'AMD Settings') {
                continue
            }

            $Records += [pscustomobject]@{
                RegistryPath = $Key.PSPath
                KeyName = [string]$Key.PSChildName
                DisplayName = $Name
                DisplayVersion = [string](
                    Get-PropertyValue -Object $Record -Name 'DisplayVersion'
                )
                UninstallString = [string](
                    Get-PropertyValue -Object $Record -Name 'UninstallString'
                )
            }
        }
    }

    return @($Records)
}

function Get-NativeMsiRecord {
    $Record = Get-AmdSettingsRecords |
        Where-Object {
            $_.KeyName -ieq $ExpectedNativeMsiProductCode -and
            $_.DisplayVersion -eq $ExpectedNativeMsiDisplayVersion
        } |
        Select-Object -First 1

    return $Record
}

function Get-LegacyConflictingMsiRecord {
    $Record = Get-AmdSettingsRecords |
        Where-Object {
            $_.KeyName -ieq $ExpectedLegacyMsiProductCode -and
            $_.DisplayVersion -eq $ExpectedLegacyMsiDisplayVersion
        } |
        Select-Object -First 1

    return $Record
}

function Get-DesktopRadeonState {
    $Path = 'C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe'

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            Path = $Path
            Exists = $false
            Length = $null
            FileVersion = ''
            SHA256 = ''
            SignatureStatus = ''
            SignerSubject = ''
            Match = $false
        }
    }

    $Item = Get-Item -LiteralPath $Path
    $Signature = Get-AuthenticodeSignature -LiteralPath $Path
    $Version = [string]$Item.VersionInfo.FileVersion
    $Hash = Get-SHA256 -LiteralPath $Path

    return [pscustomobject]@{
        Path = $Path
        Exists = $true
        Length = [int64]$Item.Length
        FileVersion = $Version
        SHA256 = $Hash
        SignatureStatus = [string]$Signature.Status
        SignerSubject = if ($null -ne $Signature.SignerCertificate) {
            [string]$Signature.SignerCertificate.Subject
        }
        else {
            ''
        }
        Match = (
            [int64]$Item.Length -eq $ExpectedNativeDesktopRadeonLength -and
            $Version -eq $ExpectedNativeDesktopRadeonVersion -and
            $Hash -eq $ExpectedNativeDesktopRadeonHash -and
            $Signature.Status -eq 'Valid'
        )
    }
}

function Get-RsxcmState {
    $Package = Get-AppxPackage `
        -Name $ExpectedRsxcmName `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    $PackageMatch = (
        $null -ne $Package -and
        [string]$Package.Version -eq $ExpectedRsxcmVersion -and
        [string]$Package.Status -eq 'Ok'
    )

    $ManifestHasNativeClsid = $false

    if ($PackageMatch) {
        $ManifestPath = Join-Path `
            ([string]$Package.InstallLocation) `
            'AppxManifest.xml'

        if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
            $ManifestText = Get-Content `
                -LiteralPath $ManifestPath `
                -Raw `
                -ErrorAction Stop
            $ManifestClsid = $NativeContextMenuClsid.Trim('{}')
            $ManifestHasNativeClsid =
                $ManifestText -match [regex]::Escape($ManifestClsid)
        }
    }

    $RsxPackagePath =
        'C:\Program Files\AMD\CNext\CNext\RSXPackage.msix'
    $RsxPackageHash = if (
        Test-Path -LiteralPath $RsxPackagePath -PathType Leaf
    ) {
        Get-SHA256 -LiteralPath $RsxPackagePath
    }
    else {
        ''
    }

    $NativeClassPath =
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\PackagedCom\ClassIndex\' +
        $NativeContextMenuClsid

    return [pscustomobject]@{
        Present = $null -ne $Package
        Match = (
            $PackageMatch -and
            $ManifestHasNativeClsid -and
            (Test-Path -LiteralPath $NativeClassPath) -and
            $RsxPackageHash -eq $ExpectedNativeRsxPackageHash
        )
        PackageFullName = if ($null -ne $Package) {
            [string]$Package.PackageFullName
        }
        else {
            ''
        }
        Version = if ($null -ne $Package) {
            [string]$Package.Version
        }
        else {
            ''
        }
        Status = if ($null -ne $Package) {
            [string]$Package.Status
        }
        else {
            ''
        }
        InstallLocation = if ($null -ne $Package) {
            [string]$Package.InstallLocation
        }
        else {
            ''
        }
        ManifestHasNativeClsid = $ManifestHasNativeClsid
        NativeClassRegistered = Test-Path -LiteralPath $NativeClassPath
        RsxPackagePath = $RsxPackagePath
        RsxPackageSHA256 = $RsxPackageHash
    }
}

function Stop-AmdSoftwareProcesses {
    Get-Process `
        -Name @(
            'RadeonSoftware'
            'cncmd'
            'AMDRSServ'
            'RSServCmd'
            'LauncherRSXRuntime'
            'WULaunchApp'
            'ccc2_install'
        ) `
        -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    foreach ($Process in @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
                (
                    $_.ExecutablePath.StartsWith(
                        'C:\Program Files\AMD\CNext',
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -or
                    $_.ExecutablePath.StartsWith(
                        'C:\Program Files\WindowsApps\AdvancedMicroDevicesInc-2.AMDRadeonSoftware_',
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -or
                    $_.ExecutablePath.StartsWith(
                        'C:\Program Files\WindowsApps\AdvancedMicroDevicesInc-RSXCM_',
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -or
                    (
                        [string]$_.Name -ieq 'dllhost.exe' -and
                        -not [string]::IsNullOrWhiteSpace($_.CommandLine) -and
                        (
                            $_.CommandLine -match
                                [regex]::Escape($ExpectedRsxcmName) -or
                            $_.CommandLine -match
                                [regex]::Escape($LegacyStoreAppxName) -or
                            $_.CommandLine -match
                                [regex]::Escape(
                                    $NativeContextMenuClsid.Trim('{}')
                                ) -or
                            $_.CommandLine -match
                                [regex]::Escape(
                                    $LegacyContextMenuClsid.Trim('{}')
                                )
                        )
                    )
                )
            }
    )) {
        Stop-Process `
            -Id ([int]$Process.ProcessId) `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Remove-LegacyConflictingMsi {
    $LegacyRecord = Get-LegacyConflictingMsiRecord

    if ($null -eq $LegacyRecord) {
        Write-Host '[INFO] The conflicting .2089 MSI product is absent.'
        return $true
    }

    Write-Host 'Removing the conflicting .2089 AMD Settings MSI product...'
    Stop-AmdSoftwareProcesses

    $UninstallLog = Join-Path `
        $LogRoot `
        "05-Legacy-2089-MSI-Uninstall-$Timestamp.log"
    $Arguments = @(
        '/x'
        $ExpectedLegacyMsiProductCode
        '/qn'
        '/norestart'
        'REBOOT=ReallySuppress'
        '/L*v'
        ('"' + $UninstallLog + '"')
    )

    $Process = Start-Process `
        -FilePath "$env:windir\System32\msiexec.exe" `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($Process.ExitCode -notin @(0, 1605, 3010)) {
        throw (
            'Conflicting .2089 MSI uninstall failed with exit code ' +
            "$($Process.ExitCode). Log: $UninstallLog"
        )
    }

    if ($null -ne (Get-LegacyConflictingMsiRecord)) {
        throw 'The conflicting .2089 MSI remains registered after uninstall.'
    }

    Write-Host '[PASS] Conflicting .2089 MSI product is absent.'
    return $true
}

function Install-Or-RepairNativeMsi {
    param([Parameter(Mandatory)][string]$MsiPath)

    $NativeRecord = Get-NativeMsiRecord
    $Desktop = Get-DesktopRadeonState
    $Rsxcm = Get-RsxcmState

    if ($null -ne $NativeRecord -and $Desktop.Match -and $Rsxcm.Match) {
        Write-Host '[PASS] Exact native .2099 CNext and RSXCM are already installed.'
        return [pscustomobject]@{
            Action = 'AlreadyComplete'
            UninstallExitCode = $null
            InstallExitCode = $null
            MsiLog = ''
            UninstallLog = ''
        }
    }

    Stop-AmdSoftwareProcesses

    $UninstallExitCode = $null
    $UninstallLog = ''

    if ($null -ne $NativeRecord) {
        $UninstallLog = Join-Path `
            $LogRoot `
            "05-Native-2099-MSI-Uninstall-$Timestamp.log"
        $UninstallArguments = @(
            '/x'
            $ExpectedNativeMsiProductCode
            '/qn'
            '/norestart'
            'REBOOT=ReallySuppress'
            '/L*v'
            ('"' + $UninstallLog + '"')
        )

        Write-Host (
            'The native MSI is registered but incomplete. Removing it before ' +
            'a clean exact reinstall...'
        )

        $UninstallProcess = Start-Process `
            -FilePath "$env:windir\System32\msiexec.exe" `
            -ArgumentList $UninstallArguments `
            -Wait `
            -PassThru

        $UninstallExitCode = [int]$UninstallProcess.ExitCode

        if ($UninstallExitCode -notin @(0, 1605, 3010)) {
            throw (
                'Native .2099 MSI uninstall failed with exit code ' +
                "$UninstallExitCode. Log: $UninstallLog"
            )
        }

        if ($null -ne (Get-NativeMsiRecord)) {
            throw 'The incomplete native .2099 MSI remains registered after uninstall.'
        }

        Stop-AmdSoftwareProcesses
    }

    $MsiLog = Join-Path $LogRoot "05-Native-2099-MSI-$Timestamp.log"
    $Arguments = @(
        '/i'
        ('"' + $MsiPath + '"')
        '/qn'
        '/norestart'
        'REBOOT=ReallySuppress'
        '/L*v'
        ('"' + $MsiLog + '"')
    )

    Write-Host 'Installing exact native AMD Software .2099...'

    $Process = Start-Process `
        -FilePath "$env:windir\System32\msiexec.exe" `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($Process.ExitCode -notin @(0, 3010)) {
        throw (
            'Native .2099 MSI installation failed with exit code ' +
            "$($Process.ExitCode). Log: $MsiLog"
        )
    }

    $Deadline = (Get-Date).AddSeconds(60)

    do {
        Start-Sleep -Seconds 2
        $NativeRecord = Get-NativeMsiRecord
        $Desktop = Get-DesktopRadeonState
        $Rsxcm = Get-RsxcmState
    } while (
        (
            $null -eq $NativeRecord -or
            -not $Desktop.Match -or
            -not $Rsxcm.Match
        ) -and
        (Get-Date) -lt $Deadline
    )

    if ($null -eq $NativeRecord) {
        throw 'Native AMD Settings .2099 MSI registration is missing.'
    }

    if (-not $Desktop.Match) {
        throw 'The exact native .2099 RadeonSoftware.exe did not validate.'
    }

    if (-not $Rsxcm.Match) {
        throw 'Native RSXCM 22.10.0.0 did not validate.'
    }

    Write-Host '[PASS] Exact native .2099 CNext and RSXCM are installed.'

    $InstallAction = if ($null -ne $UninstallExitCode) {
        'CleanReinstall'
    }
    else {
        'FreshInstall'
    }

    return [pscustomobject]@{
        Action = $InstallAction
        UninstallExitCode = $UninstallExitCode
        InstallExitCode = [int]$Process.ExitCode
        MsiLog = $MsiLog
        UninstallLog = $UninstallLog
    }
}

function Get-AmduwpInfSemantics {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InfPath
    )

    if (-not (Test-Path -LiteralPath $InfPath -PathType Leaf)) {
        return [pscustomobject]@{
            Compatible = $false
            InfPath = $InfPath
            InfSHA256 = ''
            CatalogName = ''
            FailedChecks = @('PublishedInfPresent')
            Checks = [ordered]@{
                PublishedInfPresent = $false
            }
        }
    }

    $Text = Get-Content -LiteralPath $InfPath -Raw
    $CatalogMatch = [regex]::Match(
        $Text,
        '(?im)^\s*CatalogFile(?:\.[^=]+)?\s*=\s*([^;\r\n]+)'
    )
    $CatalogName = if ($CatalogMatch.Success) {
        $CatalogMatch.Groups[1].Value.Trim().Trim('"')
    }
    else {
        ''
    }

    $Checks = [ordered]@{
        PublishedInfPresent = $true
        SoftwareComponentClass = [bool](
            $Text -match '(?im)^\s*Class\s*=\s*SoftwareComponent\s*$'
        )
        SoftwareComponentClassGuid = [bool](
            $Text -match (
                '(?im)^\s*ClassGUID\s*=\s*' +
                '\{5c4c3332-344d-483c-8739-259e934c9cc8\}\s*$'
            )
        )
        ExpectedComponentHardwareId = [bool](
            $Text -match '(?i)SWC\\VID1002&PID0001'
        )
        NullFunctionService = [bool](
            $Text -match '(?im)^\s*AddService\s*=\s*,\s*(?:2|0x2)\s*$'
        )
        ExpectedAddSoftware = [bool](
            $Text -match (
                '(?im)^\s*AddSoftware\s*=\s*AMDRadeonsettings\s*,\s*' +
                ',\s*AMDRadeonsettingsSoftware\s*$'
            )
        )
        StoreSoftwareType = [bool](
            $Text -match '(?im)^\s*SoftwareType\s*=\s*2\s*$'
        )
        ExpectedStorePackageFamily = [bool](
            $Text -match (
                '(?im)^\s*SoftwareID\s*=\s*' +
                'pfn://AdvancedMicroDevicesInc-2\.AMDRadeonSoftware_' +
                '0a9344xs7nr4m\s*$'
            )
        )
        CatalogDeclared = -not [string]::IsNullOrWhiteSpace($CatalogName)
        NoCopyFiles = -not [bool](
            $Text -match '(?im)^\s*CopyFiles\s*='
        )
        NoServiceBinary = -not [bool](
            $Text -match '(?im)^\s*ServiceBinary\s*='
        )
        NoNamedFunctionService = -not [bool](
            $Text -match '(?im)^\s*AddService\s*=\s*[^,;\s][^,;\r\n]*\s*,'
        )
        NoRuntimeRegistrationDirectives = -not [bool](
            $Text -match (
                '(?im)^\s*(?:AddReg|DelReg|RegisterDlls|' +
                'UnregisterDlls|CoInstallers32)\s*='
            )
        )
    }

    $FailedChecks = @(
        $Checks.GetEnumerator() |
            Where-Object { -not [bool]$_.Value } |
            ForEach-Object Key
    )

    return [pscustomobject]@{
        Compatible = ($FailedChecks.Count -eq 0)
        InfPath = $InfPath
        InfSHA256 = Get-SHA256 -LiteralPath $InfPath
        CatalogName = $CatalogName
        FailedChecks = $FailedChecks
        Checks = $Checks
    }
}

function Get-AmduwpState {
    $Entities = @(
        Get-CimInstance Win32_PnPEntity |
            Where-Object {
                $_.DeviceID -like 'SWD\DRIVERENUM\AMDUWP*'
            }
    )

    if ($Entities.Count -ne 1) {
        return [pscustomobject]@{
            Present = ($Entities.Count -gt 0)
            Healthy = $false
            Compatible = $false
            DeviceCount = $Entities.Count
            Name = ''
            DeviceID = ''
            Status = ''
            ProblemCode = $null
            PNPClass = ''
            HardwareIDs = @()
            InfName = ''
            DriverVersion = ''
            Provider = ''
            DriverClass = ''
            IsSigned = $false
            Signer = ''
            InfPath = ''
            InfSHA256 = ''
            CatalogName = ''
            StructureChecks = $null
            FailedChecks = @('SingleAmduwpDevice')
        }
    }

    $Entity = $Entities[0]
    $Driver = Get-CimInstance Win32_PnPSignedDriver |
        Where-Object DeviceID -EQ $Entity.DeviceID |
        Select-Object -First 1

    $InfPath = if (
        $null -ne $Driver -and
        -not [string]::IsNullOrWhiteSpace([string]$Driver.InfName)
    ) {
        Join-Path $env:windir "INF\$($Driver.InfName)"
    }
    else {
        ''
    }

    $Semantics = Get-AmduwpInfSemantics -InfPath $InfPath
    $HardwareIDs = @($Entity.HardwareID | Where-Object { $_ })
    $DriverInfName = if ($null -ne $Driver) { [string]$Driver.InfName } else { '' }
    $DriverVersion = if ($null -ne $Driver) { [string]$Driver.DriverVersion } else { '' }
    $DriverProvider = if ($null -ne $Driver) { [string]$Driver.DriverProviderName } else { '' }
    $DriverClass = if ($null -ne $Driver) { [string]$Driver.DeviceClass } else { '' }
    $DriverIsSigned = if ($null -ne $Driver) { [bool]$Driver.IsSigned } else { $false }
    $DriverSigner = if ($null -ne $Driver) { [string]$Driver.Signer } else { '' }

    $Checks = [ordered]@{
        SingleAmduwpDevice = $true
        EntityHealthy = [bool](
            $Entity.Status -eq 'OK' -and
            [int]$Entity.ConfigManagerErrorCode -eq 0
        )
        ExpectedDeviceName = [bool](
            [string]$Entity.Name -eq 'AMD-UWP Version Control'
        )
        SoftwareComponentPnPClass = [bool](
            [string]$Entity.PNPClass -ieq 'SoftwareComponent'
        )
        SignedDriverRecordPresent = ($null -ne $Driver)
        SoftwareComponentDriverClass = [bool](
            $null -ne $Driver -and
            [string]$Driver.DeviceClass -ieq 'SOFTWARECOMPONENT'
        )
        AmdProvider = [bool](
            $null -ne $Driver -and
            [string]$Driver.DriverProviderName -eq
                'Advanced Micro Devices, Inc.'
        )
        WindowsSignedPackage = [bool](
            $null -ne $Driver -and
            [bool]$Driver.IsSigned
        )
        MicrosoftHardwareCompatibilitySigner = [bool](
            $null -ne $Driver -and
            [string]$Driver.Signer -match
                'Microsoft Windows Hardware Compatibility Publisher'
        )
        CompatibleInfSemantics = [bool]$Semantics.Compatible
    }

    $FailedChecks = @(
        $Checks.GetEnumerator() |
            Where-Object { -not [bool]$_.Value } |
            ForEach-Object Key
    )

    return [pscustomobject]@{
        Present = $true
        Healthy = [bool]$Checks.EntityHealthy
        Compatible = ($FailedChecks.Count -eq 0)
        DeviceCount = 1
        Name = [string]$Entity.Name
        DeviceID = [string]$Entity.DeviceID
        Status = [string]$Entity.Status
        ProblemCode = [int]$Entity.ConfigManagerErrorCode
        PNPClass = [string]$Entity.PNPClass
        HardwareIDs = $HardwareIDs
        InfName = $DriverInfName
        DriverVersion = $DriverVersion
        Provider = $DriverProvider
        DriverClass = $DriverClass
        IsSigned = $DriverIsSigned
        Signer = $DriverSigner
        InfPath = $InfPath
        InfSHA256 = [string]$Semantics.InfSHA256
        CatalogName = [string]$Semantics.CatalogName
        StructureChecks = $Semantics.Checks
        FailedChecks = @($FailedChecks + $Semantics.FailedChecks | Select-Object -Unique)
    }
}

function Resolve-UwppairInf {
    $ValidateCandidate = {
        param([Parameter(Mandatory)][string]$Path)

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $null
        }

        if ((Get-SHA256 -LiteralPath $Path) -ne $FallbackUwppairInfHash) {
            return $null
        }

        $Text = Get-Content -LiteralPath $Path -Raw

        if (
            $Text -notmatch
                '(?im)^\s*DriverVer\s*=\s*07/08/2025\s*,\s*32\.2530\.0\.0\s*$'
        ) {
            return $null
        }

        $CatalogMatch = [regex]::Match(
            $Text,
            '(?im)^\s*CatalogFile(?:\.[^=]+)?\s*=\s*([^;\r\n]+)'
        )

        if (-not $CatalogMatch.Success) {
            return $null
        }

        $CatalogPath = Join-Path `
            (Split-Path -Parent $Path) `
            $CatalogMatch.Groups[1].Value.Trim()

        if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
            return $null
        }

        $Signature = Get-AuthenticodeSignature -LiteralPath $CatalogPath

        if (
            $Signature.Status -ne 'Valid' -or
            $null -eq $Signature.SignerCertificate -or
            [string]$Signature.SignerCertificate.Subject -notmatch
                'Microsoft Windows Hardware Compatibility Publisher'
        ) {
            return $null
        }

        return [pscustomobject]@{
            InfPath = $Path
            InfSHA256 = $FallbackUwppairInfHash
            CatalogPath = $CatalogPath
            CatalogSHA256 = Get-SHA256 -LiteralPath $CatalogPath
            CatalogSigner = [string]$Signature.SignerCertificate.Subject
        }
    }

    $Candidates = @()
    $Candidates += @(
        Get-ChildItem `
            -Path "$env:windir\System32\DriverStore\FileRepository\uwppair.inf_*\UWPPair.inf" `
            -File `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    )
    $Candidates += @(
        Get-ChildItem `
            -Path "$env:windir\System32\DriverStore\FileRepository\u0413647.inf_*\u0413647.inf" `
            -File `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    )

    foreach ($Path in @($Candidates | Select-Object -Unique)) {
        $Match = & $ValidateCandidate $Path

        if ($null -ne $Match) {
            return $Match
        }
    }

    throw (
        'The exact known-good Microsoft-signed UWPPair 32.2530.0.0 fallback package ' +
        'was not found in Driver Store.'
    )
}

function Ensure-AmduwpHealthy {
    $Amduwp = Get-AmduwpState

    if ($Amduwp.Compatible) {
        return [pscustomobject]@{
            State = $Amduwp
            Action = 'PreservedCompatibleHostPackage'
            FallbackUsed = $false
            Uwppair = [pscustomobject]@{
                InfPath = $Amduwp.InfPath
                InfSHA256 = $Amduwp.InfSHA256
                CatalogPath = ''
                CatalogSHA256 = ''
                CatalogSigner = $Amduwp.Signer
                Source = 'ActiveCompatiblePackage'
            }
        }
    }

    $InitialFailure = @($Amduwp.FailedChecks) -join ', '
    Write-Host (
        '[INFO] The active AMDUWP package is missing or not structurally ' +
        "compatible. Attempting the exact known-good fallback. $InitialFailure"
    ) -ForegroundColor Yellow

    $Uwppair = Resolve-UwppairInf

    & "$env:windir\System32\pnputil.exe" `
        /add-driver `
        $Uwppair.InfPath |
        Out-Host

    if ($LASTEXITCODE -notin @(0, 3010)) {
        throw "pnputil /add-driver failed: $LASTEXITCODE"
    }

    & "$env:windir\System32\pnputil.exe" /scan-devices |
        Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "pnputil /scan-devices failed: $LASTEXITCODE"
    }

    $Deadline = (Get-Date).AddSeconds(30)

    do {
        Start-Sleep -Seconds 2
        $Amduwp = Get-AmduwpState
    } while (-not $Amduwp.Compatible -and (Get-Date) -lt $Deadline)

    if (-not $Amduwp.Compatible) {
        throw (
            'AMDUWP is not compatible after staging the exact known-good ' +
            'fallback. Failed checks: ' +
            (@($Amduwp.FailedChecks) -join ', ')
        )
    }

    if (
        $Amduwp.DriverVersion -ne $FallbackAmduwpVersion -or
        $Amduwp.InfSHA256 -ne $FallbackUwppairInfHash
    ) {
        throw (
            'A structurally compatible AMDUWP became active, but it was not ' +
            'the exact fallback package staged by this recovery path.'
        )
    }

    return [pscustomobject]@{
        State = $Amduwp
        Action = 'InstalledKnownGoodFallback'
        FallbackUsed = $true
        Uwppair = $Uwppair
    }
}

function Get-CurrentUserLegacyStoreAppx {
    return @(
        Get-AppxPackage `
            -Name $LegacyStoreAppxName `
            -ErrorAction Stop
    )
}

function Get-AllUsersLegacyStoreAppx {
    return @(
        Get-AppxPackage `
            -AllUsers `
            -Name $LegacyStoreAppxName `
            -ErrorAction Stop
    )
}

function Get-ProvisionedLegacyStoreAppx {
    return @(
        Get-AppxProvisionedPackage `
            -Online `
            -ErrorAction Stop |
            Where-Object {
                $_.DisplayName -eq $LegacyStoreAppxName
            }
    )
}

function Get-LegacyContextMenuBlocked {
    if (-not (Test-Path -LiteralPath $ShellBlockedPath)) {
        return $false
    }

    $BlockedKey = Get-ItemProperty `
        -LiteralPath $ShellBlockedPath `
        -ErrorAction SilentlyContinue

    return (
        $null -ne $BlockedKey -and
        $null -ne $BlockedKey.PSObject.Properties[$LegacyContextMenuClsid]
    )
}

function Set-LegacyContextMenuBlocked {
    if (-not (Test-Path -LiteralPath $ShellBlockedPath)) {
        New-Item -Path $ShellBlockedPath -Force | Out-Null
    }

    New-ItemProperty `
        -LiteralPath $ShellBlockedPath `
        -Name $LegacyContextMenuClsid `
        -Value 'Disabled legacy AMD .2089 desktop context-menu handler' `
        -PropertyType String `
        -Force |
        Out-Null
}

function Get-LegacyStoreState {
    $CurrentUserPackages = @(Get-CurrentUserLegacyStoreAppx)
    $AllUsersPackages = @(Get-AllUsersLegacyStoreAppx)
    $ProvisionedPackages = @(Get-ProvisionedLegacyStoreAppx)
    $LegacyClassPath =
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\PackagedCom\ClassIndex\' +
        $LegacyContextMenuClsid

    return [pscustomobject]@{
        CurrentUserPresent = $CurrentUserPackages.Count -gt 0
        CurrentUserPackageFullNames = @(
            $CurrentUserPackages |
                Select-Object -ExpandProperty PackageFullName -Unique
        )
        RegisteredOrStagedForAnyUser = $AllUsersPackages.Count -gt 0
        AllUsersPackageFullNames = @(
            $AllUsersPackages |
                Select-Object -ExpandProperty PackageFullName -Unique
        )
        AllUsersPackageUserInformation = @(
            $AllUsersPackages |
                ForEach-Object {
                    @($_.PackageUserInformation) |
                        ForEach-Object {
                            [string]$_
                        }
                }
        )
        Provisioned = $ProvisionedPackages.Count -gt 0
        ProvisionedPackageNames = @(
            $ProvisionedPackages |
                Select-Object -ExpandProperty PackageName -Unique
        )
        LegacyPackagedComRegistered =
            Test-Path -LiteralPath $LegacyClassPath
        LegacyContextMenuBlocked = Get-LegacyContextMenuBlocked
        Clean = (
            $CurrentUserPackages.Count -eq 0 -and
            $AllUsersPackages.Count -eq 0 -and
            $ProvisionedPackages.Count -eq 0
        )
    }
}

function Retire-LegacyStoreAppx {
    $Before = Get-LegacyStoreState
    $RemovedCurrentUserPackages = @()
    $RemovedProvisionedPackages = @()
    $LegacyPresenceDetected = (
        $Before.CurrentUserPresent -or
        $Before.RegisteredOrStagedForAnyUser -or
        $Before.Provisioned -or
        $Before.LegacyPackagedComRegistered
    )

    if ($LegacyPresenceDetected) {
        Set-LegacyContextMenuBlocked
    }

    if ($Before.CurrentUserPresent) {
        Stop-AmdSoftwareProcesses

        foreach ($Package in @(Get-CurrentUserLegacyStoreAppx)) {
            Write-Host (
                'Removing legacy .2089 Store AppX for the current user: ' +
                $Package.PackageFullName
            )

            $LastError = $null

            for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
                try {
                    Remove-AppxPackage `
                        -Package $Package.PackageFullName `
                        -ErrorAction Stop
                    $RemovedCurrentUserPackages +=
                        [string]$Package.PackageFullName
                    $LastError = $null
                    break
                }
                catch {
                    $LastError = $_
                    Stop-AmdSoftwareProcesses
                    Start-Sleep -Seconds 2
                }
            }

            if ($null -ne $LastError) {
                throw (
                    'Unable to remove the legacy .2089 Store AppX for the ' +
                    'current user: ' +
                    $LastError.Exception.Message
                )
            }
        }
    }
    else {
        Write-Host (
            '[INFO] Legacy .2089 Store AppX is not registered for the ' +
            'current user.'
        )
    }

    foreach ($ProvisionedPackage in @(Get-ProvisionedLegacyStoreAppx)) {
        Write-Host (
            'Removing legacy .2089 Store AppX provisioning: ' +
            $ProvisionedPackage.PackageName
        )

        $Removal = Remove-AppxProvisionedPackage `
            -Online `
            -PackageName $ProvisionedPackage.PackageName `
            -ErrorAction Stop

        if ($null -eq $Removal -or -not [bool]$Removal.Online) {
            throw (
                'Windows did not confirm online removal of the legacy ' +
                'Store AppX provisioning: ' +
                $ProvisionedPackage.PackageName
            )
        }

        $RemovedProvisionedPackages +=
            [string]$ProvisionedPackage.PackageName
    }

    $Deadline = (Get-Date).AddSeconds(60)

    do {
        Start-Sleep -Seconds 2
        $After = Get-LegacyStoreState
    } while (-not $After.Clean -and (Get-Date) -lt $Deadline)

    $Result = [ordered]@{
        SchemaVersion = 1
        CapturedAt = (Get-Date).ToString('o')
        PackageName = $LegacyStoreAppxName
        Before = $Before
        RemovedCurrentUserPackageFullNames =
            @($RemovedCurrentUserPackages | Sort-Object -Unique)
        RemovedProvisionedPackageNames =
            @($RemovedProvisionedPackages | Sort-Object -Unique)
        LegacyContextMenuBlocked = $After.LegacyContextMenuBlocked
        After = $After
        Complete = [bool]$After.Clean
        Method = (
            'Current-user package removal followed by online provisioning ' +
            'removal; no WindowsApps files were deleted manually.'
        )
    }

    Write-JsonFile `
        -Value $Result `
        -LiteralPath $LegacyStoreRetirementPath `
        -Depth 12

    if (-not $After.Clean) {
        throw (
            'The legacy .2089 Store AppX was not fully retired. It must be ' +
            'absent for the current user, absent from all-user registered/' +
            'staged state, and absent from provisioning. Evidence: ' +
            $LegacyStoreRetirementPath
        )
    }

    Write-Host (
        '[PASS] Legacy .2089 Store AppX is absent, unprovisioned, and not ' +
        'registered or staged.'
    )

    return [pscustomobject]$Result
}

function Get-ContextMenuState {
    $NativeClassPath =
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\PackagedCom\ClassIndex\' +
        $NativeContextMenuClsid
    $LegacyStore = Get-LegacyStoreState
    $Rsxcm = Get-RsxcmState

    return [pscustomobject]@{
        LegacyStoreAppxCurrentUserPresent =
            $LegacyStore.CurrentUserPresent
        LegacyStoreAppxRegisteredOrStaged =
            $LegacyStore.RegisteredOrStagedForAnyUser
        LegacyStoreAppxProvisioned =
            $LegacyStore.Provisioned
        LegacyPackagedComRegistered =
            $LegacyStore.LegacyPackagedComRegistered
        LegacyCLSID = $LegacyContextMenuClsid
        LegacyBlocked = $LegacyStore.LegacyContextMenuBlocked
        NativeCLSID = $NativeContextMenuClsid
        NativePackagedRegistration =
            Test-Path -LiteralPath $NativeClassPath
        NativeRsxcmMatch = $Rsxcm.Match
        Match = (
            $LegacyStore.Clean -and
            (
                -not $LegacyStore.LegacyPackagedComRegistered -or
                $LegacyStore.LegacyContextMenuBlocked
            ) -and
            (Test-Path -LiteralPath $NativeClassPath) -and
            $Rsxcm.Match
        )
    }
}

function Get-CNState {
    $CN = Get-ItemProperty `
        -LiteralPath 'HKLM:\SOFTWARE\AMD\CN' `
        -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Present = $null -ne $CN
        CNVersion = [string](
            Get-PropertyValue -Object $CN -Name 'CNVersion'
        )
        DriverVersion = [string](
            Get-PropertyValue -Object $CN -Name 'DriverVersion'
        )
    }
}

function Get-ReleaseTargets {
    param([Parameter(Mandatory)][string]$DeviceId)

    $EnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$DeviceId"
    $DriverKey = [string](
        Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop
    ).Driver

    if ([string]::IsNullOrWhiteSpace($DriverKey)) {
        throw 'Unable to resolve active display class key.'
    }

    $ClassPath =
        "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$DriverKey"
    $Video0 = [string](
        Get-ItemProperty `
            -LiteralPath 'HKLM:\HARDWARE\DEVICEMAP\VIDEO' `
            -ErrorAction Stop
    ).'\Device\Video0'
    $Match = [regex]::Match(
        $Video0,
        'Control\\Video\\(?<Guid>\{[0-9A-Fa-f-]+\})\\0000'
    )

    if (-not $Match.Success) {
        throw "Video0 is not mapped to the AMD stack: $Video0"
    }

    $Guid = $Match.Groups['Guid'].Value
    $VideoTargets = @()
    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'HARDWARE\DEVICEMAP\VIDEO'
    )

    if ($null -eq $Key) {
        throw 'Unable to open runtime video map.'
    }

    try {
        foreach ($ValueName in $Key.GetValueNames()) {
            if ($ValueName -notmatch '^\\Device\\Video\d+$') {
                continue
            }

            $Mapping = [string]$Key.GetValue($ValueName)
            $MappingMatch = [regex]::Match(
                $Mapping,
                'Control\\Video\\' + [regex]::Escape($Guid) +
                    '\\(?<Subkey>\d{4})$'
            )

            if ($MappingMatch.Success) {
                $VideoTargets +=
                    "HKLM:\SYSTEM\CurrentControlSet\Control\Video\$Guid\$($MappingMatch.Groups['Subkey'].Value)"
            }
        }
    }
    finally {
        $Key.Dispose()
    }

    return @(
        @($ClassPath) + @($VideoTargets) |
            Sort-Object -Unique
    )
}

function Set-FinalCompatibilityMetadata {
    param([Parameter(Mandatory)][string[]]$ReleaseTargets)

    $CnPath = 'HKLM:\SOFTWARE\AMD\CN'

    if (-not (Test-Path -LiteralPath $CnPath)) {
        New-Item -Path $CnPath -Force | Out-Null
    }

    Set-ItemProperty `
        -LiteralPath $CnPath `
        -Name 'CNVersion' `
        -Value $ExpectedFinalCNVersion `
        -Type String
    Set-ItemProperty `
        -LiteralPath $CnPath `
        -Name 'DriverVersion' `
        -Value $ExpectedFinalCNDriverVersion `
        -Type String

    foreach ($Target in $ReleaseTargets) {
        if (-not (Test-Path -LiteralPath $Target)) {
            throw "ReleaseVersion target is missing: $Target"
        }

        Set-ItemProperty `
            -LiteralPath $Target `
            -Name 'ReleaseVersion' `
            -Value $ExpectedStableRelease `
            -Type String
    }
}

function Get-ReleaseState {
    param([Parameter(Mandatory)][string[]]$ReleaseTargets)

    $Rows = @()

    foreach ($Target in $ReleaseTargets) {
        $Value = [string](
            Get-ItemProperty `
                -LiteralPath $Target `
                -Name 'ReleaseVersion' `
                -ErrorAction Stop
        ).ReleaseVersion

        $Rows += [pscustomobject]@{
            Path = $Target
            Value = $Value
            Match = $Value -eq $ExpectedStableRelease
        }
    }

    return @($Rows)
}

function Reset-CurrentUserCnCache {
    $CnCache = Join-Path $env:LOCALAPPDATA 'AMD\CN'
    $CacheBackup = ''
    $CacheResetStatus = 'NotRequired'

    if (-not (Test-Path -LiteralPath $CnCache -PathType Container)) {
        return [pscustomobject]@{
            BackupPath = $CacheBackup
            Status = $CacheResetStatus
        }
    }

    $CacheBackup = Join-Path `
        (Split-Path -Parent $CnCache) `
        ('CN.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $LastCacheError = $null

    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        Stop-AmdSoftwareProcesses
        Start-Sleep -Milliseconds 750

        try {
            Move-Item `
                -LiteralPath $CnCache `
                -Destination $CacheBackup `
                -Force `
                -ErrorAction Stop
            $LastCacheError = $null
            $CacheResetStatus = 'BackedUp'
            break
        }
        catch {
            $LastCacheError = $_
            Start-Sleep -Milliseconds 750
        }
    }

    if (Test-Path -LiteralPath $CnCache -PathType Container) {
        $CacheBackup = ''
        $CacheResetStatus = 'SkippedLocked'
        $Message = if ($null -ne $LastCacheError) {
            $LastCacheError.Exception.Message
        }
        else {
            'Unknown sharing violation.'
        }

        Write-Warning (
            'The existing CN cache remained locked after verified AMD ' +
            'processes were closed. The workflow will continue because ' +
            "cache reset is a compatibility aid. Last error: $Message"
        )
    }

    return [pscustomobject]@{
        BackupPath = $CacheBackup
        Status = $CacheResetStatus
    }
}

function Get-Script3CompletionState {
    $Result = Read-JsonFile -LiteralPath $ResultPath

    if ($null -eq $Result) {
        return [pscustomobject]@{
            Complete = $false
            RebootProven = $false
            InstalledAt = $null
            CurrentBoot = Get-CurrentBootTime
            Reason = 'ResultMissing'
        }
    }

    try {
        $InstalledAtText =
            [string](
                Get-PropertyValue `
                    -Object $Result `
                    -Name 'InstalledAt'
            )

        $InstalledAt =
            if ([string]::IsNullOrWhiteSpace($InstalledAtText)) {
                $null
            }
            else {
                [datetime]$InstalledAtText
            }

        $CurrentBoot = Get-CurrentBootTime
        $Gpu = Get-GpuSnapshot
        Assert-GpuSnapshot -Snapshot $Gpu
        $Desktop = Get-DesktopRadeonState
        $Rsxcm = Get-RsxcmState
        $ContextMenu = Get-ContextMenuState
        $Amduwp = Get-AmduwpState
        $NativeMsiRecord = Get-NativeMsiRecord
        $LegacyMsiRecord = Get-LegacyConflictingMsiRecord
        $CN = Get-CNState
        $ReleaseTargets = @(Get-ReleaseTargets -DeviceId $Gpu.DeviceID)
        $ReleaseState = @(Get-ReleaseState -ReleaseTargets $ReleaseTargets)
        $TestSigningEnabled = Get-TestSigningEnabled

        $SavedStateMatches = (
            [string](Get-PropertyValue -Object $Result -Name 'SoftwareMode') -eq
                'Native-2099-Store-Free' -and
            [bool](Get-PropertyValue -Object $Result -Name 'Installed') -and
            [bool](Get-PropertyValue -Object $Result -Name 'DashboardConfirmed') -and
            [bool](Get-PropertyValue -Object $Result -Name 'SingleDesktopEntryConfirmed') -and
            [string](Get-PropertyValue -Object $Result -Name 'DriverVersion') -eq
                $ExpectedDriverVersion -and
            [string](Get-PropertyValue -Object $Result -Name 'ActiveInfSHA256') -eq
                $ExpectedInfHash -and
            [string](Get-PropertyValue -Object $Result -Name 'KernelSHA256') -eq
                $ExpectedKernelHash -and
            [string](Get-PropertyValue -Object $Result -Name 'NativeMsiSHA256') -eq
                $ExpectedNativeMsiHash -and
            [string](Get-PropertyValue -Object $Result -Name 'NativeMsiDisplayVersion') -eq
                $ExpectedNativeMsiDisplayVersion -and
            [bool](Get-PropertyValue -Object $Result -Name 'LegacyStoreAppxAbsentSystemWide') -and
            -not [bool](Get-PropertyValue -Object $Result -Name 'LegacyStoreAppxProvisioned') -and
            -not [bool](Get-PropertyValue -Object $Result -Name 'LegacyStoreAppxRegisteredOrStaged') -and
            -not [bool](Get-PropertyValue -Object $Result -Name 'TestSigningEnabled') -and
            [bool](Get-PropertyValue -Object $Result -Name 'AMDUWPCompatible') -and
            [bool](Get-PropertyValue -Object $Result -Name 'LenovoExtensionSemanticCompatible') -and
            [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionVersion') -eq
                $ExpectedLenovoExtensionVersion -and
            [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionInfSHA256') -eq
                $ExpectedLenovoExtensionInfSHA256 -and
            [string](Get-PropertyValue -Object $Result -Name 'LenovoExtensionCatalogSHA256') -eq
                $ExpectedLenovoExtensionCatalogSHA256
        )

        $LiveStateMatches = (
            -not $TestSigningEnabled -and
            $null -ne $NativeMsiRecord -and
            $null -eq $LegacyMsiRecord -and
            $Desktop.Match -and
            $Rsxcm.Match -and
            $ContextMenu.Match -and
            $Amduwp.Compatible -and
            $CN.CNVersion -eq $ExpectedFinalCNVersion -and
            $CN.DriverVersion -eq $ExpectedFinalCNDriverVersion -and
            @($ReleaseState | Where-Object { -not $_.Match }).Count -eq 0
        )

        return [pscustomobject]@{
            Complete = [bool]($SavedStateMatches -and $LiveStateMatches)
            RebootProven = [bool](
                $null -ne $InstalledAt -and
                $CurrentBoot -gt $InstalledAt
            )
            InstalledAt = $InstalledAt
            CurrentBoot = $CurrentBoot
            Reason = if ($SavedStateMatches -and $LiveStateMatches) {
                'SavedAndLiveStateMatch'
            } else {
                'SavedOrLiveStateMismatch'
            }
        }
    }
    catch {
        return [pscustomobject]@{
            Complete = $false
            RebootProven = $false
            InstalledAt = $null
            CurrentBoot = Get-CurrentBootTime
            Reason = 'LiveValidationFailed: ' + $_.Exception.Message
        }
    }
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    return
}

New-Item `
    -ItemType Directory `
    -Path $WorkflowRoot, $LogRoot, $AssetRoot `
    -Force |
    Out-Null

Start-Transcript -LiteralPath $LogPath -Force | Out-Null

try {
    Write-Host ''
    Write-Host 'Legion Go AMD 26.6.4 Toolkit' -ForegroundColor White
    Write-Host 'Script 3 of 4: Install and validate AMD Software'
    Write-Host ''
    Write-Host 'Source format: Readable PowerShell'
    Write-Host 'Microsoft Store dependency: None'
    Write-Host 'Install confirmation: Required'
    Write-Host 'Windows restart confirmation: Required'
    Write-Host 'Forced application closure: Disabled'
    Write-Host 'Explorer termination: Disabled'
    Write-Host "State directory: $WorkflowRoot"
    Write-Host ''

    $LenovoCompatibilityContract = Get-LenovoCompatibilityContract
    $ExpectedFinalCNVersion = $LenovoCompatibilityContract.CNVersion
    $ExpectedFinalCNDriverVersion = $LenovoCompatibilityContract.CNDriverVersion
    $ExpectedStableRelease = $LenovoCompatibilityContract.StableReleaseVersion
    $ExpectedLenovoExtensionVersion = $LenovoCompatibilityContract.ExtensionVersion
    $ExpectedLenovoExtensionInfSHA256 = $LenovoCompatibilityContract.ExtensionInfSHA256
    $ExpectedLenovoExtensionCatalogSHA256 = $LenovoCompatibilityContract.ExtensionCatalogSHA256

    Write-Host (
        '[PASS] Dynamic Lenovo compatibility contract loaded: ' +
        $ExpectedLenovoExtensionVersion
    )

    $Completion = Get-Script3CompletionState

    if ($Completion.Complete) {
        if ($Completion.RebootProven) {
            Write-Host (
                '[PASS] Saved validation and the live system both prove ' +
                'post-restart AMD Software persistence.'
            ) -ForegroundColor Green
            Write-Host ''
            Write-Host ('=' * 72) -ForegroundColor White
            Write-Host 'SCRIPT 3 PASS: True' -ForegroundColor Green
            Write-Host 'Ready for Script 4: True' -ForegroundColor Green
            Write-Host "Result file: $ResultPath"
            Write-Host ('=' * 72) -ForegroundColor White
            return
        }

        Write-Host (
            '[PASS] AMD Software installation and live validation are complete.'
        ) -ForegroundColor Green
        Write-Host (
            '[INFO] The required post-install restart has not yet been proven.'
        ) -ForegroundColor Yellow
        [void](
            Request-FinalPersistenceRestart `
                -ScriptPath $PSCommandPath
        )
        return
    }

    if (-not (Test-Stage04Complete)) {
        throw (
            'Script 2 is not complete. The exact passing normal-signing ' +
            "result is required: $Stage04ResultPath"
        )
    }

    Write-Host '=== CURRENT BOOT TRUST STATE ===' -ForegroundColor White
    $SecureBootEnabled = Get-SecureBootEnabled
    $TestSigningEnabled = Get-TestSigningEnabled
    Write-Host "Secure Boot enabled: $SecureBootEnabled"
    Write-Host "Test Signing enabled: $TestSigningEnabled"

    if ($TestSigningEnabled) {
        throw 'Script 3 requires Test Signing to be off.'
    }

    Write-Host '[PASS] Test Signing is off.'

    Write-Host ''
    Write-Host '=== VERIFY CORRECTED DISPLAY DRIVER ===' -ForegroundColor White
    $GpuBefore = Get-GpuSnapshot
    $GpuBefore | Format-List
    Assert-GpuSnapshot -Snapshot $GpuBefore
    Write-Host '[PASS] Corrected AMD 26.6.4 display driver is healthy.'

    Write-Host ''
    Write-Host '=== REVALIDATE SCRIPT 1 AMD 26.6.4 CONTAINER ===' `
        -ForegroundColor White
    $OfficialInstaller = Resolve-OfficialInstaller
    [pscustomobject]@{
        Path = $OfficialInstaller.Item.FullName
        Length = [int64]$OfficialInstaller.Item.Length
        SHA256 = $OfficialInstaller.SHA256
        SignatureStatus = $OfficialInstaller.SignatureStatus
        Signer = $OfficialInstaller.Signer
        RecordedIdentityCopyCount = $OfficialInstaller.DuplicateRecordedMatchCount
    } | Format-List
    Write-Host '[PASS] Script 1 recorded AMD 26.6.4 installer container revalidated.'

    Write-Host ''
    Write-Host '=== EXTRACT EXACT NATIVE .2099 MSI ===' `
        -ForegroundColor White
    $SevenZipPath = Resolve-SevenZipPath
    Write-Host "7-Zip: $SevenZipPath"
    $NativeMsiSource = Get-OrExtractNativeMsi `
        -OfficialInstaller $OfficialInstaller `
        -SevenZipPath $SevenZipPath
    $NativeMsiIdentity = Assert-NativeMsiIdentity `
        -LiteralPath $NativeMsiSource.Item.FullName
    [pscustomobject]@{
        Path = $NativeMsiSource.Item.FullName
        Length = [int64]$NativeMsiSource.Item.Length
        SHA256 = $ExpectedNativeMsiHash
        ProductCode = $NativeMsiIdentity.ProductCode
        ProductVersion = $NativeMsiIdentity.ProductVersion
        SignatureStatus = $NativeMsiIdentity.SignatureStatus
        Signer = $NativeMsiIdentity.Signer
        NestedSource = $NativeMsiSource.NestedSource
        ExtractedThisRun = $NativeMsiSource.ExtractedThisRun
    } | Format-List
    Write-Host '[PASS] Exact native .2099 MSI identity verified.'

    Write-Host ''
    Write-Host '=== CONFIRM INSTALLED-SYSTEM CHANGES ===' `
        -ForegroundColor White
    Write-Host (
        'Script 3 may install or repair native AMD Software, remove the ' +
        'conflicting legacy .2089 MSI and Store AppX state, update AMD/Lenovo ' +
        'compatibility metadata, back up the current-user AMD CN cache, and ' +
        'update the current-user shell-extension block list.'
    ) -ForegroundColor Yellow
    Write-Host (
        'Explorer will not be terminated. Open applications will not be ' +
        'force-closed by the final restart.'
    )

    $InstallApproved =
        Confirm-UserAction `
            -Prompt 'Continue with Script 3 installed-system changes?'

    if (-not $InstallApproved) {
        Write-Host ''
        Write-Host '[INFO] Script 3 was cancelled before installed-system changes.' `
            -ForegroundColor Yellow
        Write-Host (
            'The exact source may have been verified and preserved, but AMD ' +
            'Software, AppX state, metadata, and boot state were not changed.'
        )
        return
    }

    Write-Host ''
    Write-Host '=== VERIFY COMPATIBLE MICROSOFT-SIGNED AMDUWP ===' `
        -ForegroundColor White
    $AmduwpBundle = Ensure-AmduwpHealthy
    $AmduwpBundle.State | Format-List
    Write-Host (
        '[PASS] Compatible AMDUWP is healthy: ' +
        "$($AmduwpBundle.State.DriverVersion) / $($AmduwpBundle.Action)"
    )

    Write-Host ''
    Write-Host '=== RETIRE CONFLICTING .2089 MSI IF PRESENT ===' `
        -ForegroundColor White
    [void](Remove-LegacyConflictingMsi)

    Write-Host ''
    Write-Host '=== INSTALL EXACT NATIVE AMD SOFTWARE .2099 ===' `
        -ForegroundColor White
    $NativeInstallAction = Install-Or-RepairNativeMsi `
        -MsiPath $NativeMsiSource.Item.FullName
    $NativeMsiRecord = Get-NativeMsiRecord
    $Desktop = Get-DesktopRadeonState
    $Rsxcm = Get-RsxcmState
    $NativeMsiRecord | Format-List
    $Desktop | Format-List
    $Rsxcm | Format-List

    if ($null -eq $NativeMsiRecord -or -not $Desktop.Match -or -not $Rsxcm.Match) {
        throw 'The exact native .2099 installed state did not validate.'
    }

    Write-Host ''
    Write-Host '=== RETIRE LEGACY .2089 STORE APPX ===' `
        -ForegroundColor White
    $LegacyStoreRetirement = Retire-LegacyStoreAppx
    $LegacyStoreRetirement.After | Format-List
    Invoke-ShellAssociationRefresh
    Start-Sleep -Seconds 3
    $ContextMenu = Get-ContextMenuState
    $ContextMenu | Format-List

    if (-not $ContextMenu.Match) {
        throw (
            'The Store-free native context-menu state did not validate. ' +
            'The legacy Store package must be fully absent and native RSXCM ' +
            'must remain healthy.'
        )
    }

    Write-Host (
        '[PASS] Native RSXCM is active with no legacy Store package present.'
    )

    Write-Host ''
    Write-Host '=== RESTORE LENOVO COMPATIBILITY METADATA ===' `
        -ForegroundColor White
    $ReleaseTargets = @(Get-ReleaseTargets -DeviceId $GpuBefore.DeviceID)
    Set-FinalCompatibilityMetadata -ReleaseTargets $ReleaseTargets
    $FinalCN = Get-CNState
    $ReleaseState = @(Get-ReleaseState -ReleaseTargets $ReleaseTargets)
    $FinalCN | Format-List
    $ReleaseState | Format-Table -AutoSize

    if (
        $FinalCN.CNVersion -ne $ExpectedFinalCNVersion -or
        $FinalCN.DriverVersion -ne $ExpectedFinalCNDriverVersion
    ) {
        throw 'Final Lenovo-compatible CN metadata was not restored.'
    }

    if (@($ReleaseState | Where-Object { -not $_.Match }).Count -gt 0) {
        throw 'One or more active ReleaseVersion values were not restored.'
    }

    Write-Host '[PASS] Lenovo-compatible metadata restored.'

    Write-Host ''
    Write-Host '=== RETIRE OBSOLETE COMPATIBILITY LAUNCHER ===' `
        -ForegroundColor White

    foreach ($LegacyPath in @($LegacyShortcutPath, $LegacyLauncherPath)) {
        if (Test-Path -LiteralPath $LegacyPath) {
            Remove-Item `
                -LiteralPath $LegacyPath `
                -Force `
                -ErrorAction Stop
            Write-Host "Removed obsolete launcher asset: $LegacyPath"
        }
    }

    Write-Host '[PASS] Obsolete temporary launcher is absent.'

    Write-Host ''
    Write-Host '=== RESET CURRENT-USER CN CACHE ===' `
        -ForegroundColor White
    $CacheResult = Reset-CurrentUserCnCache
    $CacheResult | Format-List

    Write-Host ''
    Write-Host '=== LAUNCH NATIVE AMD SOFTWARE .2099 ===' `
        -ForegroundColor White
    Stop-AmdSoftwareProcesses
    Start-Sleep -Seconds 1
    Start-Process -FilePath $Desktop.Path

    $Window = $null
    $Deadline = (Get-Date).AddSeconds(45)

    do {
        Start-Sleep -Seconds 1
        $Window = Get-Process `
            -Name RadeonSoftware `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.MainWindowHandle -ne 0
            } |
            Select-Object -First 1
    } while ($null -eq $Window -and (Get-Date) -lt $Deadline)

    if ($null -eq $Window) {
        throw 'AMD Software did not open a visible native window.'
    }

    $ProcessRecord = Get-CimInstance Win32_Process `
        -Filter "ProcessId=$($Window.Id)" `
        -ErrorAction Stop

    if (
        [string]$ProcessRecord.ExecutablePath -ine $Desktop.Path
    ) {
        throw (
            'The visible dashboard did not run from the expected native path: ' +
            [string]$ProcessRecord.ExecutablePath
        )
    }

    Write-Host "Visible window PID: $($Window.Id)"
    Write-Host "Visible window title: $($Window.MainWindowTitle)"
    Write-Host "Visible executable: $($ProcessRecord.ExecutablePath)"
    Write-Host ''
    $Confirmation = Read-Host (
        'Does native .2099 show the normal dashboard AND exactly one ' +
        'desktop right-click AMD: Radeon Software entry? Type YES'
    )

    if ($Confirmation.Trim().ToUpperInvariant() -ne 'YES') {
        throw 'The native dashboard and single desktop entry were not confirmed.'
    }

    Write-Host '[PASS] Native dashboard and one desktop entry confirmed.'

    $GpuAfter = Get-GpuSnapshot
    Assert-GpuSnapshot -Snapshot $GpuAfter
    $FinalCN = Get-CNState
    $ReleaseState = @(Get-ReleaseState -ReleaseTargets $ReleaseTargets)
    $Amduwp = Get-AmduwpState
    $NativeMsiRecord = Get-NativeMsiRecord
    $LegacyMsiRecord = Get-LegacyConflictingMsiRecord
    $Desktop = Get-DesktopRadeonState
    $Rsxcm = Get-RsxcmState
    $ContextMenu = Get-ContextMenuState

    if (
        -not $Amduwp.Compatible -or
        $null -eq $NativeMsiRecord -or
        $null -ne $LegacyMsiRecord -or
        -not $Desktop.Match -or
        -not $Rsxcm.Match -or
        -not $ContextMenu.Match
    ) {
        throw 'The final Store-free native .2099 state changed during validation.'
    }

    if (
        $FinalCN.CNVersion -ne $ExpectedFinalCNVersion -or
        $FinalCN.DriverVersion -ne $ExpectedFinalCNDriverVersion -or
        @($ReleaseState | Where-Object { -not $_.Match }).Count -gt 0
    ) {
        throw 'Final compatibility metadata changed during launch validation.'
    }

    if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
        $PreviousResultPath = Join-Path `
            $LogRoot `
            "amd-software-install-result-before-store-free-$Timestamp.json"
        Copy-Item `
            -LiteralPath $ResultPath `
            -Destination $PreviousResultPath `
            -Force
    }

    $InstallResult = [ordered]@{
        SchemaVersion = 9
        Workflow = 'LegionGo-AMD-26.6.4'
        SoftwareMode = 'Native-2099-Store-Free'
        StoreDependency = $false
        Installed = $true
        DashboardConfirmed = $true
        SingleDesktopEntryConfirmed = $true
        InstalledAt = (Get-Date).ToString('o')

        OfficialInstallerPath = $OfficialInstaller.Item.FullName
        OfficialInstallerLength = [int64]$OfficialInstaller.Item.Length
        OfficialInstallerSHA256 = $OfficialInstaller.SHA256
        OfficialInstallerSigner = $OfficialInstaller.Signer
        NativeMsiNestedSource = $NativeMsiSource.NestedSource
        NativeMsiExtractedThisRun = $NativeMsiSource.ExtractedThisRun
        NativeMsiPath = $NativeMsiSource.Item.FullName
        NativeMsiLength = [int64]$NativeMsiSource.Item.Length
        NativeMsiSHA256 = $ExpectedNativeMsiHash
        NativeMsiDisplayVersion = [string]$NativeMsiRecord.DisplayVersion
        NativeMsiProductCode = [string]$NativeMsiRecord.KeyName
        NativeMsiRegistryPath = [string]$NativeMsiRecord.RegistryPath
        NativeMsiInstallAction = $NativeInstallAction.Action
        NativeMsiInstallExitCode = $NativeInstallAction.InstallExitCode
        NativeMsiUninstallExitCode = $NativeInstallAction.UninstallExitCode
        NativeMsiInstallLog = $NativeInstallAction.MsiLog
        NativeMsiUninstallLog = $NativeInstallAction.UninstallLog

        DesktopRadeonSoftwarePath = $Desktop.Path
        DesktopRadeonSoftwareLength = $Desktop.Length
        DesktopRadeonSoftwareFileVersion = $Desktop.FileVersion
        DesktopRadeonSoftwareSHA256 = $Desktop.SHA256
        ConfirmedDashboardProcessPath = [string]$ProcessRecord.ExecutablePath

        RsxcmPackageFullName = $Rsxcm.PackageFullName
        RsxcmVersion = $Rsxcm.Version
        RsxcmRsxPackageSHA256 = $Rsxcm.RsxPackageSHA256
        NativeContextMenuCLSID = $ContextMenu.NativeCLSID
        NativeContextMenuRegistered = $ContextMenu.NativePackagedRegistration

        LegacyStoreAppxName = $LegacyStoreAppxName
        LegacyStoreAppxAbsentSystemWide = (
            -not $ContextMenu.LegacyStoreAppxCurrentUserPresent -and
            -not $ContextMenu.LegacyStoreAppxRegisteredOrStaged -and
            -not $ContextMenu.LegacyStoreAppxProvisioned
        )
        LegacyStoreAppxRegisteredOrStaged =
            $ContextMenu.LegacyStoreAppxRegisteredOrStaged
        LegacyStoreAppxProvisioned =
            $ContextMenu.LegacyStoreAppxProvisioned
        LegacyStoreAppxRetirementResultPath =
            $LegacyStoreRetirementPath
        LegacyStoreAppxCurrentUserPackagesRemovedThisRun =
            @($LegacyStoreRetirement.RemovedCurrentUserPackageFullNames)
        LegacyStoreAppxProvisionedPackagesRemovedThisRun =
            @($LegacyStoreRetirement.RemovedProvisionedPackageNames)
        LegacyContextMenuCLSID = $ContextMenu.LegacyCLSID
        LegacyContextMenuRegistered =
            $ContextMenu.LegacyPackagedComRegistered
        LegacyContextMenuBlocked = $ContextMenu.LegacyBlocked
        LegacyConflictingMsiProductRetired = $null -eq $LegacyMsiRecord

        UwppairInfPath = $AmduwpBundle.Uwppair.InfPath
        UwppairInfSHA256 = $AmduwpBundle.Uwppair.InfSHA256
        UwppairCatalogPath = $AmduwpBundle.Uwppair.CatalogPath
        UwppairCatalogSHA256 = $AmduwpBundle.Uwppair.CatalogSHA256
        AMDUWPDeviceID = $Amduwp.DeviceID
        AMDUWPInfName = $Amduwp.InfName
        AMDUWPVersion = $Amduwp.DriverVersion
        AMDUWPCompatible = $Amduwp.Compatible
        AMDUWPCompatibilityAction = $AmduwpBundle.Action
        AMDUWPFallbackUsed = $AmduwpBundle.FallbackUsed
        AMDUWPProvider = $Amduwp.Provider
        AMDUWPSigner = $Amduwp.Signer
        AMDUWPInfSHA256 = $Amduwp.InfSHA256
        AMDUWPCatalogName = $Amduwp.CatalogName
        AMDUWPStructureChecks = $Amduwp.StructureChecks
        AMDUWPFailedChecks = @($Amduwp.FailedChecks)

        LenovoExtensionSemanticCompatible = $true
        LenovoExtensionVersion = $ExpectedLenovoExtensionVersion
        LenovoExtensionInfSHA256 = $ExpectedLenovoExtensionInfSHA256
        LenovoExtensionCatalogSHA256 = $ExpectedLenovoExtensionCatalogSHA256
        CNVersion = $FinalCN.CNVersion
        CNDriverVersion = $FinalCN.DriverVersion
        StableReleaseVersion = $ExpectedStableRelease
        ReleaseTargets = @($ReleaseState)
        CacheBackupPath = $CacheResult.BackupPath
        CacheResetStatus = $CacheResult.Status
        ShellRefreshMethod = 'SHChangeNotify'
        ExplorerTerminated = $false
        RestartRequired = $true

        ActiveINF = $GpuAfter.ActiveINF
        DriverVersion = $GpuAfter.DriverVersion
        ActiveInfSHA256 = $GpuAfter.ActiveInfSHA256
        KernelService = $GpuAfter.KernelService
        KernelSHA256 = $GpuAfter.KernelSHA256
        SecureBootEnabled = $SecureBootEnabled
        TestSigningEnabled = $false
        NextStage = '06-Final-Persistence-Audit-Store-Free'
        LogPath = $LogPath
    }

    Write-JsonFile `
        -Value $InstallResult `
        -LiteralPath $ResultPath `
        -Depth 14

    $State = [ordered]@{
        SchemaVersion = 9
        Workflow = 'LegionGo-AMD-26.6.4'
        Stage = 'Awaiting-Store-Free-Final-Audit-Reboot'
        UpdatedAt = (Get-Date).ToString('o')
        AMDSoftwareMode = 'Native-2099-Store-Free'
        StoreDependency = $false
        DashboardConfirmed = $true
        SingleDesktopEntryConfirmed = $true
        ActiveINF = $GpuAfter.ActiveINF
        DriverVersion = $GpuAfter.DriverVersion
        KernelService = $GpuAfter.KernelService
        LenovoExtensionSemanticCompatible = $true
        LenovoExtensionVersion = $ExpectedLenovoExtensionVersion
        LenovoExtensionInfSHA256 = $ExpectedLenovoExtensionInfSHA256
        LenovoExtensionCatalogSHA256 = $ExpectedLenovoExtensionCatalogSHA256
        CNVersion = $FinalCN.CNVersion
        CNDriverVersion = $FinalCN.DriverVersion
        NativeMsiDisplayVersion = [string]$NativeMsiRecord.DisplayVersion
        NativeRadeonSoftwareVersion = $Desktop.FileVersion
        NativeRsxcmVersion = $Rsxcm.Version
        LegacyStoreAppxAbsentSystemWide = $true
        LegacyStoreAppxProvisioned = $false
        LegacyStoreAppxRegisteredOrStaged = $false
        AMDUWPVersion = $Amduwp.DriverVersion
        AMDUWPCompatible = $Amduwp.Compatible
        AMDUWPInfSHA256 = $Amduwp.InfSHA256
        AMDUWPSigner = $Amduwp.Signer
        AMDUWPFallbackUsed = $AmduwpBundle.FallbackUsed
        TestSigningEnabled = $false
        SecureBootEnabled = $SecureBootEnabled
        ShellRefreshMethod = 'SHChangeNotify'
        ExplorerTerminated = $false
        RestartRequired = $true
        NextStage = '06-Final-Persistence-Audit-Store-Free'
        ResultPath = $ResultPath
        LogPath = $LogPath
    }

    Write-JsonFile `
        -Value $State `
        -LiteralPath $StatePath `
        -Depth 8

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host 'SCRIPT 3 INSTALLATION PASS: True' `
        -ForegroundColor Green
    Write-Host 'Microsoft Store dependency: False' `
        -ForegroundColor Green
    Write-Host "Native frontend: $($Desktop.FileVersion)"
    Write-Host "Native RSXCM:    $($Rsxcm.Version)"
    Write-Host 'Legacy Store AppX system-wide: Absent and unprovisioned'
    Write-Host "AMDUWP:          $($Amduwp.DriverVersion) / Compatible=$($Amduwp.Compatible) / $($AmduwpBundle.Action)"
    Write-Host 'Explorer terminated: False'
    Write-Host "Result file:     $ResultPath"
    Write-Host "Log file:        $LogPath"
    Write-Host 'Ready for Script 4: False (restart required)' `
        -ForegroundColor Yellow
    Write-Host ('=' * 72) -ForegroundColor White

    [void](
        Request-FinalPersistenceRestart `
            -ScriptPath $PSCommandPath
    )
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }
}
