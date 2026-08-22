#requires -Version 5.1
#requires -RunAsAdministrator
<##
Stage 2 performs the controlled Public Beta v3.1 target-device binding:
export rollback material, stage the exact freshly signed merged v2b package
without deleting the previous display package, remove only the obsolete
standalone Lenovo amduw23e extension when present, explicitly force-bind the
merged INF to the original Legion Go hardware ID, verify the active binding,
then turn Test Signing off and require a normal-signing reboot. Other inactive
Display-class packages remain staged as rollback/history material.
##>
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Internal\Common.ps1')
$Version = 'Public-Beta-v3.1'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Logs = Join-Path $Script:WorkflowRoot 'Logs'
New-Item -ItemType Directory -Path $Logs -Force | Out-Null
Initialize-InstallerRuntime -StageLabel 'Stage 2 - driver transaction'
$Stage2ResultPath = Join-Path $Script:WorkflowRoot 'stage2-result.json'
$Stage2InvocationId = [string]$env:LEGIONGO_STAGE_INVOCATION_ID

function Write-Stage2Result {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Passed','RebootRequired','Paused','Failed')][string]$Status,
        [Parameter(Mandatory=$true)][int]$ExitCode,
        [Parameter(Mandatory=$true)][string]$Detail
    )
    if ([string]::IsNullOrWhiteSpace($Stage2InvocationId)) { return }
    $Contract = [ordered]@{
        Schema='LegionGo-AMD-26.7.1-Public-Beta-v3.1-Stage2Result'
        Release='Public-Beta-v3.1'
        InvocationId=$Stage2InvocationId
        Status=$Status
        ExitCode=$ExitCode
        Detail=$Detail
        At=(Get-Date).ToString('o')
    }
    Write-JsonAtomic -InputObject $Contract -LiteralPath $Stage2ResultPath -Depth 10
}
trap {
    if($_.Exception -is [System.OperationCanceledException]){
        $PauseText=$_.Exception.Message
        Write-Host ('[PAUSE] ' + $PauseText) -ForegroundColor Yellow
        try { Write-Stage2Result -Status 'Paused' -ExitCode 3 -Detail $PauseText } catch {}
        exit 3
    }
    $FailureText=$_.Exception.Message
    try{$SafetyText=Get-WorkflowSafetySummary}catch{$SafetyText='Safety state could not be summarized; preserve rollback exports and logs.'}
    Write-FailureGuide -Stage 'Stage 2 - driver replacement/recovery' -Message $FailureText -SafetyState $SafetyText
    try { Write-Stage2Result -Status 'Failed' -ExitCode 1 -Detail $FailureText } catch {}
    exit 1
}

