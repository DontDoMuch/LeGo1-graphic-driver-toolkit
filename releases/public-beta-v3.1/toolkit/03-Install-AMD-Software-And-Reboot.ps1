#requires -Version 5.1
#requires -RunAsAdministrator
<##
Stage 3 installs only the exact AMD 26.7.1 native CNext and DVR MSI payloads
from the verified B026283 ccc2_install.exe container. It never touches the
display-driver INF. RC2zp never uses MSI repair mode for the target products:
a healthy exact product is retained; a registered-but-unhealthy exact product
is fully removed, proved absent, then freshly installed. A complete exact
runtime seal is mandatory before the software reboot checkpoint can be saved.
##>
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Internal\Common.ps1')

$Version = 'Public-Beta-v3.1'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Logs = Join-Path $Script:WorkflowRoot 'Logs'
$StageResultPath = Join-Path $Script:WorkflowRoot 'stage3-result.json'
$StageInvocationId = [string]$env:LEGIONGO_STAGE_INVOCATION_ID
if ([string]::IsNullOrWhiteSpace($StageInvocationId)) { $StageInvocationId = [guid]::NewGuid().ToString('N') }
New-Item -ItemType Directory -Path $Logs -Force | Out-Null
Initialize-InstallerRuntime -StageLabel 'Stage 3 - AMD Software update'

$ExpectedCNextHash = '4D88F5A6B4B8298F94539F8AB463C9A6E4931F78E61D8EC43E528E5D93E7A26D'
$ExpectedCNextLength = [int64]152735744
$ExpectedCNextProductCode = '{4BB6B15D-DFAB-4FD1-8DA6-07DD594939BF}'
$ExpectedCNextVersion = '2026.0716.2129.2099'
$ExpectedDvrHash = 'AF6551DA8DA1F14CF9C6FA7B5EF738B28864BA6374C85975246F663FC79ED574'
$ExpectedDvrLength = [int64]46534656
$ExpectedDvrProductCode = '{94D923DB-3F51-406F-A477-445876B3D70A}'
$ExpectedDvrVersion = '26.10.26197.2124'
$LegacyStoreAppx = 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'
$ExpectedRsxcm = 'AdvancedMicroDevicesInc-RSXCM'

$Runtime = @(
    [pscustomobject]@{Name='RadeonSoftware.exe';SHA256='1D33CAEE9336ACE73C6C15A56B5653D2516DCBCD94347DEE9CD5D518F80A7243'},
    [pscustomobject]@{Name='cncmd.exe';SHA256='27239A28E2F914B6D0A230ABAA7631DC7F77A39D6D0E36EAC2474CF0A4247064'},
    [pscustomobject]@{Name='AMDRSServ.exe';SHA256='5845FE3E344DF3DF34B2C0F50CFF14C20B3821CC9FA383A5D5DC00756955CC40'},
    [pscustomobject]@{Name='AMDRSSrcExt.exe';SHA256='0EB0B2A1742549EBE7380A82768D310C2ECDDF5B6DEF53443380F0C8B77C6B63'},
    [pscustomobject]@{Name='amdow.exe';SHA256='D4E8C6AAB55F590CF361DA2A391B788191C5188CDB9DCBDAAE26B8C697988D55'},
    [pscustomobject]@{Name='PresentMon-x64.exe';SHA256='6B208B51CB7923CB9F26C26D1920D97C453A81EFB7BF8EBA383721352DD7B99E'},
    [pscustomobject]@{Name='RSServCmd.exe';SHA256='AB82980834576C6ADEDA03C60E0C5644F6533A4E6DB37D0CC1E44341D6F4F64F'}
)
$CNextRuntimeNames = @('RadeonSoftware.exe','cncmd.exe','AMDRSSrcExt.exe','PresentMon-x64.exe')
$DvrRuntimeNames = @('AMDRSServ.exe','amdow.exe','RSServCmd.exe')

function Save-State($State) {
    Write-JsonAtomic -InputObject $State -LiteralPath $Script:WorkflowStatePath -Depth 30
}

function Write-Stage3Result {
    param(
        [Parameter(Mandatory=$true)][string]$Status,
        [Parameter(Mandatory=$true)][int]$ExitCode,
        [string]$Detail = ''
    )
    $Result = [ordered]@{
        SchemaVersion = 1
        Release = $Version
        Stage = 3
        InvocationId = $StageInvocationId
        Status = $Status
        ExitCode = $ExitCode
        Detail = $Detail
        At = (Get-Date).ToString('o')
    }
    Write-JsonAtomic -InputObject $Result -LiteralPath $StageResultPath -Depth 10
}

