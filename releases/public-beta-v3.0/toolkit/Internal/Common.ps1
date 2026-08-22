#requires -Version 5.1

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Origin-Classifier.ps1')

$Script:LegionGoHardwarePrefix = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA'
$Script:LegionGoHardwareId = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$Script:ExpectedDriverVersion = '32.0.31035.1003'
$Script:ExpectedFinalInfSHA256 = '9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409'
$Script:ExpectedFinalDatSHA256 = 'DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766'
$Script:ExpectedKernelSHA256 = 'D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5'
$Script:KnownLegacyLenovoExtensionSHA256 = 'F878996CA167B472975CCABABFF694B719C972D39B60801FC06C346D6491F84C'
$Script:KnownPublic2662InfSHA256 = '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'
$Script:KnownPublic2662DriverVersion = '32.0.31021.1015'
$Script:KnownPublic2664InfSHA256 = '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'
$Script:KnownPublic2664DriverVersion = '32.0.31021.5001'
$Script:ExpectedInstallerLength = [int64]890916160
$Script:ExpectedInstallerSHA256 = '116C6269B7676C3E76F85A8CF0CAC82D7DF3E85051C0594E18B4B1EA41BE9E3D'
$Script:ExpectedInstallerVersion = '26.7.1.0'
$Script:ExpectedOfficialInfSHA256 = '4A6C871BDF2287398E8BFC23511BBA2408A47D7874E3C5C5DE0A1575E21E754F'
$Script:ExpectedOfficialDatSHA256 = 'D48791364C234736C54811EAE3708E0C6DB999B625F770350CAE9F4E02A3716D'
$Script:ExpectedOfficialCatalogSHA256 = '17DA791480D44652FF36626B7CA63E3CE9CAC8A82BF487ECE47ED854735B96A3'
$Script:ExpectedOfficialCcc2SHA256 = '777CB9E06E5B5913E8177E181E322953C28AE12B46F44D92D3BD5B22D6C5011A'
$Script:ExpectedOfficialCcc2Length = [int64]242682672
$Script:ExpectedOfficialSourceFileCount = 194
$Script:ExpectedUnsignedFileCount = 192
$Script:ExpectedSignedFileCount = 193
$Script:WorkflowRoot = 'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2zk'
$Script:WorkflowStatePath = Join-Path $Script:WorkflowRoot 'workflow-state.json'
$Script:InstallConsentPath = Join-Path $Script:WorkflowRoot 'one-click-consent.json'
$Script:ResumeTaskName = 'LegionGo-AMD-26.7.1-v3.0-RC2zk-Resume'
$Script:PortableKitVersion = '10.0.28000.2526'
$Script:ExpectedWdkNuGetSHA256 = '63C939FB5A79295BF40E941DB592681272219B04EDFF095FE2F3D123E5579A90'
$Script:ExpectedSdkBuildToolsNuGetSHA256 = 'A09A4C9D68160CED4765137A9A7444EA560EA86C45D6A77093DEA58C2F7563A0'
$Script:ExpectedInf2CatSHA256 = '82C302FC9069783674B51665CE80E769F8500DB7FC737A4B8A3773C521950B86'
$Script:ExpectedSignToolSHA256 = '80972965E7FC311D293222B1A0E2C1BFB60F363239173964DBE2A71638314B9F'
$Script:InstallerOriginalConsoleMode = $null
$Script:InstallerAwakeRequestActive = $false
$Script:QuickEditProtectionDepth = 0
$Script:QuickEditSpanRestoreMode = $null
$Script:QuickEditSpanChanged = $false
$Script:CurrentSectionTitle = ''

function Get-SHA256 {
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Required file is missing: $LiteralPath"
    }
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Get-SHA256WithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [string]$Activity='Hash file'
    )
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { throw "Required file is missing: $LiteralPath" }
    $Item=Get-Item -LiteralPath $LiteralPath
    $Total=[int64]$Item.Length
    $Stream=$null
    $Sha=$null
    try {
        $Stream=[IO.File]::Open($LiteralPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $Sha=[Security.Cryptography.SHA256]::Create()
        $Buffer=New-Object byte[] (4MB)
        [int64]$Done=0
        $LastConsole=-10
        Write-ActivityProgress -Activity $Activity -Percent 0 -Status 'HASHING' -Detail ("0 / {0:N1} MB" -f ($Total/1MB))
        while (($Read=$Stream.Read($Buffer,0,$Buffer.Length)) -gt 0) {
            [void]$Sha.TransformBlock($Buffer,0,$Read,$Buffer,0)
            $Done += [int64]$Read
            $Percent=if($Total-gt0){[int][Math]::Floor(($Done*100.0)/$Total)}else{100}
            try{Write-Progress -Activity $Activity -Status (("{0:N1} / {1:N1} MB" -f ($Done/1MB),($Total/1MB))) -PercentComplete $Percent}catch{}
            if($Percent-lt100-and$Percent-ge($LastConsole+10)){
                Write-ActivityProgress -Activity $Activity -Percent $Percent -Status 'HASHING' -Detail (("{0:N1} / {1:N1} MB" -f ($Done/1MB),($Total/1MB)))
                $LastConsole=$Percent
            }
        }
        [void]$Sha.TransformFinalBlock([byte[]]@(),0,0)
        $Hash=([BitConverter]::ToString($Sha.Hash)).Replace('-','').ToUpperInvariant()
        Complete-ActivityProgress -Activity $Activity -Detail ('SHA256 ' + $Hash)
        return $Hash
    }
    finally {
        if($null-ne$Stream){$Stream.Dispose()}
        if($null-ne$Sha){$Sha.Dispose()}
    }
}

function Get-ConsoleProgressBar {
    param(
        [int]$Percent = 0,
        [int]$Width = 28
    )
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $Filled = [int][Math]::Floor(($Percent / 100.0) * $Width)
    if ($Filled -gt $Width) { $Filled = $Width }
    $Empty = $Width - $Filled
    return ('[' + ('#' * $Filled) + ('-' * $Empty) + ']')
}

function Get-IndeterminateProgressBar {
    param(
        [int]$Tick = 0,
        [int]$Width = 28
    )
    if ($Width -lt 8) { $Width = 8 }
    $Span = 5
    $Travel = $Width - $Span
    if ($Travel -lt 1) { $Travel = 1 }
    $Offset = [Math]::Abs($Tick % (2 * $Travel))
    if ($Offset -gt $Travel) { $Offset = (2 * $Travel) - $Offset }
    $Chars = New-Object char[] $Width
    for ($I = 0; $I -lt $Width; $I++) { $Chars[$I] = '-' }
    for ($I = 0; $I -lt $Span; $I++) {
        $Index = $Offset + $I
        if ($Index -ge 0 -and $Index -lt $Width) { $Chars[$Index] = '#' }
    }
    return ('[' + (-join $Chars) + ']')
}

function Write-ActivityProgress {
    param(
        [Parameter(Mandatory=$true)][string]$Activity,
        [int]$Percent = 0,
        [string]$Status = 'WORKING',
        [string]$Detail = ''
    )
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $Bar = Get-ConsoleProgressBar -Percent $Percent
    $Line = ('[TASK]     {0} {1,3}% {2} :: {3}' -f $Bar,$Percent,$Status,$Activity)
    if (-not [string]::IsNullOrWhiteSpace($Detail)) { $Line += (' :: ' + $Detail) }
    try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Visible($Activity,$Percent,$Status,$Detail,$true) } } catch {}
    Write-Host $Line
    $ProgressStatus=$Status
    if (-not [string]::IsNullOrWhiteSpace($Detail)) { $ProgressStatus += (' - ' + $Detail) }
    try { Write-Progress -Activity $Activity -Status $ProgressStatus -PercentComplete $Percent } catch {}
}

function Write-IndeterminateActivityProgress {
    param(
        [Parameter(Mandatory=$true)][string]$Activity,
        [int]$Tick = 0,
        [string]$Elapsed = '',
        [string]$Detail = ''
    )
    $Bar = Get-IndeterminateProgressBar -Tick $Tick
    $Line = ('[TASK]     {0} ACTIVE :: {1}' -f $Bar,$Activity)
    if (-not [string]::IsNullOrWhiteSpace($Elapsed)) { $Line += (' :: elapsed ' + $Elapsed) }
    if (-not [string]::IsNullOrWhiteSpace($Detail)) { $Line += (' :: ' + $Detail) }
    try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Visible($Activity,0,'ACTIVE',$Detail,$false) } } catch {}
    Write-Host $Line
    $ProgressStatus='ACTIVE'
    if (-not [string]::IsNullOrWhiteSpace($Elapsed)) { $ProgressStatus += (' - elapsed ' + $Elapsed) }
    try { Write-Progress -Activity $Activity -Status $ProgressStatus } catch {}
}

function Complete-ActivityProgress {
    param([Parameter(Mandatory=$true)][string]$Activity,[string]$Detail='')
    Write-ActivityProgress -Activity $Activity -Percent 100 -Status 'PASS' -Detail $Detail
    try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Complete() } } catch {}
    try { Write-Progress -Activity $Activity -Completed } catch {}
}

function Set-ActivityLivenessContext {
    param(
        [Parameter(Mandatory=$true)][string]$Activity,
        [int]$Percent = 0,
        [string]$Status = 'WORKING',
        [string]$Detail = '',
        [switch]$Indeterminate
    )
    try {
        if ('LegionGoConsoleLivenessRC2zk' -as [type]) {
            [LegionGoConsoleLivenessRC2zk]::Context($Activity,$Percent,$Status,$Detail,(-not [bool]$Indeterminate))
        }
    } catch {}
}

function Wait-VisibleCountdown {
    param(
        [Parameter(Mandatory=$true)][int]$Seconds,
        [Parameter(Mandatory=$true)][string]$Activity,
        [string]$Detail = ''
    )
    if ($Seconds -le 0) { return }
    Write-ActivityProgress -Activity $Activity -Percent 0 -Status 'WAITING' -Detail $Detail
    for ($Remaining=$Seconds; $Remaining -gt 0; $Remaining--) {
        $Elapsed=$Seconds-$Remaining
        $Percent=[int][Math]::Floor(($Elapsed*100.0)/$Seconds)
        $ThisDetail=("{0}s remaining" -f $Remaining)
        if(-not [string]::IsNullOrWhiteSpace($Detail)){$ThisDetail+=' :: '+$Detail}
        Set-ActivityLivenessContext -Activity $Activity -Percent $Percent -Status 'WAITING' -Detail $ThisDetail
        Write-ActivityProgress -Activity $Activity -Percent $Percent -Status 'WAITING' -Detail ("{0}s remaining" -f $Remaining)
        Start-Sleep -Seconds 1
    }
    Complete-ActivityProgress -Activity $Activity -Detail 'wait complete'
}

function Complete-CurrentSection {
    param([string]$Detail='section complete')
    if (-not [string]::IsNullOrWhiteSpace($Script:CurrentSectionTitle)) {
        Write-Host ("[SECTION PASS] {0} :: {1}" -f $Script:CurrentSectionTitle,$Detail) -ForegroundColor DarkGreen
        $Script:CurrentSectionTitle=''
    }
}

function Write-Section {
    param([Parameter(Mandatory=$true)][string]$Title)
    Complete-CurrentSection
    Write-Host ''
    Write-Host '========================================================================'
    Write-Host $Title
    Write-Host '========================================================================'
    $Script:CurrentSectionTitle=$Title
}

