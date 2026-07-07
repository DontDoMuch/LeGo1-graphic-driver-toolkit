#requires -Version 5.1

<#
.SYNOPSIS
    Script 4 of the Legion Go AMD 26.6.2 Toolkit public beta workflow.

.DESCRIPTION
    Performs the final post-restart persistence audit for the corrected AMD
    26.6.2 driver and native AMD Software arrangement.

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
    Public Candidate R2.

    Derived from the validated final persistence audit and hardened for public
    use with readable source, Script 1-4 terminology, safe dashboard launch,
    registered-catalog verification, atomic result publication, explicit
    verification of Script 3's non-destructive shell handoff, and support
    for intentional blank separator lines in the final text report.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$WorkflowRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'
$StatePath = Join-Path $WorkflowRoot 'workflow-state.json'
$SoftwareResultPath =
    Join-Path $WorkflowRoot 'amd-software-install-result.json'
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
    'LegionGo-AMD-26.6.2-Final-Report.txt'

$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$ExpectedSoftwareMode = 'Native-2099-Store-Free'
$ExpectedDriverVersion = '32.0.31021.1015'
$ExpectedInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'
$ExpectedKernelHash =
    'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'
$ExpectedOfficialCatalogHash =
    '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'
$ExpectedExtensionOriginalName = 'amduw23e.inf'
$ExpectedExtensionVersion = '32.0.23017.1001'
$ExpectedExtensionClassGuid = '{e2f84ce7-8efa-411c-aa69-97454ca4cb57}'
$ExpectedAmduwpVersion = '32.2530.0.0'
$ExpectedUwppairInfHash =
    '2910267F4608F15FB8714157EFE9FC8A279205E1A4F4B475C7719F9C5F7021EB'

$ExpectedLegacyMsiDisplayVersion = '2026.0309.1733.2089'
$ExpectedLegacyMsiProductCode = '{AA16A900-8FCB-442D-969E-8A3EA516B506}'
$ExpectedNativeMsiDisplayVersion = '2026.0615.0559.2099'
$ExpectedNativeMsiProductCode = '{E2BAF8F2-28AB-4A9F-B60E-9E7351FB7462}'
$ExpectedNativeMsiHash =
    '74C6B6CE196F331E48BE374C954377601EC1EC472FA55CAD41899B87297E08A4'

$ExpectedDesktopRadeonLength = [int64]29043464
$ExpectedDesktopRadeonVersion = '10,01,02,2099'
$ExpectedDesktopRadeonHash =
    'A2FD02C6D1DC49DB2901E0AC53425FA5AB1A9A18F6342FB424EDD7D1024E1F75'
$ExpectedDesktopRadeonPath =
    'C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe'

$ExpectedRsxcmName = 'AdvancedMicroDevicesInc-RSXCM'
$ExpectedRsxcmVersion = '22.10.0.0'
$ExpectedNativeRsxPackageHash =
    '19299BE2DEF88FBF8350F274C6AC59E996BF04F223175EB963B871266B6B4531'
$LegacyStoreAppxName = 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'
$LegacyContextMenuClsid = '{6767B3BC-8FF7-11EC-B909-0242AC120002}'
$NativeContextMenuClsid = '{FDADFEE3-02D1-4E7C-A511-380F4C98D73B}'
$ShellBlockedPath =
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'

$ExpectedFinalCNVersion = '25.30.17.01'
$ExpectedFinalCNDriverVersion = '32.0.23017.1001'
$ExpectedStableRelease = '25.30.17.01-260108a-198040C-Lenovo'

$LegacyLauncherPath =
    'C:\Program Files\LegionGo-AMD-26.6.2\Launch-AMD-Software.ps1'
$LegacyShortcutPath =
    'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\AMD Software (Legion Go 26.6.2).lnk'

$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'
$GpuHardwareToken = 'VEN_1002&DEV_15BF&SUBSYS_381217AA'
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