function Exit-Stage3 {
    param(
        [Parameter(Mandatory=$true)][int]$ExitCode,
        [Parameter(Mandatory=$true)][string]$Status,
        [string]$Detail = ''
    )
    Write-Stage3Result -Status $Status -ExitCode $ExitCode -Detail $Detail
    Restore-InstallerRuntime
    exit $ExitCode
}

function Test-AmdSignature([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $Sig = Get-AuthenticodeSignature -LiteralPath $Path
    return (
        $Sig.Status -eq 'Valid' -and
        $null -ne $Sig.SignerCertificate -and
        [string]$Sig.SignerCertificate.Subject -match 'Advanced Micro Devices'
    )
}

function Get-UninstallProducts {
    $Rows = @()
    foreach ($Root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        if (-not (Test-Path -LiteralPath $Root)) { continue }
        foreach ($Key in @(Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue)) {
            $Item = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $Item) { continue }
            $Code = [string]$Key.PSChildName
            if ($Code -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { continue }
            $DisplayNameProperty = $Item.PSObject.Properties['DisplayName']
            $DisplayVersionProperty = $Item.PSObject.Properties['DisplayVersion']
            $DisplayName = if ($null -ne $DisplayNameProperty) { [string]$DisplayNameProperty.Value } else { '' }
            $DisplayVersion = if ($null -ne $DisplayVersionProperty) { [string]$DisplayVersionProperty.Value } else { '' }
            $Rows += [pscustomobject]@{ProductCode=$Code;DisplayName=$DisplayName;DisplayVersion=$DisplayVersion}
        }
    }
    return @($Rows)
}

function Get-MsiInstalledVersion([string]$ProductCode) {
    if ((Get-MsiProductState -ProductCode $ProductCode) -ne 5) { return '' }
    $Installer = $null
    try {
        $Installer = New-Object -ComObject WindowsInstaller.Installer
        return [string]$Installer.ProductInfo($ProductCode,'VersionString')
    }
    catch { return '' }
    finally {
        if ($null -ne $Installer) {
            try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Installer) } catch {}
        }
    }
}

function Stop-AmdRuntime {
    Write-ActivityProgress -Activity 'Stop AMD Software runtime before normalization' -Percent 0 -Status 'STOPPING'
    foreach ($TaskName in @('StartCN','StartDVR')) {
        try {
            $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($null -ne $Task) { $Task | Stop-ScheduledTask -ErrorAction SilentlyContinue }
        }
        catch {}
    }
    foreach ($Name in @('RadeonSoftware','cncmd','AMDRSServ','AMDRSSrcExt','amdow','PresentMon-x64','RSServCmd','LauncherRSXRuntime')) {
        Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Write-IndeterminateActivityProgress -Activity 'Stop AMD Software runtime before normalization' -Tick 1 -Elapsed '00:01' -Detail 'settling stopped processes'
    Start-Sleep -Seconds 2
    Complete-ActivityProgress -Activity 'Stop AMD Software runtime before normalization'
}

function Get-RuntimeRow([string]$Name) {
    $Expected = $Runtime | Where-Object { [string]$_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $Expected) { throw "Unknown runtime identity: $Name" }
    $Path = Join-Path "$env:ProgramFiles\AMD\CNext\CNext" $Name
    $Present = Test-Path -LiteralPath $Path -PathType Leaf
    $Hash = ''
    if ($Present) {
        $Hash = Get-SHA256WithProgress -LiteralPath $Path -Activity ('Verify AMD runtime SHA-256: ' + $Name)
    } else {
        Write-ActivityProgress -Activity ('Verify AMD runtime SHA-256: ' + $Name) -Percent 100 -Status 'MISSING'
    }
    $Signed = $false
    if ($Present) {
        Write-IndeterminateActivityProgress -Activity ('Verify AMD runtime signature: ' + $Name) -Tick 0 -Elapsed '00:00' -Detail 'Windows Authenticode validation'
        Set-ActivityLivenessContext -Activity ('Verify AMD runtime signature: ' + $Name) -Status 'SIGNATURE' -Detail 'Windows Authenticode validation' -Indeterminate
        $Signed = Test-AmdSignature $Path
        $SignatureDetail=if($Signed){'valid AMD signature'}else{'signature validation failed'}
        Complete-ActivityProgress -Activity ('Verify AMD runtime signature: ' + $Name) -Detail $SignatureDetail
    }
    return [pscustomobject]@{
        Name=$Name
        Present=$Present
        SHA256=$Hash
        ExactHash=($Hash -eq [string]$Expected.SHA256)
        AmdSigned=$Signed
        Pass=($Present -and $Hash -eq [string]$Expected.SHA256 -and $Signed)
    }
}

function Test-RuntimeSubset([string[]]$Names) {
    foreach ($Name in $Names) {
        $Row = Get-RuntimeRow -Name $Name
        if (-not [bool]$Row.Pass) { return $false }
    }
    return $true
}

function Test-ExactComponentHealth {
    param(
        [Parameter(Mandatory=$true)][string]$ProductCode,
        [Parameter(Mandatory=$true)][string]$ExpectedVersion,
        [Parameter(Mandatory=$true)][string[]]$RuntimeNames,
        [string]$RequiredTask = ''
    )
    if ((Get-MsiProductState -ProductCode $ProductCode) -ne 5) { return $false }
    if ((Get-MsiInstalledVersion -ProductCode $ProductCode) -ne $ExpectedVersion) { return $false }
    if (-not (Test-RuntimeSubset -Names $RuntimeNames)) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($RequiredTask)) {
        $Task = Get-ScheduledTask -TaskName $RequiredTask -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $Task) { return $false }
    }
    return $true
}

