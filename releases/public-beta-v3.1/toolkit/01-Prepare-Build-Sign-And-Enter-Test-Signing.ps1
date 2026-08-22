#requires -Version 5.1
#requires -RunAsAdministrator
<##
Legion Go 1 / AMD 26.7.1 Public Beta v3.1.
Stage 1 verifies the exact official AMD source, deterministically rebuilds the
final RC2-v2b INF/DAT, generates a fresh local catalog, locally signs it with a
non-exportable per-machine certificate, destroys the private signing copy, and
prepares temporary Test Signing. It never uses a pre-signed package from the
development machine.
##>
[CmdletBinding()]
param([string]$InstallerPath='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Internal\Common.ps1')
$Version='Public-Beta-v3.1'
$Timestamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$Logs=Join-Path $Script:WorkflowRoot 'Logs'
New-Item -ItemType Directory -Path $Script:WorkflowRoot,$Logs -Force|Out-Null
Initialize-InstallerRuntime -StageLabel 'Stage 1 - build and local signing'
trap {
    if($_.Exception -is [System.OperationCanceledException]){Write-Host ('[PAUSE] ' + $_.Exception.Message) -ForegroundColor Yellow;exit 3}
    $FailureText=$_.Exception.Message
    try{$SafetyText=Get-WorkflowSafetySummary}catch{$SafetyText='Safety state could not be summarized; preserve the workflow directory and logs.'}
    Write-FailureGuide -Stage 'Stage 1 - build/sign/test-signing preparation' -Message $FailureText -SafetyState $SafetyText
    exit 1
}