function Confirm-YesNo {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [string]$Estimate = '',
        [string]$Impact = ''
    )
    Restore-ConsoleSelectionForInteraction
    try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Pause() } } catch {}
    if (-not [string]::IsNullOrWhiteSpace($Estimate)) { Write-Host ("[TIME] {0}" -f $Estimate) -ForegroundColor Cyan }
    if (-not [string]::IsNullOrWhiteSpace($Impact)) { Write-Host ("[INFO] {0}" -f $Impact) }
    try {
    while ($true) {
        $AnswerText = Read-Host ($Prompt + ' [Y/N]')
        if ($null -eq $AnswerText) { $AnswerText = '' }
        $AnswerText = ([string]$AnswerText).Trim().ToUpperInvariant()
        if ($AnswerText -in @('Y','YES')) { return $true }
        if ($AnswerText -in @('N','NO')) { return $false }
        $Shown = $AnswerText
        if ([string]::IsNullOrWhiteSpace($Shown)) { $Shown = '<blank>' }
        Write-Host ("[INPUT] '{0}' is not valid. Enter Y/YES or N/NO." -f $Shown) -ForegroundColor Yellow
    }
    } finally {
        try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Resume() } } catch {}
    }
}

function Read-OneClickConsent {
    if (-not (Test-Path -LiteralPath $Script:InstallConsentPath -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $Script:InstallConsentPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop) }
    catch { return $null }
}

function Test-OneClickConsent {
    $Consent = Read-OneClickConsent
    if ($null -eq $Consent) { return $false }
    return ([string]$Consent.Release -eq 'v3.0-RC2zk' -and [bool]$Consent.InstallApproved -and [bool]$Consent.AutomaticRebootsApproved)
}

function Save-OneClickConsent {
    New-Item -ItemType Directory -Path $Script:WorkflowRoot -Force | Out-Null
    $Consent = [ordered]@{
        Schema='LegionGo-AMD-26.7.1-RC2zk-OneClickConsent-v1'
        Release='v3.0-RC2zk'
        InstallApproved=$true
        AutomaticRebootsApproved=$true
        GrantedAt=(Get-Date).ToString('o')
    }
    Write-JsonAtomic -InputObject $Consent -LiteralPath $Script:InstallConsentPath -Depth 8
}

function Remove-OneClickConsent {
    Remove-Item -LiteralPath $Script:InstallConsentPath -Force -ErrorAction SilentlyContinue
}

function Confirm-ManagedOrInteractive {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [string]$Estimate='',
        [string]$Impact=''
    )
    if ($env:LEGIONGO_RC2I_MANAGED -eq '1') {
        if (-not (Test-OneClickConsent)) { throw ('Managed one-click authorization is missing before action: ' + $Prompt) }
        if (-not [string]::IsNullOrWhiteSpace($Estimate)) { Write-Host ('[TIME] ' + $Estimate) -ForegroundColor Cyan }
        if (-not [string]::IsNullOrWhiteSpace($Impact)) { Write-Host ('[INFO] ' + $Impact) }
        $AuthorizedAction = $Prompt.Trim()
        if ($AuthorizedAction.EndsWith('?')) { $AuthorizedAction = $AuthorizedAction.Substring(0,$AuthorizedAction.Length-1) }
        Write-Host ('[AUTO] Pre-authorized action: ' + $AuthorizedAction) -ForegroundColor Cyan
        return $true
    }
    return (Confirm-YesNo -Prompt $Prompt -Estimate $Estimate -Impact $Impact)
}

function Format-Elapsed {
    param([Parameter(Mandatory=$true)][TimeSpan]$Elapsed)
    if ($Elapsed.TotalHours -ge 1) { return ('{0:00}:{1:00}:{2:00}' -f [int]$Elapsed.TotalHours,$Elapsed.Minutes,$Elapsed.Seconds) }
    return ('{0:00}:{1:00}' -f [int]$Elapsed.TotalMinutes,$Elapsed.Seconds)
}