function Invoke-MsiVerified {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int[]]$AllowedExitCodes
    )
    $HeartbeatLog = Join-Path $Logs ($Timestamp + '-msi-' + $Name + '-process.txt')
    $VerboseLog = Join-Path $Logs ($Timestamp + '-msi-' + $Name + '-verbose.log')
    $MsiArgs = @($Arguments)
    $MsiArgs += @('/L*v',$VerboseLog)
    $R = Invoke-ProcessHeartbeat `
        -FilePath "$env:WINDIR\System32\msiexec.exe" `
        -Arguments $MsiArgs `
        -LogPath $HeartbeatLog `
        -TimeoutSeconds 1200 `
        -HeartbeatSeconds 5 `
        -Activity ('Windows Installer: ' + $Name) `
        -Estimate 'Typical MSI operation: seconds to several minutes; watchdog: 20 minutes.' `
        -AllowFailure

    if (-not (Test-Path -LiteralPath $VerboseLog -PathType Leaf)) {
        throw "$Name did not produce its required verbose Windows Installer log: $VerboseLog"
    }
    $LogText = Get-Content -LiteralPath $VerboseLog -Raw -ErrorAction Stop
    $MatchesFound = [regex]::Matches($LogText,'MainEngineThread is returning\s+(\d+)',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($MatchesFound.Count -lt 1) {
        throw "$Name verbose MSI log has no MainEngineThread result contract. Log: $VerboseLog"
    }
    $MsiResult = [int]$MatchesFound[$MatchesFound.Count - 1].Groups[1].Value
    Write-Host ("[RESULT] {0}: process exit={1}; MSI engine result={2}" -f $Name,$R.ExitCode,$MsiResult)
    if ([int]$R.ExitCode -notin $AllowedExitCodes) {
        throw "$Name process exit code $($R.ExitCode) is not allowed. Verbose log: $VerboseLog"
    }
    if ($MsiResult -notin $AllowedExitCodes) {
        throw "$Name MSI engine result $MsiResult is not allowed even though process exit was $($R.ExitCode). Verbose log: $VerboseLog"
    }
    return [pscustomobject]@{ExitCode=[int]$R.ExitCode;MsiResult=$MsiResult;VerboseLog=$VerboseLog;ProcessLog=$HeartbeatLog}
}