function Save-State($State){ Write-JsonAtomic -InputObject $State -LiteralPath $Script:WorkflowStatePath -Depth 30 }
function Get-UnchangedManifestRows {
    $ManifestPath=Join-Path $PSScriptRoot 'Internal\RC2-v2b-Unchanged-190.json'
    $Raw=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    if($Raw -is [System.Array]){return $Raw}
    return @($Raw)
}
function Assert-UnchangedManifestExact([string]$PackageRoot,$Rows,[string]$Label){
    $Checked=0
    $Total=@($Rows).Count
    $NextConsolePercent=0
    Write-ActivityProgress -Activity $Label -Percent 0 -Status 'VERIFYING' -Detail ("0/{0} files" -f $Total)
    foreach($Row in @($Rows)){
        $Rel=[string]$Row.path;$Path=Join-Path $PackageRoot $Rel
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label unchanged file missing: $Rel"}
        if([int64](Get-Item -LiteralPath $Path).Length-ne[int64]$Row.length){throw "$Label unchanged file length mismatch: $Rel"}
        $CurrentPercent=if($Total-gt0){[int][Math]::Floor(($Checked*100.0)/$Total)}else{0}
        $CurrentSize=[int64](Get-Item -LiteralPath $Path).Length
        Set-ActivityLivenessContext -Activity $Label -Percent $CurrentPercent -Status 'HASHING' -Detail ("file {0}/{1}: {2} ({3:N1} MB)" -f ($Checked+1),$Total,$Rel,($CurrentSize/1MB))
        $Observed=Get-SHA256 $Path
        if($Observed-ne([string]$Row.sha256).ToUpperInvariant()){throw "$Label unchanged file hash mismatch: $Rel Expected=$([string]$Row.sha256) Actual=$Observed"}
        $Checked++
        $Percent=if($Total-gt0){[int][Math]::Floor(($Checked*100.0)/$Total)}else{100}
        try{Write-Progress -Activity $Label -Status ("{0}/{1} files :: {2}" -f $Checked,$Total,$Rel) -PercentComplete $Percent}catch{}
        if($Percent-ge$NextConsolePercent-or$Checked-eq$Total){Write-ActivityProgress -Activity $Label -Percent $Percent -Status 'VERIFYING' -Detail ("{0}/{1} files" -f $Checked,$Total);$NextConsolePercent=[Math]::Min(100,$NextConsolePercent+10)}
    }
    if($Checked-ne190){throw "$Label unchanged manifest verification count mismatch: $Checked"}
    Complete-ActivityProgress -Activity $Label -Detail '190/190 files exact'
    Write-Host ("[PASS] {0}: all 190 AMD-unchanged files match the frozen manifest." -f $Label) -ForegroundColor Green
}
function Restore-OriginalAmdCompanionCatalogs(
    [string]$OfficialRoot,
    [string]$PackageRoot,
    $Rows,
    [string]$SignToolPath,
    [string]$LogRoot,
    [string]$RunStamp
){
    $Companions=@(
        [pscustomobject]@{Cat='amdafd\amdafd.cat';Inf='amdafd\amdafd.inf'},
        [pscustomobject]@{Cat='amdfdans\amdfdans.cat';Inf='amdfdans\amdfdans.inf'},
        [pscustomobject]@{Cat='amdfendr\amdfendr.cat';Inf='amdfendr\amdfendr.inf'},
        [pscustomobject]@{Cat='amdocl\amdocl.cat';Inf='amdocl\amdocl.inf'},
        [pscustomobject]@{Cat='amdogl\amdogl.cat';Inf='amdogl\amdogl.inf'},
        [pscustomobject]@{Cat='amdpcibridge\amdpcibridgeextension.cat';Inf='amdpcibridge\amdpcibridgeextension.inf'},
        [pscustomobject]@{Cat='amdvlk\amdvlk.cat';Inf='amdvlk\amdvlk.inf'},
        [pscustomobject]@{Cat='amdwin\amdwin-u0202643.cat';Inf='amdwin\amdwin-u0202643.inf'},
        [pscustomobject]@{Cat='amdxe\amdxe.cat';Inf='amdxe\amdxe.inf'}
    )

    $Preserved=@()
    $CompanionIndex=0
    Write-ActivityProgress -Activity 'Restore and verify AMD companion catalogs' -Percent 0 -Status 'START' -Detail '0/9 catalogs'
    foreach($Pair in $Companions){
        $CompanionIndex++
        $Rel=[string]$Pair.Cat
        $InfRel=[string]$Pair.Inf
        $ManifestRow=@($Rows|Where-Object{[string]$_.path-eq$Rel})
        if($ManifestRow.Count-ne1){throw "Companion catalog is not uniquely represented in the frozen 190-file manifest: $Rel"}

        $ExpectedHash=([string]$ManifestRow[0].sha256).ToUpperInvariant()
        $Src=Join-Path $OfficialRoot $Rel
        $Dst=Join-Path $PackageRoot $Rel
        $InfDst=Join-Path $PackageRoot $InfRel

        if(-not(Test-Path -LiteralPath $Src -PathType Leaf)){throw "Official companion catalog missing: $Rel"}
        if(-not(Test-Path -LiteralPath $InfDst -PathType Leaf)){throw "Companion INF missing for kernel-policy verification: $InfRel"}
        if((Get-SHA256 $Src)-ne$ExpectedHash){throw "Official companion catalog hash mismatch: $Rel"}

        Copy-Item -LiteralPath $Src -Destination $Dst -Force
        if((Get-SHA256 $Dst)-ne$ExpectedHash){throw "Companion catalog restore verification failed: $Rel"}

        $Sig=Get-AuthenticodeSignature -LiteralPath $Dst
        if($Sig.Status-ne'Valid'-or$null-eq$Sig.SignerCertificate){
            throw "Restored companion catalog Authenticode verification failed: $Rel Status=$([string]$Sig.Status)"
        }

        # Field calibration on 2026-08-19 proved all nine exact official
        # AMD-shipped catalogs are signed by Microsoft Windows Hardware
        # Compatibility Publisher. AMD is the package vendor, not the
        # certificate subject. Exact bytes plus Windows kernel policy are
        # the fail-closed identity/trust contract.
        $SafeName=($Rel -replace '[\\/:*?"<>|]','_')
        $CatVerifyLog=Join-Path $LogRoot ('companion-kp-cat-'+$SafeName+'-'+$RunStamp+'.txt')
        $InfVerifyLog=Join-Path $LogRoot ('companion-kp-inf-'+$SafeName+'-'+$RunStamp+'.txt')

        $CompanionStartPercent=[int][Math]::Floor((($CompanionIndex-1)*100.0)/$Companions.Count)
        Write-ActivityProgress -Activity 'Restore and verify AMD companion catalogs' -Percent $CompanionStartPercent -Status 'ACTIVE' -Detail ("{0}/9 :: {1}" -f $CompanionIndex,$Rel)
        $CatOutput=& $SignToolPath verify /kp /v $Dst 2>&1
        $CatExit=[int]$LASTEXITCODE
        $CatOutput|Set-Content -LiteralPath $CatVerifyLog -Encoding UTF8
        if($CatExit-ne0){
            throw "Restored companion catalog failed SignTool kernel-policy verification: $Rel Exit=$CatExit Log=$CatVerifyLog"
        }

        $InfOutput=& $SignToolPath verify /kp /v /c $Dst $InfDst 2>&1
        $InfExit=[int]$LASTEXITCODE
        $InfOutput|Set-Content -LiteralPath $InfVerifyLog -Encoding UTF8
        if($InfExit-ne0){
            throw "Restored companion catalog failed INF membership verification: $Rel / $InfRel Exit=$InfExit Log=$InfVerifyLog"
        }

        Write-Host ("[PASS] Restored exact AMD-shipped WHQL companion catalog: {0}" -f $Rel) -ForegroundColor Green
        Write-Host ("       SHA256={0}" -f $ExpectedHash)
        Write-Host ("       Signer={0}" -f [string]$Sig.SignerCertificate.Subject)
        Write-Host '       SignTool /kp CAT=PASS; /kp INF membership=PASS'
        $CompanionPercent=[int][Math]::Floor(($CompanionIndex*100.0)/$Companions.Count)
        Write-ActivityProgress -Activity 'Restore and verify AMD companion catalogs' -Percent $CompanionPercent -Status 'VERIFYING' -Detail ("{0}/9 :: {1}" -f $CompanionIndex,$Rel)
        $Preserved+=$Rel
    }
    Complete-ActivityProgress -Activity 'Restore and verify AMD companion catalogs' -Detail '9/9 catalogs exact and kernel-policy valid'
    return $Preserved
}
function Remove-OrphanPrivateSigners {
    $Prefix = 'CN=LegionGo AMD 26.7.1 Public Beta v3.1 Local Driver ' 
    $Removed = 0
    foreach ($Signer in @(Get-ChildItem -LiteralPath 'Cert:\LocalMachine\My' -ErrorAction SilentlyContinue)) {
        if ([string]$Signer.Subject -like ($Prefix + '*')) {
            try { Remove-Item -LiteralPath $Signer.PSPath -Force -ErrorAction Stop; $Removed++ } catch { throw "Unable to remove an orphaned Public Beta v3.1 private signing certificate: $($_.Exception.Message)" }
        }
    }
    if ($Removed -gt 0) { Write-Host ("[RECOVERY] Removed {0} orphaned Public Beta v3.1 private signing certificate(s) from LocalMachine\My." -f $Removed) -ForegroundColor Yellow }
}
function Verify-SignedWorkspace($State){
    $Package=[string]$State.PackageRoot
    if(-not(Test-Path -LiteralPath $Package -PathType Container)){throw "Signed package workspace is missing: $Package"}
    $Inf=Join-Path $Package 'u0202643.inf';$Dat=Join-Path $Package 'B026283\amdgcf.dat';$Cat=Join-Path $Package 'u0202643.cat'
    if((Get-SHA256 $Inf)-ne$Script:ExpectedFinalInfSHA256){throw 'Saved package INF changed.'}
    if((Get-SHA256 $Dat)-ne$Script:ExpectedFinalDatSHA256){throw 'Saved package DAT changed.'}
    if((Get-SHA256 (Join-Path $Package 'B026283\amdkmdag.sys'))-ne$Script:ExpectedKernelSHA256){throw 'Saved package kernel changed.'}
    $Files=@(Get-ChildItem -LiteralPath $Package -Recurse -File -Force)
    if($Files.Count-ne$Script:ExpectedSignedFileCount){throw "Saved signed package file count changed: $($Files.Count)"}
    $Sig=Get-AuthenticodeSignature -LiteralPath $Cat
    if($Sig.Status-ne'Valid'-or$null-eq$Sig.SignerCertificate){throw 'Saved package catalog is not validly signed.'}
    if([string]$Sig.SignerCertificate.Thumbprint-ne[string]$State.SignerThumbprint){throw 'Saved package catalog signer changed.'}
    Assert-PublicSignerTrust -Thumbprint ([string]$State.SignerThumbprint)
    $SavedManifest=Get-UnchangedManifestRows
    Assert-UnchangedManifestExact -PackageRoot $Package -Rows $SavedManifest -Label 'Saved signed package post-catalog guard'
}