function Initialize-InstallerRuntime {
    param([string]$StageLabel = 'installer')
    if (-not ('LegionGoNativeMethodsRC2zk' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class LegionGoNativeMethodsRC2zk {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
}

public static class LegionGoConsoleLivenessRC2zk {
    private static readonly object Gate = new object();
    private static Timer Timer;
    private static bool Active;
    private static bool Paused;
    private static bool Determinate = true;
    private static bool DetailIsCurrent;
    private static string Activity = "";
    private static string Status = "";
    private static string Detail = "";
    private static int Percent;
    private static DateTime StartedUtc = DateTime.UtcNow;
    private static DateTime LastVisibleUtc = DateTime.UtcNow;
    private static DateTime LastHeartbeatUtc = DateTime.MinValue;
    private static int HeartbeatMilliseconds = 2000;
    private static int SilenceMilliseconds = 2000;

    public static void Configure(int heartbeatMilliseconds, int silenceMilliseconds) {
        lock (Gate) {
            HeartbeatMilliseconds = Math.Max(1000, heartbeatMilliseconds);
            SilenceMilliseconds = Math.Max(1000, silenceMilliseconds);
            if (Timer == null) Timer = new Timer(Tick, null, 500, 500);
        }
    }

    public static void Visible(string activity, int percent, string status, string detail, bool determinate) {
        lock (Gate) {
            DateTime now = DateTime.UtcNow;
            if (!String.Equals(Activity, activity, StringComparison.Ordinal)) StartedUtc = now;
            Activity = activity ?? "";
            Percent = Math.Max(0, Math.Min(100, percent));
            Status = status ?? "";
            Detail = detail ?? "";
            Determinate = determinate;
            DetailIsCurrent = false;
            Active = true;
            Paused = false;
            LastVisibleUtc = now;
            LastHeartbeatUtc = DateTime.MinValue;
        }
    }

    public static void Context(string activity, int percent, string status, string detail, bool determinate) {
        lock (Gate) {
            DateTime now = DateTime.UtcNow;
            if (!String.Equals(Activity, activity, StringComparison.Ordinal)) StartedUtc = now;
            Activity = activity ?? "";
            Percent = Math.Max(0, Math.Min(100, percent));
            Status = status ?? "";
            Detail = detail ?? "";
            Determinate = determinate;
            DetailIsCurrent = true;
            Active = true;
            Paused = false;
        }
    }

    public static void Complete() { lock (Gate) { Active = false; DetailIsCurrent = false; } }
    public static void Pause() { lock (Gate) { Paused = true; } }
    public static void Resume() { lock (Gate) { Paused = false; LastVisibleUtc = DateTime.UtcNow; LastHeartbeatUtc = DateTime.MinValue; } }
    public static void Stop() {
        lock (Gate) {
            Active = false;
            Paused = true;
            if (Timer != null) { try { Timer.Dispose(); } catch {} Timer = null; }
        }
    }

    private static string FormatElapsed(TimeSpan value) {
        if (value.TotalHours >= 1) return String.Format("{0:00}:{1:00}:{2:00}", (int)value.TotalHours, value.Minutes, value.Seconds);
        return String.Format("{0:00}:{1:00}", (int)value.TotalMinutes, value.Seconds);
    }

    private static string DeterminateBar(int percent, int width) {
        int filled = (int)Math.Floor((percent / 100.0) * width);
        filled = Math.Max(0, Math.Min(width, filled));
        return "[" + new String('#', filled) + new String('-', width - filled) + "]";
    }

    private static string MovingBar(TimeSpan elapsed, int width) {
        int span = 5;
        int travel = Math.Max(1, width - span);
        int raw = Math.Abs(((int)elapsed.TotalSeconds) % (2 * travel));
        int offset = raw > travel ? (2 * travel) - raw : raw;
        char[] chars = new String('-', width).ToCharArray();
        for (int i=0; i<span && (offset+i)<width; i++) chars[offset+i] = '#';
        return "[" + new String(chars) + "]";
    }

    private static void Tick(object state) {
        try {
            string activity, status, detail;
            int percent;
            bool determinate, detailIsCurrent;
            DateTime started;
            lock (Gate) {
                if (!Active || Paused || String.IsNullOrWhiteSpace(Activity)) return;
                DateTime now = DateTime.UtcNow;
                if ((now - LastVisibleUtc).TotalMilliseconds < SilenceMilliseconds) return;
                if (LastHeartbeatUtc != DateTime.MinValue && (now - LastHeartbeatUtc).TotalMilliseconds < HeartbeatMilliseconds) return;
                LastHeartbeatUtc = now;
                activity = Activity;
                status = Status;
                detail = Detail;
                percent = Percent;
                determinate = Determinate;
                detailIsCurrent = DetailIsCurrent;
                started = StartedUtc;
            }
            TimeSpan elapsed = DateTime.UtcNow - started;
            string bar = determinate ? DeterminateBar(percent, 28) : MovingBar(elapsed, 28);
            string marker = determinate ? String.Format("{0,3}%", percent) : "ACTIVE";
            string line = "[LIVE]     " + bar + " " + marker + " STILL WORKING :: " + activity + " :: elapsed " + FormatElapsed(elapsed);
            if (!String.IsNullOrWhiteSpace(status)) line += " :: " + status;
            if (!String.IsNullOrWhiteSpace(detail)) line += detailIsCurrent ? " :: current: " + detail : " :: last checkpoint: " + detail;
            try { Console.WriteLine(line); } catch {}
        } catch {}
    }
}
'@
    }
    try { [LegionGoConsoleLivenessRC2zk]::Configure(2000,2000) } catch {}
    try {
        $Handle = [LegionGoNativeMethodsRC2zk]::GetStdHandle(-10)
        $Mode = [uint32]0
        if ($Handle -ne [IntPtr]::Zero -and [LegionGoNativeMethodsRC2zk]::GetConsoleMode($Handle,[ref]$Mode)) {
            if ($null -eq $Script:InstallerOriginalConsoleMode) { $Script:InstallerOriginalConsoleMode = $Mode }
            if (($Mode -band [uint32]0x40) -ne 0) {
                Write-Host '[PASS] Text selection remains available at prompts; QuickEdit pause protection engages only during long operations.' -ForegroundColor Green
            } else {
                Write-Host '[INFO] Console QuickEdit is already disabled by the host/user settings.'
            }
        } else {
            Write-Host '[INFO] No classic console input mode was available to inspect.'
        }
    } catch {
        Write-Host ("[WARN] Console selection-mode inspection was unavailable: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
    try {
        $Flags = [Convert]::ToUInt32('80000001',16) # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
        $ExecutionStateResult = [LegionGoNativeMethodsRC2zk]::SetThreadExecutionState($Flags)
        if ($ExecutionStateResult -eq 0) {
            Write-Host '[WARN] Windows did not accept the sleep-prevention request; keep the device awake manually during long stages.' -ForegroundColor Yellow
        } else {
            $Script:InstallerAwakeRequestActive = $true
            Write-Host ("[PASS] Sleep prevention active while {0} is running." -f $StageLabel) -ForegroundColor Green
        }
    } catch {
        Write-Host ("[WARN] Sleep-prevention request was unavailable: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Enter-ConsoleSelectionProtection {
    param([string]$Activity = 'long operation')
    try {
        if ($Script:QuickEditProtectionDepth -eq 0) {
            $Handle = [LegionGoNativeMethodsRC2zk]::GetStdHandle(-10)
            $Mode = [uint32]0
            if ($Handle -ne [IntPtr]::Zero -and [LegionGoNativeMethodsRC2zk]::GetConsoleMode($Handle,[ref]$Mode)) {
                $Script:QuickEditSpanRestoreMode = $Mode
                $Script:QuickEditSpanChanged = $false
                if (($Mode -band [uint32]0x40) -ne 0) {
                    $NewMode = ($Mode -band (-bnot [uint32]0x40)) -bor [uint32]0x80
                    if ([LegionGoNativeMethodsRC2zk]::SetConsoleMode($Handle,$NewMode)) {
                        $Script:QuickEditSpanChanged = $true
                        Write-Host ("[MODE] Mouse text selection temporarily disabled during: {0}" -f $Activity) -ForegroundColor DarkGray
                    }
                }
            }
        }
        $Script:QuickEditProtectionDepth++
    } catch {
        Write-Host ("[WARN] Could not apply scoped QuickEdit protection: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Exit-ConsoleSelectionProtection {
    try {
        if ($Script:QuickEditProtectionDepth -gt 0) { $Script:QuickEditProtectionDepth-- }
        if ($Script:QuickEditProtectionDepth -eq 0 -and $Script:QuickEditSpanChanged -and $null -ne $Script:QuickEditSpanRestoreMode) {
            $Handle = [LegionGoNativeMethodsRC2zk]::GetStdHandle(-10)
            [void][LegionGoNativeMethodsRC2zk]::SetConsoleMode($Handle,[uint32]$Script:QuickEditSpanRestoreMode)
            $Script:QuickEditSpanChanged = $false
            $Script:QuickEditSpanRestoreMode = $null
            Write-Host '[MODE] Text selection restored.' -ForegroundColor DarkGray
        }
    } catch {}
}

function Restore-ConsoleSelectionForInteraction {
    try {
        if ($Script:QuickEditSpanChanged -and $null -ne $Script:QuickEditSpanRestoreMode) {
            $Handle = [LegionGoNativeMethodsRC2zk]::GetStdHandle(-10)
            [void][LegionGoNativeMethodsRC2zk]::SetConsoleMode($Handle,[uint32]$Script:QuickEditSpanRestoreMode)
        }
    } catch {}
    $Script:QuickEditProtectionDepth = 0
    $Script:QuickEditSpanChanged = $false
    $Script:QuickEditSpanRestoreMode = $null
}

function Restore-InstallerRuntime {
    try { if ('LegionGoConsoleLivenessRC2zk' -as [type]) { [LegionGoConsoleLivenessRC2zk]::Stop() } } catch {}
    Restore-ConsoleSelectionForInteraction
    try {
        if ($Script:InstallerAwakeRequestActive) {
            $Continuous = [Convert]::ToUInt32('80000000',16)
            [void][LegionGoNativeMethodsRC2zk]::SetThreadExecutionState($Continuous)
            $Script:InstallerAwakeRequestActive = $false
        }
    } catch {}
    try {
        if ($null -ne $Script:InstallerOriginalConsoleMode) {
            $Handle = [LegionGoNativeMethodsRC2zk]::GetStdHandle(-10)
            [void][LegionGoNativeMethodsRC2zk]::SetConsoleMode($Handle,[uint32]$Script:InstallerOriginalConsoleMode)
            $Script:InstallerOriginalConsoleMode = $null
        }
    } catch {}
}

function Write-StageStatus {
    param([Parameter(Mandatory=$true)][int]$Stage,[Parameter(Mandatory=$true)][string]$Name,[string]$CurrentTask='')
    Write-Host ''
    Write-Host '============================================================'
    Write-Host ' LEGION GO AMD 26.7.1 INSTALLER'
    Write-Host (" Stage {0} of 4 - {1}" -f $Stage,$Name)
    Write-Host '============================================================'
    # RC2zk deliberately keeps overall workflow position out of the task/liveness
    # channel.  A stage marker is informational only; [TASK]/[LIVE] always refer
    # to the operation currently being executed.
    Write-Host ("[OVERALL] Stage {0}/4 :: {1}" -f $Stage,$Name) -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($CurrentTask)) { Write-Host (" Current task: {0}" -f $CurrentTask) }
}

function Write-FailureGuide {
    param(
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$LogPath = '',
        [string]$SafetyState = 'No safety-state summary was provided.'
    )
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ' INSTALLER STOPPED SAFELY' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ("Stage: {0}" -f $Stage)
    Write-Host ("Reason: {0}" -f $Message) -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) { Write-Host ("Log: {0}" -f $LogPath) }
    Write-Host ("Safety state: {0}" -f $SafetyState)
    Write-Host ''
    Write-Host 'Suggested next actions:' -ForegroundColor Yellow
    $Lower = $Message.ToLowerInvariant()
    if ($Lower -match '7-zip|7z\.exe') {
        Write-Host '  1. Retry after confirming Internet access and WinGet operation.'
        Write-Host '  2. Official 7-Zip download: https://www.7-zip.org/download.html'
        Write-Host '  3. If WinGet sources are broken: winget source reset --force'
        Write-Host '     Microsoft reference: https://learn.microsoft.com/windows/package-manager/winget/source'
    } elseif ($Lower -match 'sdk|wdk|inf2cat|signtool|windows kit') {
        Write-Host '  1. Retry after confirming Internet access to nuget.org.'
        Write-Host '  2. Portable WDK x64 package: https://www.nuget.org/packages/Microsoft.Windows.WDK.x64/'
        Write-Host '  3. Portable SDK BuildTools package: https://www.nuget.org/packages/Microsoft.Windows.SDK.BuildTools/'
        Write-Host '  4. RC2zk does not require a full Windows SDK/WDK MSI installation.'
    } elseif ($Lower -match 'installer.*mismatch|amd installer|authenticode') {
        Write-Host '  1. Do not bypass the identity check or substitute another AMD package.'
        Write-Host '  2. Re-download AMD Software 26.7.1 from AMD and retry.'
        Write-Host '     AMD 26.7.1 release notes: https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-7-1.html'
    } elseif ($Lower -match 'msi|windows installer|1618|1603') {
        Write-Host '  1. Reboot Windows once and retry so no other MSI transaction is pending.'
        Write-Host '  2. Review the MSI log shown above before changing anything else.'
        Write-Host '  3. Only if Windows servicing/component corruption is also reported, use DISM /RestoreHealth followed by sfc /scannow.'
        Write-Host '     Microsoft reference: https://support.microsoft.com/windows/using-system-file-checker-in-windows'
    } elseif ($Lower -match 'bcd|test signing|secure boot|integrity') {
        Write-Host '  1. Do not disable additional Windows integrity protections as a workaround.'
        Write-Host '  2. Verify Secure Boot/Test Signing status, then rerun the launcher.'
    } else {
        Write-Host '  1. Read the exact failure above and preserve the workflow/log directory.'
        Write-Host '  2. Rerun the one-command launcher after correcting the reported prerequisite.'
        Write-Host '  3. Do not manually delete Driver Store packages unless the recovery output explicitly instructs it.'
    }
}

function Get-WorkflowSafetySummary {
    $State = Read-WorkflowState
    if ($null -eq $State) { return 'No workflow state exists yet; no driver transaction is recorded.' }
    $Stage = [string]$State.Stage
    $TransactionStatus = ''
    $TxProperty = $State.PSObject.Properties['TransactionStatus']
    if ($null -ne $TxProperty -and $null -ne $TxProperty.Value) { $TransactionStatus = [string]$TxProperty.Value }
    if ($TransactionStatus -eq 'DriverTransactionInProgress') { return "Workflow stage=$Stage; a destructive driver transaction was checkpointed as IN PROGRESS. Recovery must run before a new transaction." }
    if ($TransactionStatus -like 'RecoveredAfter*') { return "Workflow stage=$Stage; rollback/recovery was attempted after a failed or interrupted driver transaction. Verify the reported GPU state before retrying." }
    if ($TransactionStatus -eq 'DriverInstalledPreReboot') { return 'Exact final driver passed pre-reboot validation; Test Signing has not yet been sealed off by the normal-signing reboot.' }
    if ($Stage -in @('SignedPackageReady','AwaitingTestSigningReboot','ReadyForInstall')) { return "Workflow stage=$Stage; active display-driver replacement has not been recorded as started." }
    if ($Stage -eq 'AwaitingNormalSigningReboot') { return 'Driver transaction passed pre-reboot validation; Test Signing is configured off for the next boot.' }
    if ($Stage -in @('DriverComplete','AwaitingSoftwareReboot','SoftwareComplete','Complete')) { return "Workflow stage=$Stage; final driver transaction has already passed its driver-stage seal." }
    return ("Workflow stage={0}; inspect the saved rollback/log paths before manual changes." -f $Stage)
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory=$true)]$InputObject,
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [int]$Depth = 20
    )
    $Parent = Split-Path -Parent $LiteralPath
    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    $Temporary = $LiteralPath + '.tmp'
    $Backup = $LiteralPath + '.bak'
    $Json = $InputObject | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($Temporary, $Json, (New-Object Text.UTF8Encoding -ArgumentList $false))
    if (Test-Path -LiteralPath $LiteralPath -PathType Leaf) {
        [IO.File]::Replace($Temporary,$LiteralPath,$Backup,$true)
    } else {
        Move-Item -LiteralPath $Temporary -Destination $LiteralPath -Force
    }
}

function Read-WorkflowState {
    $Primary = $Script:WorkflowStatePath
    $Backup = $Primary + '.bak'
    if (Test-Path -LiteralPath $Primary -PathType Leaf) {
        try { return (Get-Content -LiteralPath $Primary -Raw -Encoding UTF8 | ConvertFrom-Json) }
        catch {
            Write-Host ("[WARN] Primary workflow state is unreadable: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
            if (-not (Test-Path -LiteralPath $Backup -PathType Leaf)) { throw }
            Write-Host '[RECOVERY] Falling back to the previous atomic workflow-state backup.' -ForegroundColor Yellow
        }
    }
    if (Test-Path -LiteralPath $Backup -PathType Leaf) {
        return (Get-Content -LiteralPath $Backup -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    return $null
}

function Set-StateProperty {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$Name,$Value)
    $Property = $State.PSObject.Properties[$Name]
    if ($null -eq $Property) {
        $State | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    } else {
        $Property.Value = $Value
    }
}

function Get-CurrentBootTime {
    return (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
}

function Get-TestSigningConfigured {
    $Output = @(& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to query the current BCD entry.' }
    return [bool]($Output -match '(?im)^\s*testsigning\s+Yes\s*$')
}

function Get-SecureBootState {
    try { return [bool](Confirm-SecureBootUEFI -ErrorAction Stop) }
    catch { return $null }
}

function Get-NoIntegrityChecksConfigured {
    $Output = @(& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to query the current BCD entry.' }
    return [bool]($Output -match '(?im)^\s*nointegritychecks\s+Yes\s*$')
}


function Test-Administrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-NativeArgument {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '(\\*)"','$1$1\\"' -replace '(\\+)$','$1$1') + '"'
}

function Invoke-ProcessHeartbeat {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$LogPath,
        [int]$TimeoutSeconds = 1800,
        [int]$HeartbeatSeconds = 10,
        [string]$Activity = '',
        [string]$Estimate = '',
        [switch]$AllowFailure
    )
    $Parent = Split-Path -Parent $LogPath
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    $StdOut = $LogPath + '.stdout.tmp'
    $StdErr = $LogPath + '.stderr.tmp'
    Remove-Item -LiteralPath $StdOut,$StdErr -Force -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($Activity)) { $Activity = [IO.Path]::GetFileName($FilePath) }
    if (-not [string]::IsNullOrWhiteSpace($Estimate)) { Write-Host ("[TIME] {0}" -f $Estimate) -ForegroundColor Cyan }
    Write-Host ("[START] {0}" -f $Activity)
    Write-ActivityProgress -Activity $Activity -Percent 0 -Status 'START'
    $ArgLine = (@($Arguments | ForEach-Object { Quote-NativeArgument -Value ([string]$_) }) -join ' ')
    $Process = $null
    $TimedOut = $false
    Enter-ConsoleSelectionProtection -Activity $Activity
    try {
        $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgLine -PassThru -WindowStyle Hidden -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        $Started = Get-Date
        $NextBeat = $Started
        $LastPreview = ''
        while (-not $Process.HasExited) {
            $Now = Get-Date
            if ($Now -ge $NextBeat) {
                $ElapsedText = Format-Elapsed -Elapsed ($Now - $Started)
                Write-IndeterminateActivityProgress -Activity $Activity -Tick ([int](($Now-$Started).TotalSeconds / [Math]::Max(1,$HeartbeatSeconds))) -Elapsed $ElapsedText -Detail ("PID {0}" -f $Process.Id)
                $Preview = ''
                try {
                    if (Test-Path -LiteralPath $StdOut) { $Preview = [string](Get-Content -LiteralPath $StdOut -Tail 1 -ErrorAction SilentlyContinue) }
                    if ([string]::IsNullOrWhiteSpace($Preview) -and (Test-Path -LiteralPath $StdErr)) { $Preview = [string](Get-Content -LiteralPath $StdErr -Tail 1 -ErrorAction SilentlyContinue) }
                } catch {}
                if (-not [string]::IsNullOrWhiteSpace($Preview) -and $Preview -ne $LastPreview) { Write-Host ("         child: {0}" -f $Preview); $LastPreview = $Preview }
                $NextBeat = $Now.AddSeconds($HeartbeatSeconds)
            }
            if (($Now - $Started).TotalSeconds -gt $TimeoutSeconds) {
                $TimedOut = $true
                try { Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue } catch {}
                break
            }
            Start-Sleep -Milliseconds 500
            try { $Process.Refresh() } catch {}
        }
        $Finished = Get-Date
        $Lines = @()
        if (Test-Path -LiteralPath $StdOut) { $Lines += Get-Content -LiteralPath $StdOut -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $StdErr) { $Lines += Get-Content -LiteralPath $StdErr -ErrorAction SilentlyContinue }
        $Lines | Set-Content -LiteralPath $LogPath -Encoding UTF8
        if ($Lines.Count -gt 0) { $Lines | Select-Object -Last 25 | ForEach-Object { Write-Host $_ } }
        if ($TimedOut) { throw "Process timed out during '$Activity' after $TimeoutSeconds seconds. Log: $LogPath" }
        $ExitCode = [int]$Process.ExitCode
        $ElapsedFinal = Format-Elapsed -Elapsed ($Finished - $Started)
        if ($ExitCode -eq 0) { Complete-ActivityProgress -Activity $Activity -Detail ("elapsed {0}; exit code 0" -f $ElapsedFinal); Write-Host ("[PASS] {0} completed | elapsed {1} | exit code 0" -f $Activity,$ElapsedFinal) -ForegroundColor Green }
        else { Write-Host ("[INFO] {0} ended | elapsed {1} | exit code {2}" -f $Activity,$ElapsedFinal,$ExitCode) -ForegroundColor Yellow }
        if (-not $AllowFailure -and $ExitCode -ne 0) { throw "Process failed during '$Activity' with exit code $ExitCode. Log: $LogPath" }
        return [pscustomobject]@{ ExitCode=$ExitCode; LogPath=$LogPath; Elapsed=$ElapsedFinal; Activity=$Activity }
    } finally {
        if ($null -ne $Process) { try { $Process.Dispose() } catch {} }
        Remove-Item -LiteralPath $StdOut,$StdErr -Force -ErrorAction SilentlyContinue
        Exit-ConsoleSelectionProtection
    }
}

function Invoke-RawArgumentsProcessHeartbeat {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ArgumentLine,
        [Parameter(Mandatory=$true)][string]$LogPath,
        [string]$WorkingDirectory = '',
        [int]$TimeoutSeconds = 1800,
        [int]$HeartbeatSeconds = 10,
        [string]$Activity = '',
        [string]$Estimate = '',
        [switch]$AllowFailure
    )

    $Parent = Split-Path -Parent $LogPath
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    if ([string]::IsNullOrWhiteSpace($Activity)) { $Activity = [IO.Path]::GetFileName($FilePath) }
    if (-not [string]::IsNullOrWhiteSpace($Estimate)) { Write-Host ("[TIME] {0}" -f $Estimate) -ForegroundColor Cyan }
    Write-Host ("[START] {0}" -f $Activity)
    Write-ActivityProgress -Activity $Activity -Percent 0 -Status 'START'

    $Psi = New-Object System.Diagnostics.ProcessStartInfo
    $Psi.FileName = $FilePath
    $Psi.Arguments = $ArgumentLine
    $Psi.UseShellExecute = $false
    $Psi.CreateNoWindow = $true
    $Psi.RedirectStandardOutput = $true
    $Psi.RedirectStandardError = $true
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) { $Psi.WorkingDirectory = $WorkingDirectory }

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $Psi
    $TimedOut = $false
    $StdoutTask = $null
    $StderrTask = $null

    Enter-ConsoleSelectionProtection -Activity $Activity
    try {
        [void]$Process.Start()
        $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $StderrTask = $Process.StandardError.ReadToEndAsync()

        $Started = Get-Date
        $NextBeat = $Started
        while (-not $Process.HasExited) {
            $Now = Get-Date
            if ($Now -ge $NextBeat) {
                $ElapsedText = Format-Elapsed -Elapsed ($Now-$Started)
                Write-IndeterminateActivityProgress -Activity $Activity -Tick ([int](($Now-$Started).TotalSeconds / [Math]::Max(1,$HeartbeatSeconds))) -Elapsed $ElapsedText -Detail ("PID {0}" -f $Process.Id)
                $NextBeat = $Now.AddSeconds($HeartbeatSeconds)
            }
            if (($Now-$Started).TotalSeconds -gt $TimeoutSeconds) {
                $TimedOut = $true
                try { $Process.Kill() } catch {}
                break
            }
            Start-Sleep -Milliseconds 500
            try { $Process.Refresh() } catch {}
        }

        try { $Process.WaitForExit() } catch {}

        $Stdout = ''
        $Stderr = ''
        try { $Stdout = [string]$StdoutTask.GetAwaiter().GetResult() } catch {}
        try { $Stderr = [string]$StderrTask.GetAwaiter().GetResult() } catch {}

        @(
            ('COMMAND: ' + $FilePath)
            ('ARGUMENTS: ' + $ArgumentLine)
            ''
            'STDOUT:'
            $Stdout
            ''
            'STDERR:'
            $Stderr
        ) | Set-Content -LiteralPath $LogPath -Encoding UTF8

        $Lines = @(($Stdout+"`r`n"+$Stderr) -split "`r?`n")
        if ($Lines.Count -gt 0) {
            $Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Last 25 | ForEach-Object { Write-Host $_ }
        }

        if ($TimedOut) { throw "Process timed out during '$Activity' after $TimeoutSeconds seconds. Log: $LogPath" }

        $ExitCode = [int]$Process.ExitCode
        $ElapsedFinal = Format-Elapsed -Elapsed ((Get-Date)-$Started)
        if ($ExitCode -eq 0) {
            Complete-ActivityProgress -Activity $Activity -Detail ("elapsed {0}; exit code 0" -f $ElapsedFinal)
            Write-Host ("[PASS] {0} completed | elapsed {1} | exit code 0" -f $Activity,$ElapsedFinal) -ForegroundColor Green
        } else {
            Write-Host ("[INFO] {0} ended | elapsed {1} | exit code {2}" -f $Activity,$ElapsedFinal,$ExitCode) -ForegroundColor Yellow
        }
        if (-not $AllowFailure -and $ExitCode -ne 0) { throw "Process failed during '$Activity' with exit code $ExitCode. Log: $LogPath" }

        return [pscustomobject]@{
            ExitCode=$ExitCode
            LogPath=$LogPath
            Elapsed=$ElapsedFinal
            Activity=$Activity
            Stdout=$Stdout
            Stderr=$Stderr
        }
    }
    finally {
        if ($null -ne $Process) { try { $Process.Dispose() } catch {} }
        Exit-ConsoleSelectionProtection
    }
}

function Resolve-SevenZip {
    $Candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    $Command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($null -ne $Command) { $Candidates += [string]$Command.Source }
    foreach ($Candidate in @($Candidates | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate) -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }
    return $null
}

function Ensure-SevenZip {
    $SevenZip = Resolve-SevenZip
    if ($null -eq $SevenZip) {
        throw '7-Zip is missing after the dependency-preparation stage. Rerun the one-command launcher from Stage 1 instead of installing driver/software stages manually.'
    }
    return $SevenZip
}

function Test-X64PortableExecutable {
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    try {
        $Stream = [IO.File]::Open($LiteralPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try {
            $Reader = New-Object System.IO.BinaryReader -ArgumentList $Stream
            try {
                if ($Reader.ReadUInt16() -ne 0x5A4D) { return $false }
                $Stream.Position = 0x3C
                $PeOffset = $Reader.ReadInt32()
                if ($PeOffset -lt 0 -or $PeOffset -gt ($Stream.Length - 6)) { return $false }
                $Stream.Position = $PeOffset
                if ($Reader.ReadUInt32() -ne 0x00004550) { return $false }
                return ($Reader.ReadUInt16() -eq 0x8664)
            } finally { $Reader.Dispose() }
        } finally { $Stream.Dispose() }
    } catch { return $false }
}

function Test-PinnedInf2Cat {
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { return $false }
    if (-not (Test-X64PortableExecutable -LiteralPath $LiteralPath)) { return $false }
    if ((Get-SHA256 -LiteralPath $LiteralPath) -ne $Script:ExpectedInf2CatSHA256) { return $false }
    try {
        $File = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
        if ([string]$File.VersionInfo.ProductName -notmatch '(?i)Microsoft Hardware Development Center') { return $false }
        $Sig = Get-AuthenticodeSignature -LiteralPath $LiteralPath -ErrorAction Stop
        if ($null -eq $Sig.SignerCertificate) { return $false }
        $Subject = [string]$Sig.SignerCertificate.Subject
        if ($Subject -notmatch '(?i)Windows Internal Build Tools CodeSign' -or $Subject -notmatch '(?i)Microsoft Corporation') { return $false }
        # This exact 10.0.28000.2526 WDK Inf2Cat is observed on Windows as
        # Authenticode UnknownError despite retaining its Microsoft signer cert.
        # UnknownError is accepted ONLY with the pinned SHA256 + x64 PE + exact
        # Microsoft product/signer identity above; all other binaries fail closed.
        return ([string]$Sig.Status -in @('Valid','UnknownError'))
    } catch { return $false }
}

function Test-PinnedSignTool {
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { return $false }
    if (-not (Test-X64PortableExecutable -LiteralPath $LiteralPath)) { return $false }
    if ((Get-SHA256 -LiteralPath $LiteralPath) -ne $Script:ExpectedSignToolSHA256) { return $false }
    try {
        $Sig = Get-AuthenticodeSignature -LiteralPath $LiteralPath -ErrorAction Stop
        if ([string]$Sig.Status -ne 'Valid' -or $null -eq $Sig.SignerCertificate) { return $false }
        return ([string]$Sig.SignerCertificate.Subject -match '(?i)Microsoft Corporation')
    } catch { return $false }
}

function Get-PortableKitRoot {
    return (Join-Path $Script:WorkflowRoot 'Tools\WindowsKits-Portable')
}

function Get-PortableKitSearchRoots {
    $Roots = New-Object System.Collections.Generic.List[string]
    $Current = Get-PortableKitRoot
    $Roots.Add($Current)
    # Reuse exact, pinned portable-tool caches from prior field candidates only
    # after their file identities are revalidated. RC2zk's own cache remains first.
    foreach ($Previous in @(
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2q\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2p\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2o\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2n\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2m\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2l\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2k\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2j\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2h\Tools\WindowsKits-Portable',
        'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2g\Tools\WindowsKits-Portable'
    )) {
        if ($Previous -ne $Current -and (Test-Path -LiteralPath $Previous -PathType Container)) { $Roots.Add($Previous) }
    }
    return @($Roots.ToArray() | Select-Object -Unique)
}

function Resolve-PortableKitTools {
    $InfCandidates = New-Object System.Collections.Generic.List[object]
    $SignCandidates = New-Object System.Collections.Generic.List[object]
    foreach ($Root in @(Get-PortableKitSearchRoots)) {
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) { continue }
        foreach ($F in @(Get-ChildItem -LiteralPath $Root -Filter 'Inf2Cat.exe' -File -Recurse -ErrorAction SilentlyContinue)) {
            if (Test-PinnedInf2Cat -LiteralPath $F.FullName) { $InfCandidates.Add($F) }
        }
        foreach ($F in @(Get-ChildItem -LiteralPath $Root -Filter 'signtool.exe' -File -Recurse -ErrorAction SilentlyContinue)) {
            if (Test-PinnedSignTool -LiteralPath $F.FullName) { $SignCandidates.Add($F) }
        }
    }
    if ($InfCandidates.Count -eq 0 -or $SignCandidates.Count -eq 0) { return $null }
    $Inf2Cat = @($InfCandidates.ToArray() | Sort-Object FullName | Select-Object -First 1)[0]
    $SignTool = @($SignCandidates.ToArray() | Sort-Object FullName | Select-Object -First 1)[0]
    return [pscustomobject]@{
        Inf2Cat = $Inf2Cat.FullName
        SignTool = $SignTool.FullName
        Source = 'PinnedPortableMicrosoftNuGet'
    }
}

function Invoke-DownloadWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter(Mandatory=$true)][string]$Label,
        [int]$TimeoutMinutes = 30
    )

    $Parent = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    $Part = $DestinationPath + '.part'
    Remove-Item -LiteralPath $Part -Force -ErrorAction SilentlyContinue

    Write-Host ("[START] Downloading {0}" -f $Label)
    Write-Host ("[SOURCE] {0}" -f $Uri)
    Write-ActivityProgress -Activity ('Downloading ' + $Label) -Percent 0 -Status 'START'

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Net.Http
    $Handler = New-Object System.Net.Http.HttpClientHandler
    $Handler.AllowAutoRedirect = $true
    $Client = New-Object System.Net.Http.HttpClient -ArgumentList $Handler
    $Client.Timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
    $Client.DefaultRequestHeaders.UserAgent.ParseAdd('LegionGo-AMD-26.7.1-RC2zk/1.0')

    $Response = $null
    $InputStream = $null
    $OutputStream = $null
    Enter-ConsoleSelectionProtection -Activity ('Downloading ' + $Label)
    try {
        $Response = $Client.GetAsync($Uri,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        [void]$Response.EnsureSuccessStatusCode()
        $Total = $Response.Content.Headers.ContentLength
        $InputStream = $Response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $OutputStream = [IO.File]::Open($Part,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $Buffer = New-Object byte[] (1024*1024)
        [int64]$Done = 0
        $Started = Get-Date
        $LastReport = [datetime]::MinValue
        $LastPercent = -1

        while ($true) {
            $Read = $InputStream.Read($Buffer,0,$Buffer.Length)
            if ($Read -le 0) { break }
            $OutputStream.Write($Buffer,0,$Read)
            $Done += [int64]$Read
            $Now = Get-Date

            $ShouldReport = (($Now - $LastReport).TotalSeconds -ge 1)
            if ($null -ne $Total -and [int64]$Total -gt 0) {
                $Percent = [int][Math]::Floor(($Done * 100.0) / [int64]$Total)
                if ($Percent -ne $LastPercent -and $ShouldReport) {
                    Write-ActivityProgress -Activity ('Downloading ' + $Label) -Percent $Percent -Status 'DOWNLOADING' -Detail (("{0:N1} / {1:N1} MB" -f ($Done/1MB),([int64]$Total/1MB)))
                    $LastPercent = $Percent
                    $LastReport = $Now
                }
            } elseif ($ShouldReport) {
                Write-IndeterminateActivityProgress -Activity ('Downloading ' + $Label) -Tick ([int](($Now-$Started).TotalSeconds)) -Elapsed (Format-Elapsed -Elapsed ($Now-$Started)) -Detail (("{0:N1} MB received" -f ($Done/1MB)))
                $LastReport = $Now
            }
        }
        $OutputStream.Flush()
    } finally {
        if ($null -ne $OutputStream) { $OutputStream.Dispose() }
        if ($null -ne $InputStream) { $InputStream.Dispose() }
        if ($null -ne $Response) { $Response.Dispose() }
        $Client.Dispose()
        $Handler.Dispose()
        Exit-ConsoleSelectionProtection
    }

    if (-not (Test-Path -LiteralPath $Part -PathType Leaf) -or (Get-Item -LiteralPath $Part).Length -le 0) {
        throw "Download did not produce a usable file: $Label"
    }
    Move-Item -LiteralPath $Part -Destination $DestinationPath -Force
    $Size = [int64](Get-Item -LiteralPath $DestinationPath).Length
    $Hash = Get-SHA256 -LiteralPath $DestinationPath
    Complete-ActivityProgress -Activity ('Downloading ' + $Label) -Detail (("{0:N1} MB; SHA256 {1}" -f ($Size/1MB),$Hash))
    Write-Host ("[PASS] Downloaded {0} :: {1:N1} MB :: SHA256 {2}" -f $Label,($Size/1MB),$Hash) -ForegroundColor Green
}

function Expand-ValidatedNuGetPackage {
    param(
        [Parameter(Mandatory=$true)][string]$PackagePath,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$ExpectedId,
        [Parameter(Mandatory=$true)][string]$ExpectedVersion
    )

    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Write-Host ("[EXTRACT] {0} {1}" -f $ExpectedId,$ExpectedVersion)
    [IO.Compression.ZipFile]::ExtractToDirectory($PackagePath,$Destination)

    $Nuspec = @(Get-ChildItem -LiteralPath $Destination -Filter '*.nuspec' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($Nuspec.Count -ne 1) { throw "NuGet package metadata missing after extraction: $ExpectedId" }
    $Raw = Get-Content -LiteralPath $Nuspec[0].FullName -Raw -ErrorAction Stop
    if ($Raw -notmatch ('(?is)<id>\s*' + [regex]::Escape($ExpectedId) + '\s*</id>')) { throw "NuGet package ID mismatch: $ExpectedId" }
    if ($Raw -notmatch ('(?is)<version>\s*' + [regex]::Escape($ExpectedVersion) + '\s*</version>')) { throw "NuGet package version mismatch: $ExpectedId $ExpectedVersion" }
    Write-Host ("[PASS] Extracted exact NuGet package: {0} {1}" -f $ExpectedId,$ExpectedVersion) -ForegroundColor Green
}

function Assert-PortableKitToolExecution {
    param([Parameter(Mandatory=$true)]$Tools)
    $SmokeRoot = Join-Path $Script:WorkflowRoot 'Logs'
    New-Item -ItemType Directory -Path $SmokeRoot -Force | Out-Null
    foreach ($Spec in @(
        [pscustomobject]@{Name='Inf2Cat';Path=[string]$Tools.Inf2Cat;Args=@('/?');Log=(Join-Path $SmokeRoot 'portable-inf2cat-smoke.txt')},
        [pscustomobject]@{Name='SignTool';Path=[string]$Tools.SignTool;Args=@('/?');Log=(Join-Path $SmokeRoot 'portable-signtool-smoke.txt')}
    )) {
        $Result = Invoke-ProcessHeartbeat -FilePath $Spec.Path -Arguments $Spec.Args -LogPath $Spec.Log -TimeoutSeconds 60 -HeartbeatSeconds 5 -Activity ("Validating portable x64 {0}" -f $Spec.Name) -Estimate 'Expected: a few seconds.' -AllowFailure
        $Code = [int]$Result.ExitCode
        $LogText = ''
        try { $LogText = Get-Content -LiteralPath $Spec.Log -Raw -ErrorAction SilentlyContinue } catch {}
        if ($Code -lt 0 -or $Code -gt 255) { throw ("Portable x64 {0} failed its loader/process smoke test with abnormal exit code {1}. Log: {2}" -f $Spec.Name,$Code,$Spec.Log) }
        if ($LogText -match '(?i)side-by-side configuration|dll[^\r\n]*(not found|missing)|failed to load|unable to load') {
            throw ("Portable x64 {0} reported a loader/dependency error. Log: {1}" -f $Spec.Name,$Spec.Log)
        }
        Write-Host ("[PASS] Portable x64 {0} executed normally for smoke validation (exit code {1})." -f $Spec.Name,$Code) -ForegroundColor Green
    }
}

function Install-PortableKitTools {
    $Version = $Script:PortableKitVersion
    $Root = Get-PortableKitRoot
    $Downloads = Join-Path $Root '_downloads'
    New-Item -ItemType Directory -Path $Downloads -Force | Out-Null

    $Packages = @(
        [pscustomobject]@{
            Id='Microsoft.Windows.WDK.x64'
            Version=$Version
            Uri=('https://www.nuget.org/api/v2/package/Microsoft.Windows.WDK.x64/' + $Version)
            File=('Microsoft.Windows.WDK.x64.' + $Version + '.nupkg')
            ExpectedSHA256=$Script:ExpectedWdkNuGetSHA256
        },
        [pscustomobject]@{
            Id='Microsoft.Windows.SDK.BuildTools'
            Version=$Version
            Uri=('https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.BuildTools/' + $Version)
            File=('Microsoft.Windows.SDK.BuildTools.' + $Version + '.nupkg')
            ExpectedSHA256=$Script:ExpectedSdkBuildToolsNuGetSHA256
        }
    )

    foreach ($Pkg in $Packages) {
        $PackagePath = Join-Path $Downloads $Pkg.File
        $ExtractRoot = Join-Path $Root ($Pkg.Id + '.' + $Pkg.Version)
        if (-not (Test-Path -LiteralPath $ExtractRoot -PathType Container)) {
            if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
                Invoke-DownloadWithProgress -Uri $Pkg.Uri -DestinationPath $PackagePath -Label ($Pkg.Id + ' ' + $Pkg.Version) -TimeoutMinutes 30
            } else {
                Write-Host ("[PASS] Reusing completed package download: {0}" -f $PackagePath) -ForegroundColor Green
            }
            $ObservedPackageHash = Get-SHA256 -LiteralPath $PackagePath
            if ($ObservedPackageHash -ne [string]$Pkg.ExpectedSHA256) { throw ("Pinned NuGet package hash mismatch for {0}. Expected={1} Actual={2}" -f $Pkg.Id,$Pkg.ExpectedSHA256,$ObservedPackageHash) }
            Write-Host ("[PASS] Pinned NuGet SHA256 verified: {0}" -f $Pkg.Id) -ForegroundColor Green
            Expand-ValidatedNuGetPackage -PackagePath $PackagePath -Destination $ExtractRoot -ExpectedId $Pkg.Id -ExpectedVersion $Pkg.Version
        }
    }

    $Tools = Resolve-PortableKitTools
    if ($null -eq $Tools) {
        throw 'Portable Microsoft NuGet packages are present, but the pinned x64 Inf2Cat/SignTool identities were not found.'
    }

    foreach ($Pkg in $Packages) {
        $PackagePath = Join-Path $Downloads $Pkg.File
        Remove-Item -LiteralPath $PackagePath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $Downloads) {
        $Remaining = @(Get-ChildItem -LiteralPath $Downloads -Force -ErrorAction SilentlyContinue)
        if ($Remaining.Count -eq 0) { Remove-Item -LiteralPath $Downloads -Force -ErrorAction SilentlyContinue }
    }

    return $Tools
}

function Get-ManagedResumeLauncherPath {
    return (Join-Path $Script:WorkflowRoot 'Toolkit\Install-LegionGo-AMD-26.7.1.ps1')
}

function Test-ManagedResumeTask {
    try { return ($null -ne (Get-ScheduledTask -TaskName $Script:ResumeTaskName -ErrorAction SilentlyContinue)) } catch { return $false }
}

function Remove-ManagedResumeTask {
    param([switch]$Quiet)
    try {
        $Task = Get-ScheduledTask -TaskName $Script:ResumeTaskName -ErrorAction SilentlyContinue
        if ($null -ne $Task) {
            Unregister-ScheduledTask -TaskName $Script:ResumeTaskName -Confirm:$false -ErrorAction Stop
            if (-not $Quiet) { Write-Host '[PASS] One-shot reboot-resume task removed.' -ForegroundColor Green }
        }
    } catch {
        if (-not $Quiet) { Write-Host ("[WARN] Could not remove reboot-resume task: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
}

function Register-ManagedResumeTask {
    if ($env:LEGIONGO_RC2I_MANAGED -ne '1') { return }
    $LauncherPath = Get-ManagedResumeLauncherPath
    if (-not (Test-Path -LiteralPath $LauncherPath -PathType Leaf)) { throw "Persistent launcher is missing at reboot boundary: $LauncherPath" }
    $PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $ActionArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $LauncherPath + '" -Resume'
    $Action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $ActionArgs
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
    $Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Highest
    # Deliberately omit the scheduler's catch-up flag. Registering an AtLogOn trigger while
    # already logged in must not immediately replay the current-session stage.
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
    Register-ScheduledTask -TaskName $Script:ResumeTaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    if (-not (Test-ManagedResumeTask)) { throw 'The one-shot reboot-resume scheduled task could not be verified.' }
    Write-Host '[PASS] One-shot reboot-resume task armed for the next sign-in.' -ForegroundColor Green
}

function Arm-ManagedResumeTaskAtBoundary {
    if ($env:LEGIONGO_RC2I_MANAGED -eq '1') { Register-ManagedResumeTask }
}

function Get-RC2eLegacyKitResidue {
    $OldRoot = 'C:\ProgramData\LegionGo-AMD-26.7.1-v3.0-RC2e'
    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $Winget -or -not (Test-Path -LiteralPath $OldRoot -PathType Container)) { return @() }

    $Found = New-Object System.Collections.Generic.List[string]
    foreach ($Id in @('Microsoft.WindowsWDK.10.0.28000','Microsoft.WindowsSDK.10.0.28000')) {
        $Log = Join-Path $OldRoot ('Logs\winget-' + $Id + '.txt')
        if (-not (Test-Path -LiteralPath $Log -PathType Leaf)) { continue }
        $LogText = Get-Content -LiteralPath $Log -Raw -ErrorAction SilentlyContinue
        if ($LogText -notmatch '(?i)Successfully installed') { continue }
        $ListOutput = @(& $Winget.Source list --id $Id -e --disable-interactivity 2>&1)
        if ((@($ListOutput) -join "`n") -match [regex]::Escape($Id)) { $Found.Add($Id) }
    }
    return @($Found.ToArray())
}

function Remove-RC2eLegacyKitResidue {
    param([Parameter(Mandatory=$true)][string[]]$Ids)
    if (@($Ids).Count -eq 0) { return }
    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $Winget) { throw 'RC2e legacy SDK/WDK packages were detected, but winget is unavailable for their exact uninstall.' }
    foreach ($Id in $Ids) {
        $Log = Join-Path $Script:WorkflowRoot ('Logs\remove-rc2e-legacy-' + $Id + '.txt')
        [void](Invoke-ProcessHeartbeat -FilePath $Winget.Source -Arguments @('uninstall','--id',$Id,'-e','--silent','--disable-interactivity') -LogPath $Log -TimeoutSeconds 1800 -HeartbeatSeconds 5 -Activity ("Removing RC2e legacy full kit: {0}" -f $Id) -Estimate 'Expected: a few minutes; watchdog: 30 minutes.')
    }
}

function Ensure-Stage1Dependencies {
    $SevenZip = Resolve-SevenZip
    $Tools = Resolve-PortableKitTools
    $LegacyIds = @(Get-RC2eLegacyKitResidue)

    $NeedsSevenZip = ($null -eq $SevenZip)
    $NeedsTools = ($null -eq $Tools)
    $NeedsAction = $NeedsSevenZip -or $NeedsTools -or ($LegacyIds.Count -gt 0)

    if ($NeedsAction) {
        Write-Section 'DEPENDENCY PREPARATION'
        Write-Host 'RC2zk uses one consent gate for the entire non-driver dependency phase.'
        if ($LegacyIds.Count -gt 0) {
            Write-Host '[PLAN] Remove full SDK/WDK packages that RC2e itself logged as installing:' -ForegroundColor Yellow
            foreach ($Id in $LegacyIds) { Write-Host ("       - {0}" -f $Id) }
        }
        if ($NeedsSevenZip) { Write-Host '[PLAN] Install 7-Zip x64 through WinGet.' }
        else { Write-Host ("[PASS] Reusing existing 7-Zip: {0}" -f $SevenZip) -ForegroundColor Green }
        if ($NeedsTools) {
            Write-Host '[PLAN] Download portable Microsoft x64 signing tools only:'
            Write-Host '       - Microsoft.Windows.WDK.x64 10.0.28000.2526 (~108 MB package)'
            Write-Host '       - Microsoft.Windows.SDK.BuildTools 10.0.28000.2526 (~21 MB package)'
            Write-Host '[INFO] No full Windows SDK/WDK MSI installation is performed.'
        } else {
            Write-Host '[PASS] Portable Microsoft signing tools are already cached.' -ForegroundColor Green
        }

        if (-not (Confirm-ManagedOrInteractive -Prompt 'Prepare all required dependencies now?' -Estimate 'Usually a few minutes. Downloads show real byte/percentage progress; long native operations show a moving activity bar, PID, and elapsed time.' -Impact 'In managed one-click mode this is already authorized by the two initial confirmations; no additional Y/N is shown.')) {
            throw (New-Object System.OperationCanceledException -ArgumentList 'User declined dependency preparation.')
        }
    }

    if ($LegacyIds.Count -gt 0) { Remove-RC2eLegacyKitResidue -Ids $LegacyIds }

    if ($NeedsSevenZip) {
        $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($null -eq $Winget) { throw '7-Zip is required and was not found; winget is also unavailable.' }
        $Log = Join-Path $Script:WorkflowRoot 'Logs\winget-7zip.txt'
        [void](Invoke-ProcessHeartbeat -FilePath $Winget.Source -Arguments @('install','--id','7zip.7zip','-e','--architecture','x64','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') -LogPath $Log -TimeoutSeconds 900 -HeartbeatSeconds 5 -Activity 'Installing 7-Zip x64 dependency' -Estimate 'Expected: a few minutes; watchdog: 15 minutes.')
        $SevenZip = Resolve-SevenZip
        if ($null -eq $SevenZip) { throw '7-Zip installation completed but 7z.exe still could not be resolved.' }
    }

    if ($NeedsTools) {
        $Tools = Install-PortableKitTools
    }

    if ($null -eq $SevenZip -or $null -eq $Tools) { throw 'Dependency preparation did not resolve the required toolchain.' }
    Assert-PortableKitToolExecution -Tools $Tools
    return [pscustomobject]@{ SevenZip=$SevenZip; Tools=$Tools }
}

function Resolve-AdjacentAmdInstaller {
    param([Parameter(Mandatory=$true)][string]$BaseDirectory,[string]$InstallerPath)
    if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) {
        if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) { throw "AMD installer not found: $InstallerPath" }
        return (Resolve-Path -LiteralPath $InstallerPath).Path
    }
    $ExactName = 'whql-amd-software-adrenalin-edition-26.7.1-win11-b.exe'
    $Exact = Join-Path $BaseDirectory $ExactName
    if (Test-Path -LiteralPath $Exact -PathType Leaf) { return (Resolve-Path -LiteralPath $Exact).Path }
    $Candidates = @(Get-ChildItem -LiteralPath $BaseDirectory -Filter '*26.7.1*win11*.exe' -File -ErrorAction SilentlyContinue)
    if ($Candidates.Count -ne 1) { throw "Place the exact AMD 26.7.1 installer beside the toolkit. Candidates found: $($Candidates.Count)" }
    return $Candidates[0].FullName
}

