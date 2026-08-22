#requires -Version 5.1
#requires -RunAsAdministrator
<##
Read-only final persistence audit for Public Beta v3.1.
It does not install/remove drivers, change certificates, write registry values,
change BCD, install MSI/AppX packages, or alter workflow state. It writes
an evidence report under the current user's Downloads folder and an
invocation-specific pass/fail result contract under the workflow root.
##>
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Internal\Common.ps1')
$Version = 'Public-Beta-v3.1'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$EvidenceRoot = Join-Path "$env:USERPROFILE\Downloads" ('LegionGo-AMD-26.7.1-Public-Beta-v3.1-Final-Audit-' + $Timestamp)
$StageResultPath = Join-Path $Script:WorkflowRoot 'stage4-result.json'
$InvocationId = [string]$env:LEGIONGO_STAGE_INVOCATION_ID
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$Checks = @()
function Write-Stage4Result {
    param([Parameter(Mandatory=$true)][string]$Status,[Parameter(Mandatory=$true)][int]$ExitCode,[Parameter(Mandatory=$true)][int]$FailedChecks,[Parameter(Mandatory=$true)][string]$EvidencePath)
    $Result = [ordered]@{
        Schema = 'LegionGo-AMD-26.7.1-Public-Beta-v3.1-Stage4Result'
        Release = $Version
        InvocationId = $InvocationId
        Status = $Status
        ExitCode = $ExitCode
        FailedChecks = $FailedChecks
        EvidencePath = $EvidencePath
        GeneratedAt = (Get-Date).ToString('o')
    }
    Write-JsonAtomic -InputObject $Result -LiteralPath $StageResultPath -Depth 10
}
$ExpectedAuditCheckCount=64
function Add-Check([string]$Name,[bool]$Pass,[string]$Detail) {
    $script:Checks += [pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail}
    $CheckIndex=@($script:Checks).Count
    $AuditPercent=[int][Math]::Min(100,[Math]::Floor(($CheckIndex*100.0)/$ExpectedAuditCheckCount))
    $AuditStatus=if($Pass){'PASS'}else{'FAIL'}
    Write-ActivityProgress -Activity 'Final persistence audit' -Percent $AuditPercent -Status $AuditStatus -Detail ("Check {0}/{1} :: {2}" -f $CheckIndex,$ExpectedAuditCheckCount,$Name)
    if ($Pass) { Write-Host ("[PASS] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Green }
    else { Write-Host ("[FAIL] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Red }
}
function Hex([byte[]]$Bytes) { if ($null -eq $Bytes) { return '' }; return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join ',') }
function Read-RegValue([string]$Path,[string]$Name) {
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}
function Test-Reg([string]$Path,[string]$Name,$Expected,[string]$Kind) {
    $Actual = Read-RegValue $Path $Name
    $Pass = $false; $A=''
    if ($Kind -eq 'Binary') { $A=Hex ([byte[]]$Actual); $Pass=($A -eq [string]$Expected) }
    elseif ($Kind -eq 'Dword') { if ($null -ne $Actual) { $A=[string][uint32]$Actual; $Pass=([uint32]$Actual -eq [uint32]$Expected) } }
    else { $A=[string]$Actual; $Pass=($A -ceq [string]$Expected) }
    Add-Check -Name ('REG_' + $Name) -Pass $Pass -Detail ("Expected={0}; Actual={1}" -f $Expected,$A)
}
function Product-Installed([string]$Code) { try { return ((Get-MsiProductState -ProductCode $Code) -eq 5) } catch { return $false } }

Write-Section 'LEGION GO AMD 26.7.1 PUBLIC BETA v3.1 - FINAL READ-ONLY AUDIT'
$State = Read-WorkflowState
Add-Check 'WORKFLOW_STATE_PRESENT' ($null -ne $State) $(if($null-ne$State){[string]$State.Stage}else{'missing'})
if ($null -eq $State) { throw 'Workflow state is required to bind the per-machine signer identity.' }
Add-Check 'WORKFLOW_RELEASE' ([string]$State.Release -eq $Version) ([string]$State.Release)
Add-Check 'WORKFLOW_SOFTWARE_STAGE' ([string]$State.Stage -in @('SoftwareComplete','Complete')) ([string]$State.Stage)

Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 4 -Status 'QUERYING' -Detail 'discover live GPU, active INF, driver properties, and kernel identity'
$Gpu = Get-LegionGoGpu
Add-Check 'GPU_STATUS' ($Gpu.Status -eq 'OK' -and $Gpu.ProblemCode -eq 0 -and -not [bool]$Gpu.HasProblem) ("Status=$($Gpu.Status); ProblemCode=$($Gpu.ProblemCode); HasProblem=$($Gpu.HasProblem)")
Add-Check 'DRIVER_VERSION' ($Gpu.DriverVersion -eq $Script:ExpectedDriverVersion) $Gpu.DriverVersion
Add-Check 'ACTIVE_INF_SHA256' ($Gpu.InfSHA256 -eq $Script:ExpectedFinalInfSHA256) $Gpu.InfSHA256
Add-Check 'KERNEL_SHA256' ($Gpu.KernelSHA256 -eq $Script:ExpectedKernelSHA256) $Gpu.KernelSHA256
$DriverStoreRoot = $null
$CatalogDisposition = ''
$ExpectedCatalogSigner = ''
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 10 -Status 'RESOLVING' -Detail 'locate active Driver Store repository'
try { $DriverStoreRoot = Resolve-DriverStoreRootForPublishedInf -PublishedInf $Gpu.ActiveINF } catch { Add-Check 'DRIVERSTORE_ROOT' $false $_.Exception.Message }
if ($null -ne $DriverStoreRoot) {
    $Dat = Join-Path $DriverStoreRoot 'B026283\amdgcf.dat'
    $ResolvedFinalCatalog = $null
    try { $ResolvedFinalCatalog = Resolve-DriverStoreCatalogForPublishedInf -PublishedInf $Gpu.ActiveINF } catch { Add-Check 'ACTIVE_CATALOG_RESOLVE' $false $_.Exception.Message }
    $Cat = if ($null -ne $ResolvedFinalCatalog) { [string]$ResolvedFinalCatalog.CatalogPath } else { '' }
    $CatName = if ($null -ne $ResolvedFinalCatalog) { [string]$ResolvedFinalCatalog.CatalogName } else { '' }
    Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 12 -Status 'HASHING' -Detail 'active amdgcf.dat'
    $DatHash = ''; try { $DatHash=Get-SHA256 $Dat } catch {}
    Add-Check 'ACTIVE_DAT_SHA256' ($DatHash -eq $Script:ExpectedFinalDatSHA256) $DatHash
    Add-Check 'ACTIVE_CATALOG_NAME' ($CatName -ieq 'u0202643.cat') $CatName
    Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 14 -Status 'HASHING' -Detail ("active catalog: {0}" -f $CatName)
    $CatHash=''; if (-not [string]::IsNullOrWhiteSpace($Cat)) { try{$CatHash=Get-SHA256 $Cat}catch{} }
    $CatalogDisposition = if ($null -ne $State.PSObject.Properties['ActiveCatalogDisposition']) { [string]$State.ActiveCatalogDisposition } else { '' }
    $ExpectedCatalogHash = if ($null -ne $State.PSObject.Properties['ExpectedActiveCatalogSHA256']) { [string]$State.ExpectedActiveCatalogSHA256 } else { '' }
    $ExpectedCatalogSigner = if ($null -ne $State.PSObject.Properties['ExpectedActiveCatalogSignerThumbprint']) { [string]$State.ExpectedActiveCatalogSignerThumbprint } else { '' }
    Add-Check 'ACTIVE_CATALOG_DISPOSITION' ($CatalogDisposition -in @('Stage1Candidate','RetainedPreexistingExactFinal')) $CatalogDisposition
    Add-Check 'ACTIVE_CATALOG_EXPECTED_HASH' (-not [string]::IsNullOrWhiteSpace($ExpectedCatalogHash) -and $CatHash -eq $ExpectedCatalogHash) ("Disposition=$CatalogDisposition; Expected=$ExpectedCatalogHash; Actual=$CatHash")
    try {
        Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 18 -Status 'SIGNATURE' -Detail 'Windows Authenticode validation for active display catalog'
        $Sig=Get-AuthenticodeSignature -LiteralPath $Cat
        $ActualSigner = if($null-ne$Sig.SignerCertificate){[string]$Sig.SignerCertificate.Thumbprint}else{''}
        Add-Check 'CATALOG_SIGNATURE' ($Sig.Status -eq 'Valid' -and -not [string]::IsNullOrWhiteSpace($ExpectedCatalogSigner) -and $ActualSigner -eq $ExpectedCatalogSigner) ("Status=$($Sig.Status); Disposition=$CatalogDisposition; ExpectedSigner=$ExpectedCatalogSigner; ActualSigner=$ActualSigner")
    } catch { Add-Check 'CATALOG_SIGNATURE' $false $_.Exception.Message }
    try { Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 18 -Status 'TRUST' -Detail 'validate active catalog signer trust and absence of private key'; Assert-PublicSignerTrust -Thumbprint $ExpectedCatalogSigner; Add-Check 'ACTIVE_CATALOG_SIGNER_TRUST_NO_PRIVATE_KEY' $true $ExpectedCatalogSigner } catch { Add-Check 'ACTIVE_CATALOG_SIGNER_TRUST_NO_PRIVATE_KEY' $false $_.Exception.Message }
    try {
        Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 20 -Status 'VERIFYING' -Detail 'resolve pinned SignTool and verify active INF catalog membership'
        $Tools = Resolve-PortableKitTools
        if ($null -eq $Tools) { throw 'Pinned portable SignTool is unavailable for active catalog membership verification.' }
        $ActiveInfInStore = Join-Path $DriverStoreRoot 'u0202643.inf'
        $MembershipOutput = & $Tools.SignTool verify /pa /v /c $Cat $ActiveInfInStore 2>&1
        $MembershipExit = $LASTEXITCODE
        $MembershipDetail = (@($MembershipOutput) -join ' ')
        if ($MembershipDetail.Length -gt 500) { $MembershipDetail = $MembershipDetail.Substring(0,500) }
        Add-Check 'ACTIVE_CATALOG_INF_MEMBERSHIP' ($MembershipExit -eq 0) ("Exit=$MembershipExit; $MembershipDetail")
    } catch { Add-Check 'ACTIVE_CATALOG_INF_MEMBERSHIP' $false $_.Exception.Message }
}

Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 21 -Status 'QUERYING' -Detail 'enumerate AMD Display packages with Get-WindowsDriver -Online -All'
$Display = @(Get-AmdDisplayDrivers)
$FinalRows=@();$OldRows=@()
foreach($D in $Display){try{$H=Get-SHA256 ([string]$D.OriginalFileName);if($H-eq$Script:ExpectedFinalInfSHA256){$FinalRows+=$D};if($H-eq'A5FA34998C1B181A682727EB10EE18531EB2B5873AD8B40F0D104C6738ED0E83'){$OldRows+=$D}}catch{}}
Add-Check 'FINAL_V2B_DRIVERSTORE_ROW_PRESENT' ($FinalRows.Count -ge 1) ("ExactFinalRows=$($FinalRows.Count)")
Add-Check 'AMD_DISPLAY_PACKAGE_INVENTORY' $true ("TotalAmdDisplayRows=$($Display.Count); InactiveOrOtherRows=$([Math]::Max(0,$Display.Count-$FinalRows.Count)); OldA5faRows=$($OldRows.Count); inactive rows are retained by design")
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 25 -Status 'QUERYING' -Detail 'build target-compatible Display Driver Store inventory'
$TargetInventory=@(Get-DisplayDriverInventory | Where-Object { $_.TargetsLegionGo })
Add-Check 'LEGION_GO_DISPLAY_PACKAGE_INVENTORY' $true ("TargetCompatibleRows=$($TargetInventory.Count); ActiveINF=$($Gpu.ActiveINF); active exact binding is authoritative")
$Ext=@(Get-LenovoExtensionDrivers)
Add-Check 'NO_STAGED_AMDUW23E' ($Ext.Count -eq 0) ("Count=$($Ext.Count)")
$PhysicalExt=@(Get-ChildItem -LiteralPath "$env:WINDIR\System32\DriverStore\FileRepository" -Directory -Filter 'amduw23e.inf_*' -ErrorAction SilentlyContinue)
Add-Check 'NO_PHYSICAL_AMDUW23E_REPOSITORY' ($PhysicalExt.Count -eq 0) ("Count=$($PhysicalExt.Count)")
Add-Check 'TEST_SIGNING_OFF' (-not (Get-TestSigningConfigured)) ('Configured=' + (Get-TestSigningConfigured))
Add-Check 'NO_INTEGRITY_CHECKS_OFF' (-not (Get-NoIntegrityChecksConfigured)) ('Configured=' + (Get-NoIntegrityChecksConfigured))
$FinalSecureBoot=Get-SecureBootState
Add-Check 'SECURE_BOOT_DISABLED_FOR_LOCAL_SIGNER' ($FinalSecureBoot -eq $false) ('SecureBoot=' + [string]$FinalSecureBoot)
$Stage1Signer = [string]$State.SignerThumbprint
$SignerTrustDisposition = if ($null -ne $State.PSObject.Properties['SignerTrustDisposition']) { [string]$State.SignerTrustDisposition } else { '' }
$ExpectedSignerTrustDisposition = if ($CatalogDisposition -eq 'Stage1Candidate') { 'ActiveStage1SignerRetained' } elseif ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') { 'UnusedStage1SignerRemoved' } else { '' }
Add-Check 'STAGE1_SIGNER_TRUST_DISPOSITION' (-not [string]::IsNullOrWhiteSpace($ExpectedSignerTrustDisposition) -and $SignerTrustDisposition -eq $ExpectedSignerTrustDisposition) ("CatalogDisposition=$CatalogDisposition; Expected=$ExpectedSignerTrustDisposition; Actual=$SignerTrustDisposition")
$SignerRelationPass = if ($CatalogDisposition -eq 'Stage1Candidate') { $Stage1Signer -eq $ExpectedCatalogSigner } elseif ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') { -not [string]::IsNullOrWhiteSpace($Stage1Signer) -and $Stage1Signer -ne $ExpectedCatalogSigner } else { $false }
Add-Check 'STAGE1_ACTIVE_SIGNER_RELATION' $SignerRelationPass ("CatalogDisposition=$CatalogDisposition; Stage1Signer=$Stage1Signer; ActiveSigner=$ExpectedCatalogSigner")
if ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') {
    try { Assert-SignerTrustAbsent -Thumbprint $Stage1Signer; Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $true $Stage1Signer } catch { Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $false $_.Exception.Message }
} else {
    Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $true 'Not applicable: Stage1Candidate is the active catalog signer and its public trust must remain.'
}

$ClassPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\' + [string]$Gpu.DriverKey
$DxvaPath = Join-Path $ClassPath 'UMD\DXVA'
Test-Reg $ClassPath 'DALNonStandardModesBCD5' '07,20,12,80,00,00,00,00,08,00,12,80,00,00,00,00,09,00,16,00,00,00,00,00,10,00,16,00,00,00,00,00,10,80,19,20,00,00,00,00,12,00,19,20,00,00,00,00,14,40,25,60,00,00,00,00' 'Binary'
Test-Reg $ClassPath 'DALRestrictedModesBCD5' '16,00,12,00,00,00,00,00,12,80,10,24,00,00,00,00' 'Binary'
foreach($Pair in @(
    @('HotkeysDisabled',1,'Dword'),@('dvr_ui_component_na','true','String'),@('DFPFreeSyncDefault',1,'Dword'),@('PP_WaitOnRegisterTimeout',10000,'Dword'),@('AllowWebContent','false','String'),@('LogoUrl','hide','String'),@('SystemTray','false','String'),@('DALRULE_ALLOWMONITORRANGELIMITMODESCRT',0,'Dword'),@('ToggleRsHotkey','none','String'),@('LCDFreeSyncDefault',7,'Dword'),@('PP_UserVariBrightLevel',2,'Dword'),@('Dal_UserVariBrightLevel',2,'Dword'),
    @('DalFeatureEnablePsrSU',0,'Dword'),@('DalDisableZ10',1,'Dword'),@('EnableswGCFakeCGCG',1,'Dword'),@('DalEmbeddedIntegerScalingSupport',1,'Dword'),@('DalPSRFeatureEnable',0,'Dword'),@('DalWirelessDisplaySupport',1,'Dword'),@('DalDetectRequireHpdHigh',0,'Dword'),@('DisableFBCSupport',1,'Dword'),@('SmartDCDefMode',0,'Dword')
)) { Test-Reg $ClassPath ([string]$Pair[0]) $Pair[1] ([string]$Pair[2]) }
Test-Reg $ClassPath 'BDC7EDEA37E855EFFD36' '59,79,07,9B' 'Binary'
Test-Reg $ClassPath 'BDC7EDEA40E855EFFDFB' '59,79,07,9B' 'Binary'
Test-Reg $ClassPath 'ShowRSOverlay' 'true' 'String'
Test-Reg $DxvaPath 'ColorVibrance_ENABLE_DEF' '1' 'String'

$CNextCode='{4BB6B15D-DFAB-4FD1-8DA6-07DD594939BF}';$DvrCode='{94D923DB-3F51-406F-A477-445876B3D70A}'
Add-Check 'CNEXT_MSI_INSTALLED' (Product-Installed $CNextCode) $CNextCode
Add-Check 'DVR_MSI_INSTALLED' (Product-Installed $DvrCode) $DvrCode
$Runtime=@(
    [pscustomobject]@{Name='RadeonSoftware.exe';Hash='1D33CAEE9336ACE73C6C15A56B5653D2516DCBCD94347DEE9CD5D518F80A7243'},
    [pscustomobject]@{Name='cncmd.exe';Hash='27239A28E2F914B6D0A230ABAA7631DC7F77A39D6D0E36EAC2474CF0A4247064'},
    [pscustomobject]@{Name='AMDRSServ.exe';Hash='5845FE3E344DF3DF34B2C0F50CFF14C20B3821CC9FA383A5D5DC00756955CC40'},
    [pscustomobject]@{Name='AMDRSSrcExt.exe';Hash='0EB0B2A1742549EBE7380A82768D310C2ECDDF5B6DEF53443380F0C8B77C6B63'},
    [pscustomobject]@{Name='amdow.exe';Hash='D4E8C6AAB55F590CF361DA2A391B788191C5188CDB9DCBDAAE26B8C697988D55'},
    [pscustomobject]@{Name='PresentMon-x64.exe';Hash='6B208B51CB7923CB9F26C26D1920D97C453A81EFB7BF8EBA383721352DD7B99E'},
    [pscustomobject]@{Name='RSServCmd.exe';Hash='AB82980834576C6ADEDA03C60E0C5644F6533A4E6DB37D0CC1E44341D6F4F64F'}
)
foreach($R in $Runtime){$Path=Join-Path "$env:ProgramFiles\AMD\CNext\CNext" $R.Name;$H='';try{$H=Get-SHA256WithProgress -LiteralPath $Path -Activity ('Final audit runtime SHA-256: '+$R.Name)}catch{};Add-Check ('RUNTIME_'+$R.Name) ($H-eq$R.Hash) $H}
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 89 -Status 'QUERYING' -Detail 'query RSXCM AppX registration'
$Rsx=@(Get-AppxPackage -AllUsers -Name 'AdvancedMicroDevicesInc-RSXCM' -ErrorAction SilentlyContinue|Where-Object{[string]$_.Version-eq'22.10.0.0'})
Add-Check 'RSXCM_22_10_0_0' ($Rsx.Count -ge 1) ("Count=$($Rsx.Count)")
$Legacy=@(Get-AppxPackage -AllUsers -Name 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware' -ErrorAction SilentlyContinue)
Add-Check 'NO_LEGACY_RADEON_STORE_APPX' ($Legacy.Count -eq 0) ("Count=$($Legacy.Count)")
foreach($Task in @('StartCN','StartDVR')){$T=Get-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue|Select-Object -First 1;Add-Check ('TASK_'+$Task) ($null-ne$T) $(if($null-ne$T){[string]$T.State}else{'missing'})}

$Failed=@($Checks|Where-Object{-not$_.Pass})
$Report=[ordered]@{Schema='LegionGo-AMD-26.7.1-Public-Beta-v3.1-Final-Audit';Generated=(Get-Date).ToString('o');ReadOnly=$true;Passed=($Failed.Count-eq0);FailedChecks=$Failed.Count;Checks=$Checks;Gpu=$Gpu;WorkflowStage=[string]$State.Stage;SignerThumbprint=[string]$State.SignerThumbprint;SignerTrustDisposition=$(if($null-ne$State.PSObject.Properties['SignerTrustDisposition']){[string]$State.SignerTrustDisposition}else{''});ActiveCatalogDisposition=$(if($null-ne$State.PSObject.Properties['ActiveCatalogDisposition']){[string]$State.ActiveCatalogDisposition}else{''});ExpectedActiveCatalogSHA256=$(if($null-ne$State.PSObject.Properties['ExpectedActiveCatalogSHA256']){[string]$State.ExpectedActiveCatalogSHA256}else{''});ExpectedActiveCatalogSignerThumbprint=$(if($null-ne$State.PSObject.Properties['ExpectedActiveCatalogSignerThumbprint']){[string]$State.ExpectedActiveCatalogSignerThumbprint}else{''})}
Write-JsonAtomic -InputObject $Report -LiteralPath (Join-Path $EvidenceRoot 'Final-Audit.json') -Depth 30
$Checks|Format-Table -AutoSize|Out-String -Width 240|Set-Content -LiteralPath (Join-Path $EvidenceRoot 'Checks.txt') -Encoding UTF8
$AuditPassed = ($Failed.Count -eq 0)
$AuditExitCode = if($AuditPassed){0}else{1}
$AuditStatus = if($AuditPassed){'Passed'}else{'Failed'}
Write-Stage4Result -Status $AuditStatus -ExitCode $AuditExitCode -FailedChecks $Failed.Count -EvidencePath $EvidenceRoot
Complete-ActivityProgress -Activity 'Final persistence audit' -Detail (("{0}/{1} checks executed" -f @($Checks).Count,$ExpectedAuditCheckCount))
Write-Section 'FINAL RESULT'
Write-Host ("SCRIPT 4 PASS: {0}" -f $AuditPassed)
Write-Host ("Failed checks: {0}" -f $Failed.Count)
Write-Host ("TOOLKIT COMPLETE: {0}" -f $AuditPassed)
Write-Host "Evidence: $EvidenceRoot"
exit $AuditExitCode