Write-StageStatus -Stage 1 -Name 'Build and local signing' -CurrentTask 'Verify source, build exact 193-file package, sign local catalog'
Write-Host 'Validation candidate. Exact final RC2-v2b build; no development-machine signer is reused.'
Remove-OrphanPrivateSigners

$Existing=Read-WorkflowState
if($null-ne$Existing-and[string]$Existing.Release-eq$Version-and-not[string]::IsNullOrWhiteSpace([string]$Existing.PackageRoot)){
    Verify-SignedWorkspace $Existing
    $Stage=[string]$Existing.Stage
    if($Stage-eq'SignedPackageReady'){
        Write-Host '[PASS] Existing exact signed package is intact; build work will not be repeated.' -ForegroundColor Green
        $BootBefore=Get-CurrentBootTime
        if(-not(Get-TestSigningConfigured)){
            if(-not(Confirm-ManagedOrInteractive 'Enable temporary Windows Test Signing and restart Windows now?' -Estimate 'The configuration is immediate; the reboot typically takes about 1-3 minutes.' -Impact 'This changes only the Windows Test Signing boot flag before reboot. The active graphics driver is not replaced in this step. Installation resumes automatically after sign-in.')){Write-Host '[PAUSE] Signed package preserved. Test Signing was not changed. Rerun the one-command launcher when ready.' -ForegroundColor Yellow;exit 3}
            & bcdedit.exe /set testsigning on|Out-Host
            if($LASTEXITCODE-ne0-or-not(Get-TestSigningConfigured)){throw 'bcdedit failed to configure Test Signing.'}
        } else {
            Write-Host '[INFO] Test Signing is already configured. The required reboot will run automatically in managed one-click mode.'
            if(-not(Confirm-ManagedOrInteractive 'Restart Windows now to enter the required Test Signing boot?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.')){Write-Host '[PAUSE] Signed package preserved. Rerun the one-command launcher when ready to reboot.' -ForegroundColor Yellow;exit 3}
        }
        Set-StateProperty $Existing 'Stage' 'AwaitingTestSigningReboot';Set-StateProperty $Existing 'BootTimeAtTestSigningEnable' $BootBefore.ToString('o');Set-StateProperty $Existing 'UpdatedAt' (Get-Date).ToString('o');Save-State $Existing
        Write-Host '[PASS] Test Signing is configured for the next boot.' -ForegroundColor Green
        Write-Host 'REBOOT REQUIRED. The one-command launcher will verify the boundary and continue after sign-in.'
        Arm-ManagedResumeTaskAtBoundary
        Write-Host '[REBOOT] Restart requested by the same consent gate that enabled Test Signing.' -ForegroundColor Cyan
        Restart-Computer -Force
        exit 2
    }
    if($Stage-eq'AwaitingTestSigningReboot'){
        if(-not(Get-TestSigningConfigured)){throw 'Workflow expects Test Signing enabled in BCD, but it is not configured.'}
        $OldBoot=[datetime]::Parse([string]$Existing.BootTimeAtTestSigningEnable)
        $NowBoot=Get-CurrentBootTime
        if($NowBoot-gt$OldBoot){
            Set-StateProperty $Existing 'Stage' 'ReadyForInstall';Set-StateProperty $Existing 'UpdatedAt' (Get-Date).ToString('o');Save-State $Existing
            Write-Host '[PASS] Reboot boundary crossed with Test Signing configured.' -ForegroundColor Green
            Write-Host 'SCRIPT 1 PASS: True';if($env:LEGIONGO_RC2I_MANAGED-eq'1'){Write-Host '[NEXT] Launcher will continue to Stage 2 automatically.'}else{Write-Host 'NEXT: run 02-Install-Driver-And-Verify-Normal-Signing.ps1'};exit 0
        }
        Write-Host '[INFO] Signed package is ready, but the Test Signing reboot has not happened yet.'
        Arm-ManagedResumeTaskAtBoundary
        if(Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.'){Write-Host '[REBOOT] Restart requested. One-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan;Restart-Computer -Force;exit 2}
        Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
        exit 2
    }
    if($Stage-in@('ReadyForInstall','AwaitingNormalSigningReboot','DriverComplete','AwaitingSoftwareReboot','SoftwareComplete','Complete')){
        Write-Host "[PASS] Existing exact signed package is intact. Workflow stage: $Stage" -ForegroundColor Green
        Write-Host 'SCRIPT 1 PASS: True';exit 0
    }
}