function Remove-MsiProductVerified {
    param(
        [Parameter(Mandatory=$true)][string]$ProductCode,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if ((Get-MsiProductState -ProductCode $ProductCode) -ne 5) { return }
    [void](Invoke-MsiVerified `
        -Arguments @('/x',$ProductCode,'/qn','/norestart','REBOOT=ReallySuppress') `
        -Name $Name `
        -AllowedExitCodes @(0,1605,1614,1641,3010))
    $After = Get-MsiProductState -ProductCode $ProductCode
    Write-Host ("[CHECK] {0} ProductState after full uninstall: {1}" -f $Name,$After)
    if ($After -eq 5) { throw "$Name remains installed-local after full uninstall; refusing to continue." }
}

function Install-FreshMsiVerified {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ProductCode,
        [Parameter(Mandatory=$true)][string]$ExpectedVersion,
        [Parameter(Mandatory=$true)][string]$Name,
        [switch]$LaunchedFromCim
    )
    if ((Get-MsiProductState -ProductCode $ProductCode) -eq 5) {
        throw "$Name is still registered before a fresh install. RC2zp never invokes target-product MSI repair mode."
    }
    $MsiArguments = @('/i',$Path)
    if ($LaunchedFromCim) { $MsiArguments += 'LAUNCHED_FROM_CIM=1' }
    $MsiArguments += @('/qn','/norestart','REBOOT=ReallySuppress')
    [void](Invoke-MsiVerified -Arguments $MsiArguments -Name $Name -AllowedExitCodes @(0,1641,3010))
    if ((Get-MsiProductState -ProductCode $ProductCode) -ne 5) { throw "$Name is not installed-local after fresh install." }
    $InstalledVersion = Get-MsiInstalledVersion -ProductCode $ProductCode
    if ($InstalledVersion -ne $ExpectedVersion) { throw "$Name installed version mismatch after fresh install: $InstalledVersion" }
}

function Remove-OldMsiProducts([string]$Kind,[string]$KeepCode) {
    $Products = @(Get-UninstallProducts | Where-Object {
        if ($Kind -eq 'CN') { ([string]$_.DisplayName -match '(?i)^AMD Settings$|^AMD Software') -and $_.ProductCode -ne $KeepCode }
        else { ([string]$_.DisplayName -match '(?i)^AMD DVR') -and $_.ProductCode -ne $KeepCode }
    })
    foreach ($P in $Products) {
        Write-Host "Removing old $($P.DisplayName) $($P.DisplayVersion) [$($P.ProductCode)]"
        Remove-MsiProductVerified -ProductCode ([string]$P.ProductCode) -Name ('remove-old-' + $Kind + '-' + ([string]$P.ProductCode -replace '[{}]',''))
    }
}

function Retire-LegacyStoreAppx {
    $Found = @(Get-AppxPackage -AllUsers -Name $LegacyStoreAppx -ErrorAction SilentlyContinue)
    foreach ($P in $Found) {
        Write-Host "Removing legacy AMD Radeon Software Store AppX: $($P.PackageFullName)"
        try { Remove-AppxPackage -Package $P.PackageFullName -AllUsers -ErrorAction Stop }
        catch { Remove-AppxPackage -Package $P.PackageFullName -ErrorAction Stop }
    }
    $Provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { [string]$_.DisplayName -eq $LegacyStoreAppx })
    foreach ($P in $Provisioned) {
        [void](Remove-AppxProvisionedPackage -Online -PackageName $P.PackageName -ErrorAction Stop)
    }
    if (@(Get-AppxPackage -AllUsers -Name $LegacyStoreAppx -ErrorAction SilentlyContinue).Count -ne 0) { throw 'Legacy AMD Radeon Software Store AppX remains registered.' }
    $RemainingProvisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { [string]$_.DisplayName -eq $LegacyStoreAppx })
    if ($RemainingProvisioned.Count -ne 0) { throw 'Legacy AMD Radeon Software Store AppX remains provisioned.' }
}

function Assert-InstalledSoftware {
    Write-ActivityProgress -Activity 'Verify AMD Settings MSI registration' -Percent 0 -Status 'QUERYING' -Detail $ExpectedCNextProductCode
    Set-ActivityLivenessContext -Activity 'Verify AMD Settings MSI registration' -Percent 30 -Status 'QUERYING' -Detail 'Windows Installer product state + exact version'
    if ((Get-MsiProductState -ProductCode $ExpectedCNextProductCode) -ne 5) { throw 'Exact AMD Settings MSI product is not installed-local.' }
    if ((Get-MsiInstalledVersion -ProductCode $ExpectedCNextProductCode) -ne $ExpectedCNextVersion) { throw 'Exact AMD Settings MSI version is not installed.' }
    Complete-ActivityProgress -Activity 'Verify AMD Settings MSI registration' -Detail $ExpectedCNextVersion

    Write-ActivityProgress -Activity 'Verify AMD DVR MSI registration' -Percent 0 -Status 'QUERYING' -Detail $ExpectedDvrProductCode
    Set-ActivityLivenessContext -Activity 'Verify AMD DVR MSI registration' -Percent 30 -Status 'QUERYING' -Detail 'Windows Installer product state + exact version'
    if ((Get-MsiProductState -ProductCode $ExpectedDvrProductCode) -ne 5) { throw 'Exact AMD DVR MSI product is not installed-local.' }
    if ((Get-MsiInstalledVersion -ProductCode $ExpectedDvrProductCode) -ne $ExpectedDvrVersion) { throw 'Exact AMD DVR MSI version is not installed.' }
    Complete-ActivityProgress -Activity 'Verify AMD DVR MSI registration' -Detail $ExpectedDvrVersion

    $Rows = @()
    $RuntimeIndex=0
    Write-ActivityProgress -Activity 'Verify seven AMD runtime files' -Percent 0 -Status 'VERIFYING' -Detail '0/7 files'
    foreach ($Expected in $Runtime) {
        $Rows += Get-RuntimeRow -Name ([string]$Expected.Name)
        $RuntimeIndex++
        $RuntimePercent=[int][Math]::Floor(($RuntimeIndex*100.0)/$Runtime.Count)
        Write-ActivityProgress -Activity 'Verify seven AMD runtime files' -Percent $RuntimePercent -Status 'VERIFYING' -Detail ("{0}/7 :: {1}" -f $RuntimeIndex,[string]$Expected.Name)
    }
    Complete-ActivityProgress -Activity 'Verify seven AMD runtime files' -Detail '7/7 exact hash + AMD signature checks completed'
    $Failures = @($Rows | Where-Object { -not [bool]$_.Pass })
    if ($Failures.Count -ne 0) {
        $Names = @($Failures | ForEach-Object { $_.Name })
        throw ('Exact AMD runtime seal failed: ' + ($Names -join ', '))
    }

    Write-IndeterminateActivityProgress -Activity 'Verify native RSXCM 22.10.0.0 registration' -Tick 0 -Elapsed '00:00' -Detail 'Get-AppxPackage -AllUsers'
    Set-ActivityLivenessContext -Activity 'Verify native RSXCM 22.10.0.0 registration' -Status 'QUERYING' -Detail 'Get-AppxPackage -AllUsers' -Indeterminate
    $Rsx = @(Get-AppxPackage -AllUsers -Name $ExpectedRsxcm -ErrorAction SilentlyContinue | Where-Object { [string]$_.Version -eq '22.10.0.0' })
    Complete-ActivityProgress -Activity 'Verify native RSXCM 22.10.0.0 registration' -Detail ("matching registrations={0}" -f $Rsx.Count)
    if ($Rsx.Count -lt 1) { throw 'Native RSXCM 22.10.0.0 is not installed.' }

    Write-ActivityProgress -Activity 'Verify AMD startup tasks' -Percent 0 -Status 'QUERYING' -Detail 'StartCN + StartDVR'
    $TaskIndex=0
    foreach ($TaskName in @('StartCN','StartDVR')) {
        Set-ActivityLivenessContext -Activity 'Verify AMD startup tasks' -Percent ($TaskIndex*50) -Status 'QUERYING' -Detail $TaskName
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $Task) { throw "Required AMD startup task is missing: $TaskName" }
        $TaskIndex++
        Write-ActivityProgress -Activity 'Verify AMD startup tasks' -Percent ($TaskIndex*50) -Status 'PASS' -Detail $TaskName
    }
    Complete-ActivityProgress -Activity 'Verify AMD startup tasks' -Detail 'StartCN + StartDVR present'

    Write-IndeterminateActivityProgress -Activity 'Verify legacy Radeon Store AppX is absent' -Tick 0 -Elapsed '00:00' -Detail 'Get-AppxPackage -AllUsers'
    Set-ActivityLivenessContext -Activity 'Verify legacy Radeon Store AppX is absent' -Status 'QUERYING' -Detail $LegacyStoreAppx -Indeterminate
    $LegacyRows=@(Get-AppxPackage -AllUsers -Name $LegacyStoreAppx -ErrorAction SilentlyContinue)
    Complete-ActivityProgress -Activity 'Verify legacy Radeon Store AppX is absent' -Detail ("registrations={0}" -f $LegacyRows.Count)
    if ($LegacyRows.Count -ne 0) { throw 'Legacy Store Radeon Software AppX remains installed.' }
    return $true
}

function Get-Stage3Gpu {
    param([Parameter(Mandatory=$true)][string]$Activity)
    Write-IndeterminateActivityProgress -Activity $Activity -Tick 0 -Elapsed '00:00' -Detail 'PnP device properties + active INF + loaded kernel'
    Set-ActivityLivenessContext -Activity $Activity -Status 'QUERYING' -Detail 'PnP device properties + active INF + loaded kernel' -Indeterminate
    $Gpu=Get-LegionGoGpu
    Complete-ActivityProgress -Activity $Activity -Detail ("INF={0}; Driver={1}; Status={2}" -f $Gpu.ActiveINF,$Gpu.DriverVersion,$Gpu.Status)
    return $Gpu
}

try {
    Write-Stage3Result -Status 'Running' -ExitCode 98 -Detail 'Stage 3 invocation started.'
    Write-StageStatus -Stage 3 -Name 'AMD Software' -CurrentTask 'Verify and normalize matching native CNext/DVR software without touching the display INF'
    $State = Read-WorkflowState
    if ($null -eq $State -or [string]$State.Release -ne $Version) { throw 'Workflow state is missing or belongs to another release.' }
    $Stage = [string]$State.Stage

    if ($Stage -eq 'AwaitingSoftwareReboot') {
        $OldBoot = [datetime]::Parse([string]$State.BootTimeAtSoftwareInstall)
        if ((Get-CurrentBootTime) -le $OldBoot) {
            Write-Host '[INFO] Exact AMD Software passed its pre-reboot seal, but the saved reboot boundary has not happened yet.'
            Set-StateProperty $State 'SoftwareRebootCommandIssuedAt' ''
            Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
            Save-State $State
            Arm-ManagedResumeTaskAtBoundary
            if (Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.') {
                Set-StateProperty $State 'SoftwareRebootCommandIssuedAt' (Get-Date).ToString('o')
                Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
                Save-State $State
                Write-Stage3Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Awaiting software persistence reboot.'
                Write-Host '[REBOOT] Restart requested. One-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan
                Restart-Computer -Force
                Exit-Stage3 -ExitCode 2 -Status 'RebootRequired' -Detail 'Restart command returned unexpectedly.'
            }
            Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
            Exit-Stage3 -ExitCode 2 -Status 'RebootRequired' -Detail 'User deferred software persistence reboot.'
        }
        $PersistenceGpu=Get-Stage3Gpu -Activity 'Query Legion Go GPU after AMD Software reboot'
        [void](Assert-FinalDriver -Gpu $PersistenceGpu -Activity 'Verify exact driver after AMD Software reboot')
        [void](Assert-InstalledSoftware)
        Set-StateProperty $State 'Stage' 'SoftwareComplete'
        Set-StateProperty $State 'SoftwareCompletedAt' (Get-Date).ToString('o')
        Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
        Save-State $State
        Write-Host '[PASS] Exact 26.7.1 native AMD Software persists after reboot; display driver unchanged.' -ForegroundColor Green
        Write-Host 'SCRIPT 3 PASS: True'
        if ($env:LEGIONGO_RC2I_MANAGED -eq '1') { Write-Host '[NEXT] Launcher will continue to the final audit automatically.' }
        else { Write-Host 'NEXT: run 04-Final-Persistence-Audit.ps1' }
        Exit-Stage3 -ExitCode 0 -Status 'Passed' -Detail 'Software persistence seal passed and workflow advanced to SoftwareComplete.'
    }

    if ($Stage -in @('SoftwareComplete','Complete')) {
        $CompletedGpu=Get-Stage3Gpu -Activity 'Query Legion Go GPU for completed software-stage revalidation'
        [void](Assert-FinalDriver -Gpu $CompletedGpu -Activity 'Verify exact driver for completed software-stage revalidation')
        [void](Assert-InstalledSoftware)
        Write-Host '[PASS] Software stage already complete.' -ForegroundColor Green
        Write-Host 'SCRIPT 3 PASS: True'
        Exit-Stage3 -ExitCode 0 -Status 'Passed' -Detail 'Software stage was already complete and revalidated.'
    }

    if ($Stage -ne 'DriverComplete') { throw "Stage 3 requires Stage=DriverComplete; current Stage=$Stage" }
    if (Get-TestSigningConfigured) { throw 'Test Signing must be off before AMD Software installation.' }
    $Stage3StartGpu=Get-Stage3Gpu -Activity 'Query Legion Go GPU before AMD Software stage'
    [void](Assert-FinalDriver -Gpu $Stage3StartGpu -Activity 'Verify exact driver before AMD Software stage')

    $Ccc2 = [string]$State.OfficialCcc2Path
    if (-not (Test-Path -LiteralPath $Ccc2 -PathType Leaf)) { throw 'The exact Stage 1 source ccc2_install.exe is missing. Rerun from a clean workflow rather than substituting another payload.' }
    if ((Get-SHA256WithProgress -LiteralPath $Ccc2 -Activity 'Verify Stage 3 ccc2_install.exe SHA-256') -ne $Script:ExpectedOfficialCcc2SHA256 -or [int64](Get-Item $Ccc2).Length -ne $Script:ExpectedOfficialCcc2Length) { throw 'ccc2_install.exe identity mismatch.' }
    if (-not (Test-AmdSignature $Ccc2)) { throw 'ccc2_install.exe is not validly AMD-signed.' }

    $SevenZip = Ensure-SevenZip
    $SoftwareRoot = Join-Path ([string]$State.WorkRoot) 'Matching-AMD-Software'
    $Ccc2Root = Join-Path $SoftwareRoot 'CCC2'
    New-Item -ItemType Directory -Path $Ccc2Root -Force | Out-Null
    $ExtractLog = Join-Path $Logs ($Timestamp + '-extract-ccc2.txt')
    [void](Invoke-ProcessHeartbeat -FilePath $SevenZip -Arguments @('x','-y',('-o'+$Ccc2Root),'--',$Ccc2) -LogPath $ExtractLog -TimeoutSeconds 1200 -Activity 'Extracting matching AMD Software payloads' -Estimate 'Typical time: about 1-5 minutes; watchdog: 20 minutes.')

    $CNext = Join-Path $Ccc2Root 'CN\cnext\cnext64\ccc-next64.msi'
    $Dvr = Join-Path $Ccc2Root 'CN\amddvr\amddvr64\amddvr64.msi'
    foreach ($Target in @(
        [pscustomobject]@{Path=$CNext;Hash=$ExpectedCNextHash;Length=$ExpectedCNextLength;Code=$ExpectedCNextProductCode;Version=$ExpectedCNextVersion;Name='AMD Settings'},
        [pscustomobject]@{Path=$Dvr;Hash=$ExpectedDvrHash;Length=$ExpectedDvrLength;Code=$ExpectedDvrProductCode;Version=$ExpectedDvrVersion;Name='AMD DVR'}
    )) {
        $TargetHash=if([int64]$Target.Length -ge 64MB){Get-SHA256WithProgress -LiteralPath $Target.Path -Activity ("Verify {0} MSI SHA-256" -f $Target.Name)}else{Get-SHA256 $Target.Path}
        if ($TargetHash -ne $Target.Hash -or [int64](Get-Item $Target.Path).Length -ne $Target.Length) { throw "$($Target.Name) MSI identity mismatch." }
        if (-not (Test-AmdSignature $Target.Path)) { throw "$($Target.Name) MSI is not validly AMD-signed." }
        $Props = Get-MsiPropertyMap -LiteralPath $Target.Path
        if ([string]$Props['ProductCode'] -ne $Target.Code -or [string]$Props['ProductVersion'] -ne $Target.Version) { throw "$($Target.Name) MSI product metadata mismatch." }
    }
    Write-Host '[PASS] Exact official AMD Settings and DVR MSI payloads proved.' -ForegroundColor Green

    $AlreadyHealthy = $false
    try {
        [void](Assert-InstalledSoftware)
        $AlreadyHealthy = $true
        Write-Host '[PASS] Exact target AMD Software is already fully healthy; target MSIs will be retained without repair.' -ForegroundColor Green
    }
    catch {
        Write-Host ("[INFO] AMD Software normalization is required: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }

    if (-not $AlreadyHealthy) {
        Write-Section 'AMD SOFTWARE CHANGE GATE'
        Write-Host 'This will stop AMD Software processes, remove superseded AMD Settings/DVR products,'
        Write-Host 'retire only the legacy Radeon Software Store AppX, and normalize the exact 26.7.1 target products.'
        Write-Host 'Healthy exact target products are retained. Dirty exact target products are fully uninstalled and freshly installed.'
        Write-Host 'RC2zp NEVER invokes MSI repair mode and NEVER touches a display-driver INF in Stage 3.'
        if (-not (Confirm-ManagedOrInteractive 'Proceed with the AMD Software update?' -Estimate 'Typical time: about 3-10 minutes depending on Windows Installer and SSD speed.' -Impact 'This stage does not stage, remove, or install any display-driver INF.')) {
            Write-Host '[PAUSE] Cancelled before AMD Software changes. Driver stage remains sealed.' -ForegroundColor Yellow
            Exit-Stage3 -ExitCode 3 -Status 'Paused' -Detail 'User cancelled the AMD Software change gate.'
        }

        Stop-AmdRuntime
        Remove-OldMsiProducts -Kind 'CN' -KeepCode $ExpectedCNextProductCode
        Remove-OldMsiProducts -Kind 'DVR' -KeepCode $ExpectedDvrProductCode
        Retire-LegacyStoreAppx

        $CNextHealthy = Test-ExactComponentHealth `
            -ProductCode $ExpectedCNextProductCode `
            -ExpectedVersion $ExpectedCNextVersion `
            -RuntimeNames $CNextRuntimeNames `
            -RequiredTask 'StartCN'
        if ($CNextHealthy) {
            Write-Host '[PASS] Exact AMD Settings is already healthy; retained without MSI repair.' -ForegroundColor Green
        }
        else {
            if ((Get-MsiProductState -ProductCode $ExpectedCNextProductCode) -eq 5) {
                Write-Host '[INFO] Exact AMD Settings is registered but not healthy; full uninstall is required before fresh install.' -ForegroundColor Yellow
                Remove-MsiProductVerified -ProductCode $ExpectedCNextProductCode -Name 'remove-dirty-target-cnext'
            }
            Install-FreshMsiVerified -Path $CNext -ProductCode $ExpectedCNextProductCode -ExpectedVersion $ExpectedCNextVersion -Name 'fresh-install-target-cnext'
        }

        $DvrHealthy = Test-ExactComponentHealth `
            -ProductCode $ExpectedDvrProductCode `
            -ExpectedVersion $ExpectedDvrVersion `
            -RuntimeNames $DvrRuntimeNames `
            -RequiredTask 'StartDVR'
        if ($DvrHealthy) {
            Write-Host '[PASS] Exact AMD DVR is already healthy; retained without MSI repair.' -ForegroundColor Green
        }
        else {
            if ((Get-MsiProductState -ProductCode $ExpectedDvrProductCode) -eq 5) {
                Write-Host '[INFO] Exact AMD DVR is registered but not healthy; full uninstall bypasses the repair-only ShutdownDVR path before fresh install.' -ForegroundColor Yellow
                Remove-MsiProductVerified -ProductCode $ExpectedDvrProductCode -Name 'remove-dirty-target-dvr'
            }
            Install-FreshMsiVerified -Path $Dvr -ProductCode $ExpectedDvrProductCode -ExpectedVersion $ExpectedDvrVersion -Name 'fresh-install-target-dvr' -LaunchedFromCim
        }
    }

    Write-Section 'PRE-REBOOT SOFTWARE SEAL'
    $PreRebootGpu=Get-Stage3Gpu -Activity 'Query Legion Go GPU for pre-reboot software seal'
    [void](Assert-FinalDriver -Gpu $PreRebootGpu -Activity 'Verify exact driver for pre-reboot software seal')
    [void](Assert-InstalledSoftware)
    Write-Host '[PASS] Exact AMD Settings + DVR registrations, seven runtime hashes/signatures, startup tasks, RSXCM, and legacy-AppX retirement are sealed before reboot.' -ForegroundColor Green

    $BootBefore = Get-CurrentBootTime
    Set-StateProperty $State 'Stage' 'AwaitingSoftwareReboot'
    Set-StateProperty $State 'BootTimeAtSoftwareInstall' $BootBefore.ToString('o')
    Set-StateProperty $State 'SoftwareRebootCommandIssuedAt' ''
    Set-StateProperty $State 'CNextMsiPath' $CNext
    Set-StateProperty $State 'DvrMsiPath' $Dvr
    Set-StateProperty $State 'SoftwarePreRebootSealAt' (Get-Date).ToString('o')
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    Complete-CurrentSection -Detail 'software seal complete; reboot boundary armed'
    Write-Host '[PASS] Exact native 26.7.1 AMD Software pre-reboot seal completed; display driver remained exact.' -ForegroundColor Green
    Write-Host 'REBOOT REQUIRED. The one-command launcher will perform persistence validation after sign-in.'
    Arm-ManagedResumeTaskAtBoundary
    if (Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.') {
        Set-StateProperty $State 'SoftwareRebootCommandIssuedAt' (Get-Date).ToString('o')
        Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
        Save-State $State
        Write-Stage3Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Pre-reboot software seal passed; persistence reboot requested.'
        Write-Host '[REBOOT] Restart requested. One-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan
        Restart-Computer -Force
        Exit-Stage3 -ExitCode 2 -Status 'RebootRequired' -Detail 'Restart command returned unexpectedly.'
    }
    Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
    Exit-Stage3 -ExitCode 2 -Status 'RebootRequired' -Detail 'Pre-reboot software seal passed; user deferred persistence reboot.'
}
catch {
    $FailureText = $_.Exception.Message
    if ($_.Exception -is [System.OperationCanceledException]) {
        Write-Host ('[PAUSE] ' + $FailureText) -ForegroundColor Yellow
        Exit-Stage3 -ExitCode 3 -Status 'Paused' -Detail $FailureText
    }
    try { $SafetyText = Get-WorkflowSafetySummary }
    catch { $SafetyText = 'Safety state could not be summarized; the sealed display driver should remain unchanged unless explicitly reported otherwise.' }
    try { Write-Stage3Result -Status 'Failed' -ExitCode 1 -Detail $FailureText } catch {}
    Write-FailureGuide -Stage 'Stage 3 - AMD Software update' -Message $FailureText -SafetyState $SafetyText
    Restore-InstallerRuntime
    exit 1
}