function Assert-OfficialInstaller {
    param([Parameter(Mandatory=$true)][string]$InstallerPath)
    $Item = Get-Item -LiteralPath $InstallerPath
    if ([int64]$Item.Length -ne $Script:ExpectedInstallerLength) { throw "AMD installer length mismatch: $($Item.Length)" }
    $Hash = Get-SHA256WithProgress -LiteralPath $InstallerPath -Activity 'Verify official AMD 26.7.1 installer SHA-256'
    if ($Hash -ne $Script:ExpectedInstallerSHA256) { throw "AMD installer SHA-256 mismatch: $Hash" }
    if ([string]$Item.VersionInfo.FileVersion -ne $Script:ExpectedInstallerVersion) { throw "AMD installer version mismatch: $($Item.VersionInfo.FileVersion)" }
    $Sig = Get-AuthenticodeSignature -LiteralPath $InstallerPath
    if ($Sig.Status -ne 'Valid' -or $null -eq $Sig.SignerCertificate -or [string]$Sig.SignerCertificate.Subject -notmatch 'Advanced Micro Devices') { throw 'AMD installer Authenticode signature is not valid AMD.' }
    return [pscustomobject]@{ Path=$Item.FullName; Length=[int64]$Item.Length; SHA256=$Hash; Version=[string]$Item.VersionInfo.FileVersion; Signer=[string]$Sig.SignerCertificate.Subject }
}