function Save-State($State) { Write-JsonAtomic -InputObject $State -LiteralPath $Script:WorkflowStatePath -Depth 30 }
function Invoke-Pnp([string[]]$Arguments,[string]$Name,[switch]$AllowFailure) {
    $Log = Join-Path $Logs ($Timestamp + '-' + $Name + '.txt')
    return Invoke-ProcessHeartbeat -FilePath "$env:WINDIR\System32\pnputil.exe" -Arguments $Arguments -LogPath $Log -TimeoutSeconds 300 -Activity ('PnP driver operation: ' + $Name) -Estimate 'Most PnP operations finish in seconds to a few minutes; the screen may flicker during install/uninstall.' -AllowFailure:$AllowFailure
}
function Get-ExportedInfByHash([string]$Root,[string]$ExpectedHash) {
    $HashMatches = @()
    foreach ($Inf in @(Get-ChildItem -LiteralPath $Root -Filter '*.inf' -File -Recurse -ErrorAction SilentlyContinue)) {
        try { if ((Get-SHA256 $Inf.FullName) -eq $ExpectedHash) { $HashMatches += $Inf.FullName } } catch {}
    }
    if ($HashMatches.Count -ne 1) { throw "Expected one exported rollback INF matching $ExpectedHash; found $($HashMatches.Count)." }
    return $HashMatches[0]
}
function Get-StateTextProperty($State,[string]$Name) {
    $Property = $State.PSObject.Properties[$Name]
    if ($null -eq $Property -or $null -eq $Property.Value) { return '' }
    return [string]$Property.Value
}
function Assert-FrozenUnchangedPackage([string]$PackageRoot) {
    $ManifestPath=Join-Path $PSScriptRoot 'Internal\RC2-v2b-Unchanged-190.json'
    $Raw=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    if($Raw -is [System.Array]){$Rows=$Raw}else{$Rows=@($Raw)}
    $Checked=0;$Total=@($Rows).Count;$NextConsolePercent=0
    Write-ActivityProgress -Activity 'Stage 2 frozen 190-file guard' -Percent 0 -Status 'VERIFYING' -Detail ("0/{0} files" -f $Total)
    foreach($Row in @($Rows)){
        $Rel=[string]$Row.path;$Path=Join-Path $PackageRoot $Rel
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Pre-destructive unchanged package file missing: $Rel"}
        if([int64](Get-Item -LiteralPath $Path).Length-ne[int64]$Row.length){throw "Pre-destructive unchanged package length mismatch: $Rel"}
        $BeforePercent=if($Total-gt0){[int][Math]::Floor(($Checked*100.0)/$Total)}else{0}
        $GuardSize=[int64](Get-Item -LiteralPath $Path).Length
        Set-ActivityLivenessContext -Activity 'Stage 2 frozen 190-file guard' -Percent $BeforePercent -Status 'HASHING' -Detail ("file {0}/{1}: {2} ({3:N1} MB)" -f ($Checked+1),$Total,$Rel,($GuardSize/1MB))
        if((Get-SHA256 $Path)-ne([string]$Row.sha256).ToUpperInvariant()){throw "Pre-destructive unchanged package hash mismatch: $Rel"}
        $Checked++
        $Percent=if($Total-gt0){[int][Math]::Floor(($Checked*100.0)/$Total)}else{100}
        try{Write-Progress -Activity 'Stage 2 frozen 190-file guard' -Status ("{0}/{1} files :: {2}" -f $Checked,$Total,$Rel) -PercentComplete $Percent}catch{}
        if($Percent-ge$NextConsolePercent-or$Checked-eq$Total){Write-ActivityProgress -Activity 'Stage 2 frozen 190-file guard' -Percent $Percent -Status 'VERIFYING' -Detail ("{0}/{1} files" -f $Checked,$Total);$NextConsolePercent=[Math]::Min(100,$NextConsolePercent+10)}
    }
    if($Checked-ne190){throw "Pre-destructive unchanged-manifest count mismatch: $Checked"}
    Complete-ActivityProgress -Activity 'Stage 2 frozen 190-file guard' -Detail '190/190 files exact'
    Write-Host '[PASS] Pre-destructive package guard: all 190 AMD-unchanged files still match the frozen manifest.' -ForegroundColor Green
}
function Wait-ForPnPQuiescence {
    $Started = Get-Date
    $NextBeat = $Started
    while (@(Get-Process -Name 'pnputil' -ErrorAction SilentlyContinue).Count -gt 0) {
        $Now = Get-Date
        if (($Now - $Started).TotalSeconds -gt 300) { throw 'pnputil.exe is still running after 5 minutes; recovery will not start while another PnP transaction may still be active.' }
        if ($Now -ge $NextBeat) {
            $ElapsedText=Format-Elapsed -Elapsed ($Now-$Started)
            Write-IndeterminateActivityProgress -Activity 'Wait for existing pnputil.exe before recovery' -Tick ([int](($Now-$Started).TotalSeconds/10)) -Elapsed $ElapsedText
            $NextBeat = $Now.AddSeconds(10)
        }
        Start-Sleep -Milliseconds 500
    }
}
function Invoke-BestEffortRollback($State,[string]$RecoveryStatus,[string]$Reason) {
    Write-Section 'BEST-EFFORT ROLLBACK / INTERRUPTION RECOVERY'
    Wait-ForPnPQuiescence
    Write-Host ("[RECOVERY] Reason: {0}" -f $Reason) -ForegroundColor Yellow

    $RollbackRoot = Get-StateTextProperty -State $State -Name 'RollbackRoot'
    $RollbackBaseInf = Get-StateTextProperty -State $State -Name 'RollbackBaseInf'
    $RollbackExtensionInf = Get-StateTextProperty -State $State -Name 'RollbackExtensionInf'
    $RollbackExtensionInfs = @()
    $RollbackExtensionArrayProperty = $State.PSObject.Properties['RollbackExtensionInfs']
    if ($null -ne $RollbackExtensionArrayProperty) {
        $RollbackExtensionInfs = @(
            $RollbackExtensionArrayProperty.Value |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object { [string]$_ }
        )
    }
    if ($RollbackExtensionInfs.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($RollbackExtensionInf)) {
        $RollbackExtensionInfs = @($RollbackExtensionInf)
    }
    $PreviousOriginalInfPath = Get-StateTextProperty -State $State -Name 'PreviousOriginalInfPath'
    $PreviousInfHash = Get-StateTextProperty -State $State -Name 'PreviousInfHash'
    $PreviousOriginKind = Get-StateTextProperty -State $State -Name 'PreviousOriginKind'

    $CandidateRemovalOk = $true
    $BaseRestoreOk = $false
    $ExtensionRestoreOk = $true
    $ScanOk = $false

    if ($PreviousOriginKind -eq 'MicrosoftBasic') {
        # Microsoft Basic is the one origin for which candidate removal is the
        # rollback mechanism. There is no third-party previous INF to bind.
        try {
            foreach ($DriverRow in @(Get-AmdDisplayDrivers)) {
                try {
                    if ((Get-SHA256 ([string]$DriverRow.OriginalFileName)) -eq $Script:ExpectedFinalInfSHA256) {
                        $RemovalResult = Invoke-Pnp -Arguments @('/delete-driver',([string]$DriverRow.Driver),'/uninstall','/force') -Name 'rollback-remove-candidate-basic-origin' -AllowFailure
                        if ($RemovalResult.ExitCode -ne 0) { $CandidateRemovalOk = $false }
                    }
                } catch { $CandidateRemovalOk = $false }
            }
            [void](Invoke-Pnp -Arguments @('/scan-devices') -Name 'rollback-basic-rescan' -AllowFailure)
            Start-Sleep -Seconds 3
            $BasicGpu = Get-LegionGoGpu
            $BaseRestoreOk = (
                $BasicGpu.OriginKind -eq 'MicrosoftBasic' -and
                $BasicGpu.Status -eq 'OK' -and
                $BasicGpu.ProblemCode -eq 0 -and
                -not [bool]$BasicGpu.HasProblem
            )
            if ($BaseRestoreOk) {
                Write-Host ("[PASS] Microsoft Basic Display Adapter origin restored by candidate removal + PnP rescan: {0}" -f $BasicGpu.ActiveINF) -ForegroundColor Green
            } else {
                Write-Host ("[FAIL] Expected Microsoft Basic Display Adapter after rollback; got origin={0} driver={1} INF={2}" -f $BasicGpu.OriginKind,$BasicGpu.DriverVersion,$BasicGpu.ActiveINF) -ForegroundColor Red
            }
        } catch {
            $BaseRestoreOk = $false
            Write-Host ("[FAIL] Microsoft Basic Display Adapter rollback verification failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        # Third-party/legacy origins keep their previous display package staged.
        # Prefer rebinding that exact Driver Store INF; exported material is a
        # fallback if the staged path is unexpectedly unavailable.
        $RestoreInf = ''
        if (
            -not [string]::IsNullOrWhiteSpace($PreviousOriginalInfPath) -and
            (Test-Path -LiteralPath $PreviousOriginalInfPath -PathType Leaf)
        ) {
            try {
                if ((Get-SHA256 -LiteralPath $PreviousOriginalInfPath) -eq $PreviousInfHash) {
                    $RestoreInf = $PreviousOriginalInfPath
                }
            } catch {}
        }

        if ([string]::IsNullOrWhiteSpace($RestoreInf)) {
            if (
                -not [string]::IsNullOrWhiteSpace($RollbackBaseInf) -and
                (Test-Path -LiteralPath $RollbackBaseInf -PathType Leaf)
            ) {
                try {
                    if ((Get-SHA256 -LiteralPath $RollbackBaseInf) -eq $PreviousInfHash) {
                        [void](Invoke-Pnp -Arguments @('/add-driver',$RollbackBaseInf) -Name 'rollback-restage-previous-display' -AllowFailure)
                        $RestoreInf = $RollbackBaseInf
                    }
                } catch {}
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($RestoreInf)) {
            try {
                [void](Invoke-ForceBindLegionGoDriver -InfPath $RestoreInf)
                [void](Invoke-Pnp -Arguments @('/scan-devices') -Name 'rollback-scan-after-rebind' -AllowFailure)
                Start-Sleep -Seconds 3
                $RestoredGpu = Get-LegionGoGpu
                $BaseRestoreOk = (
                    $RestoredGpu.Status -eq 'OK' -and
                    $RestoredGpu.ProblemCode -eq 0 -and
                    -not [bool]$RestoredGpu.HasProblem -and
                    $RestoredGpu.InfSHA256 -eq $PreviousInfHash
                )
            } catch {
                $BaseRestoreOk = $false
            }
        } else {
            Write-Host '[FAIL] Saved/staged previous display INF is unavailable.' -ForegroundColor Red
        }

        Write-Host '[INFO] RC2zp candidate remains staged after third-party rollback by design; active binding determines the live driver.'
    }

    if ($RollbackExtensionInfs.Count -gt 0) {
        $RestoreIndex = 0
        foreach ($RollbackExtensionPath in $RollbackExtensionInfs) {
            $RestoreIndex++
            if (Test-Path -LiteralPath $RollbackExtensionPath -PathType Leaf) {
                try {
                    $ExtensionResult = Invoke-Pnp -Arguments @('/add-driver',$RollbackExtensionPath,'/install') -Name ('rollback-restore-extension-{0}' -f $RestoreIndex) -AllowFailure
                    if ($ExtensionResult.ExitCode -ne 0) { $ExtensionRestoreOk = $false }
                } catch { $ExtensionRestoreOk = $false }
            } else {
                $ExtensionRestoreOk = $false
            }
        }
    }

    try {
        $ScanResult = Invoke-Pnp -Arguments @('/scan-devices') -Name 'rollback-final-scan' -AllowFailure
        $ScanOk = ($ScanResult.ExitCode -eq 0)
    } catch { $ScanOk = $false }

    if ($PreviousOriginKind -eq 'MicrosoftBasic') {
        if ($CandidateRemovalOk) { Write-Host '[PASS] Candidate package cleanup for Microsoft Basic rollback' -ForegroundColor Green }
        else { Write-Host '[WARN] Candidate package cleanup for Microsoft Basic rollback was incomplete' -ForegroundColor Yellow }
    } else {
        Write-Host '[PASS] Candidate package retained; no broad Display-class cleanup performed' -ForegroundColor Green
    }

    if ($BaseRestoreOk) { Write-Host '[PASS] Previous display origin restore' -ForegroundColor Green }
    else { Write-Host '[FAIL] Previous display origin restore did not report success' -ForegroundColor Red }

    if ($RollbackExtensionInfs.Count -gt 0) {
        if ($ExtensionRestoreOk) { Write-Host ("[PASS] Lenovo extension lineage restore :: {0} package(s)" -f $RollbackExtensionInfs.Count) -ForegroundColor Green }
        else { Write-Host '[FAIL] Lenovo extension lineage restore did not report success' -ForegroundColor Red }
    }

    if ($ScanOk) { Write-Host '[PASS] Hardware rescan' -ForegroundColor Green }
    else { Write-Host '[WARN] Hardware rescan did not report success' -ForegroundColor Yellow }

    $RecoveryGpuText = 'GPU state could not be queried.'
    try {
        $RecoveryGpu = Get-LegionGoGpu
        $RecoveryGpuText = ("GPU status={0} code={1} hasProblem={2} driver={3} INF={4}" -f $RecoveryGpu.Status,$RecoveryGpu.ProblemCode,$RecoveryGpu.HasProblem,$RecoveryGpu.DriverVersion,$RecoveryGpu.ActiveINF)
        Write-Host ("[RECOVERY] {0}" -f $RecoveryGpuText)
    } catch {
        $RecoveryGpuText = 'GPU state could not be queried: ' + $_.Exception.Message
        Write-Host ("[RECOVERY] {0}" -f $RecoveryGpuText) -ForegroundColor Yellow
    }

    Set-StateProperty $State 'TransactionStatus' $RecoveryStatus
    Set-StateProperty $State 'RecoveryAt' (Get-Date).ToString('o')
    Set-StateProperty $State 'RecoveryReason' $Reason
    Set-StateProperty $State 'RecoveryGpuState' $RecoveryGpuText
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    try { Save-State $State } catch { Write-Host ("[WARN] Recovery state could not be saved: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }

    if (-not [string]::IsNullOrWhiteSpace($RollbackRoot)) { Write-Host ("Rollback exports remain at: {0}" -f $RollbackRoot) }
    Write-Host 'Test Signing is intentionally left on after recovery. Do not manually clean Driver Store packages.' -ForegroundColor Yellow

    return [pscustomobject]@{
        CandidateRemovalOk=$CandidateRemovalOk
        BaseRestoreOk=$BaseRestoreOk
        ExtensionRestoreOk=$ExtensionRestoreOk
        ScanOk=$ScanOk
        GpuState=$RecoveryGpuText
        RollbackRoot=$RollbackRoot
    }
}

function Get-ActiveCatalogIdentity {
    param([Parameter(Mandatory=$true)]$Gpu)
    $CatalogActivity='Resolve and verify active Driver Store catalog'
    Write-ActivityProgress -Activity $CatalogActivity -Percent 0 -Status 'START' -Detail ("ActiveINF={0}" -f [string]$Gpu.ActiveINF)

    Set-ActivityLivenessContext -Activity $CatalogActivity -Percent 20 -Status 'RESOLVING' -Detail 'locating active Driver Store repository'
    Write-ActivityProgress -Activity $CatalogActivity -Percent 20 -Status 'RESOLVING' -Detail 'locating active Driver Store repository'
    $ResolvedCatalog = Resolve-DriverStoreCatalogForPublishedInf -PublishedInf ([string]$Gpu.ActiveINF)
    $StoreRoot = [string]$ResolvedCatalog.StoreRoot
    $CatalogPath = [string]$ResolvedCatalog.CatalogPath

    Set-ActivityLivenessContext -Activity $CatalogActivity -Percent 50 -Status 'HASHING' -Detail ("catalog: {0}" -f $CatalogPath)
    Write-ActivityProgress -Activity $CatalogActivity -Percent 50 -Status 'HASHING' -Detail ([IO.Path]::GetFileName($CatalogPath))
    $CatalogHash = Get-SHA256 -LiteralPath $CatalogPath

    Set-ActivityLivenessContext -Activity $CatalogActivity -Percent 75 -Status 'SIGNATURE' -Detail 'Windows Authenticode trust verification'
    Write-ActivityProgress -Activity $CatalogActivity -Percent 75 -Status 'SIGNATURE' -Detail 'Windows Authenticode trust verification'
    $Sig = Get-AuthenticodeSignature -LiteralPath $CatalogPath
    $Thumb = if ($null -ne $Sig.SignerCertificate) { [string]$Sig.SignerCertificate.Thumbprint } else { '' }
    Complete-ActivityProgress -Activity $CatalogActivity -Detail ("SHA256={0}; signer={1}; status={2}" -f $CatalogHash,$Thumb,[string]$Sig.Status)
    return [pscustomobject]@{
        StoreRoot = $StoreRoot
        InfPath = [string]$ResolvedCatalog.InfPath
        CatalogName = [string]$ResolvedCatalog.CatalogName
        CatalogPath = $CatalogPath
        CatalogSHA256 = $CatalogHash
        SignatureStatus = [string]$Sig.Status
        SignerThumbprint = $Thumb
    }
}

function Assert-ExpectedActiveCatalog {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Gpu,
        $Identity = $null
    )
    $ExpectedHash = Get-StateTextProperty -State $State -Name 'ExpectedActiveCatalogSHA256'
    $ExpectedSigner = Get-StateTextProperty -State $State -Name 'ExpectedActiveCatalogSignerThumbprint'
    $Disposition = Get-StateTextProperty -State $State -Name 'ActiveCatalogDisposition'
    if ([string]::IsNullOrWhiteSpace($ExpectedHash) -or [string]::IsNullOrWhiteSpace($ExpectedSigner) -or [string]::IsNullOrWhiteSpace($Disposition)) {
        throw 'Expected active-catalog identity is missing from workflow state.'
    }
    if ($Disposition -notin @('Stage1Candidate','RetainedPreexistingExactFinal')) { throw "Unknown active catalog disposition: $Disposition" }
    if ($null -eq $Identity) { $Identity = Get-ActiveCatalogIdentity -Gpu $Gpu }
    if ($Identity.CatalogSHA256 -ne $ExpectedHash) { throw "Active catalog hash mismatch for disposition $Disposition. Expected=$ExpectedHash Actual=$($Identity.CatalogSHA256)" }
    if ($Identity.SignatureStatus -ne 'Valid' -or $Identity.SignerThumbprint -ne $ExpectedSigner) {
        throw "Active catalog signature mismatch for disposition $Disposition. Status=$($Identity.SignatureStatus) ExpectedSigner=$ExpectedSigner ActualSigner=$($Identity.SignerThumbprint)"
    }
    Assert-PublicSignerTrust -Thumbprint $ExpectedSigner
    return $Identity
}

function Apply-SignerTrustPolicy {
    param([Parameter(Mandatory=$true)]$State)
    $Disposition = Get-StateTextProperty -State $State -Name 'ActiveCatalogDisposition'
    $Stage1Signer = Get-StateTextProperty -State $State -Name 'SignerThumbprint'
    $ExpectedActiveSigner = Get-StateTextProperty -State $State -Name 'ExpectedActiveCatalogSignerThumbprint'
    if ([string]::IsNullOrWhiteSpace($Stage1Signer) -or [string]::IsNullOrWhiteSpace($ExpectedActiveSigner)) {
        throw 'Signer trust policy cannot be applied because signer identity is missing from workflow state.'
    }

    switch ($Disposition) {
        'Stage1Candidate' {
            if ($Stage1Signer -ne $ExpectedActiveSigner) { throw 'Stage1Candidate disposition requires the current-run signer to equal the active catalog signer.' }
            Assert-PublicSignerTrust -Thumbprint $Stage1Signer
            Set-StateProperty $State 'SignerTrustDisposition' 'ActiveStage1SignerRetained'
            Set-StateProperty $State 'SignerTrustCleanupRemovedCopies' 0
        }
        'RetainedPreexistingExactFinal' {
            if ($Stage1Signer -eq $ExpectedActiveSigner) { throw 'RetainedPreexistingExactFinal requires the current-run signer to differ from the retained active catalog signer.' }
            $Removed = Ensure-ExactPublicSignerTrustRemoved -Thumbprint $Stage1Signer -ExpectedActiveSignerThumbprint $ExpectedActiveSigner
            Assert-SignerTrustAbsent -Thumbprint $Stage1Signer
            Assert-PublicSignerTrust -Thumbprint $ExpectedActiveSigner
            Set-StateProperty $State 'SignerTrustDisposition' 'UnusedStage1SignerRemoved'
            Set-StateProperty $State 'SignerTrustCleanupRemovedCopies' ([int]$Removed)
            Set-StateProperty $State 'SignerTrustCleanupAt' (Get-Date).ToString('o')
            Write-Host ("[PASS] Unused current-run signer trust is absent; retained active signer remains trusted. RemovedCopies={0}; UnusedSigner={1}; ActiveSigner={2}" -f $Removed,$Stage1Signer,$ExpectedActiveSigner) -ForegroundColor Green
        }
        default { throw "Cannot apply signer trust policy for unknown catalog disposition: $Disposition" }
    }
}

function Verify-NormalFinal($State) {
    Write-IndeterminateActivityProgress -Activity 'Query Legion Go GPU for normal-signing seal' -Tick 0 -Elapsed '00:00' -Detail 'PnP device properties + active INF + loaded kernel'
    Set-ActivityLivenessContext -Activity 'Query Legion Go GPU for normal-signing seal' -Status 'QUERYING' -Detail 'PnP device properties + active INF + loaded kernel' -Indeterminate
    $Gpu = Get-LegionGoGpu
    Complete-ActivityProgress -Activity 'Query Legion Go GPU for normal-signing seal' -Detail ("INF={0}; Driver={1}; Status={2}" -f $Gpu.ActiveINF,$Gpu.DriverVersion,$Gpu.Status)
    [void](Assert-FinalDriver -Gpu $Gpu -Activity 'Verify exact driver after normal-signing reboot')
    [void](Assert-ExpectedActiveCatalog -State $State -Gpu $Gpu)
    if (Get-TestSigningConfigured) { throw 'Test Signing remains configured after the normal-signing reboot.' }

    Write-IndeterminateActivityProgress -Activity 'Check standalone Lenovo extension after normal-signing reboot' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
    Set-ActivityLivenessContext -Activity 'Check standalone Lenovo extension after normal-signing reboot' -Status 'QUERYING' -Detail 'Get-WindowsDriver -Online -All' -Indeterminate
    $Ext = @(Get-LenovoExtensionDrivers)
    Complete-ActivityProgress -Activity 'Check standalone Lenovo extension after normal-signing reboot' -Detail ("rows={0}" -f $Ext.Count)
    if ($Ext.Count -ne 0) { throw "Standalone amduw23e remains staged: $($Ext.Count)" }

    Write-IndeterminateActivityProgress -Activity 'Enumerate AMD Display Driver Store inventory for normal-signing seal' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
    Set-ActivityLivenessContext -Activity 'Enumerate AMD Display Driver Store inventory for normal-signing seal' -Status 'QUERYING' -Detail 'Get-WindowsDriver -Online -All' -Indeterminate
    $Display = @(Get-AmdDisplayDrivers)
    Complete-ActivityProgress -Activity 'Enumerate AMD Display Driver Store inventory for normal-signing seal' -Detail ("AMD Display rows={0}" -f $Display.Count)

    Write-ActivityProgress -Activity 'Verify exact final Display package remains staged' -Percent 0 -Status 'VERIFYING' -Detail ("0/{0} AMD Display rows" -f $Display.Count)
    $FinalRows=@(); $Index=0
    foreach($DriverRow in $Display){
        $Index++
        try { if ((Get-SHA256 -LiteralPath ([string]$DriverRow.OriginalFileName)) -eq $Script:ExpectedFinalInfSHA256) { $FinalRows += $DriverRow } } catch {}
        $Percent=if($Display.Count-gt0){[int][Math]::Floor(($Index*100.0)/$Display.Count)}else{100}
        Write-ActivityProgress -Activity 'Verify exact final Display package remains staged' -Percent $Percent -Status 'VERIFYING' -Detail ("{0}/{1} :: {2}" -f $Index,$Display.Count,[string]$DriverRow.Driver)
    }
    if ($FinalRows.Count -lt 1) { throw 'No exact final RC2zp Display-class package remains staged.' }
    Complete-ActivityProgress -Activity 'Verify exact final Display package remains staged' -Detail ("exact RC2zp rows={0}" -f $FinalRows.Count)
    Write-Host ("[INFO] AMD Display-class packages staged: {0}; exact RC2zp rows: {1}. Inactive packages are retained by design." -f $Display.Count,$FinalRows.Count)
    Apply-SignerTrustPolicy -State $State
    return $Gpu
}

Write-StageStatus -Stage 2 -Name 'Driver binding' -CurrentTask 'Export rollback package, retain previous display package, bind RC2zp to Legion Go, verify recovery-safe result'
$State = Read-WorkflowState
if ($null -eq $State -or [string]$State.Release -ne $Version) { throw 'Stage 1 workflow state is missing or belongs to another release.' }
$Stage = [string]$State.Stage

if ($Stage -eq 'AwaitingNormalSigningReboot') {
    $OldBoot = [datetime]::Parse([string]$State.BootTimeAtNormalSigningDisable)
    if ((Get-CurrentBootTime) -le $OldBoot) {
        Write-Host '[INFO] Driver transaction passed, but the normal-signing reboot has not happened yet.'
        Arm-ManagedResumeTaskAtBoundary
        if (Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.') { Write-Host '[REBOOT] Restart requested. One-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan; Set-StateProperty $State 'DriverRebootCommandIssuedAt' (Get-Date).ToString('o'); Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o'); Save-State $State; Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Normal-signing reboot remains required; automatic reboot command issued.'; Restart-Computer -Force; exit 2 }
        Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
        Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Normal-signing reboot remains required; reboot was deferred.'
        exit 2
    }
    $Gpu = Verify-NormalFinal -State $State
    Set-StateProperty $State 'Stage' 'DriverComplete'
    Set-StateProperty $State 'TransactionStatus' 'DriverComplete'
    Set-StateProperty $State 'DriverCompletedAt' (Get-Date).ToString('o')
    Set-StateProperty $State 'ActivePublishedInf' ([string]$Gpu.ActiveINF)
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    Write-Host '[PASS] Final v2b persists under normal signing.' -ForegroundColor Green
    Write-Host 'SCRIPT 2 PASS: True'
    if($env:LEGIONGO_RC2I_MANAGED-eq'1'){Write-Host '[NEXT] Launcher will continue to Stage 3 automatically.'}else{Write-Host 'NEXT: run 03-Install-AMD-Software-And-Reboot.ps1'}
    Write-Stage2Result -Status 'Passed' -ExitCode 0 -Detail 'Normal-signing reboot seal passed and workflow advanced to DriverComplete.'
    exit 0
}
if ($Stage -in @('DriverComplete','AwaitingSoftwareReboot','SoftwareComplete','Complete')) {
    [void](Verify-NormalFinal -State $State)
    Write-Host "[PASS] Driver stage already complete. Workflow stage: $Stage" -ForegroundColor Green
    Write-Host 'SCRIPT 2 PASS: True'
    Write-Stage2Result -Status 'Passed' -ExitCode 0 -Detail ("Driver stage already complete at workflow checkpoint {0}." -f $Stage)
    exit 0
}
if ($Stage -ne 'ReadyForInstall') { throw "Stage 2 requires Stage=ReadyForInstall; current Stage=$Stage" }
Set-StateProperty $State 'DriverRebootCommandIssuedAt' ''
Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
Save-State $State
$TransactionStatus = Get-StateTextProperty -State $State -Name 'TransactionStatus'
$TestSigningConfigured = Get-TestSigningConfigured
if (-not $TestSigningConfigured -and $TransactionStatus -ne 'DriverInstalledPreReboot') { throw 'Stage 2 requires a boot entered with Test Signing configured.' }
$SecureBootNow=Get-SecureBootState
if ($SecureBootNow -eq $true) { throw 'Secure Boot is enabled. Stop before changing the driver.' }
if ($null -eq $SecureBootNow) { throw 'Secure Boot state could not be determined immediately before the driver transaction.' }

if ($TransactionStatus -eq 'DriverTransactionInProgress') {
    Write-Host '[WARN] The previous session ended while the destructive driver transaction was marked in progress.' -ForegroundColor Yellow
    [void](Invoke-BestEffortRollback -State $State -RecoveryStatus 'RecoveredAfterInterruption' -Reason 'Previous Stage 2 process ended before the transaction reached its verified pre-reboot checkpoint.')
    throw 'An interrupted driver transaction was detected and rollback was attempted. Review the recovery lines above and rerun only after the GPU is healthy.'
}
if ($TransactionStatus -eq 'DriverInstalledPreReboot' -and -not $TestSigningConfigured) {
    $DriverBootProperty = $State.PSObject.Properties['BootTimeAtDriverInstalled']
    if ($null -eq $DriverBootProperty -or [string]::IsNullOrWhiteSpace([string]$DriverBootProperty.Value)) { throw 'Driver pre-reboot checkpoint exists but its boot-time evidence is missing.' }
    $DriverBoot = [datetime]::Parse([string]$DriverBootProperty.Value)
    $CurrentBoot = Get-CurrentBootTime
    if ($CurrentBoot -gt $DriverBoot) {
        Write-Section 'RECOVER NORMAL-SIGNING REBOOT CHECKPOINT'
        $RecoveredGpu = Verify-NormalFinal -State $State
        Set-StateProperty $State 'Stage' 'DriverComplete'
        Set-StateProperty $State 'TransactionStatus' 'DriverComplete'
        Set-StateProperty $State 'DriverCompletedAt' (Get-Date).ToString('o')
        Set-StateProperty $State 'ActivePublishedInf' ([string]$RecoveredGpu.ActiveINF)
        Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
        Save-State $State
        Write-Host '[PASS] An interrupted state-save boundary was recovered: final v2b persists under normal signing.' -ForegroundColor Green
        Write-Host 'SCRIPT 2 PASS: True'
        Write-Stage2Result -Status 'Passed' -ExitCode 0 -Detail 'Recovered verified normal-signing checkpoint and advanced to DriverComplete.'
        exit 0
    }
    Set-StateProperty $State 'Stage' 'AwaitingNormalSigningReboot'
    Set-StateProperty $State 'TransactionStatus' 'DriverInstalledAwaitingNormalSigningReboot'
    Set-StateProperty $State 'BootTimeAtNormalSigningDisable' $DriverBoot.ToString('o')
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    Write-Host '[RECOVERY] Test Signing was already configured off, but the required reboot has not happened yet.' -ForegroundColor Yellow
    Arm-ManagedResumeTaskAtBoundary
    if (Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The saved exact-driver checkpoint is intact. The launcher will resume automatically after you sign back in.') { Set-StateProperty $State 'DriverRebootCommandIssuedAt' (Get-Date).ToString('o'); Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o'); Save-State $State; Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Recovered exact driver checkpoint requires normal-signing reboot; automatic reboot command issued.'; Restart-Computer -Force; exit 2 }
    Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
    Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Recovered exact driver checkpoint requires normal-signing reboot; reboot was deferred.'
    exit 2
}

$PackageRoot = [string]$State.PackageRoot
$CandidateInf = Join-Path $PackageRoot 'u0202643.inf'
$CandidateDat = Join-Path $PackageRoot 'B026283\amdgcf.dat'
$CandidateCat = Join-Path $PackageRoot 'u0202643.cat'
if ((Get-SHA256 $CandidateInf) -ne $Script:ExpectedFinalInfSHA256) { throw 'Candidate INF changed.' }
if ((Get-SHA256 $CandidateDat) -ne $Script:ExpectedFinalDatSHA256) { throw 'Candidate DAT changed.' }
if (@(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force).Count -ne $Script:ExpectedSignedFileCount) { throw 'Candidate package file count changed.' }
$CandidateCatalogHash = Get-SHA256 -LiteralPath $CandidateCat
if ($CandidateCatalogHash -ne [string]$State.SignedCatalogSHA256) { throw 'Candidate catalog hash changed from the exact Stage 1 signed workspace.' }
$CatSig = Get-AuthenticodeSignature -LiteralPath $CandidateCat
if ($null -eq $CatSig.SignerCertificate -or [string]$CatSig.SignerCertificate.Thumbprint -ne [string]$State.SignerThumbprint) { throw 'Candidate catalog signer does not match Stage 1.' }
$SavedCatalogDisposition = Get-StateTextProperty -State $State -Name 'ActiveCatalogDisposition'
if ($SavedCatalogDisposition -eq 'RetainedPreexistingExactFinal') {
    $SavedExpectedActiveSigner = Get-StateTextProperty -State $State -Name 'ExpectedActiveCatalogSignerThumbprint'
    if ([string]::IsNullOrWhiteSpace($SavedExpectedActiveSigner) -or $SavedExpectedActiveSigner -eq [string]$State.SignerThumbprint) { throw 'Saved retained-catalog signer identity is invalid or ambiguous.' }
    Assert-PublicSignerTrust -Thumbprint $SavedExpectedActiveSigner
    $PrivateStage1 = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\My' -Thumbprint ([string]$State.SignerThumbprint))
    if ($PrivateStage1.Count -ne 0) { throw 'Current-run Stage 1 private signing certificate unexpectedly exists during retained-catalog resume.' }
} else {
    if ($CatSig.Status -ne 'Valid') { throw "Candidate catalog signature is not trusted before activation. Status=$($CatSig.Status)" }
    Assert-PublicSignerTrust -Thumbprint ([string]$State.SignerThumbprint)
}
Assert-FrozenUnchangedPackage -PackageRoot $PackageRoot

$ResumeInstalledCandidate = ($TransactionStatus -eq 'DriverInstalledPreReboot')
if ($ResumeInstalledCandidate) {
    Write-Section 'RESUME VERIFIED PRE-REBOOT DRIVER CHECKPOINT'
    Write-IndeterminateActivityProgress -Activity 'Query Legion Go GPU at pre-reboot driver checkpoint' -Tick 0 -Elapsed '00:00' -Detail 'PnP device properties + active INF + loaded kernel'
    Set-ActivityLivenessContext -Activity 'Query Legion Go GPU at pre-reboot driver checkpoint' -Status 'QUERYING' -Detail 'PnP device properties + active INF + loaded kernel' -Indeterminate
    $ResumeGpu = Get-LegionGoGpu
    Complete-ActivityProgress -Activity 'Query Legion Go GPU at pre-reboot driver checkpoint' -Detail ("INF={0}; Driver={1}; Status={2}" -f $ResumeGpu.ActiveINF,$ResumeGpu.DriverVersion,$ResumeGpu.Status)
    [void](Assert-FinalDriver -Gpu $ResumeGpu -Activity 'Verify exact driver at pre-reboot checkpoint')
    [void](Assert-ExpectedActiveCatalog -State $State -Gpu $ResumeGpu)
    Apply-SignerTrustPolicy -State $State
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    if (@(Get-LenovoExtensionDrivers).Count -ne 0) { throw 'Interrupted-session resume found a standalone amduw23e package after the driver checkpoint.' }
    $ResumeFinalRows = @(
        Get-AmdDisplayDrivers | Where-Object {
            try { (Get-SHA256 -LiteralPath ([string]$_.OriginalFileName)) -eq $Script:ExpectedFinalInfSHA256 } catch { $false }
        }
    )
    if ($ResumeFinalRows.Count -lt 1) { throw 'Interrupted-session resume cannot find the exact final RC2zp package in Driver Store.' }
    $RollbackRoot = Get-StateTextProperty -State $State -Name 'RollbackRoot'
    Write-Host '[PASS] Exact final driver checkpoint is still healthy; destructive replacement will not be repeated.' -ForegroundColor Green
} else {
    Write-IndeterminateActivityProgress -Activity 'Query current Legion Go GPU state before driver transaction' -Tick 0 -Elapsed '00:00' -Detail 'PnP device properties + active INF + loaded kernel identity'
    Set-ActivityLivenessContext -Activity 'Query current Legion Go GPU state before driver transaction' -Status 'QUERYING' -Detail 'PnP device properties + active INF + loaded kernel identity' -Indeterminate
    $Gpu = Get-LegionGoGpu
    Complete-ActivityProgress -Activity 'Query current Legion Go GPU state before driver transaction' -Detail ("INF={0}; Driver={1}; Status={2}" -f $Gpu.ActiveINF,$Gpu.DriverVersion,$Gpu.Status)

    Write-IndeterminateActivityProgress -Activity 'Classify current Legion Go display origin' -Tick 0 -Elapsed '00:00' -Detail ([string]$Gpu.ActiveINF)
    Set-ActivityLivenessContext -Activity 'Classify current Legion Go display origin' -Status 'CLASSIFYING' -Detail 'origin architecture + extension semantics + health contract' -Indeterminate
    $OriginClassification = Get-LegionGoOriginClassification -Gpu $Gpu
    Complete-ActivityProgress -Activity 'Classify current Legion Go display origin' -Detail ([string]$OriginClassification.OriginKind)
    Write-Host "Current GPU: $($Gpu.Status) / code $($Gpu.ProblemCode) / hasProblem $($Gpu.HasProblem) / classified origin $($OriginClassification.OriginKind) / provider $($Gpu.DriverProvider) / $($Gpu.DriverVersion) / $($Gpu.ActiveINF)"
    if (-not [bool]$OriginClassification.OriginAcceptable) {
        $OriginReasons = @($OriginClassification.Reasons) -join ' | '
        throw ("Starting GPU origin is not acceptable: {0}" -f $OriginReasons)
    }
    foreach ($OriginWarning in @($OriginClassification.Warnings)) {
        Write-Host ("[WARN] Origin classifier: {0}" -f $OriginWarning) -ForegroundColor Yellow
    }
    if ($Gpu.Status -ne 'OK' -or $Gpu.ProblemCode -ne 0 -or [bool]$Gpu.HasProblem) { throw 'Starting GPU state is not healthy.' }
    if ([string]::IsNullOrWhiteSpace([string]$Gpu.ActiveINF)) { throw 'Starting GPU has no active display INF.' }
    $CurrentPublishedInf = [string]$Gpu.ActiveINF
    $CurrentInfHash = [string]$Gpu.InfSHA256
    $CurrentOriginKind = [string]$OriginClassification.OriginKind
    $CurrentDriverProvider = [string]$Gpu.DriverProvider
    $CurrentOriginalInfPath = ''
    if ($CurrentOriginKind -ne 'MicrosoftBasic') {
        $CurrentInfActivity='Verify current active Driver Store INF before driver transaction'
        Write-IndeterminateActivityProgress -Activity $CurrentInfActivity -Tick 0 -Elapsed '00:00' -Detail ("query Driver Store row for {0}" -f $CurrentPublishedInf)
        Set-ActivityLivenessContext -Activity $CurrentInfActivity -Status 'QUERYING' -Detail ("Get-WindowsDriver row for {0}" -f $CurrentPublishedInf) -Indeterminate
        $CurrentRows = @(Get-WindowsDriver -Online -All | Where-Object { [string]$_.Driver -ieq $CurrentPublishedInf })
        if ($CurrentRows.Count -ne 1) { throw "Expected exactly one Driver Store row for the active INF $CurrentPublishedInf; found $($CurrentRows.Count)." }
        $CurrentOriginalInfPath = [string]$CurrentRows[0].OriginalFileName
        if (-not (Test-Path -LiteralPath $CurrentOriginalInfPath -PathType Leaf)) { throw "Active Driver Store INF path is missing: $CurrentOriginalInfPath" }
        Write-ActivityProgress -Activity $CurrentInfActivity -Percent 70 -Status 'HASHING' -Detail ([IO.Path]::GetFileName($CurrentOriginalInfPath))
        if ((Get-SHA256 -LiteralPath $CurrentOriginalInfPath) -ne $CurrentInfHash) { throw 'Active Driver Store INF hash does not match the live published INF hash.' }
        Complete-ActivityProgress -Activity $CurrentInfActivity -Detail 'active Driver Store INF exact'
    }
    $PreviousCatalogSHA256 = ''
    $PreviousCatalogSignerThumbprint = ''
    $PreviousCatalogSignatureStatus = ''
    $PreviousCatalogFileName = ''
    if ($CurrentOriginKind -ne 'MicrosoftBasic') {
        $PreviousCatalogIdentity = Get-ActiveCatalogIdentity -Gpu $Gpu
        $PreviousCatalogSHA256 = [string]$PreviousCatalogIdentity.CatalogSHA256
        $PreviousCatalogSignerThumbprint = [string]$PreviousCatalogIdentity.SignerThumbprint
        $PreviousCatalogSignatureStatus = [string]$PreviousCatalogIdentity.SignatureStatus
        $PreviousCatalogFileName = [string]$PreviousCatalogIdentity.CatalogName
        if ($CurrentInfHash -eq $Script:ExpectedFinalInfSHA256) {
            if ($PreviousCatalogSignatureStatus -ne 'Valid' -or [string]::IsNullOrWhiteSpace($PreviousCatalogSignerThumbprint)) {
                throw 'Pre-existing exact final driver has an invalid or unsigned active catalog.'
            }
            Write-ActivityProgress -Activity 'Verify pre-existing exact-final catalog signer trust' -Percent 0 -Status 'VERIFYING' -Detail $PreviousCatalogSignerThumbprint
            Set-ActivityLivenessContext -Activity 'Verify pre-existing exact-final catalog signer trust' -Percent 50 -Status 'TRUST' -Detail 'LocalMachine Root + TrustedPublisher; no private key'
            Assert-PublicSignerTrust -Thumbprint $PreviousCatalogSignerThumbprint
            Complete-ActivityProgress -Activity 'Verify pre-existing exact-final catalog signer trust' -Detail $PreviousCatalogSignerThumbprint
            Write-Host ("[PASS] Pre-existing exact final catalog captured for idempotent retention: SHA256={0}; signer={1}" -f $PreviousCatalogSHA256,$PreviousCatalogSignerThumbprint) -ForegroundColor Green
        }
    }
    Write-IndeterminateActivityProgress -Activity 'Check standalone Lenovo extension before driver transaction' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
    Set-ActivityLivenessContext -Activity 'Check standalone Lenovo extension before driver transaction' -Status 'QUERYING' -Detail 'searching for amduw23e.inf' -Indeterminate
    $Extensions = @(Get-LenovoExtensionDrivers)
    Complete-ActivityProgress -Activity 'Check standalone Lenovo extension before driver transaction' -Detail ("rows={0}" -f $Extensions.Count)

    $ValidatedExtensionIds = @()
    $ValidatedExtensionEvidence = @()
    foreach ($ExtensionRow in $Extensions) {
        $Evidence = Get-LenovoExtensionPackageEvidence -Extension $ExtensionRow

        if ([string]$Evidence.ClassName -ine 'Extension') {
            throw ("The staged amduw23e package {0} is Class={1}, not Extension; refusing to treat it as removable Go 1 extension lineage material." -f [string]$Evidence.PublishedInf,[string]$Evidence.ClassName)
        }
        if (-not [bool]$Evidence.TargetsLegionGo) {
            throw ("The staged amduw23e package {0} does not target the exact original Legion Go; refusing to remove it." -f [string]$Evidence.PublishedInf)
        }
        if ([string]::IsNullOrWhiteSpace([string]$Evidence.ExtensionId)) {
            throw ("The staged amduw23e package {0} has no parseable ExtensionId; refusing an ambiguous transaction." -f [string]$Evidence.PublishedInf)
        }
        if ([string]$Evidence.ExtensionId -ne $Script:KnownLenovoExtensionId) {
            throw ("The staged amduw23e package {0} belongs to a different applicable ExtensionId {1}; expected the Lenovo-derived Go 1 lineage {2}. A separate lineage may coexist with ours, so it will not be deleted blindly." -f [string]$Evidence.PublishedInf,[string]$Evidence.ExtensionId,$Script:KnownLenovoExtensionId)
        }

        $ValidatedExtensionIds += [string]$Evidence.ExtensionId
        $ValidatedExtensionEvidence += $Evidence

        Write-Host ("[PASS] Go 1 extension lineage member structurally scoped: {0} :: Class={1} :: DriverVer={2} :: Date={3} :: ExtensionId={4} :: SHA256={5}" -f `
            [string]$Evidence.PublishedInf,[string]$Evidence.ClassName,[string]$Evidence.DriverVersion,[string]$Evidence.DriverDate,[string]$Evidence.ExtensionId,[string]$Evidence.SHA256) -ForegroundColor Green

        if ([bool]$Evidence.SemanticCompatible) {
            Write-Host ("[INFO] {0} matches the toolkit's known Lenovo semantic profile." -f [string]$Evidence.PublishedInf)
        }
        else {
            $Missing = @($Evidence.MissingSemanticMarkers) -join ', '
            Write-Host ("[WARN] {0} has custom/unrecognized semantic contents. This does not by itself invalidate the structurally scoped Go 1 lineage. MissingKnownMarkers={1}" -f `
                [string]$Evidence.PublishedInf,$Missing) -ForegroundColor Yellow
        }
    }

    $DistinctExtensionIds = @($ValidatedExtensionIds | Select-Object -Unique)
    if ($DistinctExtensionIds.Count -gt 1) {
        throw ("Multiple distinct amduw23e ExtensionId lineages are staged; refusing an ambiguous transaction: {0}" -f ($DistinctExtensionIds -join ', '))
    }
    if ($Extensions.Count -gt 1) {
        Write-Host ("[PASS] {0} staged amduw23e package generations resolve to one structurally scoped Go 1 Lenovo-derived lineage; all will be exported and removed." -f $Extensions.Count) -ForegroundColor Green
    }
    elseif ($Extensions.Count -eq 1) {
        Write-Host ("[PASS] One structurally scoped Go 1 Lenovo-derived extension lineage member is staged: {0}" -f [string]$Extensions[0].Driver) -ForegroundColor Green
    }
    else {
        Write-Host '[INFO] No standalone amduw23e package is staged.'
    }

    $RollbackRoot = Join-Path $Script:WorkflowRoot ('Rollback\' + $Timestamp)
    $RollbackBase = Join-Path $RollbackRoot 'Current-Display'
    $RollbackExt = Join-Path $RollbackRoot 'Lenovo-Extension'
    New-Item -ItemType Directory -Path $RollbackBase,$RollbackExt -Force | Out-Null
    Write-Section 'EXPORT VERIFIED ROLLBACK MATERIAL'
    $RollbackBaseInf = ''
    if ($CurrentOriginKind -eq 'MicrosoftBasic') {
        $BasicInfBase=[IO.Path]::GetFileName($CurrentPublishedInf)
        if ($BasicInfBase -notin @('display.inf','basicdisplay.inf')) { throw "MicrosoftBasic origin resolved to an unexpected in-box INF: $CurrentPublishedInf" }
        if ($CurrentDriverProvider -notmatch '(?i)^Microsoft') { throw "MicrosoftBasic origin has an unexpected provider: $CurrentDriverProvider" }
        if ([string]$Gpu.Service -ine 'BasicDisplay') { throw "MicrosoftBasic origin has an unexpected service: $($Gpu.Service)" }
        Write-Host ("[PASS] Microsoft Basic Display Adapter is an in-box origin ({0}); no third-party base INF export is required." -f $BasicInfBase) -ForegroundColor Green
        Write-Host '[INFO] Rollback semantics for this origin are candidate removal + hardware rescan back to the Microsoft BasicDisplay binding.'
    } else {
        [void](Invoke-Pnp -Arguments @('/export-driver',$CurrentPublishedInf,$RollbackBase) -Name 'export-current-display')
        $RollbackBaseInf = Get-ExportedInfByHash -Root $RollbackBase -ExpectedHash $CurrentInfHash
    }
    $RollbackExtensionInf = ''
    $RollbackExtensionInfs = @()
    $RollbackExtensionIndex = 0
    foreach ($ExtensionRow in $Extensions) {
        $RollbackExtensionIndex++
        $ExtensionHash = Get-SHA256 ([string]$ExtensionRow.OriginalFileName)
        $ExtensionExportRoot = Join-Path $RollbackExt ([IO.Path]::GetFileNameWithoutExtension([string]$ExtensionRow.Driver))
        New-Item -ItemType Directory -Path $ExtensionExportRoot -Force | Out-Null
        [void](Invoke-Pnp -Arguments @('/export-driver',([string]$ExtensionRow.Driver),$ExtensionExportRoot) -Name ('export-lenovo-extension-{0}' -f $RollbackExtensionIndex))
        $ExportedExtensionInf = Get-ExportedInfByHash -Root $ExtensionExportRoot -ExpectedHash $ExtensionHash
        $RollbackExtensionInfs += $ExportedExtensionInf
        if ([string]::IsNullOrWhiteSpace($RollbackExtensionInf)) { $RollbackExtensionInf = $ExportedExtensionInf }
        Write-Host ("[PASS] Rollback extension lineage member: {0} -> {1}" -f [string]$ExtensionRow.Driver,$ExportedExtensionInf) -ForegroundColor Green
    }
    if ($CurrentOriginKind -eq 'MicrosoftBasic') {
        Write-Host '[PASS] Rollback base: Windows in-box Microsoft Basic Display Adapter' -ForegroundColor Green
    } else {
        Write-Host "[PASS] Rollback base: $RollbackBaseInf" -ForegroundColor Green
    }
    if ($RollbackExtensionInfs.Count -gt 0) { Write-Host ("[PASS] Rollback extension lineage exports: {0}" -f $RollbackExtensionInfs.Count) -ForegroundColor Green }
    Set-StateProperty $State 'RollbackRoot' $RollbackRoot
    Set-StateProperty $State 'RollbackBaseInf' $RollbackBaseInf
    Set-StateProperty $State 'RollbackExtensionInf' $RollbackExtensionInf
    Set-StateProperty $State 'RollbackExtensionInfs' @($RollbackExtensionInfs)
    Set-StateProperty $State 'PreviousStandaloneExtensionCount' ([int]$Extensions.Count)
    Set-StateProperty $State 'PreviousStandaloneExtensionLineageId' $(if($DistinctExtensionIds.Count -eq 1){[string]$DistinctExtensionIds[0]}else{''})
    Set-StateProperty $State 'PreviousStandaloneExtensionMembers' @(
        $ValidatedExtensionEvidence | ForEach-Object {
            [pscustomobject]@{
                PublishedInf=[string]$_.PublishedInf
                DriverVersion=[string]$_.DriverVersion
                DriverDate=[string]$_.DriverDate
                ExtensionId=[string]$_.ExtensionId
                ClassName=[string]$_.ClassName
                ProviderName=[string]$_.ProviderName
                SemanticCompatible=[bool]$_.SemanticCompatible
                MissingSemanticMarkers=@($_.MissingSemanticMarkers)
                SHA256=[string]$_.SHA256
            }
        }
    )
    Set-StateProperty $State 'PreviousPublishedInf' $CurrentPublishedInf
    Set-StateProperty $State 'PreviousOriginalInfPath' $CurrentOriginalInfPath
    Set-StateProperty $State 'PreviousInfHash' $CurrentInfHash
    Set-StateProperty $State 'PreviousOriginKind' $CurrentOriginKind
    Set-StateProperty $State 'PreviousDriverProvider' $CurrentDriverProvider
    Set-StateProperty $State 'PreviousDriverVersion' ([string]$Gpu.DriverVersion)
    Set-StateProperty $State 'PreviousCatalogSHA256' $PreviousCatalogSHA256
    Set-StateProperty $State 'PreviousCatalogSignerThumbprint' $PreviousCatalogSignerThumbprint
    Set-StateProperty $State 'PreviousCatalogSignatureStatus' $PreviousCatalogSignatureStatus
    Set-StateProperty $State 'PreviousCatalogFileName' $PreviousCatalogFileName
    Set-StateProperty $State 'PreviousOriginArchitecture' ([string]$OriginClassification.OriginArchitecture)
    Set-StateProperty $State 'PreviousExtensionDisposition' ([string]$OriginClassification.ExtensionDisposition)
    Set-StateProperty $State 'EmbeddedLenovoSemanticsPass' ([bool]$OriginClassification.EmbeddedLenovoSemanticsPass)
    Set-StateProperty $State 'PreviousGpuHealthPass' ([bool]$OriginClassification.GpuHealthPass)
    Set-StateProperty $State 'PreviousStandaloneExtensionPresent' ([bool]$OriginClassification.StandaloneExtensionPresent)
    Set-StateProperty $State 'PreviousStandaloneExtensionSemanticPass' ([bool]$OriginClassification.StandaloneExtensionSemanticPass)
    Set-StateProperty $State 'PreviousStandaloneExtensionVersionCoherent' ([bool]$OriginClassification.StandaloneExtensionVersionCoherent)
    Set-StateProperty $State 'TransactionStatus' 'RollbackPrepared'
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    Write-Host '[PASS] Rollback checkpoint saved before the destructive gate.' -ForegroundColor Green

    Write-Section 'TARGET-DEVICE BINDING GATE'
    Write-Host 'This will keep the current display package staged as rollback material, stage the exact merged RC2-v2b package,'
    Write-Host 'remove the standalone Lenovo extension when present, and explicitly bind RC2zp only to the original Legion Go GPU.'
    if (-not (Confirm-ManagedOrInteractive 'Proceed with the Legion Go driver binding now?' -Estimate 'Typical driver transaction: about 2-5 minutes. The display may flicker or briefly reset.' -Impact 'The previous display package remains staged and a verified export is also saved. Unrelated/inactive Display-class packages are not removed.')) { Write-Host '[PAUSE] Cancelled before any driver change. Rollback exports and signed candidate are preserved.' -ForegroundColor Yellow; Write-Stage2Result -Status 'Paused' -ExitCode 3 -Detail 'Cancelled before any driver change; rollback exports and signed candidate preserved.'; exit 3 }
    $DestructiveStarted = $false
    Set-StateProperty $State 'TransactionStatus' 'DriverTransactionInProgress'
    Set-StateProperty $State 'TransactionStartedAt' (Get-Date).ToString('o')
    Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
    Save-State $State
    try {
        $DestructiveStarted = $true

        Write-Section 'STAGE RC2R WITHOUT REMOVING THE PREVIOUS DISPLAY PACKAGE'
        [void](Invoke-Pnp -Arguments @('/add-driver',$CandidateInf) -Name 'stage-final-v2b')
        Write-IndeterminateActivityProgress -Activity 'Enumerate AMD Display Driver Store after staging candidate' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
        Set-ActivityLivenessContext -Activity 'Enumerate AMD Display Driver Store after staging candidate' -Status 'QUERYING' -Detail 'locating staged exact-final candidate' -Indeterminate
        $StagedDisplayRows=@(Get-AmdDisplayDrivers)
        Complete-ActivityProgress -Activity 'Enumerate AMD Display Driver Store after staging candidate' -Detail ("AMD Display rows={0}" -f $StagedDisplayRows.Count)
        Write-ActivityProgress -Activity 'Verify staged exact-final candidate identity' -Percent 0 -Status 'VERIFYING' -Detail ("0/{0} AMD Display rows" -f $StagedDisplayRows.Count)
        $StagedFinalRows=@();$StagedIndex=0
        foreach($DriverRow in $StagedDisplayRows){
            $StagedIndex++
            try{if((Get-SHA256 -LiteralPath ([string]$DriverRow.OriginalFileName))-eq$Script:ExpectedFinalInfSHA256){$StagedFinalRows+=$DriverRow}}catch{}
            $StagedPercent=if($StagedDisplayRows.Count-gt0){[int][Math]::Floor(($StagedIndex*100.0)/$StagedDisplayRows.Count)}else{100}
            Write-ActivityProgress -Activity 'Verify staged exact-final candidate identity' -Percent $StagedPercent -Status 'VERIFYING' -Detail ("{0}/{1} :: {2}" -f $StagedIndex,$StagedDisplayRows.Count,[string]$DriverRow.Driver)
        }
        if ($StagedFinalRows.Count -lt 1) { throw 'The exact RC2zp display package is not present in Driver Store after staging.' }
        Complete-ActivityProgress -Activity 'Verify staged exact-final candidate identity' -Detail ("exact rows={0}" -f $StagedFinalRows.Count)
        Write-Host ("[PASS] Exact RC2zp package staged. AMD Display inventory count={0}; inactive packages retained." -f $StagedDisplayRows.Count) -ForegroundColor Green

        if ($Extensions.Count -gt 0) {
            $RemovalRows = @(
                $Extensions |
                Sort-Object `
                    @{Expression={try{[datetime]$_.Date}catch{[datetime]::MinValue}};Descending=$false}, `
                    @{Expression={try{[version]([string]$_.Version)}catch{[version]'0.0'}};Descending=$false}
            )
            $RemovalIndex = 0
            foreach ($ExtensionRow in $RemovalRows) {
                $RemovalIndex++
                [void](Invoke-Pnp -Arguments @('/delete-driver',([string]$ExtensionRow.Driver),'/uninstall','/force') -Name ('remove-lenovo-extension-{0}' -f $RemovalIndex))
            }
            if (@(Get-LenovoExtensionDrivers).Count -ne 0) { throw 'Standalone amduw23e remains staged after deleting the validated Lenovo extension lineage.' }
        }

        if ($CurrentOriginKind -eq 'MicrosoftBasic') {
            Write-Host '[PASS] Microsoft Basic Display Adapter is an in-box binding; it is not deleted from Driver Store.' -ForegroundColor Green
        } else {
            Write-Host ("[PASS] Previous display package retained in Driver Store: {0}" -f $CurrentPublishedInf) -ForegroundColor Green
        }

        Write-Section 'EXPLICIT LEGION GO BIND'
        $BindResult = Invoke-ForceBindLegionGoDriver -InfPath $CandidateInf
        Set-StateProperty $State 'ForceBindRebootRequested' ([bool]$BindResult.RebootRequired)
        [void](Invoke-Pnp -Arguments @('/scan-devices') -Name 'scan-after-bind' -AllowFailure)
        Wait-VisibleCountdown -Seconds 5 -Activity 'Allow PnP state to settle after GPU bind' -Detail 'Windows is refreshing the active display binding'
        Write-IndeterminateActivityProgress -Activity 'Query live Legion Go GPU binding after bind' -Tick 0 -Elapsed '00:00' -Detail 'PnP device properties + active INF + kernel identity'
        Set-ActivityLivenessContext -Activity 'Query live Legion Go GPU binding after bind' -Status 'QUERYING' -Detail 'PnP device properties + active INF + kernel identity' -Indeterminate
        $Post = Get-LegionGoGpu
        Complete-ActivityProgress -Activity 'Query live Legion Go GPU binding after bind' -Detail ("INF={0}; Driver={1}; Status={2}" -f $Post.ActiveINF,$Post.DriverVersion,$Post.Status)
        [void](Assert-FinalDriver -Gpu $Post -Activity 'Verify active Driver Store identities after GPU bind')

        Write-IndeterminateActivityProgress -Activity 'Check standalone Lenovo extension after GPU bind' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
        Set-ActivityLivenessContext -Activity 'Check standalone Lenovo extension after GPU bind' -Status 'QUERYING' -Detail 'searching for amduw23e.inf' -Indeterminate
        $PostBindExtensions=@(Get-LenovoExtensionDrivers)
        Complete-ActivityProgress -Activity 'Check standalone Lenovo extension after GPU bind' -Detail ("rows={0}" -f $PostBindExtensions.Count)
        if ($PostBindExtensions.Count -ne 0) { throw 'Standalone amduw23e remains staged after the transaction.' }

        $ActiveCatalog = Get-ActiveCatalogIdentity -Gpu $Post
        $CatalogDisposition = ''
        $ExpectedActiveCatalogSHA256 = ''
        $ExpectedActiveCatalogSignerThumbprint = ''
        if (
            $ActiveCatalog.CatalogSHA256 -eq [string]$State.SignedCatalogSHA256 -and
            $ActiveCatalog.SignatureStatus -eq 'Valid' -and
            $ActiveCatalog.SignerThumbprint -eq [string]$State.SignerThumbprint
        ) {
            $CatalogDisposition = 'Stage1Candidate'
            $ExpectedActiveCatalogSHA256 = [string]$State.SignedCatalogSHA256
            $ExpectedActiveCatalogSignerThumbprint = [string]$State.SignerThumbprint
        } elseif (
            $CurrentInfHash -eq $Script:ExpectedFinalInfSHA256 -and
            [string]$Post.ActiveINF -ieq $CurrentPublishedInf -and
            -not [string]::IsNullOrWhiteSpace($PreviousCatalogSHA256) -and
            $ActiveCatalog.CatalogSHA256 -eq $PreviousCatalogSHA256 -and
            $ActiveCatalog.SignatureStatus -eq 'Valid' -and
            $ActiveCatalog.SignerThumbprint -eq $PreviousCatalogSignerThumbprint
        ) {
            $CatalogDisposition = 'RetainedPreexistingExactFinal'
            $ExpectedActiveCatalogSHA256 = $PreviousCatalogSHA256
            $ExpectedActiveCatalogSignerThumbprint = $PreviousCatalogSignerThumbprint
        } else {
            throw ("Active catalog is neither the Stage 1 candidate nor the captured pre-existing exact-final catalog. ActiveSHA={0}; ActiveSigner={1}" -f $ActiveCatalog.CatalogSHA256,$ActiveCatalog.SignerThumbprint)
        }
        Set-StateProperty $State 'ActiveCatalogDisposition' $CatalogDisposition
        Set-StateProperty $State 'ExpectedActiveCatalogSHA256' $ExpectedActiveCatalogSHA256
        Set-StateProperty $State 'ExpectedActiveCatalogSignerThumbprint' $ExpectedActiveCatalogSignerThumbprint
        [void](Assert-ExpectedActiveCatalog -State $State -Gpu $Post -Identity $ActiveCatalog)
        Write-Host ("[PASS] Exact merged v2b is active and healthy before reboot. CatalogDisposition={0}; CatalogSHA256={1}" -f $CatalogDisposition,$ExpectedActiveCatalogSHA256) -ForegroundColor Green
        Write-IndeterminateActivityProgress -Activity 'Enumerate AMD Display Driver Store inventory after bind' -Tick 0 -Elapsed '00:00' -Detail 'Get-WindowsDriver -Online -All'
        Set-ActivityLivenessContext -Activity 'Enumerate AMD Display Driver Store inventory after bind' -Status 'QUERYING' -Detail 'Get-WindowsDriver -Online -All' -Indeterminate
        $PostBindDisplayCount=@(Get-AmdDisplayDrivers).Count
        Complete-ActivityProgress -Activity 'Enumerate AMD Display Driver Store inventory after bind' -Detail ("AMD Display rows={0}" -f $PostBindDisplayCount)
        Write-Host ("[INFO] AMD Display inventory count={0}; only active Legion Go binding is authoritative." -f $PostBindDisplayCount)

        # Persist the exact active-catalog identity and verified driver checkpoint
        # before trust cleanup so an interruption can safely resume the same
        # disposition without repeating the driver transaction.
        Set-StateProperty $State 'TransactionStatus' 'DriverInstalledPreReboot'
        Set-StateProperty $State 'DriverInstalledPreRebootAt' (Get-Date).ToString('o')
        Set-StateProperty $State 'BootTimeAtDriverInstalled' (Get-CurrentBootTime).ToString('o')
        Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
        Save-State $State
        Write-Host '[PASS] Verified pre-reboot driver checkpoint saved before signer-trust policy.' -ForegroundColor Green

        Apply-SignerTrustPolicy -State $State
        Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
        Save-State $State
        Write-Host ("[PASS] Signer-trust policy persisted: {0}" -f (Get-StateTextProperty -State $State -Name 'SignerTrustDisposition')) -ForegroundColor Green
    } catch {
        $Failure = $_.Exception.Message
        Write-Host "[FAIL] Transaction error: $Failure" -ForegroundColor Red
        if ($DestructiveStarted) { [void](Invoke-BestEffortRollback -State $State -RecoveryStatus 'RecoveredAfterFailure' -Reason $Failure) }
        $SafetyText = ''
        try { $SafetyText = Get-WorkflowSafetySummary } catch { $SafetyText = 'Recovery completed, but workflow safety state could not be summarized.' }
        Write-FailureGuide -Stage 'Stage 2 - driver replacement/recovery' -Message $Failure -SafetyState $SafetyText
        try { Write-Stage2Result -Status 'Failed' -ExitCode 1 -Detail $Failure } catch {}
        exit 1
    }

}

Write-Section 'RETURN TO NORMAL SIGNING'
if ((Get-StateTextProperty -State $State -Name 'TransactionStatus') -ne 'DriverInstalledPreReboot') { throw 'Driver transaction checkpoint is not verified before disabling Test Signing.' }
$BootBefore = Get-CurrentBootTime
& bcdedit.exe /set testsigning off | Out-Host
if ($LASTEXITCODE -ne 0 -or (Get-TestSigningConfigured)) { throw 'Unable to configure Test Signing off for the next boot.' }
Set-StateProperty $State 'Stage' 'AwaitingNormalSigningReboot'
Set-StateProperty $State 'TransactionStatus' 'DriverInstalledAwaitingNormalSigningReboot'
Set-StateProperty $State 'RollbackRoot' $RollbackRoot
Set-StateProperty $State 'BootTimeAtNormalSigningDisable' $BootBefore.ToString('o')
Set-StateProperty $State 'TransactionAt' (Get-Date).ToString('o')
Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o')
Save-State $State
Complete-CurrentSection -Detail 'driver exact and healthy; Test Signing configured off; reboot boundary armed'
Write-Host '[PASS] Driver transaction passed and Test Signing is configured OFF for the next boot.' -ForegroundColor Green
Write-Host 'REBOOT REQUIRED. The one-command launcher will verify the normal-signing seal after sign-in.'
Arm-ManagedResumeTaskAtBoundary
if (Confirm-ManagedOrInteractive 'Restart Windows now?' -Estimate 'Typical reboot: about 1-3 minutes.' -Impact 'The one-command launcher will resume automatically after you sign back in.') { Write-Host '[REBOOT] Restart requested. One-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan; Set-StateProperty $State 'DriverRebootCommandIssuedAt' (Get-Date).ToString('o'); Set-StateProperty $State 'UpdatedAt' (Get-Date).ToString('o'); Save-State $State; Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Driver transaction passed; Test Signing configured off; normal-signing reboot command issued.'; Restart-Computer -Force; exit 2 }
Write-Host '[PAUSE] Reboot deferred. Progress is saved; reboot later and the launcher will resume.' -ForegroundColor Yellow
Write-Stage2Result -Status 'RebootRequired' -ExitCode 2 -Detail 'Driver transaction passed; Test Signing configured off; normal-signing reboot deferred.'
exit 2