$Gpu=Get-LegionGoGpu
Write-Host "GPU: $($Gpu.DeviceName) / $($Gpu.DeviceID)"
Write-Host "Starting display origin: $($Gpu.OriginKind) / provider=$($Gpu.DriverProvider) / version=$($Gpu.DriverVersion) / INF=$($Gpu.ActiveINF)"
if($Gpu.DeviceID-notlike($Script:LegionGoHardwarePrefix+'*')){throw 'This toolkit is only for the original Lenovo Legion Go hardware identity.'}
$SecureBoot=Get-SecureBootState
if($SecureBoot-eq$true){throw 'Secure Boot is enabled. This RC does not change firmware security settings. Disable Secure Boot manually before continuing.'}
if($SecureBoot-eq$null){throw 'Secure Boot state could not be determined. This RC refuses to prepare a local-signing transaction without proving Secure Boot is disabled.'}
if(Get-NoIntegrityChecksConfigured){throw 'nointegritychecks is enabled in BCD. This RC refuses to proceed from an already-weakened code-integrity configuration.'}

$ResolvedInstaller=Resolve-AdjacentAmdInstaller -BaseDirectory $PSScriptRoot -InstallerPath $InstallerPath
$Installer=Assert-OfficialInstaller -InstallerPath $ResolvedInstaller
Write-Host "[PASS] Exact AMD 26.7.1 installer: $($Installer.SHA256)" -ForegroundColor Green
$Dependencies=Ensure-Stage1Dependencies
$SevenZip=[string]$Dependencies.SevenZip
$Tools=$Dependencies.Tools
Write-Host "[PASS] 7-Zip: $SevenZip"
Write-Host "[PASS] Portable x64 Inf2Cat: $($Tools.Inf2Cat)"
Write-Host "[PASS] Portable x64 SignTool: $($Tools.SignTool)"