function Get-AmduwpState {
    $Entity = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -like 'SWD\DRIVERENUM\AMDUWP*' } | Select-Object -First 1
    if ($null -eq $Entity) { return [pscustomobject]@{Present=$false;Healthy=$false;DeviceID='';Status='';ProblemCode=$null;InfName='';DriverVersion='';InfPath='';InfSHA256=''} }
    $Driver = Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceID -EQ $Entity.DeviceID | Select-Object -First 1
    $InfPath = if ($null -ne $Driver -and -not [string]::IsNullOrWhiteSpace([string]$Driver.InfName)) { Join-Path $env:windir "INF\$($Driver.InfName)" } else { '' }
    return [pscustomobject]@{
        Present=$true
        Healthy=($Entity.Status -eq 'OK' -and [int]$Entity.ConfigManagerErrorCode -eq 0 -and [string]$Driver.DriverVersion -eq $ExpectedAmduwpVersion)
        Name=[string]$Entity.Name
        DeviceID=[string]$Entity.DeviceID
        Status=[string]$Entity.Status
        ProblemCode=[int]$Entity.ConfigManagerErrorCode
        InfName=[string]$Driver.InfName
        DriverVersion=[string]$Driver.DriverVersion
        Provider=[string]$Driver.DriverProviderName
        InfPath=$InfPath
        InfSHA256=$(if (-not [string]::IsNullOrWhiteSpace($InfPath) -and (Test-Path -LiteralPath $InfPath -PathType Leaf)) { Get-SHA256 -LiteralPath $InfPath } else { '' })
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

function Get-LenovoExtensionState {
    param([Parameter(Mandatory)][string]$DeviceInstanceId)
    Remove-Item -LiteralPath $PnPInventoryPath -Force -ErrorAction SilentlyContinue
    $Process = Start-Process -FilePath "$env:windir\System32\pnputil.exe" -ArgumentList @('/enum-drivers','/devices','/format','xml','/output-file',$PnPInventoryPath) -Wait -PassThru -WindowStyle Hidden
    if ($Process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $PnPInventoryPath -PathType Leaf)) {
        return [pscustomobject]@{InventoryCreated=$false;ExitCode=$Process.ExitCode;Attached=$false;MatchingRecords=@()}
    }
    [xml]$Inventory = Get-Content -LiteralPath $PnPInventoryPath -Raw
    $DriverNodes = @($Inventory.SelectNodes('//*[local-name()="Driver" or local-name()="driver"]'))
    $MatchingRecords = @()
    foreach ($DriverNode in $DriverNodes) {
        $OriginalName = [string]$DriverNode.OriginalName
        $VersionText = [string]$DriverNode.DriverVersion
        $ClassGuid = [string]$DriverNode.ClassGuid
        $DeviceNodes = @($DriverNode.SelectNodes('./*[local-name()="Devices" or local-name()="devices"]/*[local-name()="Device" or local-name()="device"]'))
        $MatchingIds = @()
        foreach ($DeviceNode in $DeviceNodes) {
            $InstanceId = [string]$DeviceNode.GetAttribute('InstanceId')
            if ($InstanceId -ieq $DeviceInstanceId -or $InstanceId -like "*$GpuHardwareToken*") { $MatchingIds += $InstanceId }
        }
        if ($OriginalName -ieq $ExpectedExtensionOriginalName -and $VersionText -match [regex]::Escape($ExpectedExtensionVersion) -and $ClassGuid -ieq $ExpectedExtensionClassGuid -and $MatchingIds.Count -gt 0) {
            $MatchingRecords += [pscustomobject]@{PublishedName=[string]$DriverNode.GetAttribute('DriverName');OriginalName=$OriginalName;VersionText=$VersionText;ClassGuid=$ClassGuid;DeviceIDs=$MatchingIds}
        }
    }
    return [pscustomobject]@{InventoryCreated=$true;ExitCode=$Process.ExitCode;Attached=($MatchingRecords.Count -gt 0);MatchingRecords=$MatchingRecords}
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

    Write-Host 'Legion Go AMD 26.6.2 Toolkit' -ForegroundColor White
    Write-Host 'Script 4 of 4: Final persistence audit'
    Write-Host ''
    Write-Host 'Source format: Readable PowerShell'
    Write-Host 'Installed-system changes: None'
    Write-Host 'Microsoft Store dependency: None'
    Write-Host 'Explorer termination: Disabled'
    Write-Host "Current boot: $BootTime"
    Write-Host "State directory: $WorkflowRoot"
    Write-Host ''

    $PriorPresent =
        Test-Path -LiteralPath $SoftwareResultPath -PathType Leaf

    Add-Check `
        -Checks $Checks `
        -Name 'Script 3 installation result exists' `
        -Passed $PriorPresent `
        -Details $SoftwareResultPath

    $Prior = $null
    $InstalledAt = $null

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
            -Name 'Script 3 recorded the exact validated UWPPair source' `
            -Passed ($PriorUwppairHash -eq $ExpectedUwppairInfHash) `
            -Details $PriorUwppairHash

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

    Add-Check `
        -Checks $Checks `
        -Name 'Lenovo display extension remains attached' `
        -Passed $Extension.Attached `
        -Details (
            "Records=$(@($Extension.MatchingRecords).Count); " +
            "Inventory=$PnPInventoryPath"
        )

    $Amduwp = Get-AmduwpState
    $Amduwp | Format-List

    Add-Check `
        -Checks $Checks `
        -Name 'AMDUWP 32.2530.0.0 remains healthy' `
        -Passed $Amduwp.Healthy `
        -Details (
            "$($Amduwp.DeviceID); $($Amduwp.InfName); " +
            "$($Amduwp.DriverVersion)"
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
        SchemaVersion = 9
        Workflow = 'LegionGo-AMD-26.6.2'
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
        AMDUWPDeviceID = $Amduwp.DeviceID
        AMDUWPInfName = $Amduwp.InfName
        AMDUWPVersion = $Amduwp.DriverVersion
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
        SchemaVersion = 9
        Workflow = 'LegionGo-AMD-26.6.2'
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
        'Legion Go AMD 26.6.2 Toolkit Final Report'
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
        ''
        "SCRIPT 4 PASS: $FinalPass"
        'Microsoft Store dependency: False'
        "Active INF: $($Gpu.ActiveINF)"
        "Driver version: $($Gpu.DriverVersion)"
        "Kernel SHA256: $($Gpu.KernelSHA256)"
        "AMDUWP: $($Amduwp.DriverVersion) / Healthy=$($Amduwp.Healthy)"
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
