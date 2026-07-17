#requires -Version 5.1

<#
.SYNOPSIS
    Script 4 of the Legion Go 1 Graphics Driver Toolkit Public Beta v2.0 workflow.

.DESCRIPTION
    Performs the final post-restart persistence audit for the corrected AMD
    26.6.4 driver and native AMD Software arrangement.

    The audit verifies the live GPU, corrected INF and kernel identities,
    normal Windows signing state, local catalog trust, the registered official
    Microsoft-signed AMD catalog, Lenovo display extension, AMDUWP, native AMD
    Software .2099, native RSXCM 22.10.0.0, Lenovo compatibility metadata,
    absence of the legacy .2089 Store AppX, and exactly one AMD desktop
    context-menu entry.

    Script 4 does not install, remove, repair, or reconfigure drivers or AMD
    Software. It writes audit state, logs, XML inventory, and a desktop report;
    it also opens the native AMD Software dashboard for manual confirmation.

    Secure Boot is recorded but is not required to be enabled. Microsoft Store
    access is not used.

.NOTES
    Public Beta v2.0. Read-only final audit with readable source, safe
    dashboard launch, registered-catalog verification, atomic result
    publication, explicit verification of Script 3's non-destructive shell
    handoff, and support for intentional blank lines in the final report.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$WorkflowRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'
$StatePath = Join-Path $WorkflowRoot 'workflow-state.json'
$SoftwareResultPath =
    Join-Path $WorkflowRoot 'amd-software-install-result.json'
$Stage04ResultPath =
    Join-Path $WorkflowRoot 'post-testsigning-validation.json'
$CatalogSigningStatePath =
    Join-Path $WorkflowRoot 'catalog-signing-state.json'
$ResultPath = Join-Path $WorkflowRoot 'final-audit-result.json'
$LogRoot = Join-Path $WorkflowRoot 'Logs'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$TranscriptPath = Join-Path `
    $LogRoot `
    "04-Final-Persistence-Audit-$Timestamp.log"
$PnPInventoryPath = Join-Path `
    $LogRoot `
    "04-PnP-Driver-Inventory-$Timestamp.xml"
$DesktopReport = Join-Path `
    ([Environment]::GetFolderPath('Desktop')) `
    'LegionGo-AMD-26.6.4-Final-Report.txt'

$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$ExpectedSoftwareMode = 'Native-2099-Store-Free'
$ExpectedDriverVersion = '32.0.31021.5001'
$ExpectedInfHash =
    '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'
$ExpectedKernelHash =
    '3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F'
$ExpectedOfficialCatalogHash =
    'F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C'
$ExpectedExtensionClassGuid = '{e2f84ce7-8efa-411c-aa69-97454ca4cb57}'
$ExpectedExtensionId = '{07A2A561-D001-4503-B239-EF2FE0379EFB}'
$ExpectedExtensionTargetHardwareId =
    'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$ExpectedExtensionCatalogSignerPattern =
    'Microsoft Windows Hardware Compatibility Publisher'
$ExpectedLegacyMsiDisplayVersion = '2026.0309.1733.2089'
$ExpectedLegacyMsiProductCode = '{AA16A900-8FCB-442D-969E-8A3EA516B506}'
$ExpectedNativeMsiDisplayVersion = '2026.0626.1637.2099'
$ExpectedNativeMsiProductCode = '{DA10E1F9-4EFE-46EB-9B71-54BD5676D810}'
$ExpectedNativeMsiHash =
    '6E44F1C9048C3990EA146DCAEB5C7A7C6373994D344498C14D8C233D01074B7E'

$ExpectedDesktopRadeonLength = [int64]29045008
$ExpectedDesktopRadeonVersion = '10,01,02,2099'
$ExpectedDesktopRadeonHash =
    'E24586BA9B07CC2CE217AC6B11B1618C7F134264EF8B534EC77C2645CF92342B'
$ExpectedDesktopRadeonPath =
    'C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe'

$ExpectedRsxcmName = 'AdvancedMicroDevicesInc-RSXCM'
$ExpectedRsxcmVersion = '22.10.0.0'
$ExpectedNativeRsxPackageHash =
    '1B8EFAE7FECA03E10CA15C88527F2E9C1F8B48E688F5C5565B04D759A7D8BB88'
$LegacyStoreAppxName = 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'
$LegacyContextMenuClsid = '{6767B3BC-8FF7-11EC-B909-0242AC120002}'
$NativeContextMenuClsid = '{FDADFEE3-02D1-4E7C-A511-380F4C98D73B}'
$ShellBlockedPath =
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'

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

$HardwareId = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'
$DashboardTimeoutSeconds = 30

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

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    return
}

