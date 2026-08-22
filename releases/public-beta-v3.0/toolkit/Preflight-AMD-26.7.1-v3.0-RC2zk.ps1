#requires -Version 5.1
<##
Read-only package preflight for v3.0 RC2zk. This script reads release files,
parses PowerShell, and executes synthetic in-memory origin-classifier fixtures.
It does not require elevation and does not modify driver state, registry,
certificates, BCD, scheduled tasks, MSI/AppX packages, console settings, power
state, or workflow state.
##>
[CmdletBinding()]
param([string]$ResultPath='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$Checks=@()
function Check([string]$Name,[bool]$Pass,[string]$Detail){$script:Checks+=[pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail};if($Pass){Write-Host("[PASS] {0} :: {1}"-f$Name,$Detail)-ForegroundColor Green}else{Write-Host("[FAIL] {0} :: {1}"-f$Name,$Detail)-ForegroundColor Red}}
function Hash([string]$P){return(Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant()}
Write-Host '========================================================================'
Write-Host 'LEGION GO AMD 26.7.1 v3.0 RC2zk - READ-ONLY PACKAGE PREFLIGHT'
Write-Host '========================================================================'
$PreflightSelf=Get-Content -LiteralPath $PSCommandPath -Raw
$UnsafeStaticProbePattern = '\.(?:Contains|IndexOf)\("[^"\r\n]*(?<!`)\$[A-Za-z_][A-Za-z0-9_:]*'
Check 'STRICTMODE_STATIC_LITERAL_GUARD' (-not($PreflightSelf -match $UnsafeStaticProbePattern)) 'Preflight static Contains()/IndexOf() probes must not interpolate unescaped $variables anywhere inside double-quoted literals under StrictMode.'
$IllegalControlHits=@()
$TextExtensions=@('.ps1','.cmd','.txt','.md','.json')
foreach($TextFile in @(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { $TextExtensions -contains $_.Extension.ToLowerInvariant() })) {
    $Bytes=[IO.File]::ReadAllBytes($TextFile.FullName)
    for($ByteIndex=0;$ByteIndex -lt $Bytes.Length;$ByteIndex++) {
        $ByteValue=[int]$Bytes[$ByteIndex]
        if($ByteValue -lt 32 -and $ByteValue -notin @(9,10,13)) {
            $IllegalControlHits+=('{0}@{1}=0x{2:X2}' -f $TextFile.FullName,$ByteIndex,$ByteValue)
            break
        }
    }
}
$ControlDetail=if($IllegalControlHits.Count -eq 0){'No package text file contains ASCII control bytes other than TAB/CR/LF.'}else{($IllegalControlHits -join ' | ')}
Check 'NO_ILLEGAL_ASCII_CONTROL_CHARS' ($IllegalControlHits.Count -eq 0) $ControlDetail
$PsFiles=@(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse)
foreach($File in $PsFiles){
    $Tokens=$null
    $Errors=$null
    [Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors)|Out-Null
    $ParserDetail='Errors='+[string]$Errors.Count
    if($Errors.Count-gt0){
        $ParserParts=@()
        foreach($ParserError in $Errors){$ParserParts+=('Line {0}: {1}'-f$ParserError.Extent.StartLineNumber,$ParserError.Message)}
        $ParserDetail+=' :: '+($ParserParts-join' | ')
    }
    Check ('PARSER_'+$File.Name) ($Errors.Count-eq0) $ParserDetail
}
$Manifest=Join-Path $Root 'Internal\RC2-v2b-Unchanged-190.json'
try{
    $Rows=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8|ConvertFrom-Json
    if ($Rows -is [System.Array]) { $RowCount=$Rows.Length } else { $RowCount=@($Rows).Count }
    Check 'UNCHANGED_MANIFEST_COUNT' ($RowCount-eq190) ("Count=$RowCount")
    Check 'UNCHANGED_MANIFEST_SHA256' ((Hash $Manifest)-eq'C9B6BE9C990030B86BA4A33F0D5736A9E03BF38341B3218BD2653DC3CA246125') (Hash $Manifest)
}catch{Check 'UNCHANGED_MANIFEST' $false $_.Exception.Message}
$InfBuilderPath=Join-Path $Root 'Internal\Build-RC2-v2b-Inf.ps1'
$DatBuilderPath=Join-Path $Root 'Internal\Build-RC2-v2b-AmdGcfDat.ps1'
$InfBuilder=Get-Content -LiteralPath $InfBuilderPath -Raw
$DatBuilder=Get-Content -LiteralPath $DatBuilderPath -Raw
Check 'INF_BUILDER_FROZEN_FROM_RC2C' ((Hash $InfBuilderPath)-eq'89A0B08BAC44DF011EEB0EE06317E7FFF608DB15B8D17AAA328CB1EB01085117') (Hash $InfBuilderPath)
Check 'DAT_BUILDER_PS51_VARIABLE_COLLISION_FIX' ((Hash $DatBuilderPath)-eq'29C6296A6DA3FA56C9AFFF1F82A163D76411B7BB7B97C181E62910B4AA7EEB78') ((Hash $DatBuilderPath)+'; field-verified to reproduce DD7B2927...D766 under Windows PowerShell 5.1')
foreach($Token in @('4A6C871BDF2287398E8BFC23511BBA2408A47D7874E3C5C5DE0A1575E21E754F','A5FA34998C1B181A682727EB10EE18531EB2B5873AD8B40F0D104C6738ED0E83','9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409','LegionGo_26_7_1_Lenovo_Delta','ColorVibrance and RS overlay')){Check ('INF_CONTRACT_'+$Token.Substring(0,[Math]::Min(12,$Token.Length))) ($InfBuilder.Contains($Token)) $Token}
foreach($Token in @('D48791364C234736C54811EAE3708E0C6DB999B625F770350CAE9F4E02A3716D','DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766','26.10.35.01-260716a-202643C-AMD-Software-Adrenalin-Edition','ArgumentNullException("data")')){Check ('DAT_CONTRACT_'+$Token.Substring(0,[Math]::Min(12,$Token.Length))) ($DatBuilder.Contains($Token)) $Token}
$S1=Get-Content -LiteralPath (Join-Path $Root '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1') -Raw
$S2=Get-Content -LiteralPath (Join-Path $Root '02-Install-Driver-And-Verify-Normal-Signing.ps1') -Raw
$S3=Get-Content -LiteralPath (Join-Path $Root '03-Install-AMD-Software-And-Reboot.ps1') -Raw
$S4=Get-Content -LiteralPath (Join-Path $Root '04-Final-Persistence-Audit.ps1') -Raw
$Common=Get-Content -LiteralPath (Join-Path $Root 'Internal\Common.ps1') -Raw
$Launcher=Get-Content -LiteralPath (Join-Path $Root 'Install-LegionGo-AMD-26.7.1.ps1') -Raw
Check 'PREFLIGHT_ASSERTION_SOURCE_BUFFERS_LOADED' (-not [string]::IsNullOrWhiteSpace($S1) -and -not [string]::IsNullOrWhiteSpace($S2) -and -not [string]::IsNullOrWhiteSpace($S3) -and -not [string]::IsNullOrWhiteSpace($S4) -and -not [string]::IsNullOrWhiteSpace($Common) -and -not [string]::IsNullOrWhiteSpace($Launcher)) 'All script-source buffers referenced by source-dependent static assertions are loaded before those assertions execute.'
Check 'RC2ZK_ACTIVE_CATALOG_RESOLVED_FROM_INF' ($Common.Contains('function Get-CatalogFileNameFromInfLines') -and $Common.Contains('function Resolve-DriverStoreCatalogForPublishedInf') -and $S2.Contains('Resolve-DriverStoreCatalogForPublishedInf -PublishedInf ([string]$Gpu.ActiveINF)') -and -not $S2.Contains('Join-Path $StoreRoot ''u0202643.cat''')) 'Stage 2 resolves the active catalog declared by the active Driver Store INF instead of hardcoding the final AMD catalog name while inspecting OEM origins.'
Check 'RC2ZK_FINAL_AUDIT_CATALOG_RESOLVED_FROM_INF' ($S4.Contains('Resolve-DriverStoreCatalogForPublishedInf -PublishedInf $Gpu.ActiveINF') -and $S4.Contains('ACTIVE_CATALOG_NAME')) 'Final audit resolves the active catalog from the active INF and separately requires the final merged driver to declare u0202643.cat.'
Check 'RC2ZK_CATALOG_RESOLVER_FAIL_CLOSED' ($Common.Contains('Active Driver Store INF contains no applicable CatalogFile directive for x64 Windows.') -and $Common.Contains('Ambiguous CatalogFile directives for x64 Windows:') -and $Common.Contains('CatalogFile directive must name a catalog in the INF repository root.') -and $Common.Contains('Active display catalog declared by $InfPath is missing: $CatalogPath')) 'Catalog resolution fails closed on missing, ambiguous, non-root, non-CAT, or physically absent catalog declarations.'
Check 'RC2ZK_CATALOG_LINES_ALLOW_EMPTY_STRING' ($Common.Contains('[Parameter(Mandatory=$true)][AllowEmptyString()][string[]]$Lines')) 'Real INF files contain blank lines; the catalog resolver must allow empty-string elements from Get-Content under Windows PowerShell 5.1.'

try {
    . (Join-Path $Root 'Internal\Common.ps1')
    $CatalogGeneric = Get-CatalogFileNameFromInfLines -Lines @(
        '[Version]',
        'Signature="$WINDOWS NT$"',
        'CatalogFile = u0198040.cat'
    )
    Check 'RC2ZK_FIXTURE_OEM_GENERIC_CATALOG' ($CatalogGeneric -ieq 'u0198040.cat') 'A Lenovo-style generic CatalogFile directive resolves to its OEM catalog instead of u0202643.cat.'

    $CatalogBlankLines = Get-CatalogFileNameFromInfLines -Lines @(
        '',
        '[Version]',
        '',
        '; Lenovo-style spacing/comment',
        'Signature="$WINDOWS NT$"',
        '',
        'CatalogFile = u0198040.cat',
        ''
    )
    Check 'RC2ZK_FIXTURE_REAL_INF_BLANK_LINES_ACCEPTED' ($CatalogBlankLines -ieq 'u0198040.cat') 'A real-INF-shaped line array containing blank lines and comments must bind and resolve normally under Windows PowerShell 5.1.'

    $CatalogX64 = Get-CatalogFileNameFromInfLines -Lines @(
        '[Version]',
        'CatalogFile = generic.cat',
        'CatalogFile.NTamd64 = x64.cat',
        'CatalogFile.NTarm64 = arm64.cat'
    )
    Check 'RC2ZK_FIXTURE_X64_DECORATED_CATALOG_WINS' ($CatalogX64 -ieq 'x64.cat') 'CatalogFile.NTamd64 is authoritative over generic and incompatible-architecture declarations on x64 Windows.'

    $AmbiguousRejected = $false
    try {
        [void](Get-CatalogFileNameFromInfLines -Lines @(
            '[Version]',
            'CatalogFile.NTamd64 = first.cat',
            'CatalogFile.NTamd64.10.0 = second.cat'
        ))
    } catch {
        $AmbiguousRejected = $_.Exception.Message -match 'Ambiguous CatalogFile directives'
    }
    Check 'RC2ZK_FIXTURE_AMBIGUOUS_CATALOG_REJECTED' $AmbiguousRejected 'Conflicting equally authoritative x64 CatalogFile declarations are rejected rather than guessed.'

    $TraversalRejected = $false
    try {
        [void](Get-CatalogFileNameFromInfLines -Lines @(
            '[Version]',
            'CatalogFile = ..\evil.cat'
        ))
    } catch {
        $TraversalRejected = $_.Exception.Message -match 'repository root'
    }
    Check 'RC2ZK_FIXTURE_CATALOG_PATH_TRAVERSAL_REJECTED' $TraversalRejected 'CatalogFile path traversal/subdirectory values are rejected; only a catalog in the active INF repository root is accepted.'
}
catch {
    Check 'RC2ZK_CATALOG_RESOLVER_FIXTURE_EXECUTION' $false $_.Exception.Message
}

Check 'RC2ZK_FINAL_DRIVER_DAT_PATH_LITERAL' ($Common.Contains("Join-Path `$Root 'B026283\amdgcf.dat'") -and $Common.Contains("'active B026283\amdgcf.dat'")) 'Assert-FinalDriver uses a literal backslash path for B026283\amdgcf.dat and cannot contain the RC2zd BEL-character regression.'
Check 'RC2ZK_STAGE2_RECOVERY_EXITS_NONZERO' ($S2.Contains("Write-FailureGuide -Stage 'Stage 2 - driver replacement/recovery'") -and $S2.Contains("Set-StateProperty `$State 'RecoveryReason' `$Reason") -and $S2.Contains('        exit 1')) 'A destructive Stage 2 exception performs recovery and then exits nonzero explicitly instead of relying on a rethrow/process-exit interaction.'
Check 'RC2ZK_FAILURE_EVIDENCE_BUNDLE' ($Launcher.Contains('function New-FailureEvidenceBundle') -and $Launcher.Contains('RC2zk-Failure-Evidence-') -and $Launcher.Contains('Failure-Summary.txt') -and $Launcher.Contains('[void](New-FailureEvidenceBundle -Reason $LauncherFailure -LauncherLog $TranscriptPath)')) 'Hard launcher failures create a best-effort Downloads failure-evidence folder and ZIP even when Stage 4 was never reached.'

Check 'NO_FIXED_OEM0' (-not($S2-match '(?i)\boem0\.inf\b')) 'Stage 2 must discover published INF names live.'
Check 'NO_FIXED_OEM1' (-not($S2-match '(?i)\boem1\.inf\b')) 'Stage 2 must discover published INF names live.'
$AllText=@(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse|Where-Object{$_.FullName-ne$PSCommandPath}|ForEach-Object{Get-Content -LiteralPath $_.FullName -Raw})-join"`n"
Check 'NO_DEVELOPMENT_SIGNER_THUMBPRINT' (-not$AllText.Contains('A310E41F37E3E986DA9DACC7B442F0C92E4DD3DD')) 'Per-machine signer must be generated fresh.'
Check 'NO_OLD_RC1_ACTIVE_INF_CONTRACT' (-not$AllText.Contains('C240CB30D65257C2CD84329C283C37E1FD0F3D83F286408A759F3A88F903A33A')) 'Final v2b must replace RC1 identity.'
$ReleaseVersionWrite=$false
foreach($Line in @($AllText -split "`r?`n")){if($Line-match'(?i)(Set-ItemProperty|New-ItemProperty).*ReleaseVersion|\breg(?:\.exe)?\b.*ReleaseVersion'){$ReleaseVersionWrite=$true;break}}
Check 'NO_LIVE_RELEASEVERSION_WRITE' (-not$ReleaseVersionWrite) 'ReleaseVersion may be used only as package-build input; never written into the live registry.'
Check 'NO_DDU_AUTOMATION' (-not($AllText-match '(?i)display\s+driver\s+uninstaller|\bddU\b')) 'DDU support is intentionally deferred; RC2zk hardens portable-tool identity, scoped QuickEdit behavior, and reboot-resume orchestration only.'
Check 'PS51_MANIFEST_ENUMERATION' ($S1.Contains('function Get-UnchangedManifestRows') -and $S1.Contains('$Raw -is [System.Array]') -and $S1.Contains('$ManifestCount=[int]$Manifest.Length')) 'Stage 1 preserves the top-level JSON array under Windows PowerShell 5.1.'
Check 'NO_AUTOMATIC_MATCHES_ASSIGNMENT' (-not($AllText-match '(?im)^\s*\$Matches\s*=')) 'Workflow scripts must not overwrite automatic $Matches.'
Check 'NO_AUTOMATIC_ARGS_ASSIGNMENT' (-not($AllText-match '(?im)^\s*\$Args\s*=')) 'Workflow scripts must not overwrite automatic $Args.'
Check 'NO_AUTOMATIC_INPUT_ASSIGNMENT' (-not($AllText-match '(?im)^\s*\$Input\s*=')) 'Workflow scripts must not assign automatic $Input.'
Check 'CASE_INSENSITIVE_YN' ($Common.Contains('.ToUpperInvariant()') -and $Common.Contains("@('Y','YES')") -and $Common.Contains("@('N','NO')")) 'Y/YES and N/NO are accepted case-insensitively.'
Check 'INVALID_INPUT_FEEDBACK' ($Common.Contains('[INPUT]') -and $Common.Contains('Enter Y/YES or N/NO.')) 'Unexpected input is rejected and explicitly re-prompted.'
Check 'NO_DEFAULT_YES' (-not($Common-match '(?i)default.*yes|default\s*=\s*true')) 'No prompt silently defaults to Yes.'
Check 'RC2ZK_ONE_CLICK_CONSENT_PERSISTENCE' ($Common.Contains('$Script:InstallConsentPath = Join-Path $Script:WorkflowRoot ''one-click-consent.json''') -and $Common.Contains('AutomaticRebootsApproved=$true') -and $Common.Contains('Save-OneClickConsent') -and $Common.Contains('Remove-OneClickConsent')) 'The two initial confirmations are persisted only for the resumable RC2zk workflow and can be revoked on failure/completion.'
Check 'RC2ZK_SECURE_BOOT_FRONT_GATE' ($Launcher.Contains('Assert-OneClickSecureBootReady') -and $Launcher.Contains('[BLOCKED] Secure Boot is currently ENABLED.') -and $Launcher.Contains('UEFI Firmware Settings') -and $S1.Contains('Secure Boot is enabled') -and $S2.Contains('$SecureBootNow=Get-SecureBootState') -and $S4.Contains('SECURE_BOOT_DISABLED_FOR_LOCAL_SIGNER')) 'Secure Boot is checked before managed consent, rechecked before the driver transaction, and audited at the end; enabled/unknown states fail closed.'
Check 'RC2ZK_LITERAL_PROGRESS_FRAMEWORK' ($Common.Contains('function Get-ConsoleProgressBar') -and $Common.Contains('function Write-ActivityProgress') -and $Common.Contains('function Write-IndeterminateActivityProgress') -and $Common.Contains('[TASK]     ') -and $Launcher.Contains('Read-only package/parser preflight') -and $S1.Contains('190 AMD-unchanged files') -and $S2.Contains('Stage 2 frozen 190-file guard') -and $S3.Contains('Verify seven AMD runtime files') -and $S3.Contains('Verify AMD runtime SHA-256: ') -and $S4.Contains('Final audit runtime SHA-256: ') -and $S4.Contains('$ExpectedAuditCheckCount=64')) 'Every major logical step has a task-local progress lifecycle; determinate work uses real percentages and indeterminate Windows queries use a moving activity bar.'
Check 'RC2ZK_OFFICIAL_INSTALLER_HASH_PROGRESS' ($Common.Contains('function Get-SHA256WithProgress') -and $Common.Contains("-Activity 'Verify official AMD 26.7.1 installer SHA-256'")) 'The ~890 MB official installer hash no longer creates an unreported white-time interval.'
Check 'RC2ZK_BACKGROUND_LIVENESS_WATCHDOG' ($Common.Contains('public static class LegionGoConsoleLivenessRC2zk') -and $Common.Contains('new Timer(Tick, null, 500, 500)') -and $Common.Contains('[LIVE]     ') -and $Common.Contains('STILL WORKING') -and $Common.Contains('Configure(2000,2000)')) 'A separate .NET ThreadPool timer can repaint liveness every ~2 seconds even while the PowerShell runspace is blocked in a synchronous call.'
Check 'RC2ZK_LIVENESS_DOES_NOT_FAKE_PERCENT' ($Common.Contains('last checkpoint: ') -and $Common.Contains('current: ') -and $Common.Contains('Percent = Math.Max(0, Math.Min(100, percent))') -and $Common.Contains('Set-ActivityLivenessContext')) 'The watchdog repeats the last real percentage and elapsed time; it does not advance determinate percentage based on wall-clock time.'
Check 'RC2ZK_190_FILE_CURRENT_ITEM_LIVENESS' ($S1.Contains('Set-ActivityLivenessContext -Activity $Label') -and $S1.Contains('file {0}/{1}: {2} ({3:N1} MB)') -and $S2.Contains("Set-ActivityLivenessContext -Activity 'Stage 2 frozen 190-file guard'")) 'Long 190-file guards expose the exact file/size currently being hashed while the outer real percentage remains authoritative.'
Check 'RC2ZK_POST_BIND_LIVENESS' ($Common.Contains('$BindActivity=''Explicit Legion Go GPU bind''') -and $Common.Contains('Set-ActivityLivenessContext -Activity $BindActivity -Status ''BINDING''') -and $S2.Contains('Allow PnP state to settle after GPU bind') -and $S2.Contains('Query live Legion Go GPU binding after bind') -and $S2.Contains('Verify active Driver Store identities after GPU bind') -and $S2.Contains('Resolve and verify active Driver Store catalog') -and $S2.Contains('Enumerate AMD Display Driver Store inventory after bind')) 'The post-bind path has explicit task-local liveness for the blocking native bind, PnP settle countdown, GPU rediscovery, active Driver Store validation, catalog verification, and inventory.'
Check 'RC2ZK_FINAL_AUDIT_LIVENESS_CONTEXT' ($S4.Contains("Set-ActivityLivenessContext -Activity 'Final persistence audit'") -and $S4.Contains('Windows Authenticode validation for active display catalog') -and $S4.Contains('enumerate AMD Display packages with Get-WindowsDriver -Online -All')) 'Final audit keeps a continuously updating elapsed/liveness signal between completed percentage checkpoints and names its slow catalog/inventory sub-operations.'
Check 'RC2ZK_OVERALL_SEPARATE_FROM_TASK_LIVENESS' ($Common.Contains('[OVERALL] Stage {0}/4 :: {1}') -and $Common.Contains('[TASK]     ') -and -not $Common.Contains("Write-ActivityProgress -Activity ('Overall workflow - Stage '") -and -not $Common.Contains('$Script:CurrentSectionActivity')) 'Overall stage position is informational only and never becomes the task/liveness percentage.'
Check 'RC2ZK_SECTION_HEADINGS_NOT_PROGRESS_TASKS' ($Common.Contains('$Script:CurrentSectionTitle') -and $Common.Contains('[SECTION PASS]') -and -not $Common.Contains('$Script:CurrentSectionActivity')) 'Section headings no longer create synthetic 0% tasks that can be repeated by the watchdog.'
Check 'RC2ZK_ACTIVE_CATALOG_LOCAL_PHASES' ($S2.Contains('Write-ActivityProgress -Activity $CatalogActivity -Percent 20 -Status ''RESOLVING''') -and $S2.Contains('Write-ActivityProgress -Activity $CatalogActivity -Percent 50 -Status ''HASHING''') -and $S2.Contains('Write-ActivityProgress -Activity $CatalogActivity -Percent 75 -Status ''SIGNATURE''') -and $S2.Contains('Assert-ExpectedActiveCatalog -State $State -Gpu $Post -Identity $ActiveCatalog')) 'Active-catalog work now shows visible local phase progress and reuses the already-proven identity instead of immediately repeating the same catalog query.'
Check 'RC2ZK_DRIVERSTORE_QUERIES_INDETERMINATE' ($S2.Contains("Write-IndeterminateActivityProgress -Activity 'Enumerate AMD Display Driver Store inventory after bind'") -and $S2.Contains("Write-IndeterminateActivityProgress -Activity 'Enumerate AMD Display Driver Store after staging candidate'") -and $S2.Contains("Write-IndeterminateActivityProgress -Activity 'Query current Legion Go GPU state before driver transaction'")) 'Windows/Driver Store operations without a measurable completion fraction are presented as ACTIVE rather than fake 0-to-100 percentages.'
Check 'RC2ZK_ASSERT_FINAL_DRIVER_LOCAL_PROGRESS' ($Common.Contains('Write-ActivityProgress -Activity $Activity -Percent 40 -Status ''RESOLVING''') -and $Common.Contains('Write-ActivityProgress -Activity $Activity -Percent 70 -Status ''RESOLVED''') -and $Common.Contains('Write-ActivityProgress -Activity $Activity -Percent 80 -Status ''HASHING''')) 'Exact-driver validation exposes its own Driver Store resolve/DAT-hash phases instead of leaving stale prior-task liveness on screen.'
Check 'RC2ZK_STAGE3_LOCAL_SOFTWARE_SEAL_PROGRESS' ($S3.Contains("Verify AMD Settings MSI registration") -and $S3.Contains("Verify AMD DVR MSI registration") -and $S3.Contains("Verify native RSXCM 22.10.0.0 registration") -and $S3.Contains("Verify AMD startup tasks") -and $S3.Contains("Verify legacy Radeon Store AppX is absent") -and $S3.Contains("Query Legion Go GPU for pre-reboot software seal")) 'AMD Software validation and the pre-reboot software seal are decomposed into task-local checks rather than inheriting a Stage 3 50% or section 0% heartbeat.'
Check 'CONTEXTUAL_HEARTBEAT' ($Common.Contains('Write-IndeterminateActivityProgress') -and $Common.Contains('PID {0}') -and $Common.Contains('Format-Elapsed') -and $Common.Contains('Complete-ActivityProgress')) 'Long native processes show a moving activity bar, PID, elapsed time, and explicit completion.'
Check 'NO_SILENT_START_PROCESS_WAIT' (-not($AllText-match '(?i)Start-Process[^\r\n]*-Wait')) 'No long native operation uses silent Start-Process -Wait.'
Check 'SCOPED_QUICKEDIT_PROTECTION' ($Common.Contains('Enter-ConsoleSelectionProtection') -and $Common.Contains('Exit-ConsoleSelectionProtection') -and $Common.Contains('Restore-ConsoleSelectionForInteraction') -and $Common.Contains('Text selection restored.')) 'Mouse selection remains available at prompts and is disabled only during long-running operations.'
Check 'SLEEP_PREVENTION' ($Common.Contains('SetThreadExecutionState') -and $Common.Contains("80000001")) 'Installer requests system-awake state while active.'
Check 'TIME_GUIDANCE' ($Common.Contains('[TIME]') -and $S1.Contains('-Estimate') -and $S2.Contains('-Estimate') -and $S3.Contains('-Estimate')) 'Dependency, change, and reboot actions retain broad time guidance in both managed and standalone modes.'
Check 'REMEDIATION_GUIDE' ($Common.Contains('Write-FailureGuide') -and $Common.Contains('7-zip.org') -and $Common.Contains('Microsoft.Windows.WDK.x64') -and $Common.Contains('Microsoft.Windows.SDK.BuildTools')) 'Common failure output provides official remediation paths for the lightweight dependencies.'
Check 'ROLLBACK_STATUS_OUTPUT' ($S2.Contains('Previous display origin restore') -and $S2.Contains('Lenovo extension restore') -and $S2.Contains('RecoveryGpuState')) 'Rollback reports origin-agnostic base restoration, Lenovo-extension restoration when applicable, and the observed recovery GPU state.'
Check 'INTERRUPTED_TRANSACTION_CHECKPOINT' ($S2.Contains("'DriverTransactionInProgress'") -and $S2.Contains('Invoke-BestEffortRollback') -and $S2.Contains("'RecoveredAfterInterruption'")) 'Stage 2 checkpoints destructive work before deletion and enters rollback recovery after an interrupted transaction.'
Check 'PRE_REBOOT_DRIVER_CHECKPOINT' ($S2.Contains("'DriverInstalledPreReboot'") -and $S2.Contains("'BootTimeAtDriverInstalled'") -and $S2.Contains('destructive replacement will not be repeated')) 'A verified installed-driver checkpoint can resume without repeating the target binding.'
Check 'PNP_QUIESCENCE_BEFORE_RECOVERY' ($S2.Contains('Wait-ForPnPQuiescence') -and $S2.Contains("Get-Process -Name 'pnputil'")) 'Interruption recovery waits for an orphaned/in-flight pnputil process instead of racing it.'
Check 'ATOMIC_STATE_BACKUP' ($Common.Contains('[IO.File]::Replace') -and $Common.Contains("`$LiteralPath + '.bak'") -and $Common.Contains('Falling back to the previous atomic workflow-state backup')) 'Workflow state keeps a previous-version backup and can fall back if the primary JSON is unreadable.'
Check 'ORPHAN_PRIVATE_SIGNER_CLEANUP' ($S1.Contains('Remove-OrphanPrivateSigners') -and $S1.Contains("Cert:\LocalMachine\My")) 'Stage 1 removes orphaned RC2zk private signing certificates left by an interrupted signing session.'
Check 'ONE_COMMAND_LAUNCHER_PRESENT' ($Launcher.Contains('ONE-COMMAND INSTALLER') -and $Launcher.Contains('Invoke-StageProcess')) 'Public launcher orchestrates the four auditable stages.'
Check 'PREFLIGHT_PROCESS_ISOLATION' ($Launcher.Contains('Start-Process -FilePath $PowerShellExe -ArgumentList $ArgLine -PassThru -NoNewWindow') -and $Launcher.Contains('$PreflightProcess.ExitCode') -and -not $Launcher.Contains('$PreflightOutput = @(& $PowerShellExe')) 'Preflight stdout/stderr cannot contaminate launcher return values; only a scalar child-process exit code is consumed.'
Check 'PREFLIGHT_RESULT_CONTRACT' ($Launcher.Contains('Preflight result contract') -and $Launcher.Contains('ResultPath') -and $PreflightSelf.Contains('param([string]$ResultPath='''')')) 'Launcher independently requires a JSON PASS contract; a misleading process exit code cannot override FailedChecks.'
Check 'STAGE_CHECKPOINT_TRANSITION_GUARD' ($Launcher.Contains('Stage returned exit code 0 but the workflow checkpoint did not advance as required') -and $Launcher.Contains('Get-ExpectedSuccessCheckpoint')) 'A child process cannot be treated as successful unless its saved workflow checkpoint advanced to the expected state.'
Check 'QUIET_REPEAT_PREFLIGHT' ($Launcher.Contains('[switch]$QuietOnPass') -and $Launcher.Contains('Persistent/resume package integrity preflight passed.')) 'The full preflight prints once; persistent-copy/resume rechecks stay quiet unless they fail.'
Check 'PERSISTENT_TOOLKIT_SCALAR_GUARD' ($Launcher.Contains('$ToolkitRoot -is [System.Array]') -and $Launcher.Contains('Persistent toolkit root did not resolve to one scalar directory path')) 'Launcher rejects any future multi-object toolkit-root return before Join-Path or stage execution.'
Check 'STAGE_EXITCODE_PROCESS_ISOLATION' ($Launcher.Contains('Start-Process -FilePath $PowerShellExe') -and $Launcher.Contains('$StageProcess.ExitCode') -and -not $Launcher.Contains('& $PowerShellExe @ChildArgs')) 'Stage stdout/stderr remains live on the console while only a scalar process exit code returns to the launcher.'
Check 'MANAGED_DEPENDENCY_AUTHORIZATION' ($Common.Contains("Confirm-ManagedOrInteractive -Prompt 'Prepare all required dependencies now?'") -and -not $Common.Contains('7-Zip is missing. Install 7-Zip with winget now?') -and -not $Common.Contains('Install the validated 10.0.28000 packages with winget?')) 'Managed one-click mode authorizes dependency preparation from the two initial confirmations without another Y/N prompt.'
Check 'SEVENZIP_X64_PIN' ($Common.Contains("'7zip.7zip','-e','--architecture','x64'")) '7-Zip acquisition is explicitly pinned to x64.'
Check 'PORTABLE_WDK_X64_NUGET' ($Common.Contains('Microsoft.Windows.WDK.x64') -and $Common.Contains('10.0.28000.2526') -and $Common.Contains('WindowsKits-Portable')) 'Inf2Cat is acquired from the Microsoft x64 WDK NuGet package into a toolkit-local cache.'
Check 'PORTABLE_SDK_BUILDTOOLS_NUGET' ($Common.Contains('Microsoft.Windows.SDK.BuildTools') -and $Common.Contains('api/v2/package/Microsoft.Windows.SDK.BuildTools')) 'SignTool is acquired from Microsoft SDK BuildTools NuGet without a full SDK installation.'
Check 'NO_FULL_SDK_WDK_INSTALL' (-not($Common.Contains("winget','install','--id','Microsoft.WindowsSDK.10.0.28000")) -and -not($Common.Contains("winget','install','--id','Microsoft.WindowsWDK.10.0.28000"))) 'RC2zk never installs the full Windows SDK/WDK packages.'
Check 'REAL_DOWNLOAD_PROGRESS' ($Common.Contains('ContentLength') -and $Common.Contains("-Status 'DOWNLOADING'") -and $Common.Contains('Write-ActivityProgress') -and $Common.Contains('MB')) 'Portable NuGet downloads report actual transferred bytes and Content-Length percentage through the literal progress bar.' 
Check 'PINNED_PORTABLE_TOOL_IDENTITY' ($Common.Contains('82C302FC9069783674B51665CE80E769F8500DB7FC737A4B8A3773C521950B86') -and $Common.Contains('80972965E7FC311D293222B1A0E2C1BFB60F363239173964DBE2A71638314B9F') -and $Common.Contains('Test-PinnedInf2Cat') -and $Common.Contains('Test-PinnedSignTool')) 'Portable Inf2Cat/SignTool are accepted by exact observed SHA256 plus x64/product/signer identity.'
Check 'INF2CAT_UNKNOWNERROR_FAIL_CLOSED_EXCEPTION' ($Common.Contains("@('Valid','UnknownError')") -and $Common.Contains('Windows Internal Build Tools CodeSign') -and $Common.Contains('Microsoft Hardware Development Center')) 'Inf2Cat Authenticode UnknownError is accepted only behind exact pinned hash, x64 PE, product, and Microsoft signer guards.'
Check 'PINNED_NUGET_PACKAGE_HASHES' ($Common.Contains('63C939FB5A79295BF40E941DB592681272219B04EDFF095FE2F3D123E5579A90') -and $Common.Contains('A09A4C9D68160CED4765137A9A7444EA560EA86C45D6A77093DEA58C2F7563A0')) 'Exact NuGet package bytes from the successful RC2g download are pinned before extraction.'
Check 'PORTABLE_TOOL_SMOKE_TEST' ($Common.Contains('Assert-PortableKitToolExecution') -and $Common.Contains("Name='Inf2Cat'") -and $Common.Contains("Name='SignTool'") -and $Common.Contains('Activity ("Validating portable x64 {0}" -f $Spec.Name)') -and $Common.Contains('$Code -lt 0 -or $Code -gt 255')) 'Pinned tools are routed through the dynamic Inf2Cat/SignTool loader smoke test before any driver build uses them.'
Check 'INF2CAT_FIELD_PROVEN_DOTNET_TRANSPORT' ($Common.Contains('function Invoke-RawArgumentsProcessHeartbeat') -and $S1.Contains('$Inf2CatArguments=''/driver:"''+$PackageRoot+''" /os:10_X64 /verbose''') -and $S1.Contains('Invoke-RawArgumentsProcessHeartbeat -FilePath $Tools.Inf2Cat')) 'Inf2Cat uses the exact ProcessStartInfo raw-argument transport field-proven to create the catalog with /os:10_X64.'
Check 'INF2CAT_EXIT0_FAIL_CLOSED' ($S1.Contains('Parameter format not correct') -and $S1.Contains('Signability test failed') -and $S1.Contains('Errors:\s*None') -and $S1.Contains('Warnings:\s*None') -and $S1.Contains('Inf2Cat did not create u0202643.cat.')) 'Inf2Cat exit code 0 alone is rejected; normal parameter/signability output and physical CAT creation are all required.'
Check 'AMD_COMPANION_CATALOG_PRESERVATION' ($S1.Contains('Restore-OriginalAmdCompanionCatalogs') -and $S1.Contains('amdafd\amdafd.cat') -and $S1.Contains('amdxe\amdxe.cat') -and $S1.Contains('PreservedAmdCompanionCatalogs')) 'All nine field-observed companion catalogs are restored from the verified official AMD source after Inf2Cat.'
Check 'COMPANION_NO_FALSE_AMD_CERT_SUBJECT_REQUIREMENT' (-not($S1.Contains("SignerCertificate.Subject-notmatch'(?i)Advanced Micro Devices'")) -and $S1.Contains('AMD is the package vendor, not the')) 'Official AMD-shipped WHQL catalogs are not rejected merely because the signing certificate subject is Microsoft Windows Hardware Compatibility Publisher.'
Check 'COMPANION_KERNEL_POLICY_CAT_VERIFY' ($S1.Contains('& $SignToolPath verify /kp /v $Dst') -and $S1.Contains('failed SignTool kernel-policy verification')) 'Every restored companion catalog must pass SignTool kernel-policy verification.'
Check 'COMPANION_KERNEL_POLICY_INF_MEMBERSHIP' ($S1.Contains('& $SignToolPath verify /kp /v /c $Dst $InfDst') -and $S1.Contains('failed INF membership verification')) 'Every restored companion INF must verify as a member of its exact restored catalog under kernel policy.'
Check 'COMPANION_FIELD_CALIBRATION_CONTRACT' ($S1.Contains('Field calibration on 2026-08-19 proved all nine exact official') -and $S1.Contains('Microsoft Windows Hardware') -and $S1.Contains('SignTool /kp CAT=PASS; /kp INF membership=PASS')) 'RC2zk encodes the field-proven Microsoft WHCP result without weakening exact-hash or kernel-policy validation.'
Check 'POST_INF2CAT_190_FILE_REHASH' ($S1.Contains("Post-Inf2Cat companion-catalog restoration guard") -and $S1.Contains('all 190 AMD-unchanged files match the frozen manifest')) 'Stage 1 re-hashes the entire 190-file unchanged manifest after Inf2Cat side effects are repaired.'
Check 'POST_SIGN_190_FILE_REHASH' ($S1.Contains('Post-sign final 190-file immutability guard')) 'Stage 1 re-hashes all 190 unchanged files again after locally signing only the main display catalog.'
Check 'PNP_AUTHENTICODE_CATALOG_VERIFY' ($S1.Contains('@(''verify'',''/pa'',''/v'',$CatPath)') -and $S1.Contains('@(''verify'',''/pa'',''/v'',''/c'',$CatPath')) 'Stage 1 verifies both the local catalog and display-INF membership under PnP Authenticode policy before Test Signing/reboot.'
Check 'STAGE2_PREDESTRUCTIVE_190_FILE_REHASH' ($S2.Contains('Assert-FrozenUnchangedPackage') -and $S2.Contains('Pre-destructive package guard: all 190 AMD-unchanged files')) 'Stage 2 repeats the frozen 190-file manifest guard after reboot before any destructive PnP operation.'
Check 'PNP_DEVICE_FIRST_GPU_DISCOVERY' ($Common.Contains('Get-PnpDevice -PresentOnly') -and $Common.Contains('original Legion Go GPU PCI function') -and -not $Common.Contains('Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { [string]$_.DeviceID -like')) 'GPU discovery is based on the physical PCI function so Microsoft Basic Display Adapter remains reportable.'
Check 'ORIGIN_CLASSIFICATION' ($Common.Contains("OriginKind = 'MicrosoftBasic'") -and $Common.Contains("OriginKind = 'ThirdPartyDisplay'") -and $Common.Contains("OriginKind = 'FinalCandidate'")) 'GPU state explicitly classifies Microsoft Basic, third-party display, and exact final candidate origins.'
Check 'MICROSOFT_BASIC_FIELD_PROVEN_DISPLAY_INF' ($Common.Contains('@(''display.inf'',''basicdisplay.inf'')') -and $Common.Contains('$Service -ieq ''BasicDisplay''') -and $Common.Contains('$Provider -match ''(?i)^Microsoft''')) 'Microsoft Basic classification follows the field-proven Windows binding: Microsoft provider + BasicDisplay service + display.inf, while retaining basicdisplay.inf compatibility.'
Check 'BASIC_PREFLIGHT_LITERAL_PROBES_PS51_SAFE' (-not($PreflightSelf -match '\.Contains\(\"\$(Service|Provider)\b')) 'Microsoft Basic static probes are literal-safe under Windows PowerShell 5.1 StrictMode and cannot evaluate unbound $Service/$Provider variables.'
Check 'BASICDISPLAY_NO_EXPORT' ($S2.Contains('Microsoft Basic Display Adapter is an in-box origin') -and $S2.Contains("CurrentOriginKind -eq 'MicrosoftBasic'") -and $S2.Contains("@('display.inf','basicdisplay.inf')")) 'Stage 2 never attempts pnputil /export-driver against either recognized Windows in-box Basic Display INF identity.'
Check 'BASICDISPLAY_NO_DELETE' ($S2.Contains('Microsoft Basic Display Adapter is an in-box binding; it is not deleted from Driver Store.')) 'Stage 2 does not attempt to delete the Windows in-box Basic Display package.'
Check 'BASICDISPLAY_PROVIDER_SERVICE_GUARD' ($S2.Contains("CurrentDriverProvider -notmatch '(?i)^Microsoft'") -and $S2.Contains("Gpu.Service -ine 'BasicDisplay'")) 'Stage 2 fails closed unless the Basic origin is actually Microsoft-provided and bound to the BasicDisplay service.'
Check 'BASICDISPLAY_ROLLBACK' ($S2.Contains('candidate removal + PnP rescan') -and $S2.Contains("PreviousOriginKind -eq 'MicrosoftBasic'") -and $S2.Contains("BasicGpu.OriginKind -eq 'MicrosoftBasic'")) 'A failed Basic-origin install rolls back by removing the candidate, rescanning, and proving Microsoft Basic is active again.'
Check 'ORIGIN_EVIDENCE_PERSISTED' ($S2.Contains("'PreviousOriginKind'") -and $S2.Contains("'PreviousDriverProvider'") -and $S2.Contains("'PreviousDriverVersion'")) 'The starting display origin is persisted in workflow evidence for regression certification.'
$ClassifierPath=Join-Path $Root 'Internal\Origin-Classifier.ps1'
$Classifier=Get-Content -LiteralPath $ClassifierPath -Raw
Check 'FUTUREPROOF_ORIGIN_CLASSIFIER_PRESENT' ($Classifier.Contains("'LegacyStandaloneExtension'") -and $Classifier.Contains("'MergedEmbedded'") -and $Classifier.Contains("'MergedEmbeddedWithStaleExtension'") -and $Classifier.Contains("'ThirdPartyDisplay'")) 'RC2zk integrates the reusable future-proof origin architecture classifier.'
Check 'FUTUREPROOF_ORIGIN_CLASSIFIER_USED' ($Common.Contains('Get-LegionGoOriginClassification') -and $S2.Contains('$OriginClassification = Get-LegionGoOriginClassification -Gpu $Gpu')) 'Stage 2 classifies the live origin before any driver transaction.'
Check 'FUTUREPROOF_ORIGIN_FIELDS_PERSISTED' ($S2.Contains("'PreviousOriginArchitecture'") -and $S2.Contains("'PreviousExtensionDisposition'") -and $S2.Contains("'PreviousGpuHealthPass'") -and $S2.Contains("'PreviousStandaloneExtensionVersionCoherent'")) 'Origin architecture, extension disposition, health, and semantic/version evidence are persisted for regression certification.'
Check 'RC2ZK_ACTIVE_DRIVER_VERSION_PASSED_TO_CLASSIFIER' ($Common.Contains('DriverVersion=[string]$Gpu.DriverVersion') -and $Classifier.Contains('$ActiveDriverVersion = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name ''DriverVersion'')') -and $Classifier.Contains('-ActiveDriverVersion $ActiveDriverVersion')) 'The live Legion Go display DriverVersion is explicitly passed into the reusable origin classifier.'
Check 'RC2ZK_LEGACY_EXTENSION_ACTIVE_DRIVER_AUTHORITY' ($Classifier.Contains('$ExtState.ActiveDriverVersionMatches') -and $Classifier.Contains('Standalone Lenovo extension DriverVer does not match the active AMD display DriverVersion.') -and -not $Classifier.Contains('Standalone Lenovo extension DriverVer does not match AMD CN DriverVersion and no verified embedded Lenovo semantics supersede it.')) 'Legacy Lenovo extension version coherence is authoritative against the active display DriverVersion, not Radeon Software CN metadata.'
Check 'RC2ZK_CN_METADATA_SUPPLEMENTAL' ($Classifier.Contains('CN metadata is supplemental for legacy-origin classification.') -and $Classifier.Contains('CN DriverVersion metadata is absent; legacy Lenovo extension coherence is validated against the active display DriverVersion.')) 'Missing or stale CN DriverVersion metadata can warn but cannot invalidate an otherwise coherent legacy OEM display+extension pair.'
Check 'RC2ZK_PUBLIC_2662_2664_PRIOR_TOOLKIT_ALLOWLIST' ($Common.Contains('39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E') -and $Common.Contains('32.0.31021.1015') -and $Common.Contains('73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034') -and $Common.Contains('32.0.31021.5001') -and $Common.Contains('$VerifiedPriorToolkitDisplayPass') -and $Common.Contains('-VerifiedPriorToolkitDisplayPass:$VerifiedPriorToolkitDisplayPass')) 'The public 26.6.2 and field-proven public 26.6.4 toolkit bases are recognized only by exact active-INF SHA256 plus exact DriverVersion.'
Check 'RC2ZK_PRIOR_TOOLKIT_EXTENSION_ARCHITECTURE' ($Classifier.Contains("OriginKind = 'VerifiedPriorToolkitWithStandaloneExtension'") -and $Classifier.Contains("ExtensionDisposition = 'ExportThenRemoveForMergedTarget'") -and $Classifier.Contains('expected public 26.6.2/26.6.4 architecture') -and $Classifier.Contains('required standalone Lenovo amduw23e extension is absent')) 'Exact prior public toolkit bases require their attached Lenovo extension; the expected cross-version DriverVer mismatch is accepted only for this architecture, then the extension is exported before the 26.7.1 merged transition removes it.'
Check 'RC2ZK_STAGE2_FAILED_CONTRACT_EXIT_NORMALIZATION' ($Launcher.Contains('$Code -eq 0 -and $Stage2ContractCode -eq 1 -and $Stage2ContractStatus -eq ''Failed''') -and $Launcher.Contains('Treating the child failure contract as authoritative.') -and $Launcher.Contains('$Stage2EffectiveCode = 1')) 'A fresh invocation-bound Stage-2 Failed/1 contract is authoritative over the field-observed process-exit-0 transport anomaly; non-failure mismatches remain fail-closed.'
Check 'RC2ZK_STAGE2_FAILURE_DETAIL_PROPAGATION' ($Launcher.Contains('$FailureContractPath = Join-Path $Script:WorkflowRoot ''stage2-result.json''') -and $Launcher.Contains('$ChildFailureDetail = [string]$FailureContract.Detail') -and $Launcher.Contains('Stage failed with exit code {0}: {1} :: {2}')) 'An authoritative Stage-2 Failed contract propagates its exact child detail into launcher failure evidence instead of collapsing to a generic stage-exit message.'

# Functional, read-only origin-classifier regression fixtures.
try {
    . (Join-Path $Root 'Internal\Origin-Classifier.ps1')

    $FixtureGpu=[pscustomobject]@{
        Status='OK'
        ProblemCode=0
        HasProblem=$false
        Provider='Advanced Micro Devices, Inc.'
        Service='amdkmdag'
        ActiveINF='oem51.inf'
        DriverVersion='32.0.23017.1001'
    }
    $FixtureExt=[pscustomobject]@{
        TargetsLegionGo=$true
        SemanticCompatible=$true
        Attached=$true
        DriverVersion='32.0.23017.1001'
    }
    $FixtureCnAbsent=[pscustomobject]@{DriverVersion=''}
    $FixtureCnMismatch=[pscustomobject]@{DriverVersion='99.99.99.99'}
    $FixtureExtensions=@($FixtureExt)
    $FixtureBadExt=[pscustomobject]@{
        TargetsLegionGo=$true
        SemanticCompatible=$true
        Attached=$true
        DriverVersion='32.0.99999.1'
    }

    $OemNoCn=Resolve-LegionGoAmdOrigin -Gpu $FixtureGpu -CnMetadata $FixtureCnAbsent -LenovoExtensions $FixtureExtensions -EmbeddedLenovoSemanticsPass:$false -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_CLEAN_OEM_CN_ABSENT_ACCEPTED' ([bool]$OemNoCn.OriginAcceptable -and [string]$OemNoCn.OriginKind -eq 'LegacyStandaloneExtension' -and [string]$OemNoCn.ExtensionDisposition -eq 'ExportThenRemove' -and [bool]$OemNoCn.StandaloneExtensionVersionCoherent) 'Exact clean-OEM shape with CN DriverVersion absent classifies LegacyStandaloneExtension / ExportThenRemove.'

    $OemStaleCn=Resolve-LegionGoAmdOrigin -Gpu $FixtureGpu -CnMetadata $FixtureCnMismatch -LenovoExtensions $FixtureExtensions -EmbeddedLenovoSemanticsPass:$false -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_STALE_CN_LIVE_COHERENT_ACCEPTED' ([bool]$OemStaleCn.OriginAcceptable -and [string]$OemStaleCn.OriginKind -eq 'LegacyStandaloneExtension' -and [bool]$OemStaleCn.StandaloneExtensionVersionCoherent -and (@($OemStaleCn.Warnings) -join ' ') -match 'supplemental') 'Stale CN metadata warns but does not override a matching live OEM display+extension pair.'

    $FixtureBadExtensions=@($FixtureBadExt)
    $OemBadLiveVersion=Resolve-LegionGoAmdOrigin -Gpu $FixtureGpu -CnMetadata $FixtureCnAbsent -LenovoExtensions $FixtureBadExtensions -EmbeddedLenovoSemanticsPass:$false -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_LIVE_VERSION_MISMATCH_REJECTED' (-not [bool]$OemBadLiveVersion.OriginAcceptable -and [string]$OemBadLiveVersion.OriginKind -eq 'InvalidStandaloneExtension' -and (@($OemBadLiveVersion.Reasons) -join ' ') -match 'active AMD display DriverVersion') 'A real active-display/extension DriverVersion mismatch remains fatal.'

    $Fixture2662Gpu=[pscustomobject]@{
        Status='OK'
        ProblemCode=0
        HasProblem=$false
        Provider='Advanced Micro Devices, Inc.'
        Service='amduw23g-201589-27e53637'
        ActiveINF='oem76.inf'
        DriverVersion='32.0.31021.1015'
    }
    $Fixture2664Gpu=[pscustomobject]@{
        Status='OK'
        ProblemCode=0
        HasProblem=$false
        Provider='Advanced Micro Devices, Inc.'
        Service='amduw23g-202082-805df935'
        ActiveINF='oem77.inf'
        DriverVersion='32.0.31021.5001'
    }
    $FixturePriorToolkitExt=[pscustomobject]@{
        TargetsLegionGo=$true
        SemanticCompatible=$true
        Attached=$true
        DriverVersion='32.0.23017.1001'
    }
    $FixturePriorToolkitExtensions=@($FixturePriorToolkitExt)

    $Prior2662=Resolve-LegionGoAmdOrigin -Gpu $Fixture2662Gpu -CnMetadata $FixtureCnAbsent -LenovoExtensions $FixturePriorToolkitExtensions -EmbeddedLenovoSemanticsPass:$false -VerifiedPriorToolkitDisplayPass:$true -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_PUBLIC_2662_STANDALONE_EXTENSION_ACCEPTED' ([bool]$Prior2662.OriginAcceptable -and [string]$Prior2662.OriginKind -eq 'VerifiedPriorToolkitWithStandaloneExtension' -and [string]$Prior2662.ExtensionDisposition -eq 'ExportThenRemoveForMergedTarget' -and -not [bool]$Prior2662.StandaloneExtensionVersionCoherent) 'Exact public 26.6.2 plus its intentionally retained Lenovo OEM-generation amduw23e classifies as a verified prior toolkit architecture.'

    $Prior2664=Resolve-LegionGoAmdOrigin -Gpu $Fixture2664Gpu -CnMetadata $FixtureCnAbsent -LenovoExtensions $FixturePriorToolkitExtensions -EmbeddedLenovoSemanticsPass:$false -VerifiedPriorToolkitDisplayPass:$true -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_PUBLIC_2664_STANDALONE_EXTENSION_ACCEPTED' ([bool]$Prior2664.OriginAcceptable -and [string]$Prior2664.OriginKind -eq 'VerifiedPriorToolkitWithStandaloneExtension' -and [string]$Prior2664.ExtensionDisposition -eq 'ExportThenRemoveForMergedTarget' -and -not [bool]$Prior2664.StandaloneExtensionVersionCoherent) 'Exact public 26.6.4 plus its intentionally retained Lenovo OEM-generation amduw23e classifies as a verified prior toolkit architecture.'

    $PriorMissingExt=Resolve-LegionGoAmdOrigin -Gpu $Fixture2664Gpu -CnMetadata $FixtureCnAbsent -LenovoExtensions @() -EmbeddedLenovoSemanticsPass:$false -VerifiedPriorToolkitDisplayPass:$true -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_PRIOR_TOOLKIT_MISSING_EXTENSION_REJECTED' (-not [bool]$PriorMissingExt.OriginAcceptable -and [string]$PriorMissingExt.OriginKind -eq 'InvalidPriorToolkitMissingExtension') 'An exact 26.6.2/26.6.4 toolkit base without its required standalone Lenovo extension is rejected rather than misclassified as a complete prior toolkit architecture.'

    $UnknownToolkitMismatch=Resolve-LegionGoAmdOrigin -Gpu $Fixture2664Gpu -CnMetadata $FixtureCnAbsent -LenovoExtensions $FixturePriorToolkitExtensions -EmbeddedLenovoSemanticsPass:$false -VerifiedPriorToolkitDisplayPass:$false -AllowGenericThirdPartyDisplay:$true
    Check 'RC2ZK_FIXTURE_UNKNOWN_AMD_EXTENSION_MISMATCH_REJECTED' (-not [bool]$UnknownToolkitMismatch.OriginAcceptable -and [string]$UnknownToolkitMismatch.OriginKind -eq 'InvalidStandaloneExtension') 'The prior-toolkit exception does not generalize to unknown AMD display origins; without the exact 26.6.2/26.6.4 allowlist, the same cross-version extension mismatch remains fatal.'
}
catch {
    Check 'RC2ZK_ORIGIN_FIXTURE_EXECUTION' $false $_.Exception.Message
}

Check 'RC2ZK_EXPLICIT_FORCE_BIND' ($Common.Contains('UpdateDriverForPlugAndPlayDevicesW') -and $Common.Contains('$Script:LegionGoHardwareId') -and $S2.Contains('Invoke-ForceBindLegionGoDriver -InfPath $CandidateInf')) 'RC2zk explicitly binds the exact candidate only to the original Legion Go hardware ID.'
Check 'RC2ZK_STAGE_BEFORE_BIND' ($S2.IndexOf("'stage-final-v2b'") -lt $S2.IndexOf('Invoke-ForceBindLegionGoDriver -InfPath $CandidateInf')) 'RC2zk stages the candidate before changing the live Legion Go binding.'
Check 'RC2ZK_RETAINS_PREVIOUS_DISPLAY' (-not $S2.Contains('''/delete-driver'',$CurrentPublishedInf') -and $S2.Contains('Previous display package retained in Driver Store')) 'The prior display package is retained as rollback material instead of deleted.'
Check 'RC2ZK_CURRENT_PUBLISHED_INF_PROBE_LITERAL_SAFE' (-not($PreflightSelf.Contains('Contains("''/delete-driver'',$CurrentPublishedInf")'))) 'The RC2r CurrentPublishedInf preflight regression is encoded as a non-interpolating literal in RC2zk.'

Check 'RC2ZK_NO_GLOBAL_DISPLAY_COUNT_GATE' (-not $S2.Contains('Post-transaction AMD Display package count is not exactly one') -and -not $S2.Contains('Expected exactly one AMD Display-class package')) 'Inactive AMD Display packages do not fail the target-device transaction.'
Check 'RC2ZK_FINAL_AUDIT_INVENTORY_ONLY' ((Get-Content -LiteralPath (Join-Path $Root '04-Final-Persistence-Audit.ps1') -Raw).Contains('AMD_DISPLAY_PACKAGE_INVENTORY') -and -not (Get-Content -LiteralPath (Join-Path $Root '04-Final-Persistence-Audit.ps1') -Raw).Contains('ONE_AMD_DISPLAY_PACKAGE')) 'Final audit records other AMD Display packages as inventory while the exact active Legion Go binding remains the hard contract.'
Check 'RC2ZK_ROLLBACK_REBIND' ($S2.Contains('PreviousOriginalInfPath') -and $S2.Contains('rollback-restage-previous-display') -and $S2.Contains('Invoke-ForceBindLegionGoDriver -InfPath $RestoreInf')) 'Third-party rollback force-binds the verified previous display INF without deleting the RC2zk candidate.'
Check 'RC2ZK_BASIC_ONLY_CANDIDATE_DELETE' ($S2.Contains('rollback-remove-candidate-basic-origin') -and $S2.Contains("PreviousOriginKind -eq 'MicrosoftBasic'")) 'Candidate deletion is reserved for Microsoft Basic rollback, where removal+rescan is the restoration mechanism.'
Check 'RC2ZK_HASPROBLEM_HEALTH' ($Common.Contains('HasProblem=') -and $Common.Contains('[bool]$Gpu.HasProblem')) 'Final GPU health requires Status OK, ProblemCode 0, and HasProblem false.'

Check 'STAGE3_OPTIONAL_UNINSTALL_PROPERTIES' ($S3.Contains('$Item.PSObject.Properties[''DisplayVersion'']') -and $S3.Contains('$Item.PSObject.Properties[''DisplayName'']') -and -not $S3.Contains('[string]$Item.DisplayVersion')) 'Stage 3 tolerates uninstall registry entries that omit DisplayName or DisplayVersion under StrictMode.'
Check 'RC2ZK_NO_TARGET_MSI_REPAIR_MODE' (-not $S3.Contains('REINSTALL=ALL') -and -not $S3.Contains('REINSTALLMODE=') -and $S3.Contains('RC2zk never invokes target-product MSI repair mode')) 'Stage 3 never repairs the exact target MSI products.'
Check 'RC2ZK_DIRTY_TARGET_FULL_UNINSTALL' ($S3.Contains('Remove-MsiProductVerified -ProductCode $ExpectedDvrProductCode -Name ''remove-dirty-target-dvr''') -and $S3.Contains('remains installed-local after full uninstall; refusing to continue')) 'A dirty exact DVR registration is fully removed and proved absent before fresh install.'
Check 'RC2ZK_FRESH_DVR_CIM_INSTALL' ($S3.Contains('Install-FreshMsiVerified -Path $Dvr -ProductCode $ExpectedDvrProductCode -ExpectedVersion $ExpectedDvrVersion -Name ''fresh-install-target-dvr'' -LaunchedFromCim') -and $S3.Contains('$MsiArguments += ''LAUNCHED_FROM_CIM=1''')) 'Fresh exact DVR install uses AMD LAUNCHED_FROM_CIM=1.'
Check 'RC2ZK_FRESH_DVR_CIM_PROBE_CONSISTENT' ($S3.Contains('$MsiArguments = @(''/i'',$Path)') -and $S3.Contains('if ($LaunchedFromCim) { $MsiArguments += ''LAUNCHED_FROM_CIM=1'' }') -and -not $S3.Contains('$Args += ''LAUNCHED_FROM_CIM=1''')) 'Stage 3 and its preflight agree on the non-automatic MSI argument variable used for the DVR CIM property.'

Check 'RC2ZK_VERBOSE_MSI_RESULT_CONTRACT' ($S3.Contains('@(''/L*v'',$VerboseLog)') -and $S3.Contains('MainEngineThread is returning') -and $S3.Contains('MSI engine result')) 'Every Stage 3 MSI operation emits verbose logging and cross-checks the MSI engine result against the process exit code.'
Check 'RC2ZK_PRE_REBOOT_SOFTWARE_SEAL' ($S3.Contains('Write-Section ''PRE-REBOOT SOFTWARE SEAL''') -and $S3.IndexOf('[void](Assert-InstalledSoftware)') -lt $S3.IndexOf('Set-StateProperty $State ''Stage'' ''AwaitingSoftwareReboot''')) 'The complete software/runtime seal runs before the reboot checkpoint is written.'
Check 'RC2ZK_HEALTHY_TARGET_RETAINED' ($S3.Contains('target MSIs will be retained without repair') -and $S3.Contains('Exact AMD DVR is already healthy; retained without MSI repair')) 'Healthy exact target MSI products are retained instead of needlessly reconfigured.'
Check 'RC2ZK_STAGE2_RESULT_CONTRACT' ($S2.Contains('stage2-result.json') -and $S2.Contains('LEGIONGO_STAGE_INVOCATION_ID') -and $S2.Contains('Write-Stage2Result') -and $Launcher.Contains('Stage 2 result contract agrees') -and $Launcher.Contains('Stage 2 process/result disagreement')) 'Stage 2 now has an invocation-bound child result contract; process exit, child status/detail, and checkpoint must agree.'
Check 'RC2ZK_STAGE2_REBOOT_COMMAND_MARKER' ($S2.Contains('Set-StateProperty $State ''DriverRebootCommandIssuedAt'' (Get-Date).ToString(''o'')') -and $S2.Contains('Set-StateProperty $State ''DriverRebootCommandIssuedAt'' ''''') -and $S2.Contains('Write-Stage2Result -Status ''RebootRequired'' -ExitCode 2')) 'Stage 2 records an explicit reboot-command marker and clears it before a later ReadyForInstall attempt.'
Check 'RC2ZK_STAGE2_REBOOT_EXIT_NORMALIZATION' ($Launcher.Contains('$Code -eq 0 -and $Stage2ContractCode -eq 2 -and $Stage2ContractStatus -eq ''RebootRequired''') -and $Launcher.Contains('$BoundaryCheckpoint -eq ''AwaitingNormalSigningReboot''') -and $Launcher.Contains('$BoundaryState.PSObject.Properties[''DriverRebootCommandIssuedAt'']') -and $Launcher.Contains('$Stage2EffectiveCode = 2') -and $Launcher.Contains('Stage 2 reboot handoff accepted')) 'Stage 2 shutdown exit normalization is limited to an invocation-bound RebootRequired contract at AwaitingNormalSigningReboot with an explicit reboot-command marker.'
Check 'RC2ZK_STAGE2_ZERO_EXIT_EXPECTED_CHECKPOINT' ($Launcher.Contains('''ReadyForInstall'' { if($StageFile -eq ''02-Install-Driver-And-Verify-Normal-Signing.ps1''){ return ''DriverComplete'' } }')) 'If Stage 2 ever legitimately returns zero from ReadyForInstall, the parent requires DriverComplete instead of reporting a blank expected checkpoint.'
Check 'RC2ZK_FAILURE_CODE_INTEGRITY_NORMALIZATION' ($Launcher.Contains('function Invoke-FailureCodeIntegrityRecovery') -and $Launcher.Contains('Get-TestSigningConfigured') -and $Launcher.Contains('Get-NoIntegrityChecksConfigured') -and $Launcher.Contains('& bcdedit.exe /set testsigning off') -and $Launcher.Contains('& bcdedit.exe /set nointegritychecks off') -and $Launcher.Contains('Failure recovery could not prove Test Signing and nointegritychecks are both configured off.')) 'Any hard launcher failure inspects BCD and, if needed, configures Test Signing and nointegritychecks OFF before recovery completes.'
Check 'RC2ZK_FAILURE_RECOVERY_REBOOT_NO_RETRY' ($Launcher.Contains('$CodeIntegrityRecovery.RecoverySucceeded -and $CodeIntegrityRecovery.RebootRequired') -and $Launcher.Contains('No installer resume task is armed; the failed workflow will NOT automatically retry.') -and $Launcher.Contains('Restart-Computer -Force')) 'A failure that normalizes BCD reboots only after resume-task removal and never automatically retries the failed installer.'
Check 'RC2ZK_FAILURE_EVIDENCE_INCLUDES_STAGE2' ($Launcher.Contains('@(''workflow-state.json'',''stage2-result.json'',''stage3-result.json'',''stage4-result.json'',''one-click-consent.json'')')) 'Failure evidence now preserves the Stage 2 invocation result contract when available.'
Check 'RC2ZK_STAGE3_RESULT_CONTRACT' ($S3.Contains('stage3-result.json') -and $S3.Contains('LEGIONGO_STAGE_INVOCATION_ID') -and $Launcher.Contains('Stage 3 result contract agrees') -and $Launcher.Contains('ExpectedInvocation=')) 'Stage 3 child exit, invocation-specific result contract, and launcher interpretation must agree.'
Check 'RC2ZK_STAGE3_REBOOT_COMMAND_MARKER' ($S3.Contains('Set-StateProperty $State ''SoftwareRebootCommandIssuedAt'' (Get-Date).ToString(''o'')') -and $S3.Contains('Set-StateProperty $State ''SoftwareRebootCommandIssuedAt'' ''''') -and $S3.Contains('Write-Stage3Result -Status ''RebootRequired'' -ExitCode 2')) 'Stage 3 records an explicit reboot-command marker immediately before the authorized automatic reboot and resets it before a later same-boot retry.'
Check 'RC2ZK_STAGE3_REBOOT_EXIT_NORMALIZATION' ($Launcher.Contains('$Code -eq 0 -and $ContractCode -eq 2 -and $ContractStatus -eq ''RebootRequired''') -and $Launcher.Contains('$BoundaryCheckpoint -eq ''AwaitingSoftwareReboot''') -and $Launcher.Contains('$BoundaryState.PSObject.Properties[''SoftwareRebootCommandIssuedAt'']') -and $Launcher.Contains('$EffectiveCode = 2') -and $Launcher.Contains('Stage 3 reboot handoff accepted')) 'The launcher narrowly normalizes the Windows shutdown race only for an invocation-bound Stage 3 RebootRequired contract at the saved software-reboot boundary with an explicit reboot-command marker.'
Check 'RC2ZK_STAGE3_REBOOT_MISMATCH_FAIL_CLOSED' ($Launcher.Contains('if (-not $NormalizedRebootShutdownExit)') -and $Launcher.Contains('throw "Stage 3 process/result disagreement. ProcessExit=$Code ContractExit=$ContractCode Status=$ContractStatus"')) 'All Stage 3 process/contract mismatches outside the exact reboot-shutdown exception still fail closed.'
Check 'RC2ZK_IDEMPOTENT_CATALOG_DISPOSITION' ($S2.Contains('RetainedPreexistingExactFinal') -and $S2.Contains('Stage1Candidate') -and $S2.Contains('ExpectedActiveCatalogSHA256') -and $S2.Contains('PreviousCatalogSHA256')) 'Stage 2 records whether Windows activated the new Stage 1 catalog or retained an already-installed exact-final catalog.'
Check 'RC2ZK_FINAL_AUDIT_EXPECTED_CATALOG' ($S4.Contains('ACTIVE_CATALOG_DISPOSITION') -and $S4.Contains('ACTIVE_CATALOG_EXPECTED_HASH') -and $S4.Contains('ACTIVE_CATALOG_SIGNER_TRUST_NO_PRIVATE_KEY') -and $S4.Contains('ACTIVE_CATALOG_INF_MEMBERSHIP') -and -not $S4.Contains('ACTIVE_CATALOG_MATCHES_STAGE1')) 'Final audit validates the catalog identity selected by Stage 2 instead of assuming an identical INF must replace an existing Driver Store catalog.'
Check 'RC2ZK_STAGE4_RESULT_CONTRACT' ($S4.Contains('stage4-result.json') -and $S4.Contains('Write-Stage4Result') -and $Launcher.Contains('Stage 4 result contract agrees') -and $Launcher.Contains('Stage 4 process/result disagreement')) 'Final audit pass/fail is bound to an invocation-specific result contract and cannot be converted into launcher success by an inconsistent process exit code.'
Check 'RC2ZK_EXACT_UNUSED_SIGNER_CLEANUP' ($Common.Contains('function Ensure-ExactPublicSignerTrustRemoved') -and $Common.Contains('Get-CertificateMatches -StorePath ''Cert:\LocalMachine\Root'' -Thumbprint $Thumbprint') -and $Common.Contains('Get-CertificateMatches -StorePath ''Cert:\LocalMachine\TrustedPublisher'' -Thumbprint $Thumbprint') -and $Common.Contains('Remove-Item -LiteralPath ([string]$Cert.PSPath)') -and $Common.Contains('Refusing to remove signer trust because the Stage 1 signer equals the expected active catalog signer.')) 'Unused current-run trust cleanup is restricted to the exact Stage 1 thumbprint and refuses to remove the retained active signer.'
Check 'RC2ZK_SIGNER_CLEANUP_RESUME_SAFE' ($S2.Contains('Apply-SignerTrustPolicy -State $State') -and $S2.Contains('Verified pre-reboot driver checkpoint saved before signer-trust policy') -and $S2.Contains("'UnusedStage1SignerRemoved'") -and $S2.Contains('Candidate catalog hash changed from the exact Stage 1 signed workspace.')) 'Stage 2 checkpoints active catalog identity before cleanup and can safely resume when the inactive candidate signer is already untrusted/absent.'
Check 'RC2ZK_UNUSED_SIGNER_FINAL_AUDIT' ($S4.Contains('STAGE1_SIGNER_TRUST_DISPOSITION') -and $S4.Contains('STAGE1_ACTIVE_SIGNER_RELATION') -and $S4.Contains('UNUSED_STAGE1_SIGNER_ABSENT') -and -not $S4.Contains('PUBLIC_SIGNER_TRUST_NO_PRIVATE_KEY')) 'Final audit distinguishes active signer trust from unused current-run signer absence.'
Check 'RC2ZK_FINAL_EVIDENCE_BUNDLE' ($Launcher.Contains('Prepare-FinalEvidenceContracts') -and $Launcher.Contains("'stage2-result.json'") -and $Launcher.Contains("'stage3-result.json'") -and $Launcher.Contains("'stage4-result.json'") -and $Launcher.Contains('Copy-RelevantLauncherEvidence') -and $Launcher.Contains("'Launcher-Logs'")) 'Launcher packages Stage 2/3/4 result contracts and the relevant launcher session logs into the Stage 4 evidence directory.'
Check 'RC2ZK_LAUNCHER_EVIDENCE_MARKERS' ($Launcher.Contains("'Stage 2 result contract agrees'") -and $Launcher.Contains("'Stage 3 result contract agrees'") -and $Launcher.Contains("'Stage 4 result contract agrees'") -and $Launcher.Contains("'One-command workflow marked complete.'") -and $Launcher.Contains("workflow returned to SoftwareComplete so Stage 4 can be safely rerun")) 'Evidence packaging requires Stage 2/3/4 parent-consumption markers and fails closed back to SoftwareComplete if final evidence cannot be completed.'
Check 'RC2ZK_COMBINED_TESTSIGN_REBOOT_GATE' ($S1.Contains("Enable temporary Windows Test Signing and restart Windows now?") -and $S1.Contains('Confirm-ManagedOrInteractive') -and $S1.Contains('Restart requested by the same consent gate that enabled Test Signing.') -and -not $S1.Contains("Enable temporary Windows Test Signing for the local catalog install?")) 'The Test Signing change and immediate reboot consume the already-recorded one-click authorization without adding another managed Y/N prompt.'

Check 'RC2ZK_LAUNCHER_RESULT_ERROR_FORMAT_SAFE' ($Launcher.Contains('catch { throw (''Stage 3 result contract is unreadable after process exit {0}: {1}'' -f $Code,$_.Exception.Message) }') -and -not $Launcher.Contains('process exit $Code:')) 'Launcher result-contract errors avoid the invalid expandable-string variable-colon form.'

Check 'RC2ZK_PS51_NO_FOREACH_PIPE' (-not ($S3 -match '(?m)^\s*\}\s*\|')) 'Stage 3 contains no Windows PowerShell 5.1 close-brace pipeline parser hazard.'
Check 'RC2ZK_STAGE3_NO_AUTOMATIC_ARGS_LOCAL' ($S3.Contains('$MsiArguments = @(') -and -not ($S3 -match '(?im)^\s*\$Args\s*=')) 'Stage 3 uses a normal local MSI argument variable and never assigns PowerShell automatic $Args.'


Check 'FINAL_RESUME_WINDOW_HOLD' ($Launcher.Contains('$HoldCompletedResumeWindow') -and $Launcher.Contains('Press Enter to close this completed installer window')) 'A successful automatic resume session remains visible for user acknowledgement instead of auto-closing immediately.'
Check 'NO_RAW_WORKFLOW_CHECKPOINT_UI' (-not($Launcher.Contains('Workflow checkpoint:')) -and $Launcher.Contains('Installation progress')) 'Internal workflow checkpoints remain in state/logs but are not exposed as confusing raw state names in the normal console.'
Check 'RESUME_USER_FACING_ACK' ($Launcher.Contains('Previous reboot completed. Resuming installation.')) 'A resumed session acknowledges the completed reboot without exposing internal checkpoint names.'
$PublicCmd=Get-Content -LiteralPath (Join-Path $Root 'Start-LegionGo-AMD-26.7.1.cmd') -Raw
Check 'PUBLIC_CMD_USES_VALIDATED_GATE' ($PublicCmd.Contains('Run-Validated-LegionGo-AMD-26.7.1-RC2zk.ps1') -and -not $PublicCmd.Contains('-File "%~dp0Install-LegionGo-AMD-26.7.1.ps1"')) 'The public CMD entrypoint goes through the independent parser gate.'
Check 'RC2Q_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2q\Tools\WindowsKits-Portable')) 'RC2zk can reuse the exact pinned portable Microsoft tool cache from the RC2q field run.'
Check 'RC2P_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2p\Tools\WindowsKits-Portable')) 'RC2zk can reuse the exact pinned portable Microsoft tool cache from the successful RC2p field run.'
Check 'RC2O_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2o\Tools\WindowsKits-Portable')) 'RC2zk can reuse an exact pinned RC2o portable Microsoft tool cache if present.'
Check 'RC2N_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2n\Tools\WindowsKits-Portable')) 'RC2zk can reuse an exact pinned RC2n portable Microsoft tool cache if present.'
Check 'RC2M_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2m\Tools\WindowsKits-Portable')) 'RC2zk can reuse the exact pinned portable Microsoft tool cache from the fully successful RC2m regression.'
Check 'RC2L_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2l\Tools\WindowsKits-Portable')) 'RC2zk can reuse the exact pinned portable Microsoft tool cache downloaded and smoke-validated in the RC2l field run.'
Check 'RC2K_PORTABLE_CACHE_REUSE' ($Common.Contains('C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2k\Tools\WindowsKits-Portable')) 'RC2zk can reuse the exact pinned portable Microsoft tool cache field-validated in RC2k.'
Check 'RC2E_MIGRATION_ONE_GATE' ($Common.Contains('Get-RC2eLegacyKitResidue') -and $Common.Contains('Remove-RC2eLegacyKitResidue')) 'Only exact full-kit packages proven by RC2e logs can be offered for migration cleanup, under the same dependency gate.'