$WorkRoot=Join-Path $env:SystemDrive ('AMD\LegionGo-AMD-26.7.1-Public-Beta-v3.1-'+$Timestamp)
$SourceRoot=Join-Path $WorkRoot 'Official-26.7.1'
$WtRoot=Join-Path $SourceRoot 'Packages\Drivers\Display\WT6A_INF'
$PackageRoot=Join-Path $WorkRoot 'Locally-Signed-RC2-v2b\Package'
New-Item -ItemType Directory -Path $SourceRoot,$PackageRoot -Force|Out-Null
Write-Section 'EXTRACT EXACT OFFICIAL AMD SOURCE'
$ExtractLog=Join-Path $Logs ('extract-official-'+$Timestamp+'.txt')
[void](Invoke-ProcessHeartbeat -FilePath $SevenZip -Arguments @('x','-y',('-o'+$SourceRoot),'--',$ResolvedInstaller) -LogPath $ExtractLog -TimeoutSeconds 2400 -Activity 'Extracting official AMD 26.7.1 source' -Estimate 'Typical time: about 2-8 minutes on an SSD; watchdog: 40 minutes.')
if(-not(Test-Path -LiteralPath $WtRoot -PathType Container)){throw "Expected WT6A_INF source was not extracted: $WtRoot"}
$SourceFiles=@(Get-ChildItem -LiteralPath $WtRoot -Recurse -File -Force)
if($SourceFiles.Count-ne$Script:ExpectedOfficialSourceFileCount){throw "Official WT6A_INF file-count mismatch. Expected=$($Script:ExpectedOfficialSourceFileCount) Actual=$($SourceFiles.Count)"}
$OfficialInf=Join-Path $WtRoot 'u0202643.inf';$OfficialDat=Join-Path $WtRoot 'B026283\amdgcf.dat';$OfficialCat=Join-Path $WtRoot 'u0202643.cat';$OfficialCcc2=Join-Path $WtRoot 'B026283\ccc2_install.exe'
if((Get-SHA256 $OfficialInf)-ne$Script:ExpectedOfficialInfSHA256){throw 'Official INF identity mismatch.'}
if((Get-SHA256 $OfficialDat)-ne$Script:ExpectedOfficialDatSHA256){throw 'Official DAT identity mismatch.'}
if((Get-SHA256 $OfficialCat)-ne$Script:ExpectedOfficialCatalogSHA256){throw 'Official main CAT identity mismatch.'}
if((Get-SHA256WithProgress -LiteralPath $OfficialCcc2 -Activity 'Verify extracted AMD ccc2_install.exe SHA-256')-ne$Script:ExpectedOfficialCcc2SHA256-or[int64](Get-Item $OfficialCcc2).Length-ne$Script:ExpectedOfficialCcc2Length){throw 'Official ccc2_install.exe identity mismatch.'}
if((Get-SHA256WithProgress -LiteralPath (Join-Path $WtRoot 'B026283\amdkmdag.sys') -Activity 'Verify extracted amdkmdag.sys SHA-256')-ne$Script:ExpectedKernelSHA256){throw 'Official kernel identity mismatch.'}
Write-Host '[PASS] Exact 194-file 26.7.1 WT6A_INF source proved.' -ForegroundColor Green