function Get-LegionGoGpu {
    # Locate the physical PCI function first. This remains valid when the device
    # is bound to Microsoft Basic Display Adapter and does not depend on the
    # current vendor driver's Win32_PnPSignedDriver representation.
    $Candidates = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {
        [string]$_.InstanceId -like ($Script:LegionGoHardwarePrefix + '*')
    })
    if ($Candidates.Count -ne 1) { throw "Expected exactly one original Legion Go GPU PCI function; found $($Candidates.Count)." }

    $Pnp = $Candidates[0]
    $DeviceId = [string]$Pnp.InstanceId
    $ProblemProperty = Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue
    $Problem = if ($null -ne $ProblemProperty -and $null -ne $ProblemProperty.Data) { [int]$ProblemProperty.Data } else { 0 }

    $ActiveInf = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data
    $Version = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction Stop).Data
    $DriverKey = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_Driver' -ErrorAction Stop).Data
    $Service = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
    $Provider = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction SilentlyContinue).Data
    $Desc = [string](Get-PnpDeviceProperty -InstanceId $DeviceId -KeyName 'DEVPKEY_Device_DeviceDesc' -ErrorAction SilentlyContinue).Data

    $DeviceName = [string]$Pnp.FriendlyName
    if ([string]::IsNullOrWhiteSpace($DeviceName)) { $DeviceName = $Desc }
    if ([string]::IsNullOrWhiteSpace($DeviceName)) { $DeviceName = 'Legion Go GPU' }

    $InfPath = ''
    $InfHash = ''
    if (-not [string]::IsNullOrWhiteSpace($ActiveInf)) {
        $CandidateInfPath = Join-Path $env:WINDIR ('INF\' + $ActiveInf)
        if (Test-Path -LiteralPath $CandidateInfPath -PathType Leaf) {
            $InfPath = $CandidateInfPath
            $InfHash = Get-SHA256 -LiteralPath $CandidateInfPath
        }
    }

    $Kernel = ''
    $KernelHash = ''
    if (-not [string]::IsNullOrWhiteSpace($Service)) {
        try {
            $ImagePath = [string](Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $Service) -Name ImagePath -ErrorAction Stop).ImagePath
            $Kernel = [Environment]::ExpandEnvironmentVariables($ImagePath.Trim('"'))
            if ($Kernel.StartsWith('\SystemRoot\',[StringComparison]::OrdinalIgnoreCase)) { $Kernel = Join-Path $env:WINDIR $Kernel.Substring(12) }
            elseif ($Kernel.StartsWith('System32\',[StringComparison]::OrdinalIgnoreCase)) { $Kernel = Join-Path $env:WINDIR $Kernel }
            if (Test-Path -LiteralPath $Kernel -PathType Leaf) { $KernelHash = Get-SHA256 -LiteralPath $Kernel }
        } catch {
            $Kernel = ''
            $KernelHash = ''
        }
    }

    $InfBase = [IO.Path]::GetFileName($ActiveInf)
    $OriginKind = 'ThirdPartyDisplay'
    $IsMicrosoftBasic = (
        ($Provider -match '(?i)^Microsoft') -and
        ($Service -ieq 'BasicDisplay') -and
        ($InfBase -in @('display.inf','basicdisplay.inf'))
    )
    if ($IsMicrosoftBasic) {
        $OriginKind = 'MicrosoftBasic'
    } elseif ($InfHash -eq $Script:ExpectedFinalInfSHA256) {
        $OriginKind = 'FinalCandidate'
    } elseif ([string]::IsNullOrWhiteSpace($ActiveInf)) {
        $OriginKind = 'NoActiveInf'
    }

    return [pscustomobject]@{
        DeviceName=$DeviceName
        DeviceID=$DeviceId
        Status=[string]$Pnp.Status
        ProblemCode=$Problem
        HasProblem=([string]$Pnp.Status -ne 'OK' -or $Problem -ne 0)
        ActiveINF=$ActiveInf
        DriverVersion=$Version
        DriverProvider=$Provider
        InfPath=$InfPath
        InfSHA256=$InfHash
        DriverKey=$DriverKey
        Service=$Service
        KernelPath=$Kernel
        KernelSHA256=$KernelHash
        OriginKind=$OriginKind
    }
}

function Get-AmdCnMetadataSafe {
    $Path = 'HKLM:\SOFTWARE\AMD\CN'
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ CNVersion=''; DriverVersion=''; ReleaseVersion='' }
    }
    try {
        $Item = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        $CNVersion = if ($null -ne $Item.PSObject.Properties['CNVersion']) { [string]$Item.CNVersion } else { '' }
        $DriverVersion = if ($null -ne $Item.PSObject.Properties['DriverVersion']) { [string]$Item.DriverVersion } else { '' }
        $ReleaseVersion = if ($null -ne $Item.PSObject.Properties['ReleaseVersion']) { [string]$Item.ReleaseVersion } else { '' }
        return [pscustomobject]@{
            CNVersion=$CNVersion
            DriverVersion=$DriverVersion
            ReleaseVersion=$ReleaseVersion
        }
    } catch {
        return [pscustomobject]@{ CNVersion=''; DriverVersion=''; ReleaseVersion='' }
    }
}

function Get-LegionGoOriginClassification {
    param([Parameter(Mandatory=$true)]$Gpu)

    $GpuContract = [pscustomobject]@{
        Status=[string]$Gpu.Status
        ProblemCode=[int]$Gpu.ProblemCode
        HasProblem=[bool]$Gpu.HasProblem
        Provider=[string]$Gpu.DriverProvider
        Service=[string]$Gpu.Service
        ActiveINF=[string]$Gpu.ActiveINF
        DriverVersion=[string]$Gpu.DriverVersion
    }

    $CnMetadata = Get-AmdCnMetadataSafe
    $ExtensionRecords = @()
    foreach ($Extension in @(Get-LenovoExtensionDrivers)) {
        $Text = ''
        $Hash = ''
        try { $Text = Get-Content -LiteralPath ([string]$Extension.OriginalFileName) -Raw -ErrorAction Stop } catch {}
        try { $Hash = Get-SHA256 -LiteralPath ([string]$Extension.OriginalFileName) } catch {}

        $TargetsLegionGo = ($Text -match 'VEN_1002&DEV_15BF&SUBSYS_381217AA')
        $SemanticMarkers = @(
            'DALNonStandardModesBCD5',
            'DALRestrictedModesBCD5',
            'HotkeysDisabled',
            'DFPFreeSyncDefault',
            'ToggleRsHotkey',
            'LCDFreeSyncDefault'
        )
        $MarkerPass = $TargetsLegionGo
        foreach ($Marker in $SemanticMarkers) {
            if ($Text.IndexOf($Marker,[StringComparison]::OrdinalIgnoreCase) -lt 0) {
                $MarkerPass = $false
                break
            }
        }

        $ExtensionRecords += [pscustomobject]@{
            TargetsLegionGo=$TargetsLegionGo
            SemanticCompatible=(
                $Hash -eq $Script:KnownLegacyLenovoExtensionSHA256 -or
                $MarkerPass
            )
            DriverVersion=[string]$Extension.Version
            PublishedInf=[string]$Extension.Driver
            SHA256=$Hash
        }
    }

    $ActiveInfText = ''
    try {
        if (-not [string]::IsNullOrWhiteSpace([string]$Gpu.InfPath)) {
            $ActiveInfText = Get-Content -LiteralPath ([string]$Gpu.InfPath) -Raw -ErrorAction Stop
        }
    } catch {}

    # Embedded semantics are release-specific: require the dedicated Legion Go
    # DDInstall family and Lenovo delta section, not merely registry-token names
    # that might also exist elsewhere in a generic AMD INF.
    $EmbeddedMarkers = @(
        'VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04',
        'ati2mtag_Phoenix_LegionGo',
        'LegionGo_26_7_1_Lenovo_Delta'
    )
    $EmbeddedPass = Test-EmbeddedLenovoSemantics -ActiveInfText $ActiveInfText -RequiredMarkers $EmbeddedMarkers

    # Exact prior-toolkit allowlist. This is deliberately cryptographic and
    # version-bound: it recognizes only the public 26.6.2 / 26.6.4 Legion Go
    # toolkit display bases. Those releases intentionally rely on a separate
    # Lenovo amduw23e extension, which the classifier validates independently.
    $VerifiedPriorToolkitDisplayPass = (
        (
            [string]$Gpu.InfSHA256 -eq $Script:KnownPublic2662InfSHA256 -and
            [string]$Gpu.DriverVersion -eq $Script:KnownPublic2662DriverVersion
        ) -or (
            [string]$Gpu.InfSHA256 -eq $Script:KnownPublic2664InfSHA256 -and
            [string]$Gpu.DriverVersion -eq $Script:KnownPublic2664DriverVersion
        )
    )

    return Resolve-LegionGoAmdOrigin `
        -Gpu $GpuContract `
        -CnMetadata $CnMetadata `
        -LenovoExtensions $ExtensionRecords `
        -EmbeddedLenovoSemanticsPass:$EmbeddedPass `
        -VerifiedPriorToolkitDisplayPass:$VerifiedPriorToolkitDisplayPass `
        -AllowGenericThirdPartyDisplay:$true
}

function Get-AmdDisplayDrivers {
    return @(Get-WindowsDriver -Online -All | Where-Object { $_.ClassName -eq 'Display' -and [string]$_.ProviderName -match 'AMD|Advanced Micro Devices' })
}

function Get-DisplayDriverInventory {
    $Rows = @()
    foreach ($Driver in @(Get-WindowsDriver -Online -All | Where-Object { $_.ClassName -eq 'Display' })) {
        $Hash = ''
        try {
            if (Test-Path -LiteralPath ([string]$Driver.OriginalFileName) -PathType Leaf) {
                $Hash = Get-SHA256 -LiteralPath ([string]$Driver.OriginalFileName)
            }
        } catch {}
        $TargetsLegionGo = $false
        try {
            $Text = Get-Content -LiteralPath ([string]$Driver.OriginalFileName) -Raw -ErrorAction Stop
            $TargetsLegionGo = ($Text -match 'VEN_1002&DEV_15BF&SUBSYS_381217AA')
        } catch {}
        $Rows += [pscustomobject]@{
            PublishedInf=[string]$Driver.Driver
            OriginalInf=[string]$Driver.OriginalFileName
            Provider=[string]$Driver.ProviderName
            Version=[string]$Driver.Version
            SHA256=$Hash
            TargetsLegionGo=$TargetsLegionGo
            IsFinalCandidate=($Hash -eq $Script:ExpectedFinalInfSHA256)
        }
    }
    return @($Rows)
}

function Invoke-ForceBindLegionGoDriver {
    param([Parameter(Mandatory=$true)][string]$InfPath)

    if (-not (Test-Path -LiteralPath $InfPath -PathType Leaf)) {
        throw "Force-bind INF is missing: $InfPath"
    }

    if (-not ('LegionGoDriverBindNativeRC2zk' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LegionGoDriverBindNativeRC2zk {
    [DllImport("newdev.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UpdateDriverForPlugAndPlayDevicesW(
        IntPtr hwndParent,
        string HardwareId,
        string FullInfPath,
        uint InstallFlags,
        out bool RebootRequired
    );
}
'@
    }

    $FullInfPath = [IO.Path]::GetFullPath($InfPath)
    [bool]$RebootRequired = $false
    $InstallFlagForce = [uint32]0x00000001

    $BindActivity='Explicit Legion Go GPU bind'
    Write-IndeterminateActivityProgress -Activity $BindActivity -Tick 0 -Elapsed '00:00' -Detail ("HardwareId={0}" -f $Script:LegionGoHardwareId)
    Set-ActivityLivenessContext -Activity $BindActivity -Status 'BINDING' -Detail 'Windows UpdateDriverForPlugAndPlayDevicesW is applying the exact candidate' -Indeterminate
    Write-Host ("[START] Explicitly binding {0} to {1}" -f $Script:LegionGoHardwareId,$FullInfPath)
    Enter-ConsoleSelectionProtection -Activity $BindActivity
    try {
        $Success = [LegionGoDriverBindNativeRC2zk]::UpdateDriverForPlugAndPlayDevicesW(
            [IntPtr]::Zero,
            $Script:LegionGoHardwareId,
            $FullInfPath,
            $InstallFlagForce,
            [ref]$RebootRequired
        )
        $Win32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    } finally {
        Exit-ConsoleSelectionProtection
    }

    Write-Host ("[DONE] Explicit bind success={0}; Win32Error={1}; RebootRequired={2}" -f $Success,$Win32Error,$RebootRequired)
    if ($Success) { Complete-ActivityProgress -Activity $BindActivity -Detail ("Win32Error={0}; RebootRequired={1}" -f $Win32Error,$RebootRequired) }

    if (-not $Success) {
        throw ("UpdateDriverForPlugAndPlayDevicesW failed. Win32Error={0}" -f $Win32Error)
    }

    return [pscustomobject]@{
        Success=$true
        Win32Error=$Win32Error
        RebootRequired=$RebootRequired
        HardwareId=$Script:LegionGoHardwareId
        InfPath=$FullInfPath
    }
}

function Get-LenovoExtensionDrivers {
    return @(Get-WindowsDriver -Online -All | Where-Object { [IO.Path]::GetFileName([string]$_.OriginalFileName) -ieq 'amduw23e.inf' })
}

function Resolve-DriverStoreRootForPublishedInf {
    param([Parameter(Mandatory=$true)][string]$PublishedInf)
    $Rows = @(Get-WindowsDriver -Online -All | Where-Object { [string]$_.Driver -ieq $PublishedInf })
    if ($Rows.Count -ne 1) { throw "Expected exactly one Driver Store row for $PublishedInf; found $($Rows.Count)." }
    $Original = [string]$Rows[0].OriginalFileName
    if (-not (Test-Path -LiteralPath $Original -PathType Leaf)) { throw "Driver Store INF path is missing: $Original" }
    return (Split-Path -Parent $Original)
}

function Get-CatalogFileNameFromInfLines {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string[]]$Lines)

    $Candidates = @()
    $LineNumber = 0
    foreach ($Line in $Lines) {
        $LineNumber++
        $Body = ([string]$Line -split ';',2)[0].Trim()
        if ([string]::IsNullOrWhiteSpace($Body)) { continue }

        $Match = [regex]::Match(
            $Body,
            '^(CatalogFile(?:\.[^=\s]+)?)\s*=\s*(.+?)\s*$',
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        if (-not $Match.Success) { continue }

        $Directive = [string]$Match.Groups[1].Value
        $Value = ([string]$Match.Groups[2].Value).Trim()
        if ($Value.Length -ge 2 -and $Value.StartsWith('"') -and $Value.EndsWith('"')) {
            $Value = $Value.Substring(1,$Value.Length-2).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($Value)) { throw "Empty $Directive directive at INF line $LineNumber." }

        $FileName = [IO.Path]::GetFileName($Value)
        if ($FileName -ne $Value -or [IO.Path]::IsPathRooted($Value)) {
            throw "CatalogFile directive must name a catalog in the INF repository root. Directive=$Directive Value=$Value"
        }
        if ([IO.Path]::GetExtension($FileName) -ine '.cat') {
            throw "CatalogFile directive does not reference a .cat file. Directive=$Directive Value=$Value"
        }

        $Score = 0
        if ($Directive -match '(?i)^CatalogFile\.NTamd64(?:\.|$)') {
            $Score = 400
        } elseif ($Directive -ieq 'CatalogFile') {
            $Score = 300
        } elseif ($Directive -match '(?i)^CatalogFile\.NT(?:\.|$)') {
            $Score = 200
        } elseif ($Directive -match '(?i)^CatalogFile\.NT(?:x86|arm|arm64)(?:\.|$)') {
            continue
        } else {
            $Score = 100
        }

        $Candidates += [pscustomobject]@{
            Directive = $Directive
            FileName = $FileName
            Score = $Score
            LineNumber = $LineNumber
        }
    }

    if ($Candidates.Count -eq 0) { throw 'Active Driver Store INF contains no applicable CatalogFile directive for x64 Windows.' }

    $BestScore = ($Candidates | Measure-Object -Property Score -Maximum).Maximum
    $Best = @($Candidates | Where-Object { $_.Score -eq $BestScore })
    $Names = @($Best | ForEach-Object { [string]$_.FileName } | Sort-Object -Unique)
    if ($Names.Count -ne 1) {
        $Detail = @($Best | ForEach-Object { '{0}={1}@{2}' -f $_.Directive,$_.FileName,$_.LineNumber }) -join ' | '
        throw "Ambiguous CatalogFile directives for x64 Windows: $Detail"
    }
    return [string]$Names[0]
}

function Resolve-DriverStoreCatalogForPublishedInf {
    param([Parameter(Mandatory=$true)][string]$PublishedInf)

    $Rows = @(Get-WindowsDriver -Online -All | Where-Object { [string]$_.Driver -ieq $PublishedInf })
    if ($Rows.Count -ne 1) { throw "Expected exactly one Driver Store row for $PublishedInf; found $($Rows.Count)." }

    $InfPath = [string]$Rows[0].OriginalFileName
    if (-not (Test-Path -LiteralPath $InfPath -PathType Leaf)) { throw "Driver Store INF path is missing: $InfPath" }

    $CatalogName = Get-CatalogFileNameFromInfLines -Lines @(Get-Content -LiteralPath $InfPath -ErrorAction Stop)
    $StoreRoot = Split-Path -Parent $InfPath
    $CatalogPath = Join-Path $StoreRoot $CatalogName
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "Active display catalog declared by $InfPath is missing: $CatalogPath"
    }

    return [pscustomobject]@{
        PublishedInf = $PublishedInf
        InfPath = $InfPath
        StoreRoot = $StoreRoot
        CatalogName = $CatalogName
        CatalogPath = $CatalogPath
    }
}

function Assert-FinalDriver {
    param(
        [Parameter(Mandatory=$true)]$Gpu,
        [string]$Activity = 'Verify exact active Legion Go driver'
    )
    Write-ActivityProgress -Activity $Activity -Percent 0 -Status 'VERIFYING' -Detail 'GPU health + driver version + INF + loaded kernel identity'
    Set-ActivityLivenessContext -Activity $Activity -Percent 10 -Status 'VERIFYING' -Detail 'validate live GPU health and exact package identities'
    if ($Gpu.Status -ne 'OK' -or $Gpu.ProblemCode -ne 0 -or [bool]$Gpu.HasProblem) { throw "GPU is not healthy: Status=$($Gpu.Status); ProblemCode=$($Gpu.ProblemCode); HasProblem=$($Gpu.HasProblem)" }
    if ($Gpu.DriverVersion -ne $Script:ExpectedDriverVersion) { throw "Driver version mismatch: $($Gpu.DriverVersion)" }
    if ($Gpu.InfSHA256 -ne $Script:ExpectedFinalInfSHA256) { throw "Active INF mismatch: $($Gpu.InfSHA256)" }
    if ($Gpu.KernelSHA256 -ne $Script:ExpectedKernelSHA256) { throw "Loaded kernel mismatch: $($Gpu.KernelSHA256)" }
    Write-ActivityProgress -Activity $Activity -Percent 30 -Status 'PASS' -Detail 'live GPU/INF/kernel identities exact'

    Set-ActivityLivenessContext -Activity $Activity -Percent 40 -Status 'RESOLVING' -Detail ("active Driver Store repository for {0}" -f [string]$Gpu.ActiveINF)
    Write-ActivityProgress -Activity $Activity -Percent 40 -Status 'RESOLVING' -Detail ("active Driver Store repository for {0}" -f [string]$Gpu.ActiveINF)
    $Root = Resolve-DriverStoreRootForPublishedInf -PublishedInf $Gpu.ActiveINF
    Write-ActivityProgress -Activity $Activity -Percent 70 -Status 'RESOLVED' -Detail $Root

    $Dat = Join-Path $Root 'B026283\amdgcf.dat'
    Set-ActivityLivenessContext -Activity $Activity -Percent 80 -Status 'HASHING' -Detail 'active B026283\amdgcf.dat'
    Write-ActivityProgress -Activity $Activity -Percent 80 -Status 'HASHING' -Detail 'active B026283\amdgcf.dat'
    if ((Get-SHA256 -LiteralPath $Dat) -ne $Script:ExpectedFinalDatSHA256) { throw 'Active amdgcf.dat hash mismatch.' }
    Complete-ActivityProgress -Activity $Activity -Detail 'GPU + INF + kernel + Driver Store DAT exact'
    return $Root
}

function Get-CertificateMatches {
    param([Parameter(Mandatory=$true)][string]$StorePath,[Parameter(Mandatory=$true)][string]$Thumbprint)
    return @(Get-ChildItem -LiteralPath $StorePath -ErrorAction SilentlyContinue | Where-Object { [string]$_.Thumbprint -eq $Thumbprint })
}

function Assert-PublicSignerTrust {
    param([Parameter(Mandatory=$true)][string]$Thumbprint)
    $Root = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\Root' -Thumbprint $Thumbprint)
    $Publisher = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\TrustedPublisher' -Thumbprint $Thumbprint)
    $My = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\My' -Thumbprint $Thumbprint)
    if ($Root.Count -lt 1 -or $Publisher.Count -lt 1) { throw 'Public signer certificate is not trusted in both Root and TrustedPublisher.' }
    if ($My.Count -ne 0) { throw 'Signing certificate still exists in LocalMachine\\My; private signing material must not persist.' }
    foreach ($Cert in @($Root + $Publisher)) { if ($Cert.HasPrivateKey) { throw 'A retained public signer certificate unexpectedly exposes a private key.' } }
}

function Assert-SignerTrustAbsent {
    param([Parameter(Mandatory=$true)][string]$Thumbprint)
    if ([string]::IsNullOrWhiteSpace($Thumbprint)) { throw 'Signer thumbprint is empty; refusing an ambiguous trust-store assertion.' }
    $Root = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\Root' -Thumbprint $Thumbprint)
    $Publisher = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\TrustedPublisher' -Thumbprint $Thumbprint)
    $My = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\My' -Thumbprint $Thumbprint)
    if ($Root.Count -ne 0 -or $Publisher.Count -ne 0 -or $My.Count -ne 0) {
        throw ("Signer certificate is not fully absent. Thumbprint={0}; Root={1}; TrustedPublisher={2}; My={3}" -f $Thumbprint,$Root.Count,$Publisher.Count,$My.Count)
    }
}

function Ensure-ExactPublicSignerTrustRemoved {
    param(
        [Parameter(Mandatory=$true)][string]$Thumbprint,
        [Parameter(Mandatory=$true)][string]$ExpectedActiveSignerThumbprint
    )
    if ([string]::IsNullOrWhiteSpace($Thumbprint) -or [string]::IsNullOrWhiteSpace($ExpectedActiveSignerThumbprint)) {
        throw 'Signer cleanup identities are incomplete; refusing an ambiguous trust-store change.'
    }
    if ($Thumbprint -eq $ExpectedActiveSignerThumbprint) {
        throw 'Refusing to remove signer trust because the Stage 1 signer equals the expected active catalog signer.'
    }

    # The active retained signer must be validly trusted before and after any
    # cleanup. Only the exact current-run Stage 1 thumbprint is eligible.
    Assert-PublicSignerTrust -Thumbprint $ExpectedActiveSignerThumbprint

    $My = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\My' -Thumbprint $Thumbprint)
    if ($My.Count -ne 0) { throw 'Current-run Stage 1 signer still exists in LocalMachine\\My; refusing public-trust cleanup while private signing material may remain.' }

    $Root = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\Root' -Thumbprint $Thumbprint)
    $Publisher = @(Get-CertificateMatches -StorePath 'Cert:\LocalMachine\TrustedPublisher' -Thumbprint $Thumbprint)
    foreach ($Cert in @($Root + $Publisher)) {
        if ($Cert.HasPrivateKey) { throw 'Current-run Stage 1 signer unexpectedly exposes a private key in a public trust store.' }
    }

    $Removed = 0
    foreach ($Cert in $Root) {
        Remove-Item -LiteralPath ([string]$Cert.PSPath) -Force -ErrorAction Stop
        $Removed++
    }
    foreach ($Cert in $Publisher) {
        Remove-Item -LiteralPath ([string]$Cert.PSPath) -Force -ErrorAction Stop
        $Removed++
    }

    Assert-SignerTrustAbsent -Thumbprint $Thumbprint
    Assert-PublicSignerTrust -Thumbprint $ExpectedActiveSignerThumbprint
    return $Removed
}

function Get-MsiProductState {
    param([Parameter(Mandatory=$true)][string]$ProductCode)
    $Installer = $null
    try { $Installer = New-Object -ComObject WindowsInstaller.Installer; return [int]$Installer.ProductState($ProductCode) }
    finally { if ($null -ne $Installer) { try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Installer) } catch {} } }
}

function Get-MsiPropertyMap {
    param([Parameter(Mandatory=$true)][string]$LiteralPath)
    $Installer=$null; $Database=$null; $View=$null; $Record=$null; $Map=[ordered]@{}
    try {
        $Installer = New-Object -ComObject WindowsInstaller.Installer
        $Database = $Installer.OpenDatabase($LiteralPath,0)
        $View = $Database.OpenView('SELECT `Property`,`Value` FROM `Property`')
        [void]$View.Execute()
        while ($true) {
            $Record=$View.Fetch(); if ($null -eq $Record) { break }
            $Map[[string]$Record.StringData(1)] = [string]$Record.StringData(2)
            try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Record) } catch {}; $Record=$null
        }
    } finally {
        foreach ($Obj in @($Record,$View,$Database,$Installer)) { if ($null -ne $Obj) { try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Obj) } catch {} } }
    }
    return $Map
}