Check 'PERSISTENT_TOOLKIT_COPY' ($Launcher.Contains("'Toolkit'") -and $Launcher.Contains('Initialize-PersistentToolkit')) 'Launcher persists its own small script set under ProgramData before reboot boundaries.'
Check 'INTERACTIVE_RESUME_TASK' ($Common.Contains('New-ScheduledTaskTrigger -AtLogOn') -and $Common.Contains('-LogonType Interactive') -and $Common.Contains('-RunLevel Highest')) 'One-shot resume task is interactive, elevated, and logon-triggered.'
Check 'RESUME_TASK_BATTERY_SAFE' ($Common.Contains('-AllowStartIfOnBatteries') -and $Common.Contains('-DontStopIfGoingOnBatteries')) 'Resume is not blocked merely because the handheld is on battery.'
Check 'RESUME_TASK_NOT_STARTWHENAVAILABLE' (-not $Common.Contains('-StartWhenAvailable')) 'AtLogOn task cannot immediately replay the already-active logon session via StartWhenAvailable.'
Check 'RESUME_TASK_BOUNDARY_ONLY' (-not $Launcher.Contains('Register-ResumeTask -LauncherPath') -and $S1.Contains('Arm-ManagedResumeTaskAtBoundary') -and $S2.Contains('Arm-ManagedResumeTaskAtBoundary') -and $S3.Contains('Arm-ManagedResumeTaskAtBoundary')) 'Resume task is armed only after a stage has reached a saved reboot boundary.'
Check 'RESUME_TASK_ONE_SHOT_CONSUME' ($Launcher.Contains('if ($Resume)') -and $Launcher.Contains('One-shot resume trigger consumed') -and $Common.Contains('Remove-ManagedResumeTask')) 'A resumed launcher removes its own trigger immediately so a later stage failure cannot loop.'
Check 'RESUME_REBOOT_BOUNDARY_GUARD' ($Launcher.Contains('Resume trigger fired before the saved reboot boundary was crossed') -and $Launcher.Contains('(Get-CurrentBootTime) -le $RecordedBoot')) 'Even an unexpectedly early resume trigger exits without running a stage until the saved boot-time boundary is crossed.'
Check 'RESUME_TASK_CLEANUP' ($Common.Contains('Unregister-ScheduledTask') -and $Launcher.Contains('Remove-ResumeTask')) 'One-shot task has explicit cleanup paths.'
Check 'BOUNDED_STAGE_ROUTING' ($Launcher.Contains('Invoke-RoutedStageOnce') -and $Launcher.Contains('Invoke-ExpectedSuccessorOnce') -and -not($Launcher -match 'while\s*\(\$true\)')) 'Launcher has no unbounded stage autoroute loop; at most one saved-checkpoint stage plus one expected successor runs per session.'
$LauncherYnCount=[regex]::Matches($Launcher,'Confirm-YesNo').Count
Check 'RC2ZK_PUBLIC_EXACTLY_TWO_YN' ($LauncherYnCount-eq2 -and $Launcher.Contains('This is a one-click installer that will install AMD graphics driver 26.7.1 on the Lenovo Legion Go. Proceed?') -and $Launcher.Contains('This installer will automatically restart your device as required and continue installation after each reboot.') -and -not $S1.Contains('Confirm-YesNo') -and -not $S2.Contains('Confirm-YesNo') -and -not $S3.Contains('Confirm-YesNo')) ("Public launcher Y/N call count={0}; managed stages contain no direct Confirm-YesNo calls." -f $LauncherYnCount)
Check 'RC2ZK_TWO_YN_AT_FRESH_RUN_FRONT' ($Launcher.IndexOf('    Assert-OneClickSecureBootReady') -lt $Launcher.IndexOf('    $ToolkitRoot = Initialize-PersistentToolkit') -and $Launcher.IndexOf('        if (-not (Request-OneClickConsent))') -lt $Launcher.IndexOf('    $ToolkitRoot = Initialize-PersistentToolkit') -and $Launcher.IndexOf('    $ToolkitRoot = Initialize-PersistentToolkit') -lt $Launcher.IndexOf("    if (`$InitialCheckpoint -eq 'NotStarted') { `$FirstRunInstaller = Resolve-ValidatedInstallerForFirstRun")) 'On a fresh run, Secure Boot is checked first, then the only two Y/N confirmations occur before the long full preflight/copy/installer-hash workflow begins.'
Check 'RC2ZK_AUTOMATIC_REBOOTS_AFTER_INITIAL_CONSENT' ($Common.Contains('function Confirm-ManagedOrInteractive') -and $Common.Contains('Test-OneClickConsent') -and $S1.Contains('Confirm-ManagedOrInteractive') -and $S2.Contains('Confirm-ManagedOrInteractive') -and $S3.Contains('Confirm-ManagedOrInteractive') -and $Common.Contains('AutomaticRebootsApproved=$true')) 'After the two initial confirmations, dependency/change gates and all workflow-required reboots are authorized automatically in managed mode.' 
Check 'USER_CANCEL_CLEANUP' ($Launcher.Contains('Installation was not started.') -and $Launcher.Contains('Remove-OneClickConsent') -and $Launcher.Contains('$Code -eq 3') -and $Launcher.Contains('No automatic retry will occur')) 'Declining either initial managed confirmation starts no installation; standalone/manual stage cancellation still pauses safely.'
# Release SHA manifest verification. SHA256SUMS intentionally excludes itself.
$SumPath=Join-Path $Root 'SHA256SUMS.txt'
if(Test-Path -LiteralPath $SumPath){foreach($Line in Get-Content -LiteralPath $SumPath){if([string]::IsNullOrWhiteSpace($Line)){continue};if($Line-notmatch '^([0-9A-F]{64})  (.+)$'){Check 'SHA256SUMS_FORMAT' $false $Line;continue};$Expected=$Matches[1];$Rel=$Matches[2];$Path=Join-Path $Root $Rel;try{Check ('SHA_'+$Rel) ((Hash $Path)-eq$Expected) $Expected}catch{Check ('SHA_'+$Rel) $false $_.Exception.Message}}}else{Check 'SHA256SUMS_PRESENT' $false 'missing'}
$Failed=@($Checks|Where-Object{-not$_.Pass})
Write-Host '========================================================================'
Write-Host("PREFLIGHT PASS: {0}"-f($Failed.Count-eq0))
Write-Host("Failed checks: {0}"-f$Failed.Count)
Write-Host 'Changes made: None'
Write-Host '========================================================================'
if(-not [string]::IsNullOrWhiteSpace($ResultPath)){
    $ResultObject=[ordered]@{Schema='LegionGo-RC2zk-PreflightResult-v1';Passed=($Failed.Count-eq0);FailedChecks=[int]$Failed.Count;Generated=(Get-Date).ToString('o')}
    $ResultObject|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
if($Failed.Count-ne0){exit 1}