Write-Section 'BUILD EXACT 193-FILE RC2-v2b PACKAGE'
$Manifest=Get-UnchangedManifestRows
$ManifestCount=[int]$Manifest.Length
if($ManifestCount-ne190){throw "Internal unchanged-file manifest count mismatch: $ManifestCount"}
$Index=0
Write-ActivityProgress -Activity 'Verify and copy frozen unchanged package files' -Percent 0 -Status 'COPYING' -Detail ("0/{0} files" -f $ManifestCount)
foreach($Row in $Manifest){
    $Index++;$Rel=[string]$Row.path;$Src=Join-Path $WtRoot $Rel;$Dst=Join-Path $PackageRoot $Rel
    if(-not(Test-Path -LiteralPath $Src -PathType Leaf)){throw "Manifest source missing: $Rel"}
    if([int64](Get-Item $Src).Length-ne[int64]$Row.length){throw "Manifest length mismatch: $Rel"}
    $PreCopyPercent=if($ManifestCount-gt0){[int][Math]::Floor((($Index-1)*100.0)/$ManifestCount)}else{0}
    $SourceSize=[int64](Get-Item -LiteralPath $Src).Length
    Set-ActivityLivenessContext -Activity 'Verify and copy frozen unchanged package files' -Percent $PreCopyPercent -Status 'HASHING' -Detail ("file {0}/{1}: {2} ({3:N1} MB)" -f $Index,$ManifestCount,$Rel,($SourceSize/1MB))
    if((Get-SHA256 $Src)-ne([string]$Row.sha256).ToUpperInvariant()){throw "Manifest source hash mismatch: $Rel"}
    Set-ActivityLivenessContext -Activity 'Verify and copy frozen unchanged package files' -Percent $PreCopyPercent -Status 'COPYING' -Detail ("file {0}/{1}: {2}" -f $Index,$ManifestCount,$Rel)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Dst) -Force|Out-Null;Copy-Item -LiteralPath $Src -Destination $Dst -Force
    $CopyPercent=[int][Math]::Floor(($Index*100.0)/$ManifestCount)
    try{Write-Progress -Activity 'Verify and copy frozen unchanged package files' -Status ("{0}/{1} :: {2}" -f $Index,$ManifestCount,$Rel) -PercentComplete $CopyPercent}catch{}
    if($Index%10-eq0-or$Index-eq$ManifestCount){Write-ActivityProgress -Activity 'Verify and copy frozen unchanged package files' -Percent $CopyPercent -Status 'COPYING' -Detail ("{0}/{1} files" -f $Index,$ManifestCount)}
}
Complete-ActivityProgress -Activity 'Verify and copy frozen unchanged package files' -Detail ("{0}/{0} files exact" -f $ManifestCount)
$InfBuilder=Join-Path $PSScriptRoot 'Internal\Build-RC2-v2b-Inf.ps1';$DatBuilder=Join-Path $PSScriptRoot 'Internal\Build-RC2-v2b-AmdGcfDat.ps1'
& $InfBuilder -OfficialInfPath $OfficialInf -OutputPath (Join-Path $PackageRoot 'u0202643.inf')|Format-List
& $DatBuilder -OfficialDatPath $OfficialDat -OutputPath (Join-Path $PackageRoot 'B026283\amdgcf.dat')|Format-List
if(@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force).Count-ne$Script:ExpectedUnsignedFileCount){throw 'Unsigned package is not exactly 192 files before Inf2Cat.'}
if(Test-Path -LiteralPath (Join-Path $PackageRoot 'B026283\ccc2_install.exe')){throw 'ccc2_install.exe must not be included in the driver catalog package.'}
if(Test-Path -LiteralPath (Join-Path $PackageRoot 'amdcp\amdcp.inf')){throw 'Source-absent amdcp CopyINF package unexpectedly exists.'}
if(Test-Path -LiteralPath (Join-Path $PackageRoot 'amduw23e.inf')){throw 'Standalone Lenovo extension must not be included in merged v2b.'}

$CatPath=Join-Path $PackageRoot 'u0202643.cat'
Remove-Item -LiteralPath $CatPath -Force -ErrorAction SilentlyContinue
$Inf2CatLog=Join-Path $Logs ('inf2cat-'+$Timestamp+'.txt')
$Inf2CatArguments='/driver:"'+$PackageRoot+'" /os:10_X64 /verbose'
$Inf2CatResult=Invoke-RawArgumentsProcessHeartbeat -FilePath $Tools.Inf2Cat -ArgumentLine $Inf2CatArguments -WorkingDirectory (Split-Path -Parent $Tools.Inf2Cat) -LogPath $Inf2CatLog -TimeoutSeconds 900 -Activity 'Building Windows driver catalog for 193-file package' -Estimate 'Typical time: under a few minutes; watchdog: 15 minutes.'
$Inf2CatCombined=([string]$Inf2CatResult.Stdout+"`r`n"+[string]$Inf2CatResult.Stderr)
if($Inf2CatCombined-match'(?i)Parameter format not correct'){throw "Inf2Cat rejected the command-line transport despite exit code $($Inf2CatResult.ExitCode). Log: $Inf2CatLog"}
if($Inf2CatCombined-match'(?i)Signability test failed'){throw "Inf2Cat signability test failed. Log: $Inf2CatLog"}
if($Inf2CatCombined-notmatch'(?i)Signability test complete\.'){throw "Inf2Cat did not report a completed signability test. Log: $Inf2CatLog"}
if($Inf2CatCombined-notmatch'(?is)Errors:\s*None'){throw "Inf2Cat did not report Errors: None. Log: $Inf2CatLog"}
if($Inf2CatCombined-notmatch'(?is)Warnings:\s*None'){throw "Inf2Cat did not report Warnings: None. Log: $Inf2CatLog"}
if(-not(Test-Path -LiteralPath $CatPath -PathType Leaf)){throw 'Inf2Cat did not create u0202643.cat.'}
if(@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force).Count-ne$Script:ExpectedSignedFileCount){throw 'Package is not exactly 193 files after Inf2Cat.'}
Write-Section 'RESTORE ORIGINAL AMD COMPANION CATALOGS'
$PreservedCompanionCatalogs=Restore-OriginalAmdCompanionCatalogs -OfficialRoot $WtRoot -PackageRoot $PackageRoot -Rows $Manifest -SignToolPath $Tools.SignTool -LogRoot $Logs -RunStamp $Timestamp
if($PreservedCompanionCatalogs.Count-ne9){throw "Expected to preserve exactly 9 AMD companion catalogs; actual=$($PreservedCompanionCatalogs.Count)"}
Assert-UnchangedManifestExact -PackageRoot $PackageRoot -Rows $Manifest -Label 'Post-Inf2Cat companion-catalog restoration guard'
if(@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force).Count-ne$Script:ExpectedSignedFileCount){throw 'Package file count changed while restoring AMD companion catalogs.'}
$UnsignedCatalogSHA256=Get-SHA256 $CatPath
Write-Host '[PASS] Inf2Cat field-proven transport: ProcessStartInfo raw arguments + /os:10_X64; Errors=None; Warnings=None.' -ForegroundColor Green
Write-Host "Unsigned local catalog SHA256: $UnsignedCatalogSHA256"