New-Item `
    -ItemType Directory `
    -Path $WorkflowRoot, $LogRoot `
    -Force |
    Out-Null

Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null

function Get-SHA256 {
    param([Parameter(Mandatory)][string]$LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-PropertyValue {
    param([AllowNull()]$Object,[Parameter(Mandatory)][string]$Name)
    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $null }
    return $Property.Value
}


function Get-LenovoCompatibilityContract {
    if (-not (Test-Path -LiteralPath $Stage04ResultPath -PathType Leaf)) {
        throw "Script 2 result is missing: $Stage04ResultPath"
    }

    $Result = Get-Content -LiteralPath $Stage04ResultPath -Raw | ConvertFrom-Json
    if (
        -not [bool](Get-PropertyValue -Object $Result -Name 'Validated') -or
        -not [bool](Get-PropertyValue -Object $Result -Name 'LenovoExtensionSemanticCompatible')
    ) {
        throw 'Script 2 did not record a compatible Lenovo extension contract.'
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
        'ExtensionVersion','ExtensionInfSHA256','ExtensionCatalogSHA256',
        'CNVersion','CNDriverVersion','StableReleaseVersion'
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$Contract.$Name)) {
            throw "Lenovo compatibility field is missing: $Name"
        }
    }

    if ($Contract.CNDriverVersion -ne $Contract.ExtensionVersion) {
        throw 'Recorded Lenovo CN DriverVersion is incoherent.'
    }

    return $Contract
}

function Add-Check {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.IList]$Checks,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Details = ''
    )
    [void]$Checks.Add([pscustomobject]@{ Name=$Name; Passed=$Passed; Details=$Details })
    $Prefix = if ($Passed) { '[PASS]' } else { '[FAIL]' }
    Write-Host "$Prefix $Name"
    if (-not [string]::IsNullOrWhiteSpace($Details)) { Write-Host "       $Details" }
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
    $Driver = Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceID -Like $GpuPattern | Select-Object -First 1
    $Device = Get-CimInstance Win32_PnPEntity | Where-Object DeviceID -Like $GpuPattern | Select-Object -First 1
    if ($null -eq $Driver -or $null -eq $Device) { throw 'The Legion Go AMD GPU was not found.' }
    $InfPath = Join-Path $env:windir "INF\$($Driver.InfName)"
    $EnumPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\$($Device.DeviceID)"
    $KernelService = [string](Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop).Service
    $Service = Get-CimInstance Win32_SystemDriver | Where-Object Name -EQ $KernelService | Select-Object -First 1
    if ($null -eq $Service) { throw "GPU kernel service not found: $KernelService" }
    $KernelPath = Resolve-KernelPath -RawPath ([string]$Service.PathName)
    return [pscustomobject]@{
        DeviceName=[string]$Device.Name
        DeviceID=[string]$Device.DeviceID
        ActiveINF=[string]$Driver.InfName
        DriverVersion=[string]$Driver.DriverVersion
        ActiveInfPath=$InfPath
        ActiveInfSHA256=Get-SHA256 -LiteralPath $InfPath
        Status=[string]$Device.Status
        ProblemCode=[int]$Device.ConfigManagerErrorCode
        KernelService=$KernelService
        KernelState=[string]$Service.State
        KernelPath=$KernelPath
        KernelSHA256=Get-SHA256 -LiteralPath $KernelPath
    }
}

function Get-TestSigningEnabled {
    $Output = & bcdedit.exe /enum '{current}' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read current BCD state.' }
    $Line = $Output | Where-Object { $_ -match '(?i)^testsigning\s+' } | Select-Object -First 1
    if ($null -eq $Line) { return $false }
    return $Line -match '(?i)\bYes\b|\bOn\b|\bTrue\b'
}

function Get-SecureBootState {
    try {
        return [pscustomobject]@{
            Known = $true
            Enabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
            Error = ''
        }
    }
    catch {
        return [pscustomobject]@{
            Known = $false
            Enabled = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-AmdSettingsRecords {
    $Records = @()
    foreach ($Root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )) {
        foreach ($Key in @(Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue)) {
            $Record = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
            $Name = [string](Get-PropertyValue -Object $Record -Name 'DisplayName')
            if ($Name -ne 'AMD Settings') { continue }
            $Records += [pscustomobject]@{
                RegistryPath=$Key.PSPath
                KeyName=[string]$Key.PSChildName
                DisplayName=$Name
                DisplayVersion=[string](Get-PropertyValue -Object $Record -Name 'DisplayVersion')
                UninstallString=[string](Get-PropertyValue -Object $Record -Name 'UninstallString')
            }
        }
    }
    return @($Records)
}

function Get-NativeMsiRecord {
    return @(
        Get-AmdSettingsRecords |
            Where-Object {
                $_.KeyName -ieq $ExpectedNativeMsiProductCode -and
                $_.DisplayVersion -eq $ExpectedNativeMsiDisplayVersion
            } |
            Select-Object -First 1
    )[0]
}

function Get-LegacyConflictingMsiRecord {
    return @(
        Get-AmdSettingsRecords |
            Where-Object {
                $_.KeyName -ieq $ExpectedLegacyMsiProductCode -or
                $_.DisplayVersion -eq $ExpectedLegacyMsiDisplayVersion
            } |
            Select-Object -First 1
    )[0]
}

function Get-DesktopRadeonState {
    $Path = $ExpectedDesktopRadeonPath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [pscustomobject]@{Path=$Path;Match=$false;Length=$null;FileVersion='';SHA256='';SignatureStatus=''} }
    $Item = Get-Item -LiteralPath $Path
    $Signature = Get-AuthenticodeSignature -LiteralPath $Path
    return [pscustomobject]@{
        Path=$Path
        Match=([int64]$Item.Length -eq $ExpectedDesktopRadeonLength -and [string]$Item.VersionInfo.FileVersion -eq $ExpectedDesktopRadeonVersion -and (Get-SHA256 -LiteralPath $Path) -eq $ExpectedDesktopRadeonHash -and $Signature.Status -eq 'Valid')
        Length=[int64]$Item.Length
        FileVersion=[string]$Item.VersionInfo.FileVersion
        SHA256=Get-SHA256 -LiteralPath $Path
        SignatureStatus=[string]$Signature.Status
        SignerSubject=$(if ($null -ne $Signature.SignerCertificate) { [string]$Signature.SignerCertificate.Subject } else { '' })
    }
}

function Get-CNState {
    $CN = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\AMD\CN' -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Present=($null -ne $CN)
        CNVersion=[string](Get-PropertyValue -Object $CN -Name 'CNVersion')
        DriverVersion=[string](Get-PropertyValue -Object $CN -Name 'DriverVersion')
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

function Get-ReleaseTargets {
    param([Parameter(Mandatory)][string]$DeviceId)
    $EnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$DeviceId"
    $DriverKey = [string](Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop).Driver
    $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$DriverKey"
    $Video0 = [string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DEVICEMAP\VIDEO' -ErrorAction Stop).'\Device\Video0'
    $Match = [regex]::Match($Video0, 'Control\\Video\\(?<Guid>\{[0-9A-Fa-f-]+\})\\0000')
    if (-not $Match.Success) { throw "Video0 mapping is invalid: $Video0" }
    $Guid = $Match.Groups['Guid'].Value
    $Targets = @($ClassPath)
    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('HARDWARE\DEVICEMAP\VIDEO')
    if ($null -eq $Key) { throw 'Unable to open runtime video map.' }
    try {
        foreach ($ValueName in $Key.GetValueNames()) {
            if ($ValueName -notmatch '^\\Device\\Video\d+$') { continue }
            $Mapping = [string]$Key.GetValue($ValueName)
            $MappingMatch = [regex]::Match($Mapping, 'Control\\Video\\' + [regex]::Escape($Guid) + '\\(?<Subkey>\d{4})$')
            if ($MappingMatch.Success) { $Targets += "HKLM:\SYSTEM\CurrentControlSet\Control\Video\$Guid\$($MappingMatch.Groups['Subkey'].Value)" }
        }
    }
    finally { $Key.Dispose() }
    return @($Targets | Sort-Object -Unique)
}

function Get-ReleaseState {
    param([Parameter(Mandatory)][string[]]$Targets)
    $Rows = @()
    foreach ($Target in $Targets) {
        $Value = [string](Get-ItemProperty -LiteralPath $Target -Name 'ReleaseVersion' -ErrorAction Stop).ReleaseVersion
        $Rows += [pscustomobject]@{Path=$Target;Value=$Value;Match=($Value -eq $ExpectedStableRelease)}
    }
    return @($Rows)
}

function Get-ExtensionPropertyValue {
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

function Normalize-InfLine {
    param([AllowEmptyString()][string]$Line)

    if ($null -eq $Line) {
        return ''
    }

    $WithoutComment = ($Line -split ';', 2)[0]
    return (($WithoutComment -replace '\s+', '').ToLowerInvariant())
}

function Get-InfValue {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines = @(),

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($Line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }

        $Match = [regex]::Match(
            $Line,
            ('^\s*' + [regex]::Escape($Name) + '\s*=\s*([^;\r\n]+)'),
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )

        if ($Match.Success) {
            return $Match.Groups[1].Value.Trim().Trim('"')
        }
    }

    return ''
}

function Resolve-LenovoExtensionPackage {
    param(
        [Parameter(Mandatory)][string]$OriginalName,
        [Parameter(Mandatory)][string]$PublishedInfPath
    )

    $PublishedHash = Get-SHA256 -LiteralPath $PublishedInfPath
    $Repository = Join-Path $env:windir 'System32\DriverStore\FileRepository'
    $Stem = [IO.Path]::GetFileNameWithoutExtension($OriginalName)
    $Pattern = Join-Path $Repository ($Stem + '.inf_*\' + $OriginalName)

    foreach ($Candidate in @(
        Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue
    )) {
        if ((Get-SHA256 -LiteralPath $Candidate.FullName) -eq $PublishedHash) {
            return [pscustomobject]@{
                InfPath = $Candidate.FullName
                PackageRoot = Split-Path -Parent $Candidate.FullName
                InfSHA256 = $PublishedHash
            }
        }
    }

    return $null
}

function Get-LenovoReleaseTargets {
    param([Parameter(Mandatory)][string]$DeviceId)

    $EnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$DeviceId"
    $DriverKey = [string](
        Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop
    ).Driver

    if ([string]::IsNullOrWhiteSpace($DriverKey)) {
        throw 'Unable to resolve the active display class key.'
    }

    $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$DriverKey"
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
    $Targets = @($ClassPath)
    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'HARDWARE\DEVICEMAP\VIDEO'
    )

    if ($null -eq $Key) {
        throw 'Unable to open the runtime video map.'
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
                $Targets +=
                    "HKLM:\SYSTEM\CurrentControlSet\Control\Video\$Guid\$($MappingMatch.Groups['Subkey'].Value)"
            }
        }
    }
    finally {
        $Key.Dispose()
    }

    return @($Targets | Sort-Object -Unique)
}

function Get-LenovoExtensionState {
    param(
        [Parameter(Mandatory)]
        [string]$DeviceInstanceId
    )

    Remove-Item `
        -LiteralPath $PnPInventoryPath `
        -Force `
        -ErrorAction SilentlyContinue

    $Process = Start-Process `
        -FilePath "$env:windir\System32\pnputil.exe" `
        -ArgumentList @(
            '/enum-drivers'
            '/devices'
            '/format'
            'xml'
            '/output-file'
            $PnPInventoryPath
        ) `
        -Wait `
        -PassThru `
        -WindowStyle Hidden

    if (
        $Process.ExitCode -ne 0 -or
        -not (Test-Path -LiteralPath $PnPInventoryPath -PathType Leaf)
    ) {
        return [pscustomobject]@{
            InventoryCreated = $false
            ExitCode = $Process.ExitCode
            Attached = $false
            Compatible = $false
            MatchingRecords = @()
            FailureReasons = @('PnPInventoryUnavailable')
            InventoryPath = $PnPInventoryPath
        }
    }

    [xml]$Inventory = Get-Content -LiteralPath $PnPInventoryPath -Raw
    $DriverNodes = @(
        $Inventory.SelectNodes(
            '//*[local-name()="Driver" or local-name()="driver"]'
        )
    )
    $AttachedCandidates = @()
    $CompatibleRecords = @()
    $Failures = @()

    foreach ($DriverNode in $DriverNodes) {
        $ClassGuid = [string]$DriverNode.ClassGuid
        if ($ClassGuid -ine $ExpectedExtensionClassGuid) {
            continue
        }

        $MatchingDeviceIds = @()
        foreach ($DeviceNode in @(
            $DriverNode.SelectNodes(
                './*[local-name()="Devices" or local-name()="devices"]' +
                '/*[local-name()="Device" or local-name()="device"]'
            )
        )) {
            $InstanceId = [string]$DeviceNode.GetAttribute('InstanceId')
            if (
                -not [string]::IsNullOrWhiteSpace($InstanceId) -and
                $InstanceId -ieq $DeviceInstanceId
            ) {
                $MatchingDeviceIds += $InstanceId
            }
        }

        if ($MatchingDeviceIds.Count -eq 0) {
            continue
        }

        $PublishedName = [string]$DriverNode.GetAttribute('DriverName')
        $OriginalName = [string]$DriverNode.OriginalName
        $DriverVersionText = [string]$DriverNode.DriverVersion
        $AttachedCandidates += $PublishedName
        $RecordFailures = @()
        $PublishedInfPath = Join-Path $env:windir "INF\$PublishedName"

        if (-not (Test-Path -LiteralPath $PublishedInfPath -PathType Leaf)) {
            $Failures += "${PublishedName}:PublishedInfMissing"
            continue
        }

        $Package = Resolve-LenovoExtensionPackage `
            -OriginalName $OriginalName `
            -PublishedInfPath $PublishedInfPath

        if ($null -eq $Package) {
            $Failures += "${PublishedName}:DriverStorePackageUnresolved"
            continue
        }

        $InfText = Get-Content -LiteralPath $Package.InfPath -Raw
        $InfLines = @($InfText -split "`r?`n")
        $NormalizedLines = @(
            $InfLines |
                ForEach-Object { Normalize-InfLine -Line $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $Class = Get-InfValue -Lines $InfLines -Name 'Class'
        $InfClassGuid = Get-InfValue -Lines $InfLines -Name 'ClassGUID'
        $ExtensionId = Get-InfValue -Lines $InfLines -Name 'ExtensionId'
        $CatalogName = Get-InfValue -Lines $InfLines -Name 'CatalogFile'
        $DriverVer = Get-InfValue -Lines $InfLines -Name 'DriverVer'
        $VersionMatch = [regex]::Match($DriverVer, ',\s*(?<Version>[^,]+)$')
        $DriverVersion = if ($VersionMatch.Success) {
            $VersionMatch.Groups['Version'].Value.Trim()
        }
        else {
            ''
        }

        $RequiredInstallDirectives = @(
            'AddReg=ati2mtag_SoftwareDeviceSettings'
            'AddReg=ati2mtag_NAVIA_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Phoenix_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Post_EG'
            'AddReg=ati2mtag_MultiUVD_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_NONPX_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_PX_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_PXAA_SoftwareDeviceSettings'
            'AddReg=ati2mtag_PXAA'
            'AddReg=ati2mtag_Manhattan_PX'
            'AddReg=ati2mtag_PXAA_IGPU_Only_2ID'
            'AddReg=ati2mtag_DSUMD'
            'DelReg=ati2mtag_RemoveDeviceSettings'
        )

        $RequiredRegistryDirectives = @(
            'HKR,,DalFeatureEnablePsrSU,%REG_DWORD%,0'
            'HKR,,DalDisableZ10,%REG_DWORD%,1'
            'HKR,,EnableswGCForceAtcL24KbWa,%REG_DWORD%,1'
            'HKR,,EnableswGCFakeCGCG,%REG_DWORD%,1'
            'HKR,,DalEmbeddedIntegerScalingSupport,%REG_DWORD%,1'
            'HKR,,DalPSRFeatureEnable,%REG_DWORD%,0'
            'HKR,,DalWirelessDisplaySupport,%REG_DWORD%,1'
            'HKR,,DalDetectRequireHpdHigh,%REG_DWORD%,0'
            'HKR,,DisableFBCSupport,%REG_DWORD%,1'
            'HKR,,BDC7EDEA37E855EFFD36,%REG_BINARY%,59,79,07,9B'
            'HKR,,BDC7EDEA40E855EFFDFB,%REG_BINARY%,59,79,07,9B'
            'HKR,,PP_UserVariBrightLevel,%REG_DWORD%,2'
            'HKR,,Dal_UserVariBrightLevel,%REG_DWORD%,2'
            'HKR,,PXSplashScreen,%REG_DWORD%,0'
            'HKR,,DALNonStandardModesBCD5,%REG_BINARY%,07,20,12,80,00,00,00,00,08,00,12,80,00,00,00,00,09,00,16,00,00,00,00,00,10,00,16,00,00,00,00,00,10,80,19,20,00,00,00,00,12,00,19,20,00,00,00,00,14,40,25,60,00,00,00,00'
            'HKR,,ProblemReportUrl,%REG_SZ%,show'
            'HKR,,DALRestrictedModesBCD5,%REG_BINARY%,16,00,12,00,00,00,00,00,12,80,10,24,00,00,00,00'
            'HKR,,HotkeysDisabled,%REG_DWORD%,0x1'
            'HKR,,dvr_ui_component_na,%REG_SZ%,true'
            'HKR,,DFPFreeSyncDefault,%REG_DWORD%,1'
            'HKR,,PP_WaitOnRegisterTimeout,%REG_DWORD%,0x2710'
            'HKR,,mobile_runtime_component_NA,%REG_SZ%,true'
            'HKR,,AllowWebContent,%REG_SZ%,false'
            'HKR,,LogoUrl,%REG_SZ%,hide'
            'HKR,,SystemTray,%REG_SZ%,false'
            'HKR,,DalWFDEnable,%REG_DWORD%,1'
            'HKR,"UMD\DXVA",ColorVibrance_DEF,%REG_SZ%,40'
            'HKR,"UMD\DXVA",ColorVibrance_ENABLE_DEF,%REG_SZ%,0'
            'HKR,,DALRULE_ALLOWMONITORRANGELIMITMODESCRT,%REG_DWORD%,0'
            'HKR,,ToggleRsHotkey,%REG_SZ%,none'
            'HKR,,LCDFreeSyncDefault,%REG_DWORD%,0x7'
            'HKR,,ShowRSOverlay,%REG_SZ%,false'
        )

        if ($Class -ine 'Extension') { $RecordFailures += 'ExtensionClass' }
        if ($InfClassGuid -ine $ExpectedExtensionClassGuid) { $RecordFailures += 'ExtensionClassGuid' }
        if ($ExtensionId -ine $ExpectedExtensionId) { $RecordFailures += 'ExtensionId' }
        if ($NormalizedLines -notcontains 'ati="advancedmicrodevices,inc."') { $RecordFailures += 'AmdProviderString' }
        $TargetIdNormalized = Normalize-InfLine -Line $ExpectedExtensionTargetHardwareId
        if (@($NormalizedLines | Where-Object { $_ -like "*$TargetIdNormalized*" }).Count -eq 0) {
            $RecordFailures += 'TargetHardwareId'
        }

        foreach ($Directive in @($RequiredInstallDirectives + $RequiredRegistryDirectives)) {
            if ($NormalizedLines -notcontains (Normalize-InfLine -Line $Directive)) {
                $RecordFailures += 'MissingDirective:' + $Directive
            }
        }

        foreach ($PatternName in @(
            'CopyFiles'
            'AddService'
            'ServiceBinary'
            'RegisterDlls'
            'CoInstallers32'
        )) {
            if ($InfText -match ('(?im)^\s*' + [regex]::Escape($PatternName) + '\s*=')) {
                $RecordFailures += 'UnexpectedRuntimeDirective:' + $PatternName
            }
        }

        $CatalogPath = Join-Path $Package.PackageRoot $CatalogName
        $CatalogSignature = if (Test-Path -LiteralPath $CatalogPath -PathType Leaf) {
            Get-AuthenticodeSignature -LiteralPath $CatalogPath
        }
        else {
            $null
        }
        $CatalogSigner = if (
            $null -ne $CatalogSignature -and
            $null -ne $CatalogSignature.SignerCertificate
        ) {
            [string]$CatalogSignature.SignerCertificate.Subject
        }
        else {
            ''
        }
        if (
            $null -eq $CatalogSignature -or
            [string]$CatalogSignature.Status -ne 'Valid' -or
            $CatalogSigner -notmatch $ExpectedExtensionCatalogSignerPattern
        ) {
            $RecordFailures += 'CatalogTrust'
        }

        $PackageFiles = @(
            Get-ChildItem -LiteralPath $Package.PackageRoot -File -Recurse
        )
        $ExecutableExtensions = @(
            '.sys', '.dll', '.exe', '.msi', '.msix', '.appx', '.com', '.ocx'
        )
        if (@($PackageFiles | Where-Object {
            $ExecutableExtensions -contains $_.Extension.ToLowerInvariant()
        }).Count -gt 0) {
            $RecordFailures += 'ExecutablePayload'
        }

        $CN = Get-ItemProperty `
            -LiteralPath 'HKLM:\SOFTWARE\AMD\CN' `
            -ErrorAction SilentlyContinue
        $RawCNVersion = [string](
            Get-ExtensionPropertyValue -Object $CN -Name 'CNVersion'
        )
        $RawCNDriverVersion = [string](
            Get-ExtensionPropertyValue -Object $CN -Name 'DriverVersion'
        )
        $CNVersionPresent =
            -not [string]::IsNullOrWhiteSpace($RawCNVersion)
        $CNDriverVersionPresent =
            -not [string]::IsNullOrWhiteSpace($RawCNDriverVersion)
        $CNMetadataState = if (
            $CNVersionPresent -and
            $CNDriverVersionPresent
        ) {
            'Present'
        }
        elseif (
            -not $CNVersionPresent -and
            -not $CNDriverVersionPresent
        ) {
            'Absent'
        }
        else {
            'Partial'
        }

        if ($CNMetadataState -eq 'Partial') {
            $RecordFailures += 'CNMetadataPartial'
        }
        if (
            $CNMetadataState -eq 'Present' -and
            $RawCNDriverVersion -ne $DriverVersion
        ) {
            $RecordFailures += 'CNDriverVersionMismatch'
        }

        $ReleaseRows = @()
        try {
            foreach ($Target in @(Get-LenovoReleaseTargets -DeviceId $DeviceInstanceId)) {
                $Value = ''
                try {
                    $Value = [string](
                        Get-ItemProperty `
                            -LiteralPath $Target `
                            -Name 'ReleaseVersion' `
                            -ErrorAction Stop
                    ).ReleaseVersion
                }
                catch {
                    $Value = ''
                }
                $ReleaseRows += [pscustomobject]@{
                    Path = $Target
                    Value = $Value
                    Present = -not [string]::IsNullOrWhiteSpace($Value)
                }
            }
        }
        catch {
            $RecordFailures += 'ReleaseTargetsUnresolved'
        }

        $DistinctReleaseValues = @(
            $ReleaseRows |
                Where-Object Present |
                Select-Object -ExpandProperty Value -Unique
        )
        $StableReleaseVersion = if ($DistinctReleaseValues.Count -eq 1) {
            [string]$DistinctReleaseValues[0]
        }
        else {
            ''
        }
        if (
            $ReleaseRows.Count -eq 0 -or
            @($ReleaseRows | Where-Object { -not $_.Present }).Count -gt 0 -or
            $DistinctReleaseValues.Count -ne 1
        ) {
            $RecordFailures += 'ReleaseVersionInconsistent'
        }

        $ReleaseVersionMatch = [regex]::Match(
            $StableReleaseVersion,
            '^(?<CNVersion>\d+(?:\.\d+){3})-.+-Lenovo$',
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $ReleaseCNVersion = if ($ReleaseVersionMatch.Success) {
            [string]$ReleaseVersionMatch.Groups['CNVersion'].Value
        }
        else {
            ''
        }

        if (
            [string]::IsNullOrWhiteSpace($StableReleaseVersion) -or
            -not $ReleaseVersionMatch.Success
        ) {
            $RecordFailures += 'ReleaseVersionProvenance'
        }
        if (
            $CNMetadataState -eq 'Present' -and
            $RawCNVersion -ne $ReleaseCNVersion
        ) {
            $RecordFailures += 'CNReleaseVersionMismatch'
        }

        $CNVersion = if ($CNMetadataState -eq 'Present') {
            $RawCNVersion
        }
        else {
            $ReleaseCNVersion
        }
        $CNDriverVersion = if ($CNMetadataState -eq 'Present') {
            $RawCNDriverVersion
        }
        else {
            $DriverVersion
        }

        if (
            [string]::IsNullOrWhiteSpace($CNVersion) -or
            [string]::IsNullOrWhiteSpace($CNDriverVersion)
        ) {
            $RecordFailures += 'CNMetadataUnresolved'
        }

        if ($RecordFailures.Count -eq 0) {
            $CompatibleRecords += [pscustomobject]@{
                PublishedName = $PublishedName
                OriginalName = $OriginalName
                Version = $DriverVersion
                VersionText = $DriverVersionText
                ClassGuid = $InfClassGuid
                ExtensionId = $ExtensionId
                DeviceIDs = $MatchingDeviceIds
                InfPath = $Package.InfPath
                InfSHA256 = $Package.InfSHA256
                CatalogPath = $CatalogPath
                CatalogSHA256 = Get-SHA256 -LiteralPath $CatalogPath
                CatalogSigner = $CatalogSigner
                PackageRoot = $Package.PackageRoot
                PackageFileCount = $PackageFiles.Count
                CNVersion = $CNVersion
                CNDriverVersion = $CNDriverVersion
                RawCNVersion = $RawCNVersion
                RawCNDriverVersion = $RawCNDriverVersion
                CNMetadataState = $CNMetadataState
                StableReleaseVersion = $StableReleaseVersion
                ReleaseTargets = @($ReleaseRows)
                RequiredRegistryDirectiveCount = $RequiredRegistryDirectives.Count
                SemanticCompatible = $true
            }
        }
        else {
            $Failures += "${PublishedName}:" + ($RecordFailures -join ',')
        }
    }

    return [pscustomobject]@{
        InventoryCreated = $true
        ExitCode = $Process.ExitCode
        Attached = ($AttachedCandidates.Count -gt 0)
        Compatible = ($CompatibleRecords.Count -eq 1)
        MatchingRecords = @($CompatibleRecords)
        FailureReasons = @($Failures)
        InventoryPath = $PnPInventoryPath
    }
}

