#requires -Version 5.1
<##
One-command, resumable launcher for the Legion Go AMD 26.7.1 v3.0 RC2zk
validation candidate. The four underlying stages remain independently auditable,
but normal users run only this launcher. It persists a small toolkit copy under
ProgramData, creates a one-shot interactive resume task only at saved reboot boundaries,
and removes that task when consumed, on completion, cancellation, or hard failure.
##>
[CmdletBinding()]
param(
    [string]$InstallerPath = '',
    [switch]$Resume
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Release = 'v3.0-RC2zk'
$PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

function Test-LocalAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $Identity
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-LocalAdministrator)) {
    Write-Host '[INFO] Administrator rights are required. Requesting elevation...'
    $ElevatedArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $PSCommandPath + '"'))
    if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) { $ElevatedArgs += @('-InstallerPath',('"' + $InstallerPath + '"')) }
    if ($Resume) { $ElevatedArgs += '-Resume' }
    Start-Process -FilePath $PowerShellExe -Verb RunAs -ArgumentList ($ElevatedArgs -join ' ')
    exit 0
}

. (Join-Path $PSScriptRoot 'Internal\Common.ps1')
Initialize-InstallerRuntime -StageLabel 'one-command installer launcher'
$Logs = Join-Path $Script:WorkflowRoot 'Logs'
New-Item -ItemType Directory -Path $Logs -Force | Out-Null
$TranscriptPath = Join-Path $Logs ('launcher-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$TranscriptStarted = $false
try { Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null; $TranscriptStarted = $true } catch {}

function Stop-LauncherTranscript {
    if ($script:TranscriptStarted) { try { Stop-Transcript | Out-Null } catch {}; $script:TranscriptStarted = $false }
}

function Get-PersistentToolkitRoot { return (Join-Path $Script:WorkflowRoot 'Toolkit') }
function Get-PersistentLauncherPath { return (Join-Path (Get-PersistentToolkitRoot) 'Install-LegionGo-AMD-26.7.1.ps1') }

function Remove-ResumeTask {
    param([switch]$Quiet)
    Remove-ManagedResumeTask -Quiet:$Quiet
}

function Invoke-PackagePreflight {
    param(
        [Parameter(Mandatory=$true)][string]$ToolkitRoot,
        [switch]$QuietOnPass
    )
    $Preflight = Join-Path $ToolkitRoot 'Preflight-AMD-26.7.1-v3.0-RC2zk.ps1'
    if (-not (Test-Path -LiteralPath $Preflight -PathType Leaf)) { throw "Package preflight is missing: $Preflight" }
    $ResultPath = Join-Path $Logs ('preflight-result-' + [Guid]::NewGuid().ToString('N') + '.json')
    $ChildArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Preflight,'-ResultPath',$ResultPath)
    $ArgLine = (@($ChildArgs | ForEach-Object { Quote-NativeArgument -Value ([string]$_) }) -join ' ')
    $StdOut = $null
    $StdErr = $null

    try {
        if (-not $QuietOnPass) {
            Write-Host '[CHECK] Running read-only package/parser preflight...'
            $PreflightProcess = Start-Process -FilePath $PowerShellExe -ArgumentList $ArgLine -PassThru -NoNewWindow
        }
        else {
            $TmpBase = Join-Path $Logs ('preflight-' + [Guid]::NewGuid().ToString('N'))
            $StdOut = $TmpBase + '.stdout.txt'
            $StdErr = $TmpBase + '.stderr.txt'
            $PreflightProcess = Start-Process -FilePath $PowerShellExe -ArgumentList $ArgLine -PassThru -NoNewWindow `
                -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        }
        try {
            $WaitStarted = Get-Date
            $NextProgress = $WaitStarted
            $Tick = 0
            while (-not $PreflightProcess.HasExited) {
                $Now = Get-Date
                if ($Now -ge $NextProgress) {
                    Write-IndeterminateActivityProgress -Activity 'Read-only package/parser preflight' -Tick $Tick -Elapsed (Format-Elapsed -Elapsed ($Now-$WaitStarted)) -Detail ("PID {0}" -f $PreflightProcess.Id)
                    $Tick++
                    $NextProgress = $Now.AddSeconds(2)
                }
                Start-Sleep -Milliseconds 250
                try { $PreflightProcess.Refresh() } catch {}
            }
            $PreflightProcess.WaitForExit()
            $PreflightProcess.Refresh()
            $Code = [int]$PreflightProcess.ExitCode
            if ($Code -eq 0) { Complete-ActivityProgress -Activity 'Read-only package/parser preflight' -Detail ('elapsed ' + (Format-Elapsed -Elapsed ((Get-Date)-$WaitStarted))) }
        } finally {
            $PreflightProcess.Dispose()
        }

        $Contract = $null
        if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
            try { $Contract = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json -ErrorAction Stop } catch {}
        }
        $ContractPass = ($null -ne $Contract -and [string]$Contract.Schema -eq 'LegionGo-RC2zk-PreflightResult-v1' -and [bool]$Contract.Passed -and [int]$Contract.FailedChecks -eq 0)

        if ($Code -ne 0 -or -not $ContractPass) {
            if ($QuietOnPass) {
                if ($null -ne $StdOut -and (Test-Path -LiteralPath $StdOut)) { Get-Content -LiteralPath $StdOut -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ } }
                if ($null -ne $StdErr -and (Test-Path -LiteralPath $StdErr)) { Get-Content -LiteralPath $StdErr -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
            }
            $ContractText = if($null -eq $Contract){'missing/unreadable'}else{"Passed=$([bool]$Contract.Passed); FailedChecks=$([int]$Contract.FailedChecks)"}
            throw "Preflight result contract failed. ProcessExitCode=$Code Contract=$ContractText. No driver stage was started."
        }
        if ($QuietOnPass) { Write-Host '[PASS] Persistent/resume package integrity preflight passed.' -ForegroundColor Green }
        else { Write-Host '[PASS] Package/parser preflight passed.' -ForegroundColor Green }
    }
    finally {
        Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $StdOut) { Remove-Item -LiteralPath $StdOut -Force -ErrorAction SilentlyContinue }
        if ($null -ne $StdErr) { Remove-Item -LiteralPath $StdErr -Force -ErrorAction SilentlyContinue }
    }
}

function Initialize-PersistentToolkit {
    $Persistent = Get-PersistentToolkitRoot
    $ExistingState = Read-WorkflowState
    if ($null -ne $ExistingState) {
        if ([string]$ExistingState.Release -ne $Release) { throw "Another workflow release is already present in this RC2zk workflow root: $([string]$ExistingState.Release)" }
        if (-not (Test-Path -LiteralPath $Persistent -PathType Container)) { throw 'Workflow state exists but the persistent toolkit copy is missing. Do not substitute files mid-transaction.' }
        Invoke-PackagePreflight -ToolkitRoot $Persistent -QuietOnPass
        return $Persistent
    }
    Invoke-PackagePreflight -ToolkitRoot $PSScriptRoot
    Write-ActivityProgress -Activity 'Create persistent reboot-safe toolkit copy' -Percent 0 -Status 'START'
    if (Test-Path -LiteralPath $Persistent) { Remove-Item -LiteralPath $Persistent -Recurse -Force }
    New-Item -ItemType Directory -Path $Persistent -Force | Out-Null
    $CopyItems = @(Get-ChildItem -LiteralPath $PSScriptRoot -Force)
    $CopyIndex = 0
    foreach ($CopyItem in $CopyItems) {
        Copy-Item -LiteralPath $CopyItem.FullName -Destination $Persistent -Recurse -Force
        $CopyIndex++
        $CopyPercent = if($CopyItems.Count -gt 0){[int][Math]::Floor(($CopyIndex*100.0)/$CopyItems.Count)}else{100}
        Write-ActivityProgress -Activity 'Create persistent reboot-safe toolkit copy' -Percent $CopyPercent -Status 'COPYING' -Detail $CopyItem.Name
    }
    Complete-ActivityProgress -Activity 'Create persistent reboot-safe toolkit copy'
    Invoke-PackagePreflight -ToolkitRoot $Persistent -QuietOnPass
    Write-Host ("[PASS] Persistent toolkit copy created: {0}" -f $Persistent) -ForegroundColor Green
    return $Persistent
}

function Resolve-ValidatedInstallerForFirstRun {
    param([string]$RequestedPath)
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return (Assert-OfficialInstaller -InstallerPath $RequestedPath).Path
    }
    $ExactName = 'whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe'
    $Downloads = Join-Path $env:USERPROFILE 'Downloads'
    Write-Host ("[CHECK] Looking under Downloads for: {0}" -f $ExactName)
    Write-ActivityProgress -Activity 'Locate and validate official AMD 26.7.1 installer' -Percent 0 -Status 'SEARCHING'
    $Candidates = @(Get-ChildItem -LiteralPath $Downloads -Filter $ExactName -File -Recurse -ErrorAction SilentlyContinue)
    if ($Candidates.Count -eq 0) { throw "Exact AMD 26.7.1 installer was not found under Downloads: $ExactName" }
    foreach ($Candidate in $Candidates) {
        if ([int64]$Candidate.Length -ne $Script:ExpectedInstallerLength) { continue }
        try { $ValidatedPath=(Assert-OfficialInstaller -InstallerPath $Candidate.FullName).Path; Complete-ActivityProgress -Activity 'Locate and validate official AMD 26.7.1 installer' -Detail $ValidatedPath; return $ValidatedPath } catch { Write-Host ("[WARN] Rejected candidate: {0} :: {1}" -f $Candidate.FullName,$_.Exception.Message) -ForegroundColor Yellow }
    }
    throw 'AMD 26.7.1 installer candidates were found, but none matched the required size/hash/version/AMD signature.'
}

function Assert-OneClickSecureBootReady {
    Write-ActivityProgress -Activity 'Verify Secure Boot requirement' -Percent 0 -Status 'CHECKING'
    $SecureBoot = Get-SecureBootState
    if ($SecureBoot -eq $true) {
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor Yellow
        Write-Host ' SECURE BOOT MUST BE DISABLED BEFORE INSTALLATION' -ForegroundColor Yellow
        Write-Host '============================================================' -ForegroundColor Yellow
        Write-Host '[BLOCKED] Secure Boot is currently ENABLED.' -ForegroundColor Yellow
        Write-Host '[INFO] This installer uses a per-machine local driver signer and cannot safely continue with Secure Boot enabled.'
        Write-Host '[ACTION] Open Windows Settings > System > Recovery > Advanced startup > Restart now.'
        Write-Host '[ACTION] Choose Troubleshoot > Advanced options > UEFI Firmware Settings, restart into firmware, disable Secure Boot, save/exit, then run this installer again.'
        throw 'Secure Boot is enabled. Disable it in UEFI firmware and rerun RC2zk.'
    }
    if ($null -eq $SecureBoot) {
        throw 'Secure Boot state could not be determined. RC2zk fails closed until Secure Boot can be proven disabled.'
    }
    Complete-ActivityProgress -Activity 'Verify Secure Boot requirement' -Detail 'Secure Boot is disabled'
}

function Request-OneClickConsent {
    param([switch]$AutomaticResume)
    if (Test-OneClickConsent) {
        Write-Host '[PASS] Existing one-click authorization is valid for this resumable installation.' -ForegroundColor Green
        return $true
    }
    if ($AutomaticResume) {
        throw 'Automatic resume found no valid RC2zk one-click consent record. No stage will run unattended.'
    }

    Write-Host ''
    Write-Host '============================================================'
    Write-Host ' ONE-CLICK INSTALLATION CONFIRMATION'
    Write-Host '============================================================'
    $First = Confirm-YesNo `
        -Prompt 'This is a one-click installer that will install AMD graphics driver 26.7.1 on the Lenovo Legion Go. Proceed?' `
        -Estimate 'Initial validation/build work can take several minutes before the first reboot.' `
        -Impact 'No driver or boot-setting change is made unless you answer Yes.'
    if (-not $First) {
        Remove-OneClickConsent
        Write-Host '[PAUSE] Installation was not started.' -ForegroundColor Yellow
        return $false
    }

    $Second = Confirm-YesNo `
        -Prompt 'This installer will automatically restart your device as required and continue installation after each reboot. Close all applications and save your work before continuing. Ready to begin the installation?' `
        -Estimate 'The complete workflow includes multiple reboot/resume boundaries.' `
        -Impact 'Answering Yes authorizes the remaining dependency preparation, driver binding, AMD Software normalization when required, temporary Test Signing changes, and all workflow-required automatic reboots. No additional Y/N prompts are shown in the managed one-click path.'
    if (-not $Second) {
        Remove-OneClickConsent
        Write-Host '[PAUSE] Installation was not started.' -ForegroundColor Yellow
        return $false
    }

    Save-OneClickConsent
    Write-Host '[PASS] One-click installation and automatic reboot authorization recorded.' -ForegroundColor Green
    return $true
}

function Write-WorkflowOverview {
    param($State)
    $StageName = 'NotStarted'
    if ($null -ne $State) { $StageName = [string]$State.Stage }

    # The raw state machine remains internal for resume/recovery. The normal
    # console intentionally presents only stable user-facing progress.
    $Build='[    ]';$Driver='[    ]';$Software='[    ]';$Audit='[    ]'
    switch ($StageName) {
        'NotStarted'                  { $Build='[....]' }
        'SignedPackageReady'          { $Build='[....]' }
        'AwaitingTestSigningReboot'   { $Build='[....]' }
        'ReadyForInstall'             { $Build='[PASS]';$Driver='[....]' }
        'AwaitingNormalSigningReboot' { $Build='[PASS]';$Driver='[....]' }
        'DriverComplete'              { $Build='[PASS]';$Driver='[PASS]';$Software='[....]' }
        'AwaitingSoftwareReboot'      { $Build='[PASS]';$Driver='[PASS]';$Software='[....]' }
        'SoftwareComplete'            { $Build='[PASS]';$Driver='[PASS]';$Software='[PASS]';$Audit='[....]' }
        'Complete'                    { $Build='[PASS]';$Driver='[PASS]';$Software='[PASS]';$Audit='[PASS]' }
        default                       { $Build='[....]' }
    }

    Write-Host ''
    Write-Host '------------------------------------------------------------'
    Write-Host ' Installation progress'
    Write-Host '------------------------------------------------------------'
    Write-Host (" {0} Build and sign package" -f $Build)
    Write-Host (" {0} Install display driver" -f $Driver)
    Write-Host (" {0} Install AMD Software" -f $Software)
    Write-Host (" {0} Final verification" -f $Audit)
}
function Invoke-StageProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [string]$FirstRunInstaller = ''
    )
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { throw "Stage script missing: $ScriptPath" }
    $StageFile = [IO.Path]::GetFileName($ScriptPath)
    $ChildArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath)
    if (-not [string]::IsNullOrWhiteSpace($FirstRunInstaller)) { $ChildArgs += @('-InstallerPath',$FirstRunInstaller) }
    $ArgLine = (@($ChildArgs | ForEach-Object { Quote-NativeArgument -Value ([string]$_) }) -join ' ')
    $env:LEGIONGO_RC2I_MANAGED = '1'
    $IsStage2 = ($StageFile -eq '02-Install-Driver-And-Verify-Normal-Signing.ps1')
    $IsStage3 = ($StageFile -eq '03-Install-AMD-Software-And-Reboot.ps1')
    $IsStage4 = ($StageFile -eq '04-Final-Persistence-Audit.ps1')
    $Stage2ResultPath = Join-Path $Script:WorkflowRoot 'stage2-result.json'
    $Stage3ResultPath = Join-Path $Script:WorkflowRoot 'stage3-result.json'
    $Stage4ResultPath = Join-Path $Script:WorkflowRoot 'stage4-result.json'
    $InvocationId = ''
    if ($IsStage2 -or $IsStage3 -or $IsStage4) {
        $InvocationId = [guid]::NewGuid().ToString('N')
        $env:LEGIONGO_STAGE_INVOCATION_ID = $InvocationId
        if ($IsStage2) { Remove-Item -LiteralPath $Stage2ResultPath -Force -ErrorAction SilentlyContinue }
        if ($IsStage3) { Remove-Item -LiteralPath $Stage3ResultPath -Force -ErrorAction SilentlyContinue }
        if ($IsStage4) { Remove-Item -LiteralPath $Stage4ResultPath -Force -ErrorAction SilentlyContinue }
    }
    Write-Host ("[LAUNCH] {0}" -f $StageFile) -ForegroundColor Cyan
    $StageProcess = Start-Process -FilePath $PowerShellExe -ArgumentList $ArgLine -PassThru -NoNewWindow
    try {
        $StageProcess.WaitForExit()
        $StageProcess.Refresh()
        $Code = [int]$StageProcess.ExitCode
    } finally {
        $StageProcess.Dispose()
        if ($IsStage2 -or $IsStage3 -or $IsStage4) { Remove-Item Env:\LEGIONGO_STAGE_INVOCATION_ID -ErrorAction SilentlyContinue }
    }
    if ($IsStage2) {
        if (-not (Test-Path -LiteralPath $Stage2ResultPath -PathType Leaf)) {
            throw "Stage 2 exited with code $Code but did not produce its invocation result contract."
        }
        try { $Stage2Result = Get-Content -LiteralPath $Stage2ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { throw ('Stage 2 result contract is unreadable after process exit {0}: {1}' -f $Code,$_.Exception.Message) }
        if ([string]$Stage2Result.Release -ne 'v3.0-RC2zk' -or [string]$Stage2Result.InvocationId -ne $InvocationId) {
            throw "Stage 2 result contract identity mismatch. ExpectedInvocation=$InvocationId ActualInvocation=$($Stage2Result.InvocationId) Release=$($Stage2Result.Release)"
        }
        $Stage2ContractCode = [int]$Stage2Result.ExitCode
        $Stage2ContractStatus = [string]$Stage2Result.Status
        $Stage2EffectiveCode = $Code
        if ($Stage2ContractCode -ne $Code) {
            $NormalizedStage2RebootShutdownExit = $false
            if ($Code -eq 0 -and $Stage2ContractCode -eq 2 -and $Stage2ContractStatus -eq 'RebootRequired') {
                $BoundaryState = Read-WorkflowState
                $BoundaryCheckpoint = Get-CheckpointName -State $BoundaryState
                $RebootIssuedAt = ''
                if ($null -ne $BoundaryState) {
                    $IssuedProperty = $BoundaryState.PSObject.Properties['DriverRebootCommandIssuedAt']
                    if ($null -ne $IssuedProperty) { $RebootIssuedAt = [string]$IssuedProperty.Value }
                }
                if ($BoundaryCheckpoint -eq 'AwaitingNormalSigningReboot' -and -not [string]::IsNullOrWhiteSpace($RebootIssuedAt)) {
                    $Stage2EffectiveCode = 2
                    $NormalizedStage2RebootShutdownExit = $true
                    Write-Host ("[PASS] Stage 2 reboot handoff accepted: process exit={0}; contract exit=2; status=RebootRequired; reboot-command marker={1}" -f $Code,$RebootIssuedAt) -ForegroundColor Green
                }
            }
            if (-not $NormalizedStage2RebootShutdownExit) {
                # Field evidence on 2026-08-21 showed Windows/Start-Process can surface
                # process exit 0 even after the invocation-bound Stage 2 child atomically
                # writes Failed/1. A fresh invocation ID plus freshly removed result file
                # makes that child contract authoritative for FAILURE only. Success,
                # pause, and reboot mismatches remain fail-closed.
                if ($Code -eq 0 -and $Stage2ContractCode -eq 1 -and $Stage2ContractStatus -eq 'Failed') {
                    $Stage2EffectiveCode = 1
                    Write-Host ("[WARN] Stage 2 process exit transport reported 0, but the fresh invocation-bound child contract reported Failed/1. Treating the child failure contract as authoritative. Detail={0}" -f $Stage2Result.Detail) -ForegroundColor Yellow
                }
                else {
                    throw "Stage 2 process/result disagreement. ProcessExit=$Code ContractExit=$Stage2ContractCode Status=$Stage2ContractStatus Detail=$($Stage2Result.Detail)"
                }
            }
        }
        $ExpectedStage2Status = switch ($Stage2EffectiveCode) {
            0 { 'Passed' }
            2 { 'RebootRequired' }
            3 { 'Paused' }
            default { 'Failed' }
        }
        if ($Stage2ContractStatus -ne $ExpectedStage2Status) {
            throw "Stage 2 process/result disagreement. ProcessExit=$Code EffectiveExit=$Stage2EffectiveCode ExpectedStatus=$ExpectedStage2Status ContractStatus=$Stage2ContractStatus Detail=$($Stage2Result.Detail)"
        }
        $Code = $Stage2EffectiveCode
        Write-Host ("[PASS] Stage 2 result contract agrees: exit={0}; status={1}" -f $Code,$ExpectedStage2Status) -ForegroundColor Green
    }
    if ($IsStage3) {
        if (-not (Test-Path -LiteralPath $Stage3ResultPath -PathType Leaf)) {
            throw "Stage 3 exited with code $Code but did not produce its invocation result contract."
        }
        try { $Stage3Result = Get-Content -LiteralPath $Stage3ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { throw ('Stage 3 result contract is unreadable after process exit {0}: {1}' -f $Code,$_.Exception.Message) }
        if ([string]$Stage3Result.Release -ne 'v3.0-RC2zk' -or [string]$Stage3Result.InvocationId -ne $InvocationId) {
            throw "Stage 3 result contract identity mismatch. ExpectedInvocation=$InvocationId ActualInvocation=$($Stage3Result.InvocationId) Release=$($Stage3Result.Release)"
        }
        $ContractCode = [int]$Stage3Result.ExitCode
        $ContractStatus = [string]$Stage3Result.Status
        $EffectiveCode = $Code
        if ($ContractCode -ne $Code) {
            $NormalizedRebootShutdownExit = $false
            if ($Code -eq 0 -and $ContractCode -eq 2 -and $ContractStatus -eq 'RebootRequired') {
                $BoundaryState = Read-WorkflowState
                $BoundaryCheckpoint = Get-CheckpointName -State $BoundaryState
                $RebootIssuedAt = ''
                if ($null -ne $BoundaryState) {
                    $IssuedProperty = $BoundaryState.PSObject.Properties['SoftwareRebootCommandIssuedAt']
                    if ($null -ne $IssuedProperty) { $RebootIssuedAt = [string]$IssuedProperty.Value }
                }
                if ($BoundaryCheckpoint -eq 'AwaitingSoftwareReboot' -and -not [string]::IsNullOrWhiteSpace($RebootIssuedAt)) {
                    $EffectiveCode = 2
                    $NormalizedRebootShutdownExit = $true
                    Write-Host ("[PASS] Stage 3 reboot handoff accepted: process exit={0}; contract exit=2; status=RebootRequired; reboot-command marker={1}" -f $Code,$RebootIssuedAt) -ForegroundColor Green
                }
            }
            if (-not $NormalizedRebootShutdownExit) {
                throw "Stage 3 process/result disagreement. ProcessExit=$Code ContractExit=$ContractCode Status=$ContractStatus"
            }
        }
        $ExpectedStatus = switch ($EffectiveCode) {
            0 { 'Passed' }
            2 { 'RebootRequired' }
            3 { 'Paused' }
            default { 'Failed' }
        }
        if ($ContractStatus -ne $ExpectedStatus) {
            throw "Stage 3 process/result disagreement. ProcessExit=$Code EffectiveExit=$EffectiveCode ExpectedStatus=$ExpectedStatus ContractStatus=$ContractStatus Detail=$($Stage3Result.Detail)"
        }
        $Code = $EffectiveCode
        Write-Host ("[PASS] Stage 3 result contract agrees: exit={0}; status={1}" -f $Code,$ExpectedStatus) -ForegroundColor Green
    }
    if ($IsStage4) {
        if (-not (Test-Path -LiteralPath $Stage4ResultPath -PathType Leaf)) {
            throw "Stage 4 exited with code $Code but did not produce its invocation result contract."
        }
        try { $Stage4Result = Get-Content -LiteralPath $Stage4ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { throw ('Stage 4 result contract is unreadable after process exit {0}: {1}' -f $Code,$_.Exception.Message) }
        if ([string]$Stage4Result.Release -ne 'v3.0-RC2zk' -or [string]$Stage4Result.InvocationId -ne $InvocationId) {
            throw "Stage 4 result contract identity mismatch. ExpectedInvocation=$InvocationId ActualInvocation=$($Stage4Result.InvocationId) Release=$($Stage4Result.Release)"
        }
        if ([int]$Stage4Result.ExitCode -ne $Code) {
            throw "Stage 4 process/result disagreement. ProcessExit=$Code ContractExit=$($Stage4Result.ExitCode) Status=$($Stage4Result.Status) FailedChecks=$($Stage4Result.FailedChecks)"
        }
        $ExpectedStage4Status = if($Code -eq 0){'Passed'}else{'Failed'}
        if ([string]$Stage4Result.Status -ne $ExpectedStage4Status) {
            throw "Stage 4 process/result disagreement. ProcessExit=$Code ExpectedStatus=$ExpectedStage4Status ContractStatus=$($Stage4Result.Status) FailedChecks=$($Stage4Result.FailedChecks)"
        }
        if ($Code -eq 0 -and [int]$Stage4Result.FailedChecks -ne 0) {
            throw "Stage 4 claimed success but its result contract reports FailedChecks=$($Stage4Result.FailedChecks)."
        }
        Write-Host ("[PASS] Stage 4 result contract agrees: exit={0}; status={1}; failedChecks={2}" -f $Code,$ExpectedStage4Status,$Stage4Result.FailedChecks) -ForegroundColor Green
    }
    return $Code
}

function Prepare-FinalEvidenceContracts {
    param([Parameter(Mandatory=$true)][string]$EvidencePath)
    Write-ActivityProgress -Activity 'Package Stage 2/3/4 result contracts into final evidence' -Percent 0 -Status 'VERIFYING'
    if ([string]::IsNullOrWhiteSpace($EvidencePath) -or -not (Test-Path -LiteralPath $EvidencePath -PathType Container)) {
        throw "Final evidence directory is missing after Stage 4: $EvidencePath"
    }
    $Stage2Path = Join-Path $Script:WorkflowRoot 'stage2-result.json'
    $Stage3Path = Join-Path $Script:WorkflowRoot 'stage3-result.json'
    $Stage4Path = Join-Path $Script:WorkflowRoot 'stage4-result.json'
    foreach ($Required in @($Stage2Path,$Stage3Path,$Stage4Path)) {
        if (-not (Test-Path -LiteralPath $Required -PathType Leaf)) { throw "Required final evidence contract is missing: $Required" }
    }
    $Stage2Contract = Get-Content -LiteralPath $Stage2Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $Stage3Contract = Get-Content -LiteralPath $Stage3Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $Stage4Contract = Get-Content -LiteralPath $Stage4Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$Stage2Contract.Release -ne 'v3.0-RC2zk' -or [string]$Stage2Contract.Status -ne 'Passed' -or [int]$Stage2Contract.ExitCode -ne 0) {
        throw 'Stage 2 final result contract is not a clean RC2zk PASS; refusing to package misleading final evidence.'
    }
    if ([string]$Stage3Contract.Release -ne 'v3.0-RC2zk' -or [int]$Stage3Contract.Stage -ne 3 -or [string]$Stage3Contract.Status -ne 'Passed' -or [int]$Stage3Contract.ExitCode -ne 0) {
        throw 'Stage 3 final result contract is not a clean RC2zk PASS; refusing to package misleading final evidence.'
    }
    if ([string]$Stage4Contract.Release -ne 'v3.0-RC2zk' -or [string]$Stage4Contract.Status -ne 'Passed' -or [int]$Stage4Contract.ExitCode -ne 0 -or [int]$Stage4Contract.FailedChecks -ne 0) {
        throw 'Stage 4 final result contract is not a clean RC2zk PASS; refusing to package misleading final evidence.'
    }
    if ([string]$Stage4Contract.EvidencePath -ne $EvidencePath) { throw 'Stage 4 result contract evidence path changed before launcher finalization.' }
    Copy-Item -LiteralPath $Stage2Path -Destination (Join-Path $EvidencePath 'stage2-result.json') -Force
    Write-ActivityProgress -Activity 'Package Stage 2/3/4 result contracts into final evidence' -Percent 33 -Status 'COPYING' -Detail 'stage2-result.json'
    Copy-Item -LiteralPath $Stage3Path -Destination (Join-Path $EvidencePath 'stage3-result.json') -Force
    Write-ActivityProgress -Activity 'Package Stage 2/3/4 result contracts into final evidence' -Percent 66 -Status 'COPYING' -Detail 'stage3-result.json'
    Copy-Item -LiteralPath $Stage4Path -Destination (Join-Path $EvidencePath 'stage4-result.json') -Force
    Complete-ActivityProgress -Activity 'Package Stage 2/3/4 result contracts into final evidence' -Detail 'stage2-result.json + stage3-result.json + stage4-result.json'
}

function Copy-RelevantLauncherEvidence {
    param([Parameter(Mandatory=$true)][string]$EvidencePath)
    Write-ActivityProgress -Activity 'Package launcher contract-consumption evidence' -Percent 0 -Status 'SCANNING'
    $LauncherEvidence = Join-Path $EvidencePath 'Launcher-Logs'
    New-Item -ItemType Directory -Path $LauncherEvidence -Force | Out-Null
    $Combined = ''
    $Copied = 0
    $LauncherLogs = @(Get-ChildItem -LiteralPath $Logs -Filter 'launcher-*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    $LogIndex = 0
    foreach ($LogFile in $LauncherLogs) {
        $LogIndex++
        $Text = Get-Content -LiteralPath $LogFile.FullName -Raw -ErrorAction Stop
        if ($Text.Contains('Stage 2 result contract agrees') -or $Text.Contains('Stage 3 result contract agrees') -or $Text.Contains('Stage 4 result contract agrees') -or $Text.Contains('One-command workflow marked complete.')) {
            Copy-Item -LiteralPath $LogFile.FullName -Destination (Join-Path $LauncherEvidence $LogFile.Name) -Force
            $Combined += "`r`n" + $Text
            $Copied++
        }
        $LogPercent = if($LauncherLogs.Count -gt 0){[int][Math]::Floor(($LogIndex*100.0)/$LauncherLogs.Count)}else{100}
        Write-ActivityProgress -Activity 'Package launcher contract-consumption evidence' -Percent $LogPercent -Status 'SCANNING' -Detail ("{0}/{1} launcher logs" -f $LogIndex,$LauncherLogs.Count)
    }
    if ($Copied -lt 1) { throw 'No relevant launcher session log could be copied into final evidence.' }
    foreach ($Marker in @('Stage 2 result contract agrees','Stage 3 result contract agrees','Stage 4 result contract agrees','One-command workflow marked complete.')) {
        if (-not $Combined.Contains($Marker)) { throw "Launcher evidence does not prove required parent consumption marker: $Marker" }
    }
    Complete-ActivityProgress -Activity 'Package launcher contract-consumption evidence' -Detail (("{0} relevant launcher log(s) copied" -f $Copied))
    Write-Host ("[PASS] Final evidence bundle includes Stage 2/3/4 contracts plus {0} relevant launcher log(s)." -f $Copied) -ForegroundColor Green
}

function Get-CheckpointName {
    param($State)
    if ($null -eq $State) { return 'NotStarted' }
    return [string]$State.Stage
}

function Get-StageRoute {
    param([Parameter(Mandatory=$true)][string]$Checkpoint,[string]$FirstRunInstaller='')
    switch ($Checkpoint) {
        'NotStarted' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1');Installer=$FirstRunInstaller} }
        'SignedPackageReady' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1');Installer=''} }
        'AwaitingTestSigningReboot' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1');Installer=''} }
        'ReadyForInstall' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '02-Install-Driver-And-Verify-Normal-Signing.ps1');Installer=''} }
        'AwaitingNormalSigningReboot' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '02-Install-Driver-And-Verify-Normal-Signing.ps1');Installer=''} }
        'DriverComplete' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '03-Install-AMD-Software-And-Reboot.ps1');Installer=''} }
        'AwaitingSoftwareReboot' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '03-Install-AMD-Software-And-Reboot.ps1');Installer=''} }
        'SoftwareComplete' { return [pscustomobject]@{Script=(Join-Path $ToolkitRoot '04-Final-Persistence-Audit.ps1');Installer=''} }
        'Complete' { return $null }
        default { throw "Unknown workflow checkpoint: $Checkpoint" }
    }
}

function Get-ExpectedSuccessCheckpoint {
    param([Parameter(Mandatory=$true)][string]$BeforeCheckpoint,[Parameter(Mandatory=$true)][string]$StageFile)
    switch ($BeforeCheckpoint) {
        'AwaitingTestSigningReboot' { return 'ReadyForInstall' }
        'ReadyForInstall' { if($StageFile -eq '02-Install-Driver-And-Verify-Normal-Signing.ps1'){ return 'DriverComplete' } }
        'AwaitingNormalSigningReboot' { return 'DriverComplete' }
        'AwaitingSoftwareReboot' { return 'SoftwareComplete' }
        'SoftwareComplete' { if($StageFile -eq '04-Final-Persistence-Audit.ps1'){ return 'SoftwareComplete' } }
    }
    return ''
}

function Get-ExpectedRebootCheckpoint {
    param([Parameter(Mandatory=$true)][string]$BeforeCheckpoint)
    switch ($BeforeCheckpoint) {
        'NotStarted' { return 'AwaitingTestSigningReboot' }
        'SignedPackageReady' { return 'AwaitingTestSigningReboot' }
        'AwaitingTestSigningReboot' { return 'AwaitingTestSigningReboot' }
        'ReadyForInstall' { return 'AwaitingNormalSigningReboot' }
        'AwaitingNormalSigningReboot' { return 'AwaitingNormalSigningReboot' }
        'DriverComplete' { return 'AwaitingSoftwareReboot' }
        'AwaitingSoftwareReboot' { return 'AwaitingSoftwareReboot' }
        default { return '' }
    }
}

function Invoke-RoutedStageOnce {
    param([Parameter(Mandatory=$true)][string]$Checkpoint,[string]$FirstRunInstaller='')
    $Route = Get-StageRoute -Checkpoint $Checkpoint -FirstRunInstaller $FirstRunInstaller
    if ($null -eq $Route) { return [pscustomobject]@{Status='Complete';Checkpoint='Complete'} }
    $StageFile = [IO.Path]::GetFileName([string]$Route.Script)
    $Code = Invoke-StageProcess -ScriptPath ([string]$Route.Script) -FirstRunInstaller ([string]$Route.Installer)
    $AfterState = Read-WorkflowState
    $AfterCheckpoint = Get-CheckpointName -State $AfterState

    if ($Code -eq 0) {
        $Expected = Get-ExpectedSuccessCheckpoint -BeforeCheckpoint $Checkpoint -StageFile $StageFile
        if ([string]::IsNullOrWhiteSpace($Expected) -or $AfterCheckpoint -ne $Expected) {
            Remove-ResumeTask
            throw "Stage returned exit code 0 but the workflow checkpoint did not advance as required. Stage=$StageFile Before=$Checkpoint Expected=$Expected After=$AfterCheckpoint. Treating this as a hard failure; no retry will occur."
        }
        if ($StageFile -eq '04-Final-Persistence-Audit.ps1') {
            if ($null -eq $AfterState) { throw 'Final audit passed but workflow state disappeared.' }
            $FinalStage4ResultPath = Join-Path $Script:WorkflowRoot 'stage4-result.json'
            if (-not (Test-Path -LiteralPath $FinalStage4ResultPath -PathType Leaf)) { throw 'Final Stage 4 result contract disappeared before evidence packaging.' }
            $FinalStage4Result = Get-Content -LiteralPath $FinalStage4ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $FinalEvidencePath = [string]$FinalStage4Result.EvidencePath
            Prepare-FinalEvidenceContracts -EvidencePath $FinalEvidencePath

            Set-StateProperty $AfterState 'Stage' 'Complete'
            Set-StateProperty $AfterState 'CompletedAt' (Get-Date).ToString('o')
            Set-StateProperty $AfterState 'UpdatedAt' (Get-Date).ToString('o')
            Write-JsonAtomic -InputObject $AfterState -LiteralPath $Script:WorkflowStatePath -Depth 30
            Remove-ResumeTask
            Write-Host '[PASS] One-command workflow marked complete.' -ForegroundColor Green

            # Stop the transcript only after the launcher has recorded its Stage 4
            # contract acceptance and Complete decision, then copy every launcher
            # session needed to prove Stage 3 + Stage 4 parent consumption.
            Stop-LauncherTranscript
            try {
                Copy-RelevantLauncherEvidence -EvidencePath $FinalEvidencePath
                Remove-OneClickConsent
            } catch {
                Set-StateProperty $AfterState 'Stage' 'SoftwareComplete'
                Set-StateProperty $AfterState 'CompletedAt' ''
                Set-StateProperty $AfterState 'UpdatedAt' (Get-Date).ToString('o')
                Write-JsonAtomic -InputObject $AfterState -LiteralPath $Script:WorkflowStatePath -Depth 30
                throw ("Final audit passed, but required evidence packaging failed; workflow returned to SoftwareComplete so Stage 4 can be safely rerun. {0}" -f $_.Exception.Message)
            }
            return [pscustomobject]@{Status='Complete';Checkpoint='Complete'}
        }
        return [pscustomobject]@{Status='Passed';Checkpoint=$AfterCheckpoint}
    }

    if ($Code -eq 2) {
        $ExpectedBoundary = Get-ExpectedRebootCheckpoint -BeforeCheckpoint $Checkpoint
        if ([string]::IsNullOrWhiteSpace($ExpectedBoundary) -or $AfterCheckpoint -ne $ExpectedBoundary) {
            Remove-ResumeTask
            throw "Stage reported a reboot boundary but the saved checkpoint is inconsistent. Stage=$StageFile Before=$Checkpoint Expected=$ExpectedBoundary After=$AfterCheckpoint."
        }
        if (-not (Test-ManagedResumeTask)) { Register-ManagedResumeTask }
        Write-Host '[INFO] Workflow is at a saved reboot boundary. A one-shot resume task is armed for the next sign-in.' -ForegroundColor Cyan
        Write-Host '[INFO] If you deferred the reboot, simply reboot when ready; the launcher will resume once after sign-in.'
        return [pscustomobject]@{Status='RebootBoundary';Checkpoint=$AfterCheckpoint}
    }

    if ($Code -eq 3) {
        Remove-ResumeTask
        Write-Host '[PAUSE] You chose not to continue at a change gate. No automatic retry will occur.' -ForegroundColor Yellow
        Write-Host '[INFO] Progress/workspace is preserved. Run this same launcher again when ready.'
        return [pscustomobject]@{Status='Paused';Checkpoint=$AfterCheckpoint}
    }

    Remove-ResumeTask
    Write-Host ("[FAIL] {0} exited with code {1}. No automatic retry will occur." -f $StageFile,$Code) -ForegroundColor Red
    Write-Host ("[INFO] Launcher transcript: {0}" -f $TranscriptPath)
    $ChildFailureDetail = ''
    if ($StageFile -eq '02-Install-Driver-And-Verify-Normal-Signing.ps1') {
        try {
            $FailureContractPath = Join-Path $Script:WorkflowRoot 'stage2-result.json'
            if (Test-Path -LiteralPath $FailureContractPath -PathType Leaf) {
                $FailureContract = Get-Content -LiteralPath $FailureContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ([string]$FailureContract.Status -eq 'Failed' -and [int]$FailureContract.ExitCode -eq $Code) {
                    $ChildFailureDetail = [string]$FailureContract.Detail
                }
            }
        } catch {}
    }
    if (-not [string]::IsNullOrWhiteSpace($ChildFailureDetail)) {
        throw ("Stage failed with exit code {0}: {1} :: {2}" -f $Code,$StageFile,$ChildFailureDetail)
    }
    throw "Stage failed with exit code ${Code}: $StageFile"
}

function Invoke-FailureCodeIntegrityRecovery {
    param([Parameter(Mandatory=$true)][string]$Reason)

    $Result = [ordered]@{
        QuerySucceeded=$false
        TestSigningBefore=$null
        NoIntegrityChecksBefore=$null
        TestSigningAfter=$null
        NoIntegrityChecksAfter=$null
        Changed=$false
        RebootRequired=$false
        RecoverySucceeded=$false
        Detail=''
    }

    try {
        $TestSigningBefore = Get-TestSigningConfigured
        $NoIntegrityBefore = Get-NoIntegrityChecksConfigured
        $Result.QuerySucceeded = $true
        $Result.TestSigningBefore = [bool]$TestSigningBefore
        $Result.NoIntegrityChecksBefore = [bool]$NoIntegrityBefore

        Write-Host ("[RECOVERY] Failure code-integrity state: TestSigning={0}; NoIntegrityChecks={1}" -f $TestSigningBefore,$NoIntegrityBefore) -ForegroundColor Yellow

        if ($TestSigningBefore -or $NoIntegrityBefore) {
            Write-Host '[RECOVERY] A weakened boot-integrity flag is still configured. Normalizing BCD before recovery completes.' -ForegroundColor Yellow
            & bcdedit.exe /set testsigning off | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'bcdedit failed to configure Test Signing off during failure recovery.' }
            & bcdedit.exe /set nointegritychecks off | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'bcdedit failed to configure nointegritychecks off during failure recovery.' }

            $TestSigningAfter = Get-TestSigningConfigured
            $NoIntegrityAfter = Get-NoIntegrityChecksConfigured
            $Result.TestSigningAfter = [bool]$TestSigningAfter
            $Result.NoIntegrityChecksAfter = [bool]$NoIntegrityAfter
            if ($TestSigningAfter -or $NoIntegrityAfter) { throw 'Failure recovery could not prove Test Signing and nointegritychecks are both configured off.' }

            $Result.Changed = $true
            $Result.RebootRequired = $true
            $Result.RecoverySucceeded = $true
            $Result.Detail = 'BCD normalized to Test Signing OFF and nointegritychecks OFF; reboot required before any retry.'
            Write-Host '[PASS] Failure recovery configured Test Signing OFF and nointegritychecks OFF.' -ForegroundColor Green
        } else {
            $Result.TestSigningAfter = $false
            $Result.NoIntegrityChecksAfter = $false
            $Result.RecoverySucceeded = $true
            $Result.Detail = 'BCD code-integrity flags were already normal; no recovery reboot required.'
            Write-Host '[PASS] Failure recovery found Test Signing and nointegritychecks already OFF.' -ForegroundColor Green
        }

        try {
            $FailureState = Read-WorkflowState
            if ($null -ne $FailureState) {
                Set-StateProperty $FailureState 'FailureCodeIntegrityReason' $Reason
                Set-StateProperty $FailureState 'FailureTestSigningBefore' $Result.TestSigningBefore
                Set-StateProperty $FailureState 'FailureNoIntegrityChecksBefore' $Result.NoIntegrityChecksBefore
                Set-StateProperty $FailureState 'FailureTestSigningAfter' $Result.TestSigningAfter
                Set-StateProperty $FailureState 'FailureNoIntegrityChecksAfter' $Result.NoIntegrityChecksAfter
                Set-StateProperty $FailureState 'FailureCodeIntegrityNormalizedAt' (Get-Date).ToString('o')
                Set-StateProperty $FailureState 'FailureRecoveryRebootRequired' ([bool]$Result.RebootRequired)
                Set-StateProperty $FailureState 'UpdatedAt' (Get-Date).ToString('o')
                Write-JsonAtomic -InputObject $FailureState -LiteralPath $Script:WorkflowStatePath -Depth 30
            }
        } catch {
            Write-Host ("[WARN] BCD recovery succeeded but workflow-state annotation failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        }
    } catch {
        $Result.Detail = $_.Exception.Message
        Write-Host ("[FAIL] Failure code-integrity recovery could not complete: {0}" -f $Result.Detail) -ForegroundColor Red
    }

    return [pscustomobject]$Result
}

function New-FailureEvidenceBundle {
    param([Parameter(Mandatory=$true)][string]$Reason,[string]$LauncherLog='')
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Downloads = Join-Path $env:USERPROFILE 'Downloads'
    $EvidencePath = Join-Path $Downloads ('LegionGo-AMD-26.7.1-v3.0-RC2zk-Failure-Evidence-' + $Stamp)
    $ZipPath = $EvidencePath + '.zip'
    try {
        New-Item -ItemType Directory -Path $EvidencePath -Force | Out-Null
        $Summary = @(
            'LEGION GO AMD 26.7.1 v3.0 RC2zk - FAILURE EVIDENCE',
            ('GeneratedAt: ' + (Get-Date).ToString('o')),
            ('Reason: ' + $Reason),
            ('WorkflowRoot: ' + $Script:WorkflowRoot),
            ('LauncherLog: ' + $LauncherLog)
        ) -join [Environment]::NewLine
        [IO.File]::WriteAllText((Join-Path $EvidencePath 'Failure-Summary.txt'),$Summary,(New-Object Text.UTF8Encoding -ArgumentList $false))
        foreach($Name in @('workflow-state.json','stage2-result.json','stage3-result.json','stage4-result.json','one-click-consent.json')) {
            $Source = Join-Path $Script:WorkflowRoot $Name
            if (Test-Path -LiteralPath $Source -PathType Leaf) { Copy-Item -LiteralPath $Source -Destination (Join-Path $EvidencePath $Name) -Force }
        }
        $SourceLogs = Join-Path $Script:WorkflowRoot 'Logs'
        if (Test-Path -LiteralPath $SourceLogs -PathType Container) {
            $DestLogs = Join-Path $EvidencePath 'Logs'
            New-Item -ItemType Directory -Path $DestLogs -Force | Out-Null
            Get-ChildItem -LiteralPath $SourceLogs -File -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $DestLogs $_.Name) -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path -LiteralPath $ZipPath -PathType Leaf) { Remove-Item -LiteralPath $ZipPath -Force }
        Compress-Archive -Path (Join-Path $EvidencePath '*') -DestinationPath $ZipPath -Force -CompressionLevel Optimal
        Write-Host ("[EVIDENCE] Failure evidence folder: {0}" -f $EvidencePath) -ForegroundColor Yellow
        Write-Host ("[EVIDENCE] Failure evidence ZIP: {0}" -f $ZipPath) -ForegroundColor Yellow
        return [pscustomobject]@{Folder=$EvidencePath;Zip=$ZipPath}
    } catch {
        Write-Host ("[WARN] Failure evidence packaging could not complete: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        return $null
    }
}

function Invoke-ExpectedSuccessorOnce {
    param([Parameter(Mandatory=$true)][string]$InitialCheckpoint,[Parameter(Mandatory=$true)]$FirstResult)
    if ([string]$FirstResult.Status -ne 'Passed') { return $FirstResult }
    $ExpectedSuccessor = switch ($InitialCheckpoint) {
        'AwaitingTestSigningReboot' { 'ReadyForInstall' }
        'AwaitingNormalSigningReboot' { 'DriverComplete' }
        'AwaitingSoftwareReboot' { 'SoftwareComplete' }
        default { '' }
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedSuccessor) -or [string]$FirstResult.Checkpoint -ne $ExpectedSuccessor) { return $FirstResult }
    Write-Host ("[NEXT] Saved reboot checkpoint passed; continuing exactly once from {0}." -f $ExpectedSuccessor) -ForegroundColor Cyan
    return (Invoke-RoutedStageOnce -Checkpoint $ExpectedSuccessor)
}

try {
    Write-Host '============================================================'
    Write-Host ' LEGION GO AMD 26.7.1 v3.0 RC2zk - ONE-COMMAND INSTALLER'
    Write-Host '============================================================'
    Write-Host '[INFO] Losing focus/minimizing this console does not pause the workflow.'
    Write-Host '[INFO] Text selection stays available at prompts; QuickEdit is blocked only during long operations. Sleep prevention is best-effort.'
    Write-Host '[INFO] Fresh one-click runs use exactly two Y/N confirmations up front; after approval, required reboots and installation stages continue automatically.'
    Write-Host '[INFO] Stage routing is bounded: no generic while-loop can relaunch a failed stage.'
    Write-Host ("[INFO] Session log: {0}" -f $TranscriptPath)

    Assert-OneClickSecureBootReady

    # Fresh/manual launcher invocations ask exactly twice here, before the long full
    # package preflight, installer hash, dependency preparation, build, or driver work.
    # Automatic resume never asks again; it must possess the persisted authorization.
    $PreInitState = Read-WorkflowState
    $PreInitCheckpoint = Get-CheckpointName -State $PreInitState
    if (-not $Resume -and $PreInitCheckpoint -ne 'Complete') {
        if (-not (Request-OneClickConsent)) {
            Stop-LauncherTranscript
            Restore-InstallerRuntime
            exit 0
        }
    }

    $ToolkitRoot = Initialize-PersistentToolkit
    if ($ToolkitRoot -is [System.Array] -or [string]::IsNullOrWhiteSpace([string]$ToolkitRoot)) { throw 'Persistent toolkit root did not resolve to one scalar directory path. No stage was started.' }
    $ToolkitRoot = [string]$ToolkitRoot
    if (-not (Test-Path -LiteralPath $ToolkitRoot -PathType Container)) { throw "Persistent toolkit root is not a directory: $ToolkitRoot" }

    if ($Resume) {
        Remove-ResumeTask
        Write-Host '[PASS] One-shot resume trigger consumed; no automatic retry remains armed while this session runs.' -ForegroundColor Green
        $ResumeState = Read-WorkflowState
        if ($null -ne $ResumeState) {
            $ResumeStage = [string]$ResumeState.Stage
            $RecordedBoot = $null
            if ($ResumeStage -eq 'AwaitingTestSigningReboot' -and $null -ne $ResumeState.PSObject.Properties['BootTimeAtTestSigningEnable']) { $RecordedBoot = [datetime]::Parse([string]$ResumeState.BootTimeAtTestSigningEnable) }
            elseif ($ResumeStage -eq 'AwaitingNormalSigningReboot' -and $null -ne $ResumeState.PSObject.Properties['BootTimeAtNormalSigningDisable']) { $RecordedBoot = [datetime]::Parse([string]$ResumeState.BootTimeAtNormalSigningDisable) }
            elseif ($ResumeStage -eq 'AwaitingSoftwareReboot' -and $null -ne $ResumeState.PSObject.Properties['BootTimeAtSoftwareInstall']) { $RecordedBoot = [datetime]::Parse([string]$ResumeState.BootTimeAtSoftwareInstall) }
            if ($null -ne $RecordedBoot -and (Get-CurrentBootTime) -le $RecordedBoot) {
                Write-Host '[GUARD] Resume trigger fired before the saved reboot boundary was crossed. No stage will run in this boot session.' -ForegroundColor Yellow
                Stop-LauncherTranscript; Restore-InstallerRuntime; exit 0
            }
        }
        Write-Host '[PASS] Previous reboot completed. Resuming installation.' -ForegroundColor Green
    }

    $State = Read-WorkflowState
    $InitialCheckpoint = Get-CheckpointName -State $State
    $FirstRunInstaller = ''
    if ($InitialCheckpoint -eq 'NotStarted') { $FirstRunInstaller = Resolve-ValidatedInstallerForFirstRun -RequestedPath $InstallerPath }
    if ($Resume -and $InitialCheckpoint -ne 'Complete') {
        # Resume is intentionally non-interactive: the two fresh-run confirmations
        # must already have been persisted before the first automatic reboot.
        [void](Request-OneClickConsent -AutomaticResume)
    }
    Write-WorkflowOverview -State $State
    if ($InitialCheckpoint -eq 'Complete') {
        Write-Host '[PASS] Workflow is already complete.' -ForegroundColor Green
        Remove-ResumeTask
    }
    else {
        $FirstResult = Invoke-RoutedStageOnce -Checkpoint $InitialCheckpoint -FirstRunInstaller $FirstRunInstaller
        [void](Invoke-ExpectedSuccessorOnce -InitialCheckpoint $InitialCheckpoint -FirstResult $FirstResult)
    }

} catch {
    $LauncherFailure = $_.Exception.Message
    Remove-ResumeTask
    Remove-OneClickConsent
    $SafetyText = ''
    try { $SafetyText = Get-WorkflowSafetySummary } catch { $SafetyText = 'Unable to summarize workflow state; preserve ProgramData workflow and logs.' }
    Write-FailureGuide -Stage 'One-command launcher' -Message $LauncherFailure -LogPath $TranscriptPath -SafetyState $SafetyText

    # No failed stage is automatically retried. Before recovery is considered
    # complete, inspect the live BCD state. If Stage 1 left Test Signing enabled
    # (or nointegritychecks is unexpectedly enabled), configure both OFF, package
    # the failure evidence, and reboot without arming a resume task.
    $CodeIntegrityRecovery = Invoke-FailureCodeIntegrityRecovery -Reason $LauncherFailure

    Stop-LauncherTranscript
    [void](New-FailureEvidenceBundle -Reason $LauncherFailure -LauncherLog $TranscriptPath)
    Restore-InstallerRuntime

    if ($null -ne $CodeIntegrityRecovery -and $CodeIntegrityRecovery.RecoverySucceeded -and $CodeIntegrityRecovery.RebootRequired) {
        Write-Host ''
        Write-Host '[RECOVERY] Boot-integrity normalization requires one reboot.' -ForegroundColor Yellow
        Write-Host '[RECOVERY] No installer resume task is armed; the failed workflow will NOT automatically retry.' -ForegroundColor Yellow
        Write-Host '[REBOOT] Restarting Windows now so Test Signing/nointegritychecks changes take effect.' -ForegroundColor Cyan
        Restart-Computer -Force
        exit 1
    }
    if ($null -ne $CodeIntegrityRecovery -and -not $CodeIntegrityRecovery.RecoverySucceeded) {
        Write-Host '[ACTION] Automatic BCD recovery could not be proven. Do not rerun the installer until Test Signing and nointegritychecks are manually verified OFF.' -ForegroundColor Red
    }
    exit 1
}

$HoldCompletedResumeWindow=$false
$FinalState=Read-WorkflowState
if($Resume-and$null-ne$FinalState-and[string]$FinalState.Stage-eq'Complete'){
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ' LEGION GO AMD 26.7.1 - INSTALLATION COMPLETE' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green
    Write-WorkflowOverview -State $FinalState
    Write-ActivityProgress -Activity 'Overall workflow' -Percent 100 -Status 'COMPLETE' -Detail 'Driver, AMD Software, and persistence audit passed'
    Write-Host '[PASS] Driver, AMD Software, and final persistence audit completed.' -ForegroundColor Green
    Write-Host ("[INFO] Logs and rollback material remain under: {0}" -f $Script:WorkflowRoot)
    Write-Host '[INFO] This automatic post-sign-in window will stay open until you acknowledge it.'
    $HoldCompletedResumeWindow=$true
}
Stop-LauncherTranscript
Restore-InstallerRuntime
Write-Host ''
Write-Host '[INFO] Launcher session ended cleanly.'
Write-Host ("[INFO] Logs and rollback material remain under: {0}" -f $Script:WorkflowRoot)
if($HoldCompletedResumeWindow){[void](Read-Host 'Press Enter to close this completed installer window')}
exit 0