Write-Section 'CREATE ONE-TIME LOCAL SIGNER AND SIGN CATALOG'
$Subject='CN=LegionGo AMD 26.7.1 Public Beta v3.1 Local Driver '+$Timestamp
$Cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject -FriendlyName 'LegionGo AMD 26.7.1 Public Beta v3.1 Local Catalog Signing' -CertStoreLocation 'Cert:\LocalMachine\My' -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddYears(5)
if($null-eq$Cert-or-not$Cert.HasPrivateKey){throw 'Failed to create the temporary non-exportable code-signing certificate.'}
$Thumb=[string]$Cert.Thumbprint
$CerPath=Join-Path $WorkRoot 'LegionGo-AMD-26.7.1-Public-Beta-v3.1-Public.cer'
Export-Certificate -Cert $Cert -FilePath $CerPath -Type CERT -Force|Out-Null
Import-Certificate -FilePath $CerPath -CertStoreLocation 'Cert:\LocalMachine\Root'|Out-Null
Import-Certificate -FilePath $CerPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'|Out-Null
$SignLog=Join-Path $Logs ('signtool-sign-'+$Timestamp+'.txt')
[void](Invoke-ProcessHeartbeat -FilePath $Tools.SignTool -Arguments @('sign','/sm','/s','My','/sha1',$Thumb,'/fd','SHA256','/v',$CatPath) -LogPath $SignLog -TimeoutSeconds 300 -Activity 'Signing local driver catalog' -Estimate 'Typical time: under 1 minute; watchdog: 5 minutes.')
$SignedCatalogSHA256=Get-SHA256 $CatPath
$Sig=Get-AuthenticodeSignature -LiteralPath $CatPath
if($Sig.Status-ne'Valid'-or$null-eq$Sig.SignerCertificate-or[string]$Sig.SignerCertificate.Thumbprint-ne$Thumb){throw 'Signed catalog verification failed.'}
Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$Thumb) -Force
Assert-PublicSignerTrust -Thumbprint $Thumb
Write-Host '[PASS] Catalog signed; private signing copy removed; public trust retained.' -ForegroundColor Green

$VerifyCatLog=Join-Path $Logs ('signtool-verify-cat-'+$Timestamp+'.txt')
$VerifyInfLog=Join-Path $Logs ('signtool-verify-inf-membership-'+$Timestamp+'.txt')
[void](Invoke-ProcessHeartbeat -FilePath $Tools.SignTool -Arguments @('verify','/pa','/v',$CatPath) -LogPath $VerifyCatLog -TimeoutSeconds 300 -Activity 'Verifying local catalog under PnP Authenticode policy' -Estimate 'Typical time: under 1 minute; watchdog: 5 minutes.')
[void](Invoke-ProcessHeartbeat -FilePath $Tools.SignTool -Arguments @('verify','/pa','/v','/c',$CatPath,(Join-Path $PackageRoot 'u0202643.inf')) -LogPath $VerifyInfLog -TimeoutSeconds 300 -Activity 'Verifying display INF membership in local catalog' -Estimate 'Typical time: under 1 minute; watchdog: 5 minutes.')
Assert-UnchangedManifestExact -PackageRoot $PackageRoot -Rows $Manifest -Label 'Post-sign final 190-file immutability guard'
if(@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force).Count-ne$Script:ExpectedSignedFileCount){throw 'Final signed package is not exactly 193 files.'}
Write-Host '[PASS] PnP signature verification passed and all nine companion catalogs remain exact original AMD-shipped WHQL-signed bytes.' -ForegroundColor Green