function Get-RsxcmState {
    $Package = Get-AppxPackage -Name $ExpectedRsxcmName -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $PackageMatch = (
        $null -ne $Package -and
        [string]$Package.Version -eq $ExpectedRsxcmVersion -and
        [string]$Package.Status -eq 'Ok'
    )
    $ManifestHasNativeClsid = $false
    if ($PackageMatch) {
        $Manifest = Get-AppxPackageManifest -Package $Package.PackageFullName
        $ManifestClsid = $NativeContextMenuClsid.Trim('{}')
        $ManifestHasNativeClsid = $Manifest.OuterXml -match [regex]::Escape($ManifestClsid)
    }
    $RsxPackagePath = 'C:\Program Files\AMD\CNext\CNext\RSXPackage.msix'
    $RsxPackageHash = if (Test-Path -LiteralPath $RsxPackagePath -PathType Leaf) { Get-SHA256 -LiteralPath $RsxPackagePath } else { '' }
    $NativeClassPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\PackagedCom\ClassIndex\' + $NativeContextMenuClsid
    return [pscustomobject]@{
        Present=($null -ne $Package)
        Match=($PackageMatch -and $ManifestHasNativeClsid -and (Test-Path -LiteralPath $NativeClassPath) -and $RsxPackageHash -eq $ExpectedNativeRsxPackageHash)
        PackageFullName=$(if ($null -ne $Package) { [string]$Package.PackageFullName } else { '' })
        Version=$(if ($null -ne $Package) { [string]$Package.Version } else { '' })
        Status=$(if ($null -ne $Package) { [string]$Package.Status } else { '' })
        InstallLocation=$(if ($null -ne $Package) { [string]$Package.InstallLocation } else { '' })
        ManifestHasNativeClsid=$ManifestHasNativeClsid
        NativeClassRegistered=(Test-Path -LiteralPath $NativeClassPath)
        RsxPackagePath=$RsxPackagePath
        RsxPackageSHA256=$RsxPackageHash
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
        LegacyCannotActivate = (
            -not $LegacyStore.LegacyPackagedComRegistered -or
            $LegacyStore.LegacyContextMenuBlocked
        )
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

function Invoke-SignToolVerify {
    param([Parameter(Mandatory)][string]$SignToolPath,[Parameter(Mandatory)][string]$CatalogPath,[Parameter(Mandatory)][string]$FilePath)
    if (-not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) { return [pscustomobject]@{Passed=$false;ExitCode=$null;Output="SignTool missing: $SignToolPath"} }
    $Output = & $SignToolPath verify /kp /v /c $CatalogPath $FilePath 2>&1
    return [pscustomobject]@{Passed=($LASTEXITCODE -eq 0);ExitCode=$LASTEXITCODE;Output=($Output -join [Environment]::NewLine)}
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$LiteralPath,
        [int]$Depth = 14
    )

    $Parent = Split-Path -Parent $LiteralPath
    if (-not (Test-Path -LiteralPath $Parent -PathType Container)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $TemporaryPath = Join-Path $Parent (
        '.{0}.{1}.tmp' -f
        [IO.Path]::GetFileName($LiteralPath),
        [guid]::NewGuid().ToString('N')
    )

    try {
        $InputObject |
            ConvertTo-Json -Depth $Depth |
            Set-Content -LiteralPath $TemporaryPath -Encoding UTF8

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

function Write-AtomicText {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,
        [Parameter(Mandatory)][string]$LiteralPath
    )

    $Parent = Split-Path -Parent $LiteralPath
    if (-not (Test-Path -LiteralPath $Parent -PathType Container)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $TemporaryPath = Join-Path $Parent (
        '.{0}.{1}.tmp' -f
        [IO.Path]::GetFileName($LiteralPath),
        [guid]::NewGuid().ToString('N')
    )

    try {
        $Lines | Set-Content -LiteralPath $TemporaryPath -Encoding UTF8
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

function Get-RegisteredOfficialCatalogState {
    param(
        [Parameter(Mandatory)][string]$SignToolPath,
        [Parameter(Mandatory)][string]$KernelPath
    )

    $CatalogRoot = Join-Path `
        "$env:windir\System32\CatRoot" `
        '{F750E6C3-38EE-11D1-85E5-00C04FC295EE}'

    if (-not (Test-Path -LiteralPath $CatalogRoot -PathType Container)) {
        return [pscustomobject]@{
            Present = $false
            KernelPolicyVerified = $false
            Matches = @()
            Details = "Catalog database missing: $CatalogRoot"
        }
    }

    $Matches = @(
        Get-ChildItem `
            -LiteralPath $CatalogRoot `
            -File `
            -Filter '*.cat' `
            -ErrorAction Stop |
        ForEach-Object {
            try {
                $Hash = Get-SHA256 -LiteralPath $_.FullName

                if ($Hash -eq $ExpectedOfficialCatalogHash) {
                    $Signature =
                        Get-AuthenticodeSignature -LiteralPath $_.FullName
                    $Signer = if ($null -ne $Signature.SignerCertificate) {
                        [string]$Signature.SignerCertificate.Subject
                    }
                    else { '' }

                    [pscustomobject]@{
                        Path = $_.FullName
                        SHA256 = $Hash
                        SignatureStatus = [string]$Signature.Status
                        SignerSubject = $Signer
                        Valid = (
                            $Signature.Status -eq 'Valid' -and
                            $Signer -match
                                '^CN=Microsoft Windows Hardware Compatibility Publisher,'
                        )
                    }
                }
            }
            catch {
            }
        }
    )

    $KernelPolicyVerified = $false
    $VerifyDetails = ''

    if ($Matches.Count -gt 0) {
        $Verify = Invoke-SignToolVerify `
            -SignToolPath $SignToolPath `
            -CatalogPath $Matches[0].Path `
            -FilePath $KernelPath

        $KernelPolicyVerified = [bool]$Verify.Passed
        $VerifyDetails = "ExitCode=$($Verify.ExitCode)"
    }

    return [pscustomobject]@{
        Present = $Matches.Count -gt 0
        KernelPolicyVerified = $KernelPolicyVerified
        Matches = $Matches
        Details = $VerifyDetails
    }
}

try {
    $Checks = New-Object System.Collections.ArrayList
    $BootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

    Write-Host 'Legion Go AMD 26.6.4 Toolkit' -ForegroundColor White
    Write-Host 'Script 4 of 4: Final persistence audit'
    Write-Host ''
    Write-Host 'Source format: Readable PowerShell'
    Write-Host 'Installed-system changes: None'
    Write-Host 'Microsoft Store dependency: None'
    Write-Host 'Explorer termination: Disabled'
    Write-Host "Current boot: $BootTime"
    Write-Host "State directory: $WorkflowRoot"
    Write-Host ''

    $LenovoCompatibilityContract = Get-LenovoCompatibilityContract
    $ExpectedFinalCNVersion = $LenovoCompatibilityContract.CNVersion
    $ExpectedFinalCNDriverVersion = $LenovoCompatibilityContract.CNDriverVersion
    $ExpectedStableRelease = $LenovoCompatibilityContract.StableReleaseVersion
    $ExpectedLenovoExtensionVersion = $LenovoCompatibilityContract.ExtensionVersion
    $ExpectedLenovoExtensionInfSHA256 = $LenovoCompatibilityContract.ExtensionInfSHA256
    $ExpectedLenovoExtensionCatalogSHA256 = $LenovoCompatibilityContract.ExtensionCatalogSHA256

    $PriorPresent =
        Test-Path -LiteralPath $SoftwareResultPath -PathType Leaf

    Add-Check `
        -Checks $Checks `
        -Name 'Script 3 installation result exists' `
        -Passed $PriorPresent `
        -Details $SoftwareResultPath

    $Prior = $null
    $InstalledAt = $null
    $PriorUwppairHash = ''
    $PriorAmduwpVersion = ''
    $PriorAmduwpCompatible = $false
    $PriorAmduwpSigner = ''
    $PriorAmduwpAction = ''

    if ($PriorPresent) {
        $Prior =
            Get-Content -LiteralPath $SoftwareResultPath -Raw |
                ConvertFrom-Json

        $InstalledAtText =
            [string](Get-PropertyValue -Object $Prior -Name 'InstalledAt')

        if (-not [string]::IsNullOrWhiteSpace($InstalledAtText)) {
            $InstalledAt = [datetime]$InstalledAtText
        }

        $PriorSchemaVersion =
            Get-PropertyValue -Object $Prior -Name 'SchemaVersion'
        $PriorInstalled =
            Get-PropertyValue -Object $Prior -Name 'Installed'
        $PriorNextStage =
            [string](Get-PropertyValue -Object $Prior -Name 'NextStage')
        $PriorSoftwareMode =
            [string](Get-PropertyValue -Object $Prior -Name 'SoftwareMode')
        $PriorStoreDependency =
            Get-PropertyValue -Object $Prior -Name 'StoreDependency'
        $PriorDashboard =
            Get-PropertyValue -Object $Prior -Name 'DashboardConfirmed'
        $PriorSingleEntry =
            Get-PropertyValue `
                -Object $Prior `
                -Name 'SingleDesktopEntryConfirmed'
        $PriorLegacyAbsent =
            Get-PropertyValue `
                -Object $Prior `
                -Name 'LegacyStoreAppxAbsentSystemWide'
        $PriorLegacyProvisioned =
            Get-PropertyValue `
                -Object $Prior `
                -Name 'LegacyStoreAppxProvisioned'
        $PriorLegacyRegistered =
            Get-PropertyValue `
                -Object $Prior `
                -Name 'LegacyStoreAppxRegisteredOrStaged'
        $PriorUwppairHash =
            [string](Get-PropertyValue -Object $Prior -Name 'UwppairInfSHA256')
        $PriorAmduwpVersion =
            [string](Get-PropertyValue -Object $Prior -Name 'AMDUWPVersion')
        $PriorAmduwpCompatible =
            Get-PropertyValue -Object $Prior -Name 'AMDUWPCompatible'
        $PriorAmduwpSigner =
            [string](Get-PropertyValue -Object $Prior -Name 'AMDUWPSigner')
        $PriorAmduwpAction =
            [string](Get-PropertyValue -Object $Prior -Name 'AMDUWPCompatibilityAction')
        $PriorNativeMsiHash =
            [string](Get-PropertyValue -Object $Prior -Name 'NativeMsiSHA256')
        $PriorShellRefreshMethod =
            [string](Get-PropertyValue -Object $Prior -Name 'ShellRefreshMethod')
        $PriorExplorerTerminated =
            Get-PropertyValue -Object $Prior -Name 'ExplorerTerminated'
        $PriorRestartRequired =
            Get-PropertyValue -Object $Prior -Name 'RestartRequired'

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 result matches the final-audit handoff contract' `
            -Passed (
                [int]$PriorSchemaVersion -ge 7 -and
                $PriorInstalled -eq $true -and
                $PriorNextStage -eq
                    '06-Final-Persistence-Audit-Store-Free'
            ) `
            -Details (
                "SchemaVersion=$PriorSchemaVersion; " +
                "Installed=$PriorInstalled; NextStage=$PriorNextStage"
            )

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 used the native .2099 mode' `
            -Passed ($PriorSoftwareMode -eq $ExpectedSoftwareMode) `
            -Details $PriorSoftwareMode

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 recorded no Microsoft Store dependency' `
            -Passed ($PriorStoreDependency -eq $false) `
            -Details "StoreDependency=$PriorStoreDependency"

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 dashboard and one desktop entry were confirmed' `
            -Passed (
                $PriorDashboard -eq $true -and
                $PriorSingleEntry -eq $true
            ) `
            -Details (
                "Dashboard=$PriorDashboard; " +
                "SingleDesktopEntry=$PriorSingleEntry"
            )

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 recorded complete legacy Store AppX retirement' `
            -Passed (
                $PriorLegacyAbsent -eq $true -and
                $PriorLegacyProvisioned -eq $false -and
                $PriorLegacyRegistered -eq $false
            ) `
            -Details (
                "AbsentSystemWide=$PriorLegacyAbsent; " +
                "Provisioned=$PriorLegacyProvisioned; " +
                "RegisteredOrStaged=$PriorLegacyRegistered"
            )

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 recorded a compatible Microsoft-signed AMDUWP package' `
            -Passed (
                $PriorAmduwpCompatible -eq $true -and
                -not [string]::IsNullOrWhiteSpace($PriorUwppairHash) -and
                -not [string]::IsNullOrWhiteSpace($PriorAmduwpVersion) -and
                $PriorAmduwpSigner -match
                    'Microsoft Windows Hardware Compatibility Publisher'
            ) `
            -Details (
                "Version=$PriorAmduwpVersion; Hash=$PriorUwppairHash; " +
                "Action=$PriorAmduwpAction; Signer=$PriorAmduwpSigner"
            )

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 recorded the exact native .2099 MSI source' `
            -Passed ($PriorNativeMsiHash -eq $ExpectedNativeMsiHash) `
            -Details $PriorNativeMsiHash

        Add-Check `
            -Checks $Checks `
            -Name 'Script 3 used safe shell refresh without terminating Explorer' `
            -Passed (
                $PriorShellRefreshMethod -eq 'SHChangeNotify' -and
                $PriorExplorerTerminated -eq $false -and
                $PriorRestartRequired -eq $true
            ) `
            -Details (
                "ShellRefresh=$PriorShellRefreshMethod; " +
                "ExplorerTerminated=$PriorExplorerTerminated; " +
                "RestartRequired=$PriorRestartRequired"
            )

        Add-Check `
            -Checks $Checks `
            -Name 'A reboot occurred after Script 3' `
            -Passed (
                $null -ne $InstalledAt -and
                $BootTime -gt $InstalledAt
            ) `
            -Details "Script3=$InstalledAt; Boot=$BootTime"
    }

    $SecureBootState = Get-SecureBootState
    $SecureBootEnabled = [bool]$SecureBootState.Enabled
    $TestSigningEnabled = Get-TestSigningEnabled

    Add-Check `
        -Checks $Checks `
        -Name 'Test Signing is off' `
        -Passed (-not $TestSigningEnabled) `
        -Details "TestSigning=$TestSigningEnabled"

    Add-Check `
        -Checks $Checks `
        -Name 'Secure Boot state was read successfully' `
        -Passed $SecureBootState.Known `
        -Details (
            "SecureBoot=$SecureBootEnabled; Error=$($SecureBootState.Error)"
        )

    $Gpu = Get-GpuSnapshot
    $Gpu | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'Corrected display driver version persists' `
        -Passed ($Gpu.DriverVersion -eq $ExpectedDriverVersion) `
        -Details "$($Gpu.DriverVersion) / $($Gpu.ActiveINF)"

    Add-Check `
        -Checks $Checks `
        -Name 'Active corrected INF hash persists' `
        -Passed ($Gpu.ActiveInfSHA256 -eq $ExpectedInfHash) `
        -Details $Gpu.ActiveInfSHA256

    Add-Check `
        -Checks $Checks `
        -Name 'GPU remains healthy' `
        -Passed (
            $Gpu.Status -eq 'OK' -and
            $Gpu.ProblemCode -eq 0
        ) `
        -Details (
            "Status=$($Gpu.Status); ProblemCode=$($Gpu.ProblemCode)"
        )

    Add-Check `
        -Checks $Checks `
        -Name 'Exact AMD kernel remains loaded' `
        -Passed (
            $Gpu.KernelState -eq 'Running' -and
            $Gpu.KernelSHA256 -eq $ExpectedKernelHash
        ) `
        -Details "$($Gpu.KernelService); $($Gpu.KernelSHA256)"

    $SigningStatePresent =
        Test-Path `
            -LiteralPath $CatalogSigningStatePath `
            -PathType Leaf

    Add-Check `
        -Checks $Checks `
        -Name 'Catalog signing state exists' `
        -Passed $SigningStatePresent `
        -Details $CatalogSigningStatePath

    $SigningState = $null
    $RegisteredOfficialCatalog = $null

    if ($SigningStatePresent) {
        $SigningState =
            Get-Content -LiteralPath $CatalogSigningStatePath -Raw |
                ConvertFrom-Json

        $LocalCatalogPath =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'SignedCatalogPath')
        $LocalCatalogExpectedHash =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'SignedCatalogSHA256')
        $Thumbprint =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'CertificateThumbprint')
        $OfficialCatalogPath =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'OfficialCatalogPath')
        $OfficialCatalogExpectedHash =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'OfficialCatalogSHA256')
        $SignToolPath =
            [string](Get-PropertyValue `
                -Object $SigningState `
                -Name 'SignToolPath')

        $LocalExists =
            Test-Path -LiteralPath $LocalCatalogPath -PathType Leaf
        $LocalHash = if ($LocalExists) {
            Get-SHA256 -LiteralPath $LocalCatalogPath
        }
        else {
            ''
        }
        $LocalSignature = if ($LocalExists) {
            Get-AuthenticodeSignature -LiteralPath $LocalCatalogPath
        }
        else {
            $null
        }

        Add-Check `
            -Checks $Checks `
            -Name 'Locally signed corrected-driver catalog persists exactly' `
            -Passed (
                $LocalExists -and
                $LocalHash -eq $LocalCatalogExpectedHash -and
                $null -ne $LocalSignature -and
                $LocalSignature.Status -eq 'Valid'
            ) `
            -Details "$LocalCatalogPath; $LocalHash"

        $RootCert =
            Test-Path -LiteralPath "Cert:\LocalMachine\Root\$Thumbprint"
        $PublisherCert =
            Test-Path `
                -LiteralPath (
                    "Cert:\LocalMachine\TrustedPublisher\$Thumbprint"
                )

        Add-Check `
            -Checks $Checks `
            -Name 'Corrected-driver catalog signer trust persists' `
            -Passed ($RootCert -and $PublisherCert) `
            -Details (
                "Thumbprint=$Thumbprint; Root=$RootCert; " +
                "TrustedPublisher=$PublisherCert"
            )

        $OfficialExists =
            Test-Path `
                -LiteralPath $OfficialCatalogPath `
                -PathType Leaf
        $OfficialHash = if ($OfficialExists) {
            Get-SHA256 -LiteralPath $OfficialCatalogPath
        }
        else {
            ''
        }

        Add-Check `
            -Checks $Checks `
            -Name 'Official AMD Microsoft catalog persists exactly' `
            -Passed (
                $OfficialExists -and
                $OfficialHash -eq $ExpectedOfficialCatalogHash -and
                $OfficialHash -eq $OfficialCatalogExpectedHash
            ) `
            -Details "$OfficialCatalogPath; $OfficialHash"

        if ($OfficialExists) {
            $KernelCatalogVerify =
                Invoke-SignToolVerify `
                    -SignToolPath $SignToolPath `
                    -CatalogPath $OfficialCatalogPath `
                    -FilePath $Gpu.KernelPath

            Add-Check `
                -Checks $Checks `
                -Name (
                    'Official AMD source catalog validates the loaded kernel ' +
                    'under kernel policy'
                ) `
                -Passed $KernelCatalogVerify.Passed `
                -Details "ExitCode=$($KernelCatalogVerify.ExitCode)"

            $RegisteredOfficialCatalog =
                Get-RegisteredOfficialCatalogState `
                    -SignToolPath $SignToolPath `
                    -KernelPath $Gpu.KernelPath

            Add-Check `
                -Checks $Checks `
                -Name 'Official AMD catalog remains registered in CatRoot' `
                -Passed (
                    $RegisteredOfficialCatalog.Present -and
                    @($RegisteredOfficialCatalog.Matches |
                        Where-Object { -not $_.Valid }).Count -eq 0
                ) `
                -Details (
                    (@($RegisteredOfficialCatalog.Matches |
                        ForEach-Object Path) -join '; ')
                )

            Add-Check `
                -Checks $Checks `
                -Name (
                    'Registered official AMD catalog validates the loaded ' +
                    'kernel under kernel policy'
                ) `
                -Passed $RegisteredOfficialCatalog.KernelPolicyVerified `
                -Details $RegisteredOfficialCatalog.Details
        }
    }

    $Extension =
        Get-LenovoExtensionState -DeviceInstanceId $Gpu.DeviceID

    $ExtensionRecord = if ($Extension.Compatible) {
        @($Extension.MatchingRecords)[0]
    }
    else {
        [pscustomobject]@{
            Version = ''
            InfSHA256 = ''
            CatalogSHA256 = ''
        }
    }

    Add-Check `
        -Checks $Checks `
        -Name 'Semantically compatible Lenovo display extension persists' `
        -Passed (
            $Extension.Compatible -and
            [string]$ExtensionRecord.Version -eq $ExpectedLenovoExtensionVersion -and
            [string]$ExtensionRecord.InfSHA256 -eq $ExpectedLenovoExtensionInfSHA256 -and
            [string]$ExtensionRecord.CatalogSHA256 -eq $ExpectedLenovoExtensionCatalogSHA256
        ) `
        -Details (
            "Version=$([string]$ExtensionRecord.Version); " +
            "INF=$([string]$ExtensionRecord.InfSHA256); " +
            "Catalog=$([string]$ExtensionRecord.CatalogSHA256); " +
            "Failures=" + (@($Extension.FailureReasons) -join ' | ')
        )

    $Amduwp = Get-AmduwpState
    $Amduwp | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'Compatible Microsoft-signed AMDUWP remains healthy' `
        -Passed $Amduwp.Compatible `
        -Details (
            "$($Amduwp.DeviceID); $($Amduwp.InfName); " +
            "$($Amduwp.DriverVersion); $($Amduwp.InfSHA256); " +
            "Signer=$($Amduwp.Signer); Failed=" +
            (@($Amduwp.FailedChecks) -join ', ')
        )

    $LegacyMsi = Get-LegacyConflictingMsiRecord

    Add-Check `
        -Checks $Checks `
        -Name 'Conflicting AMD Settings .2089 MSI remains retired' `
        -Passed ($null -eq $LegacyMsi) `
        -Details $(if ($null -eq $LegacyMsi) {
            'Absent'
        }
        else {
            "$($LegacyMsi.KeyName); $($LegacyMsi.DisplayVersion)"
        })

    $NativeMsi = Get-NativeMsiRecord

    Add-Check `
        -Checks $Checks `
        -Name 'Native AMD Settings .2099 MSI registration persists' `
        -Passed ($null -ne $NativeMsi) `
        -Details $(if ($null -ne $NativeMsi) {
            "$($NativeMsi.KeyName); $($NativeMsi.DisplayVersion)"
        }
        else {
            'Missing'
        })

    $Desktop = Get-DesktopRadeonState

    Add-Check `
        -Checks $Checks `
        -Name 'Exact native .2099 RadeonSoftware.exe persists' `
        -Passed $Desktop.Match `
        -Details (
            "Length=$($Desktop.Length); " +
            "Version=$($Desktop.FileVersion); " +
            "SHA256=$($Desktop.SHA256); " +
            "Signature=$($Desktop.SignatureStatus)"
        )

    if ($PriorPresent) {
        $PriorDesktopHash =
            [string](Get-PropertyValue `
                -Object $Prior `
                -Name 'DesktopRadeonSoftwareSHA256')

        Add-Check `
            -Checks $Checks `
            -Name 'Desktop CNext binary matches the Script 3 installation' `
            -Passed ($Desktop.SHA256 -eq $PriorDesktopHash) `
            -Details (
                "Current=$($Desktop.SHA256); Script3=$PriorDesktopHash"
            )
    }

    $LegacyStore = Get-LegacyStoreState
    $LegacyStore | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'Legacy .2089 Store AppX remains absent system-wide' `
        -Passed $LegacyStore.Clean `
        -Details (
            "CurrentUser=$($LegacyStore.CurrentUserPresent); " +
            "RegisteredOrStaged=" +
            "$($LegacyStore.RegisteredOrStagedForAnyUser); " +
            "Provisioned=$($LegacyStore.Provisioned)"
        )

    $Rsxcm = Get-RsxcmState
    $Rsxcm | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'Native RSXCM 22.10.0.0 persists exactly' `
        -Passed $Rsxcm.Match `
        -Details (
            "$($Rsxcm.PackageFullName); " +
            "$($Rsxcm.RsxPackageSHA256)"
        )

    $ContextMenu = Get-ContextMenuState
    $ContextMenu | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'No legacy .2089 context-menu handler can activate' `
        -Passed $ContextMenu.LegacyCannotActivate `
        -Details (
            "Registered=$($ContextMenu.LegacyPackagedComRegistered); " +
            "Blocked=$($ContextMenu.LegacyBlocked)"
        )

    Add-Check `
        -Checks $Checks `
        -Name 'Native .2099 context-menu handler remains registered' `
        -Passed $ContextMenu.NativePackagedRegistration `
        -Details $ContextMenu.NativeCLSID

    Add-Check `
        -Checks $Checks `
        -Name 'Complete native context-menu state persists' `
        -Passed $ContextMenu.Match `
        -Details (
            "NativeRSXCM=$($ContextMenu.NativeRsxcmMatch); " +
            "LegacyStoreClean=$($LegacyStore.Clean)"
        )

    $CN = Get-CNState

    Add-Check `
        -Checks $Checks `
        -Name 'Lenovo-compatible CN metadata persists' `
        -Passed (
            $CN.CNVersion -eq $ExpectedFinalCNVersion -and
            $CN.DriverVersion -eq $ExpectedFinalCNDriverVersion
        ) `
        -Details "$($CN.CNVersion) / $($CN.DriverVersion)"

    Add-Check `
        -Checks $Checks `
        -Name 'Obsolete compatibility launcher is absent' `
        -Passed (
            -not (Test-Path -LiteralPath $LegacyLauncherPath) -and
            -not (Test-Path -LiteralPath $LegacyShortcutPath)
        ) `
        -Details "$LegacyLauncherPath; $LegacyShortcutPath"

    $ReleaseTargets = @(Get-ReleaseTargets -DeviceId $Gpu.DeviceID)
    $ReleaseState = @(Get-ReleaseState -Targets $ReleaseTargets)
    $ReleaseFailures =
        @($ReleaseState | Where-Object { -not $_.Match })

    Add-Check `
        -Checks $Checks `
        -Name 'Stable Lenovo ReleaseVersion persists on all active targets' `
        -Passed ($ReleaseFailures.Count -eq 0) `
        -Details (
            "Targets=$($ReleaseState.Count); " +
            "Failures=$($ReleaseFailures.Count)"
        )

    Write-Host ''
    Write-Host '=== OPEN NATIVE AMD SOFTWARE FOR FINAL CONFIRMATION ==='

    $Window =
        Get-Process `
            -Name RadeonSoftware `
            -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1

    if ($null -eq $Window -and $Desktop.Match) {
        Start-Process -FilePath $Desktop.Path
    }

    $Deadline = (Get-Date).AddSeconds($DashboardTimeoutSeconds)

    do {
        Start-Sleep -Seconds 1
        $Window =
            Get-Process `
                -Name RadeonSoftware `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.MainWindowHandle -ne 0
                } |
                Select-Object -First 1
    } while ($null -eq $Window -and (Get-Date) -lt $Deadline)

    Add-Check `
        -Checks $Checks `
        -Name 'AMD Software opens a visible window for final confirmation' `
        -Passed ($null -ne $Window) `
        -Details $(if ($null -ne $Window) {
            "PID=$($Window.Id); Title=$($Window.MainWindowTitle)"
        }
        else {
            'No visible window'
        })

    $ConfirmedDashboardProcessPath = ''

    if ($null -ne $Window) {
        $WindowProcess =
            Get-CimInstance `
                Win32_Process `
                -Filter "ProcessId = $($Window.Id)" `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

        if ($null -ne $WindowProcess) {
            $ConfirmedDashboardProcessPath =
                [string]$WindowProcess.ExecutablePath
        }
    }

    Add-Check `
        -Checks $Checks `
        -Name 'Visible dashboard is the native .2099 CNext executable' `
        -Passed (
            -not [string]::IsNullOrWhiteSpace(
                $ConfirmedDashboardProcessPath
            ) -and
            $ConfirmedDashboardProcessPath -ieq $ExpectedDesktopRadeonPath
        ) `
        -Details $ConfirmedDashboardProcessPath

    $DashboardConfirmed = $false

    if ($null -ne $Window) {
        $Confirmation = Read-Host (
            'Does native .2099 show the normal dashboard AND exactly one ' +
            'desktop right-click AMD: Radeon Software entry? Type YES'
        )

        $DashboardConfirmed =
            $Confirmation.Trim().ToUpperInvariant() -eq 'YES'
    }

    Add-Check `
        -Checks $Checks `
        -Name (
            'Native .2099 dashboard and exactly one desktop entry confirmed ' +
            'after restart'
        ) `
        -Passed $DashboardConfirmed

    $GpuAfterLaunch = Get-GpuSnapshot

    Add-Check `
        -Checks $Checks `
        -Name 'GPU remains healthy after opening AMD Software' `
        -Passed (
            $GpuAfterLaunch.Status -eq 'OK' -and
            $GpuAfterLaunch.ProblemCode -eq 0 -and
            $GpuAfterLaunch.DriverVersion -eq $ExpectedDriverVersion -and
            $GpuAfterLaunch.KernelSHA256 -eq $ExpectedKernelHash
        ) `
        -Details (
            "$($GpuAfterLaunch.DriverVersion); " +
            "$($GpuAfterLaunch.Status); " +
            "$($GpuAfterLaunch.ProblemCode)"
        )

    $CNAfter = Get-CNState
    $ReleaseAfter = @(Get-ReleaseState -Targets $ReleaseTargets)

    Add-Check `
        -Checks $Checks `
        -Name 'Compatibility metadata remains stable after launch' `
        -Passed (
            $CNAfter.CNVersion -eq $ExpectedFinalCNVersion -and
            $CNAfter.DriverVersion -eq $ExpectedFinalCNDriverVersion -and
            @($ReleaseAfter | Where-Object { -not $_.Match }).Count -eq 0
        ) `
        -Details "$($CNAfter.CNVersion) / $($CNAfter.DriverVersion)"

    $LegacyStoreAfterLaunch = Get-LegacyStoreState
    $RsxcmAfterLaunch = Get-RsxcmState

    Add-Check `
        -Checks $Checks `
        -Name 'Native package state remains stable after launch' `
        -Passed (
            $LegacyStoreAfterLaunch.Clean -and
            $RsxcmAfterLaunch.Match
        ) `
        -Details (
            "LegacyStoreClean=$($LegacyStoreAfterLaunch.Clean); " +
            "NativeRSXCM=$($RsxcmAfterLaunch.Match)"
        )

    $DxDiagPath =
        Join-Path `
            $env:TEMP `
            "LegionGo-DxDiag-Final-Audit-$Timestamp.xml"

    Remove-Item `
        -LiteralPath $DxDiagPath `
        -Force `
        -ErrorAction SilentlyContinue

    $Dx =
        Start-Process `
            -FilePath "$env:windir\System32\dxdiag.exe" `
            -ArgumentList @('/whql:off', '/x', $DxDiagPath) `
            -Wait `
            -PassThru

    $DxDriverVersion = ''
    $DxDriverModel = ''

    if (
        $Dx.ExitCode -eq 0 -and
        (Test-Path -LiteralPath $DxDiagPath -PathType Leaf)
    ) {
        [xml]$DxXml =
            Get-Content -LiteralPath $DxDiagPath -Raw
        $DisplayDevices =
            @($DxXml.DxDiag.DisplayDevices.DisplayDevice)
        $DxDevice =
            $DisplayDevices |
                Where-Object {
                    [string]$_.DeviceIdentifier -match '15BF' -or
                    [string]$_.CardName -match '780M'
                } |
                Select-Object -First 1

        if ($null -ne $DxDevice) {
            $DxDriverVersion = [string]$DxDevice.DriverVersion
            $DxDriverModel = [string]$DxDevice.DriverModel
        }
    }

    Add-Check `
        -Checks $Checks `
        -Name 'DxDiag reports the corrected driver version' `
        -Passed (
            $DxDriverVersion -match
                [regex]::Escape($ExpectedDriverVersion)
        ) `
        -Details (
            "DriverVersion=$DxDriverVersion; DriverModel=$DxDriverModel"
        )

    $RelevantErrors = @()

    foreach (
        $LogName in @(
            'System',
            'Microsoft-Windows-CodeIntegrity/Operational'
        )
    ) {
        try {
            $RelevantErrors += @(
                Get-WinEvent `
                    -FilterHashtable @{
                        LogName = $LogName
                        StartTime = $BootTime
                        Level = 2
                    } `
                    -ErrorAction Stop |
                    Where-Object {
                        $_.ProviderName -match (
                            'Display|amdkmdag|Kernel-PnP|CodeIntegrity'
                        ) -or
                        $_.Message -match (
                            'amdkmdag|VEN_1002&DEV_15BF'
                        )
                    }
            )
        }
        catch {
        }
    }

    Add-Check `
        -Checks $Checks `
        -Name 'No relevant GPU or Code Integrity errors occurred since boot' `
        -Passed ($RelevantErrors.Count -eq 0) `
        -Details "Count=$($RelevantErrors.Count)"

    $Failed = @($Checks | Where-Object { -not $_.Passed })
    $FinalPass = $Failed.Count -eq 0
    $ChecksArray = @($Checks | ForEach-Object { $_ })
    $FailedArray = @($Failed | ForEach-Object { $_ })
    $NativeMsiReportVersion = if ($null -ne $NativeMsi) {
        [string]$NativeMsi.DisplayVersion
    }
    else {
        ''
    }
    $NativeMsiReportProductCode = if ($null -ne $NativeMsi) {
        [string]$NativeMsi.KeyName
    }
    else {
        ''
    }
    $LegacyMsiReportVersion = if ($null -ne $LegacyMsi) {
        [string]$LegacyMsi.DisplayVersion
    }
    else {
        ''
    }

    $FinalResult = [ordered]@{
        SchemaVersion = 10
        Workflow = 'LegionGo-AMD-26.6.4'
        Complete = $FinalPass
        SoftwareMode = $ExpectedSoftwareMode
        StoreDependency = $false
        AuditedAt = (Get-Date).ToString('o')
        BootTime = $BootTime
        Script3InstalledAt = $InstalledAt
        RebootAfterScript3Confirmed = (
            $null -ne $InstalledAt -and
            $BootTime -gt $InstalledAt
        )
        SecureBootStateKnown = [bool]$SecureBootState.Known
        SecureBootEnabled = $SecureBootEnabled
        TestSigningEnabled = $TestSigningEnabled
        ActiveINF = $Gpu.ActiveINF
        DriverVersion = $Gpu.DriverVersion
        ActiveInfSHA256 = $Gpu.ActiveInfSHA256
        KernelService = $Gpu.KernelService
        KernelPath = $Gpu.KernelPath
        KernelSHA256 = $Gpu.KernelSHA256
        LenovoExtensionAttached = $Extension.Attached
        LenovoExtensionSemanticCompatible = $Extension.Compatible
        LenovoExtensionVersion = [string]$ExtensionRecord.Version
        LenovoExtensionInfSHA256 = [string]$ExtensionRecord.InfSHA256
        LenovoExtensionCatalogSHA256 = [string]$ExtensionRecord.CatalogSHA256
        AMDUWPDeviceID = $Amduwp.DeviceID
        AMDUWPInfName = $Amduwp.InfName
        AMDUWPVersion = $Amduwp.DriverVersion
        AMDUWPCompatible = $Amduwp.Compatible
        AMDUWPProvider = $Amduwp.Provider
        AMDUWPSigner = $Amduwp.Signer
        AMDUWPInfSHA256 = $Amduwp.InfSHA256
        AMDUWPCatalogName = $Amduwp.CatalogName
        AMDUWPStructureChecks = $Amduwp.StructureChecks
        AMDUWPFailedChecks = @($Amduwp.FailedChecks)
        Script3AMDUWPVersion = $PriorAmduwpVersion
        Script3AMDUWPInfSHA256 = $PriorUwppairHash
        Script3AMDUWPCompatibilityAction = $PriorAmduwpAction
        AMDUWPIdentityUnchangedSinceScript3 = [bool](
            $PriorAmduwpVersion -eq $Amduwp.DriverVersion -and
            $PriorUwppairHash -eq $Amduwp.InfSHA256
        )
        LegacyMsiPresent = $null -ne $LegacyMsi
        NativeMsiDisplayVersion = $NativeMsiReportVersion
        NativeMsiProductCode = $NativeMsiReportProductCode
        DesktopRadeonSoftwarePath = $Desktop.Path
        DesktopRadeonSoftwareVersion = $Desktop.FileVersion
        DesktopRadeonSoftwareSHA256 = $Desktop.SHA256
        ConfirmedDashboardProcessPath =
            $ConfirmedDashboardProcessPath
        RsxcmPackageFullName = $RsxcmAfterLaunch.PackageFullName
        RsxcmVersion = $RsxcmAfterLaunch.Version
        RsxcmRsxPackageSHA256 =
            $RsxcmAfterLaunch.RsxPackageSHA256
        LegacyStoreAppxName = $LegacyStoreAppxName
        LegacyStoreAppxCurrentUserPresent =
            $LegacyStoreAfterLaunch.CurrentUserPresent
        LegacyStoreAppxRegisteredOrStaged =
            $LegacyStoreAfterLaunch.RegisteredOrStagedForAnyUser
        LegacyStoreAppxProvisioned =
            $LegacyStoreAfterLaunch.Provisioned
        LegacyPackagedComRegistered =
            $LegacyStoreAfterLaunch.LegacyPackagedComRegistered
        LegacyContextMenuBlocked =
            $LegacyStoreAfterLaunch.LegacyContextMenuBlocked
        NativeContextMenuRegistered =
            $ContextMenu.NativePackagedRegistration
        CNVersion = $CNAfter.CNVersion
        CNDriverVersion = $CNAfter.DriverVersion
        StableReleaseVersion = $ExpectedStableRelease
        AMDSoftwareVisible = $null -ne $Window
        DashboardConfirmed = $DashboardConfirmed
        SingleDesktopEntryConfirmed = $DashboardConfirmed
        DxDiagDriverVersion = $DxDriverVersion
        DxDiagDriverModel = $DxDriverModel
        RelevantErrorCount = $RelevantErrors.Count
        RegisteredOfficialCatalogCount = $(
            if ($null -ne $RegisteredOfficialCatalog) {
                @($RegisteredOfficialCatalog.Matches).Count
            }
            else { 0 }
        )
        RegisteredOfficialCatalogKernelPolicyVerified = $(
            if ($null -ne $RegisteredOfficialCatalog) {
                [bool]$RegisteredOfficialCatalog.KernelPolicyVerified
            }
            else { $false }
        )
        ExplorerTerminated = $false
        InstalledSystemChanges = $false
        Checks = $ChecksArray
        FailedChecks = $FailedArray
        PnPInventoryPath = $PnPInventoryPath
        TranscriptPath = $TranscriptPath
        DesktopReport = $DesktopReport
    }

    Write-AtomicJson `
        -InputObject $FinalResult `
        -LiteralPath $ResultPath `
        -Depth 14

    $State = [ordered]@{
        SchemaVersion = 10
        Workflow = 'LegionGo-AMD-26.6.4'
        Stage = $(if ($FinalPass) {
            'Complete'
        }
        else {
            'Final-Audit-Failed'
        })
        UpdatedAt = (Get-Date).ToString('o')
        Complete = $FinalPass
        AMDSoftwareMode = $ExpectedSoftwareMode
        StoreDependency = $false
        ActiveINF = $Gpu.ActiveINF
        DriverVersion = $Gpu.DriverVersion
        KernelService = $Gpu.KernelService
        NativeMsiDisplayVersion = $NativeMsiReportVersion
        NativeRadeonSoftwareVersion = $Desktop.FileVersion
        NativeRsxcmVersion = $RsxcmAfterLaunch.Version
        LegacyStoreAppxAbsentSystemWide =
            $LegacyStoreAfterLaunch.Clean
        LegacyStoreAppxProvisioned =
            $LegacyStoreAfterLaunch.Provisioned
        LegacyStoreAppxRegisteredOrStaged =
            $LegacyStoreAfterLaunch.RegisteredOrStagedForAnyUser
        CNVersion = $CNAfter.CNVersion
        CNDriverVersion = $CNAfter.DriverVersion
        AMDUWPVersion = $Amduwp.DriverVersion
        AMDUWPCompatible = $Amduwp.Compatible
        AMDUWPInfSHA256 = $Amduwp.InfSHA256
        AMDUWPSigner = $Amduwp.Signer
        DashboardConfirmed = $DashboardConfirmed
        SingleDesktopEntryConfirmed = $DashboardConfirmed
        TestSigningEnabled = $TestSigningEnabled
        SecureBootStateKnown = [bool]$SecureBootState.Known
        SecureBootEnabled = $SecureBootEnabled
        ResultPath = $ResultPath
        LogPath = $TranscriptPath
        ExplorerTerminated = $false
        InstalledSystemChanges = $false
        RegisteredOfficialCatalogKernelPolicyVerified = $(
            if ($null -ne $RegisteredOfficialCatalog) {
                [bool]$RegisteredOfficialCatalog.KernelPolicyVerified
            }
            else { $false }
        )
    }

    Write-AtomicJson `
        -InputObject $State `
        -LiteralPath $StatePath `
        -Depth 10

    $Report = @(
        'Legion Go AMD 26.6.4 Toolkit Final Report'
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
        ''
        "SCRIPT 4 PASS: $FinalPass"
        'Microsoft Store dependency: False'
        "Active INF: $($Gpu.ActiveINF)"
        "Driver version: $($Gpu.DriverVersion)"
        "Kernel SHA256: $($Gpu.KernelSHA256)"
        "AMDUWP: $($Amduwp.DriverVersion) / Compatible=$($Amduwp.Compatible) / $($Amduwp.InfSHA256)"
        "AMD Settings MSI: native $NativeMsiReportVersion; legacy $LegacyMsiReportVersion"
        "Native frontend: $($Desktop.FileVersion) / $($Desktop.SHA256)"
        "Native RSXCM: $($RsxcmAfterLaunch.Version)"
        (
            'Legacy Store AppX: CurrentUser=' +
            "$($LegacyStoreAfterLaunch.CurrentUserPresent); " +
            'RegisteredOrStaged=' +
            "$($LegacyStoreAfterLaunch.RegisteredOrStagedForAnyUser); " +
            "Provisioned=$($LegacyStoreAfterLaunch.Provisioned)"
        )
        "CN metadata: $($CNAfter.CNVersion) / $($CNAfter.DriverVersion)"
        "Dashboard confirmed: $DashboardConfirmed"
        "DxDiag: $DxDriverVersion / $DxDriverModel"
        ''
        'Checks:'
    )

    foreach ($Check in $Checks) {
        $Report += (
            '[{0}] {1} -- {2}' -f
            $(if ($Check.Passed) {
                'PASS'
            }
            else {
                'FAIL'
            }),
            $Check.Name,
            $Check.Details
        )
    }

    Write-AtomicText `
        -Lines $Report `
        -LiteralPath $DesktopReport

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host 'SCRIPT 4 FINAL RESULT' -ForegroundColor White
    Write-Host "SCRIPT 4 PASS: $FinalPass" `
        -ForegroundColor $(if ($FinalPass) { 'Green' } else { 'Red' })
    Write-Host "Failed checks: $($Failed.Count)"
    Write-Host 'Microsoft Store dependency: False'
    Write-Host 'Installed-system changes: False'
    Write-Host 'Explorer terminated: False'
    Write-Host "Result file:    $ResultPath"
    Write-Host "Desktop report: $DesktopReport"
    Write-Host "Transcript:     $TranscriptPath"

    if ($FinalPass) {
        Write-Host 'TOOLKIT COMPLETE: True' -ForegroundColor Green
    }

    Write-Host ('=' * 72) -ForegroundColor White

    if (-not $FinalPass) {
        throw (
            "Script 4 final audit failed with $($Failed.Count) " +
            'failed check(s).'
        )
    }
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }
}