$SnapshotFiles=@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force)
$Snapshot=@();$SnapshotIndex=0;$SnapshotTotal=$SnapshotFiles.Count
Write-ActivityProgress -Activity 'Capture final signed package inventory' -Percent 0 -Status 'HASHING' -Detail ("0/{0} files" -f $SnapshotTotal)
foreach($SnapshotFile in $SnapshotFiles){
    $SnapshotIndex++
    $SnapshotBeforePercent=if($SnapshotTotal-gt0){[int][Math]::Floor((($SnapshotIndex-1)*100.0)/$SnapshotTotal)}else{0}
    Set-ActivityLivenessContext -Activity 'Capture final signed package inventory' -Percent $SnapshotBeforePercent -Status 'HASHING' -Detail ("file {0}/{1}: {2} ({3:N1} MB)" -f $SnapshotIndex,$SnapshotTotal,$SnapshotFile.Name,([int64]$SnapshotFile.Length/1MB))
    $Snapshot += [pscustomobject]@{Path=$SnapshotFile.FullName.Substring($PackageRoot.Length+1);Length=[int64]$SnapshotFile.Length;SHA256=Get-SHA256 $SnapshotFile.FullName}
    $SnapshotPercent=if($SnapshotTotal-gt0){[int][Math]::Floor(($SnapshotIndex*100.0)/$SnapshotTotal)}else{100}
    try{Write-Progress -Activity 'Capture final signed package inventory' -Status ("{0}/{1} :: {2}" -f $SnapshotIndex,$SnapshotTotal,$SnapshotFile.Name) -PercentComplete $SnapshotPercent}catch{}
    if($SnapshotIndex%10-eq0-or$SnapshotIndex-eq$SnapshotTotal){Write-ActivityProgress -Activity 'Capture final signed package inventory' -Percent $SnapshotPercent -Status 'HASHING' -Detail ("{0}/{1} files" -f $SnapshotIndex,$SnapshotTotal)}
}
Complete-ActivityProgress -Activity 'Capture final signed package inventory' -Detail ("{0}/{0} files recorded" -f $SnapshotTotal)
$State=[pscustomobject]@{
    SchemaVersion=3;Release=$Version;Stage='SignedPackageReady';CreatedAt=(Get-Date).ToString('o');UpdatedAt=(Get-Date).ToString('o');
    InstallerPath=$ResolvedInstaller;InstallerSHA256=$Script:ExpectedInstallerSHA256;WorkRoot=$WorkRoot;SourceRoot=$SourceRoot;OfficialCcc2Path=$OfficialCcc2;
    PackageRoot=$PackageRoot;FinalInfSHA256=$Script:ExpectedFinalInfSHA256;FinalDatSHA256=$Script:ExpectedFinalDatSHA256;KernelSHA256=$Script:ExpectedKernelSHA256;
    SignedCatalogSHA256=$SignedCatalogSHA256;UnsignedCatalogSHA256=$UnsignedCatalogSHA256;SignerThumbprint=$Thumb;SignerSubject=$Subject;PublicCerPath=$CerPath;PublicCerSHA256=(Get-SHA256 $CerPath);
    PreservedAmdCompanionCatalogs=@($PreservedCompanionCatalogs);PackageFiles=$Snapshot;SecureBoot=$SecureBoot;BootTimeAtBuild=(Get-CurrentBootTime).ToString('o')
}
Save-State $State

Write-Section 'TEMPORARY TEST SIGNING + REBOOT BOUNDARY'
$BootBefore=Get-CurrentBootTime
if(-not(Get-TestSigningConfigured)){
    if(-not(Confirm-ManagedOrInteractive 'Enable temporary Windows Test Signing and restart Windows now?' -Estimate 'The configuration is immediate; the reboot typically takes about 1-3 minutes.' -Impact 'This changes only the Windows Test Signing boot flag before reboot. The active graphics driver is not replaced in this step. Installation resumes automatically after sign-in.')){Write-Host '[PAUSE] Package build/signing is complete and preserved. Test Signing was not changed. Rerun the one-command launcher when ready.' -ForegroundColor Yellow;exit 3}
    & bcdedit.exe /set testsigning on|Out-Host
    if($LASTEXITCODE-ne0-or-not(Get-TestSigningConfigured)){throw 'bcdedit failed to configure Test Signing.'}
} else {
    Write-Host '[INFO] Test Signing was already configured. The required reboot will run automatically in managed one-click mode.'
    if(-not(Confirm-ManagedOrInteractive 'Restart Windows now to enter the required Test Signing boot?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.')){Write-Host '[PAUSE] Package build/signing is complete and preserved. Rerun the one-command launcher when ready to reboot.' -ForegroundColor Yellow;exit 3}
}
Set-StateProperty $State 'Stage' 'AwaitingTestSigningReboot';Set-StateProperty $State 'BootTimeAtTestSigningEnable' $BootBefore.ToString('o');Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o');Save-State $State
Complete-CurrentSection -Detail 'package signed; Test Signing configured; reboot boundary armed'
Write-Host '[PASS] Exact v2b package built and signed. Test Signing is configured for the next boot.' -ForegroundColor Green
Write-Host 'REBOOT REQUIRED. The one-command launcher will verify the boundary and continue after sign-in.'
Arm-ManagedResumeTaskAtBoundary
Write-Host '[REBOOT] Restart requested by the same consent gate that enabled Test Signing.' -ForegroundColor Cyan
Restart-Computer -Force
exit 2
