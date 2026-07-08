#requires -Version 5.1
<#
.SYNOPSIS
    Script 2 of 4 for the Legion Go AMD 26.6.2 Toolkit.

.DESCRIPTION
    Installs the corrected AMD 26.6.2 display driver, disables Test Signing
    for the next Windows boot, and verifies the driver after restart under
    normal Windows signing.

    First run:
      - verifies Script 1 state and the current Lenovo OEM baseline;
      - requires explicit approval before modifying the installed driver;
      - installs and force-binds the corrected driver;
      - registers AMD's exact Microsoft-signed catalog with the exact
        Microsoft SignTool verified by Script 1;
      - configures Test Signing OFF for the next boot; and
      - requires explicit approval before restarting Windows.

    Run after restart:
      - verifies the live driver, INF, loaded kernel, GPU health, catalog,
        certificate trust, Lenovo extension, AMDUWP component, and signing
        state; and
      - records readiness for Script 3.

    Saved JSON alone is never treated as proof of completion. Script 2 also
    verifies the currently active GPU binding, INF hash, loaded kernel hash,
    GPU status, current boot, and Test Signing state.

    All embedded PowerShell components are stored as readable plain text and
    verified against their declared SHA-256 identities before execution.

.NOTES
    Public Candidate R3: minimal Script 2 correction for catalog registration.
    Phase 2 and the security-hardening library are unchanged from v1.0.

    Unofficial community toolkit. This script modifies the installed display
    driver, Driver Store, certificate trust stores, catalog registration, and
    Windows boot-signing configuration. Use at your own risk.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StateRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'
$InternalRoot = Join-Path $StateRoot 'Toolkit-Script-02\Internal'
$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$InstallResultPath = Join-Path $StateRoot 'driver-install-result.json'
$ValidationResultPath = Join-Path $StateRoot 'post-testsigning-validation.json'
$BootPreparationResultPath =
    Join-Path $StateRoot 'boot-preparation-result.json'
$PayloadVerificationPath =
    Join-Path $StateRoot 'payload-verification.json'
$CatalogSigningStatePath =
    Join-Path $StateRoot 'catalog-signing-state.json'

$ExpectedDriverVersion = '32.0.31021.1015'
$ExpectedInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'
$ExpectedKernelHash =
    'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'
$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'

function Test-IsAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal =
        New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Quote-NativeArgument {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

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

function Get-SHA256 {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    return (
        Get-FileHash `
            -LiteralPath $LiteralPath `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()
}

function Write-AtomicBytes {
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes,

        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $Directory = Split-Path -Parent $LiteralPath
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $TemporaryPath =
        $LiteralPath + '.tmp-' + [guid]::NewGuid().ToString('N')

    try {
        [IO.File]::WriteAllBytes($TemporaryPath, $Bytes)
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

function Convert-PlainTextPayloadToBytes {
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    $Parts = @($Entry.ContentParts)

    if ($Parts.Count -eq 0) {
        throw 'Embedded plain-text payload contains no content parts.'
    }

    $NormalizedParts = @(
        foreach ($Part in $Parts) {
            $PartText = ([string]$Part) -replace "`r`n", "`n"
            $PartText -replace "`r", "`n"
        }
    )

    $Text = $NormalizedParts -join "`n"

    if ([bool]$Entry.TrailingNewline) {
        $Text += "`n"
    }

    switch ([string]$Entry.LineEnding) {
        'LF' { break }
        'CRLF' {
            $Text = $Text -replace "`n", "`r`n"
            break
        }
        default {
            throw (
                'Unsupported embedded payload line-ending value: ' +
                [string]$Entry.LineEnding
            )
        }
    }

    $Encoding = [Text.UTF8Encoding]::new([bool]$Entry.Utf8Bom)
    $Preamble = $Encoding.GetPreamble()
    $ContentBytes = $Encoding.GetBytes($Text)
    $Bytes =
        New-Object byte[] ($Preamble.Length + $ContentBytes.Length)

    if ($Preamble.Length -gt 0) {
        [Buffer]::BlockCopy(
            $Preamble,
            0,
            $Bytes,
            0,
            $Preamble.Length
        )
    }

    if ($ContentBytes.Length -gt 0) {
        [Buffer]::BlockCopy(
            $ContentBytes,
            0,
            $Bytes,
            $Preamble.Length,
            $ContentBytes.Length
        )
    }

    return $Bytes
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

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

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Property = $Object.PSObject.Properties[$Name]

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function Convert-ToDateTime {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    try {
        return [datetime]$Value
    }
    catch {
        return $null
    }
}

function Resolve-KernelPath {
    param(
        [Parameter(Mandatory)]
        [string]$RawPath
    )

    $Resolved = $RawPath.Trim('"')
    $Resolved = $Resolved -replace '^(?i)\\SystemRoot', $env:windir
    $Resolved = $Resolved -replace '^(?i)System32\\', "$env:windir\System32\"
    $Resolved = $Resolved -replace '^(?i)\\\?\?\\', ''
    return $Resolved
}

function Get-LiveDriverState {
    try {
        $Devices = @(
            Get-CimInstance Win32_PnPEntity |
                Where-Object DeviceID -Like $GpuPattern
        )

        if ($Devices.Count -ne 1) {
            throw (
                'Expected exactly one Legion Go GPU device; found ' +
                $Devices.Count + '.'
            )
        }

        $Device = $Devices[0]
        $EnumPath =
            'HKLM:\SYSTEM\CurrentControlSet\Enum\' +
            [string]$Device.DeviceID
        $EnumValues = Get-ItemProperty -LiteralPath $EnumPath
        $ClassDriverKey = [string]$EnumValues.Driver

        if ([string]::IsNullOrWhiteSpace($ClassDriverKey)) {
            throw 'The Legion Go GPU has no active class-driver binding.'
        }

        $ClassPath =
            'HKLM:\SYSTEM\CurrentControlSet\Control\Class\' +
            $ClassDriverKey
        $ClassValues = Get-ItemProperty -LiteralPath $ClassPath
        $InfName = [string]$ClassValues.InfPath
        $DriverVersion = [string]$ClassValues.DriverVersion
        $ActiveInfPath = Join-Path $env:windir "INF\$InfName"

        if (-not (Test-Path -LiteralPath $ActiveInfPath -PathType Leaf)) {
            throw "Active GPU INF is missing: $ActiveInfPath"
        }

        $ServiceName = [string]$EnumValues.Service

        if ([string]::IsNullOrWhiteSpace($ServiceName)) {
            throw 'The Legion Go GPU has no kernel-service assignment.'
        }

        $KernelService =
            Get-CimInstance Win32_SystemDriver |
                Where-Object Name -EQ $ServiceName |
                Select-Object -First 1

        if ($null -eq $KernelService) {
            throw "GPU kernel service is missing: $ServiceName"
        }

        $KernelPath =
            Resolve-KernelPath -RawPath ([string]$KernelService.PathName)

        if (-not (Test-Path -LiteralPath $KernelPath -PathType Leaf)) {
            throw "Running GPU kernel file is missing: $KernelPath"
        }

        return [pscustomobject]@{
            QuerySucceeded = $true
            DeviceName = [string]$Device.Name
            DeviceID = [string]$Device.DeviceID
            ActiveINF = $InfName
            DriverVersion = $DriverVersion
            ActiveInfPath = $ActiveInfPath
            ActiveInfSHA256 = Get-SHA256 -LiteralPath $ActiveInfPath
            KernelService = $ServiceName
            KernelState = [string]$KernelService.State
            KernelStarted = [bool]$KernelService.Started
            KernelPath = $KernelPath
            KernelSHA256 = Get-SHA256 -LiteralPath $KernelPath
            Status = [string]$Device.Status
            ProblemCode = [int]$Device.ConfigManagerErrorCode
            Error = $null
        }
    }
    catch {
        return [pscustomobject]@{
            QuerySucceeded = $false
            DeviceName = $null
            DeviceID = $null
            ActiveINF = $null
            DriverVersion = $null
            ActiveInfPath = $null
            ActiveInfSHA256 = $null
            KernelService = $null
            KernelState = $null
            KernelStarted = $false
            KernelPath = $null
            KernelSHA256 = $null
            Status = $null
            ProblemCode = $null
            Error = $_.Exception.Message
        }
    }
}

function Get-BootSigningState {
    $BcdOutput = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    $BcdQuerySucceeded = ($LASTEXITCODE -eq 0)
    $Configured =
        $BcdQuerySucceeded -and
        $BcdOutput -match '(?im)^\s*testsigning\s+Yes\s*$'

    $SystemStartOptions = ''
    $ActiveKnown = $false
    $Active = $false

    try {
        $SystemStartOptions =
            [string](
                Get-ItemPropertyValue `
                    -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control' `
                    -Name 'SystemStartOptions' `
                    -ErrorAction Stop
            )
        $ActiveKnown = $true
        $Active =
            $SystemStartOptions -match
                '(?i)(^|\s)TESTSIGNING($|\s)'
    }
    catch {
        $ActiveKnown = $false
    }

    return [pscustomobject]@{
        BcdQuerySucceeded = [bool]$BcdQuerySucceeded
        Configured = [bool]$Configured
        ActiveKnown = [bool]$ActiveKnown
        Active = [bool]$Active
        SystemStartOptions = $SystemStartOptions
    }
}

function Test-LiveTargetDriver {
    param(
        [Parameter(Mandatory)]
        $LiveState
    )

    return (
        [bool]$LiveState.QuerySucceeded -and
        [string]$LiveState.DriverVersion -eq $ExpectedDriverVersion -and
        [string]$LiveState.ActiveInfSHA256 -eq $ExpectedInfHash -and
        [string]$LiveState.KernelSHA256 -eq $ExpectedKernelHash -and
        [string]$LiveState.KernelState -eq 'Running' -and
        [bool]$LiveState.KernelStarted -and
        [string]$LiveState.Status -eq 'OK' -and
        [int]$LiveState.ProblemCode -eq 0
    )
}

function Test-Phase01Complete {
    $Result = Read-JsonFile -LiteralPath $InstallResultPath

    if ($null -eq $Result) {
        return $false
    }

    $LiveState = Get-LiveDriverState

    return (
        [bool](Get-OptionalProperty -Object $Result -Name 'Installed') -and
        [string](Get-OptionalProperty -Object $Result -Name 'DriverVersion') -eq
            $ExpectedDriverVersion -and
        [string](Get-OptionalProperty -Object $Result -Name 'ActiveInfSHA256') -eq
            $ExpectedInfHash -and
        [string](Get-OptionalProperty -Object $Result -Name 'KernelSHA256') -eq
            $ExpectedKernelHash -and
        [bool](Get-OptionalProperty -Object $Result -Name 'TestSigningConfiguredOffNextBoot') -and
        (Test-LiveTargetDriver -LiveState $LiveState)
    )
}

function Test-Phase02Complete {
    $Validation = Read-JsonFile -LiteralPath $ValidationResultPath
    $Install = Read-JsonFile -LiteralPath $InstallResultPath

    if ($null -eq $Validation -or $null -eq $Install) {
        return $false
    }

    $InstalledAt =
        Convert-ToDateTime -Value (
            Get-OptionalProperty -Object $Install -Name 'InstalledAt'
        )
    $ValidatedAt =
        Convert-ToDateTime -Value (
            Get-OptionalProperty -Object $Validation -Name 'ValidatedAt'
        )
    $CurrentBoot =
        (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $LiveState = Get-LiveDriverState
    $SigningState = Get-BootSigningState

    if (
        $null -eq $InstalledAt -or
        $null -eq $ValidatedAt
    ) {
        return $false
    }

    return (
        [bool](Get-OptionalProperty -Object $Validation -Name 'Validated') -and
        [bool](Get-OptionalProperty -Object $Validation -Name 'RebootAfterStage03Confirmed') -and
        -not [bool](Get-OptionalProperty -Object $Validation -Name 'TestSigningEnabled') -and
        [string](Get-OptionalProperty -Object $Validation -Name 'DriverVersion') -eq
            $ExpectedDriverVersion -and
        [string](Get-OptionalProperty -Object $Validation -Name 'ActiveInfSHA256') -eq
            $ExpectedInfHash -and
        [string](Get-OptionalProperty -Object $Validation -Name 'KernelSHA256') -eq
            $ExpectedKernelHash -and
        [bool](Get-OptionalProperty -Object $Validation -Name 'LenovoExtensionAttached') -and
        [bool](Get-OptionalProperty -Object $Validation -Name 'AMDUWPHealthy') -and
        $ValidatedAt -gt $InstalledAt -and
        $CurrentBoot -gt $InstalledAt -and
        (Test-LiveTargetDriver -LiveState $LiveState) -and
        [bool]$SigningState.BcdQuerySucceeded -and
        -not [bool]$SigningState.Configured -and
        [bool]$SigningState.ActiveKnown -and
        -not [bool]$SigningState.Active
    )
}

function Invoke-InternalPhase {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter()]
        [string[]]$PhaseArguments = @()
    )

    if (-not (Test-Path -LiteralPath $WindowsPowerShell -PathType Leaf)) {
        throw "Windows PowerShell 5.1 is missing: $WindowsPowerShell"
    }

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Internal phase script is missing: $ScriptPath"
    }

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host $DisplayName -ForegroundColor White
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host ''

    & $WindowsPowerShell `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ScriptPath `
        @PhaseArguments

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        throw "$DisplayName failed with exit code $ExitCode."
    }
}

function Write-RerunCommand {
    Write-Host (
        'PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File ' +
        ('"{0}"' -f $PSCommandPath)
    ) -ForegroundColor Cyan
}

function Request-WindowsRestart {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host 'SCRIPT 2: WINDOWS RESTART REQUIRED' -ForegroundColor Yellow
    Write-Host ''
    Write-Host (
        'The corrected driver is installed and Test Signing is configured ' +
        'OFF for the next boot.'
    )
    Write-Host (
        'Save your work and close open applications before restarting.'
    ) -ForegroundColor Yellow

    if (-not (Confirm-UserAction -Prompt 'Restart Windows now?')) {
        Write-Host ''
        Write-Host '[INFO] Restart declined. Script 2 remains pending.'
        Write-Host 'Restart Windows normally, then rerun Script 2:'
        Write-RerunCommand
        Write-Host ('=' * 72) -ForegroundColor White
        return
    }

    & shutdown.exe `
        /r `
        /t 10 `
        /c (
            'Legion Go AMD 26.6.2 Toolkit: restarting to verify the ' +
            'corrected driver under normal signing.'
        )

    if ($LASTEXITCODE -ne 0) {
        throw (
            'Failed to schedule the Windows restart. Exit code: ' +
            $LASTEXITCODE
        )
    }

    Write-Host '[PASS] Windows restart scheduled for 10 seconds.'
    Write-Host 'After sign-in, rerun Script 2:'
    Write-RerunCommand
    Write-Host ('=' * 72) -ForegroundColor White
}

function Write-Script02Pass {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host 'SCRIPT 2 PASS: True' -ForegroundColor Green
    Write-Host 'Ready for Script 3: True' -ForegroundColor Green
    Write-Host "Result file: $ValidationResultPath"
    Write-Host ('=' * 72) -ForegroundColor White
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    return
}

$EmbeddedPayload = [ordered]@{
    # Readable plain-text components for Script 2.
    'Phase-01-Install-Corrected-Driver.ps1' = [ordered]@{
        SHA256 = '36F7F50DD49A5CC78F5A73E5E31EAEA4269136F1047927573358F3A5A321C50F'
        Utf8Bom = $true
        LineEnding = 'CRLF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 1 of Script 2 in the Legion Go AMD 26.6.2 Toolkit.

Preconditions:
  - Script 1 completed: the canonical 125-file package was
    reproduced, a unique per-user catalog was generated and signed, and
    verification state was written.
  - Script 1 completed its Windows restart: Secure Boot is OFF and the
    current boot occurred after Test Signing was configured ON.
  - The original Lenovo OEM graphics baseline 32.0.23017.1001 is active,
    unless this exact target driver is already active from a partial rerun.

Actions:
  - Load the verified build and per-user signing state dynamically.
  - Resolve the signed package, public certificate, original AMD catalog,
    and separate official CCC2 asset.
  - Verify the fixed canonical files and dynamic local CAT/certificate pair.
  - Confirm CCC2 is not embedded in the signed driver package.
  - Normalize and preserve catalog-signing-state.json for later scripts.
  - Verify the Lenovo OEM baseline and required extension.
  - Import the per-user public certificate into LocalMachine Root and
    TrustedPublisher.
  - Stage and force-bind the corrected AMD 26.6.2 display package.
  - Verify the active GPU and loaded kernel driver.
  - Register AMD's exact Microsoft-signed original catalog with the exact
    Microsoft SignTool selected and verified by Script 1.
  - Confirm registration against the loaded kernel through the catalog API.
  - Configure Test Signing OFF for the next boot.
  - Save workflow state and return restart control to Script 2.

This stage does not install AMD Software and does not enable Secure Boot.
#>

[CmdletBinding()]
param(
    [string]$VerificationResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\payload-verification.json',

    [string]$CatalogSigningStatePath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\catalog-signing-state.json',

    [string]$BootPreparationResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\boot-preparation-result.json',

    [string]$SignedPackageRoot,

    [string]$PublicCertificatePath,

    [string]$OfficialCatalogPath,

    [string]$OfficialCcc2Path,

    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
Set-StrictMode -Version 2.0

$WorkflowRoot = 'C:\ProgramData\LegionGo-AMD-26.6.2'
$StatePath = Join-Path $WorkflowRoot 'workflow-state.json'
$ResultPath = Join-Path $WorkflowRoot 'driver-install-result.json'
$LogRoot = Join-Path $WorkflowRoot 'Logs'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogPath = Join-Path $LogRoot "03-Install-Driver-$Timestamp.log"
$PnPInventoryPath =
    Join-Path $LogRoot "03-PnP-Driver-Inventory-$Timestamp.xml"

$ExpectedInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'

$ExpectedKernelHash =
    'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'

$ExpectedAmgcfHash =
    'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'

$ExpectedAtiicdxxHash =
    'DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F'

$ExpectedCcc2Hash =
    '804BB7C852E2003948D5945C99058DB58080D41692CF36CE6BDD6FC93E2ACC48'

$ExpectedCcc2Length = [int64]242517520

$ExpectedOfficialCatalogHash =
    '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'

$ExpectedTargetVersion = '32.0.31021.1015'
$ExpectedOemVersion = '32.0.23017.1001'
$ExpectedOemInfHash =
    '2F337E2DAD0FC1371203A846D9F0AB6EAA3FE056704956C38244D05E1E7ADB22'

$ExpectedExtensionName = 'amduw23e.inf'
$ExpectedExtensionVersion = '32.0.23017.1001'
$ExpectedExtensionClassGuid = '{e2f84ce7-8efa-411c-aa69-97454ca4cb57}'

$HardwareId = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'
$GpuHardwareToken = 'VEN_1002&DEV_15BF&SUBSYS_381217AA'

$WorkflowAcl = Protect-WorkflowStateDirectory -Path $WorkflowRoot

New-Item -ItemType Directory -Path $WorkflowRoot, $LogRoot -Force | Out-Null
Start-Transcript -LiteralPath $LogPath -Force | Out-Null

function Get-SHA256 {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    return (
        Get-FileHash `
            -LiteralPath $LiteralPath `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()
}

function Assert-Hash {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [string]$ExpectedHash,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "$Label is missing: $LiteralPath"
    }

    $ActualHash = Get-SHA256 -LiteralPath $LiteralPath

    if ($ActualHash -ne $ExpectedHash.ToUpperInvariant()) {
        throw (
            "$Label hash mismatch.`n" +
            "Expected: $ExpectedHash`n" +
            "Actual:   $ActualHash`n" +
            "Path:     $LiteralPath"
        )
    }

    Write-Host "[PASS] $Label"
    Write-Host "       $ActualHash"

    return $ActualHash
}

function Get-OptionalProperty {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
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

function Get-FirstPropertyValue {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {
        $Value = Get-OptionalProperty -Object $Object -Name $Name

        if ($null -eq $Value) {
            continue
        }

        if (
            $Value -is [string] -and
            [string]::IsNullOrWhiteSpace([string]$Value)
        ) {
            continue
        }

        return $Value
    }

    return $null
}

function Test-RecordedSuccess {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    $Text = ([string]$Value).Trim()

    return $Text -match '^(?i:true|yes|passed|success|complete|verified)$'
}

function Convert-ToFullPath {
    param(
        [AllowNull()]
        [string]$Path,

        [AllowNull()]
        [string]$BasePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $Expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())

    if ([IO.Path]::IsPathRooted($Expanded)) {
        return [IO.Path]::GetFullPath($Expanded)
    }

    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return [IO.Path]::GetFullPath((Join-Path $BasePath $Expanded))
    }

    return [IO.Path]::GetFullPath($Expanded)
}

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory)]
        [string[]]$Candidates,

        [string]$ExpectedHash
    )

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        $FullPath = Convert-ToFullPath -Path $Candidate -BasePath $null

        if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
            $ActualHash = Get-SHA256 -LiteralPath $FullPath

            if ($ActualHash -ne $ExpectedHash.ToUpperInvariant()) {
                continue
            }
        }

        return $FullPath
    }

    return $null
}

function Resolve-ExistingDirectory {
    param(
        [Parameter(Mandatory)]
        [string[]]$Candidates
    )

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        $FullPath = Convert-ToFullPath -Path $Candidate -BasePath $null

        if (Test-Path -LiteralPath $FullPath -PathType Container) {
            return $FullPath
        }
    }

    return $null
}

function Resolve-DriverPackageRoot {
    param(
        [AllowNull()]
        [string]$ExplicitRoot,

        [AllowNull()]
        $SigningState,

        [AllowNull()]
        $VerificationState
    )

    $Candidates = @(
        $ExplicitRoot
        (Get-FirstPropertyValue -Object $SigningState -Names @(
            'PackageRoot'
            'SignedPackageRoot'
            'OutputPackageRoot'
            'SignedOutputRoot'
            'DriverPackageRoot'
            'PackagePath'
        ))
        (Get-FirstPropertyValue -Object $VerificationState -Names @(
            'PackageRoot'
            'SignedPackageRoot'
            'OutputPackageRoot'
            'DriverPackageRoot'
            'PayloadRoot'
            'PackagePath'
        ))
    )

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace([string]$Candidate)) {
            continue
        }

        $CandidatePath = Convert-ToFullPath `
            -Path ([string]$Candidate) `
            -BasePath $null

        $DirectInf = Join-Path $CandidatePath 'u0201589.inf'
        $LegacyInf = Join-Path $CandidatePath 'Driver\u0201589.inf'

        if (Test-Path -LiteralPath $DirectInf -PathType Leaf) {
            return $CandidatePath
        }

        if (Test-Path -LiteralPath $LegacyInf -PathType Leaf) {
            return (Split-Path -LiteralPath $LegacyInf -Parent)
        }
    }

    throw (
        'Unable to resolve the signed driver package root. ' +
        'Supply -SignedPackageRoot or ensure the verification/signing JSON ' +
        'contains PackageRoot, SignedPackageRoot, OutputPackageRoot, ' +
        'DriverPackageRoot, PayloadRoot, or PackagePath.'
    )
}

function Get-GpuDriver {
    # Win32_PnPSignedDriver can retain the previous display-driver record for
    # several minutes after UpdateDriverForPlugAndPlayDevicesW succeeds.
    # Resolve the device instance through Win32_PnPEntity, but read the active
    # INF and driver version from the live Enum/Class registry binding.
    $Devices = @(
        Get-CimInstance Win32_PnPEntity |
            Where-Object DeviceID -Like $GpuPattern
    )

    if ($Devices.Count -ne 1) {
        throw (
            'Expected exactly one Legion Go GPU device; found ' +
            $Devices.Count + '.'
        )
    }

    $Device = $Devices[0]
    $EnumPath =
        'HKLM:\SYSTEM\CurrentControlSet\Enum\' +
        [string]$Device.DeviceID

    $EnumValues = Get-ItemProperty -LiteralPath $EnumPath
    $ClassDriverKey = [string]$EnumValues.Driver

    if ([string]::IsNullOrWhiteSpace($ClassDriverKey)) {
        throw 'The Legion Go GPU has no active class-driver binding.'
    }

    $ClassPath =
        'HKLM:\SYSTEM\CurrentControlSet\Control\Class\' +
        $ClassDriverKey

    $ClassValues = Get-ItemProperty -LiteralPath $ClassPath
    $InfName = [string]$ClassValues.InfPath
    $DriverVersion = [string]$ClassValues.DriverVersion

    if (
        [string]::IsNullOrWhiteSpace($InfName) -or
        [string]::IsNullOrWhiteSpace($DriverVersion)
    ) {
        throw (
            'The live Legion Go GPU class binding is missing InfPath or ' +
            'DriverVersion.'
        )
    }

    return [pscustomobject]@{
        DeviceName    = [string]$Device.Name
        DeviceID      = [string]$Device.DeviceID
        InfName       = $InfName
        DriverVersion = $DriverVersion
    }
}

function Get-GpuEntity {
    $Matches = @(
        Get-CimInstance Win32_PnPEntity |
            Where-Object DeviceID -Like $GpuPattern
    )

    if ($Matches.Count -ne 1) {
        throw (
            'Expected exactly one Legion Go GPU device; found ' +
            $Matches.Count + '.'
        )
    }

    return $Matches[0]
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
            MatchingRecords = @()
            InventoryPath = $PnPInventoryPath
        }
    }

    [xml]$Inventory = Get-Content -LiteralPath $PnPInventoryPath -Raw

    # Current Windows builds emit title-cased XML element names. XPath
    # local-name comparisons are case-sensitive, so accept both forms.
    $DriverNodes = @(
        $Inventory.SelectNodes(
            '//*[local-name()="Driver" or local-name()="driver"]'
        )
    )

    if ($DriverNodes.Count -eq 0) {
        if ($null -ne $Inventory.PnpUtil) {
            $DriverNodes = @($Inventory.PnpUtil.Driver)
        }
        elseif ($null -ne $Inventory.pnputil) {
            $DriverNodes = @($Inventory.pnputil.driver)
        }
    }

    $MatchingRecords = @()

    foreach ($DriverNode in $DriverNodes) {
        $OriginalName = [string]$DriverNode.OriginalName
        $DriverVersionText = [string]$DriverNode.DriverVersion
        $ClassGuid = [string]$DriverNode.ClassGuid

        $DeviceNodes = @(
            $DriverNode.SelectNodes(
                './*[local-name()="Devices" or local-name()="devices"]' +
                '/*[local-name()="Device" or local-name()="device"]'
            )
        )

        $MatchingDeviceIds = @()

        foreach ($DeviceNode in $DeviceNodes) {
            $InstanceId = [string]$DeviceNode.GetAttribute('InstanceId')

            if (
                -not [string]::IsNullOrWhiteSpace($InstanceId) -and
                (
                    $InstanceId -ieq $DeviceInstanceId -or
                    $InstanceId -like "*$GpuHardwareToken*"
                )
            ) {
                $MatchingDeviceIds += $InstanceId
            }
        }

        $NameMatch =
            $OriginalName -ieq $ExpectedExtensionName

        $VersionMatch =
            $DriverVersionText -match [regex]::Escape(
                $ExpectedExtensionVersion
            )

        $ClassMatch =
            $ClassGuid -ieq $ExpectedExtensionClassGuid

        $DeviceMatch = $MatchingDeviceIds.Count -gt 0

        if ($NameMatch -and $VersionMatch -and $ClassMatch -and $DeviceMatch) {
            $MatchingRecords += [pscustomobject]@{
                PublishedName = [string]$DriverNode.GetAttribute('DriverName')
                OriginalName = $OriginalName
                Version = $ExpectedExtensionVersion
                VersionText = $DriverVersionText
                ClassGuid = $ClassGuid
                DeviceIDs = $MatchingDeviceIds
                RawXml = [string]$DriverNode.OuterXml
            }
        }
    }

    return [pscustomobject]@{
        InventoryCreated = $true
        ExitCode = $Process.ExitCode
        Attached = ($MatchingRecords.Count -gt 0)
        MatchingRecords = $MatchingRecords
        InventoryPath = $PnPInventoryPath
    }
}

function Resolve-KernelPath {
    param(
        [Parameter(Mandatory)]
        [string]$RawPath
    )

    $Resolved = $RawPath.Trim('"')
    $Resolved = $Resolved -replace '^(?i)\\SystemRoot', $env:windir
    $Resolved = $Resolved -replace '^(?i)System32\\', "$env:windir\System32\"
    $Resolved = $Resolved -replace '^(?i)\\\?\?\\', ''

    return $Resolved
}

function Find-ExactCatalog {
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedHash,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$CandidateFiles,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$SearchRoots
    )

    $Matches = New-Object 'System.Collections.Generic.List[string]'

    foreach ($Candidate in $CandidateFiles) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        $FullPath = Convert-ToFullPath -Path $Candidate -BasePath $null

        if (
            (Test-Path -LiteralPath $FullPath -PathType Leaf) -and
            (Get-SHA256 -LiteralPath $FullPath) -eq $ExpectedHash
        ) {
            $Matches.Add($FullPath)
        }
    }

    foreach ($Root in $SearchRoots) {
        if ([string]::IsNullOrWhiteSpace($Root)) {
            continue
        }

        $FullRoot = Convert-ToFullPath -Path $Root -BasePath $null

        if (-not (Test-Path -LiteralPath $FullRoot -PathType Container)) {
            continue
        }

        foreach ($Catalog in (
            Get-ChildItem `
                -LiteralPath $FullRoot `
                -Recurse `
                -File `
                -Filter '*.cat' `
                -ErrorAction SilentlyContinue
        )) {
            if ((Get-SHA256 -LiteralPath $Catalog.FullName) -eq $ExpectedHash) {
                $Matches.Add($Catalog.FullName)
            }
        }
    }

    $Unique = @(
        $Matches |
            Sort-Object -Unique
    )

    if ($Unique.Count -lt 1) {
        return $null
    }

    return $Unique[0]
}

function Find-PublicCertificate {
    param(
        [AllowNull()]
        [string]$ExplicitPath,

        [AllowNull()]
        $SigningState,

        [AllowNull()]
        $VerificationState,

        [Parameter(Mandatory)]
        [string]$PackageRoot,

        [AllowNull()]
        [string]$ExpectedThumbprint
    )

    $Candidates = @(
        $ExplicitPath
        (Get-FirstPropertyValue -Object $SigningState -Names @(
            'CertificatePath'
            'PublicCertificatePath'
            'CertificateCERPath'
            'CerPath'
            'PublicCerPath'
        ))
        (Get-FirstPropertyValue -Object $VerificationState -Names @(
            'CertificatePath'
            'PublicCertificatePath'
            'CertificateCERPath'
            'CerPath'
            'PublicCerPath'
        ))
    )

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace([string]$Candidate)) {
            continue
        }

        $FullPath = Convert-ToFullPath `
            -Path ([string]$Candidate) `
            -BasePath $null

        if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
            continue
        }

        try {
            $Certificate =
                [Security.Cryptography.X509Certificates.X509Certificate2]::new(
                    $FullPath
                )
        }
        catch {
            continue
        }

        if (
            [string]::IsNullOrWhiteSpace($ExpectedThumbprint) -or
            $Certificate.Thumbprint -eq $ExpectedThumbprint
        ) {
            return $FullPath
        }
    }

    $SearchRoots = @(
        (Split-Path -LiteralPath $PackageRoot -Parent)
        $PackageRoot
    ) |
        Sort-Object -Unique

    foreach ($Root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
            continue
        }

        foreach ($Cer in (
            Get-ChildItem `
                -LiteralPath $Root `
                -Recurse `
                -File `
                -Filter '*.cer' `
                -ErrorAction SilentlyContinue
        )) {
            try {
                $Certificate =
                    [Security.Cryptography.X509Certificates.X509Certificate2]::new(
                        $Cer.FullName
                    )
            }
            catch {
                continue
            }

            if (
                [string]::IsNullOrWhiteSpace($ExpectedThumbprint) -or
                $Certificate.Thumbprint -eq $ExpectedThumbprint
            ) {
                return $Cer.FullName
            }
        }
    }

    return $null
}

function Register-OfficialCatalog {
    param(
        [Parameter(Mandatory)]
        [string]$CatalogPath,

        [Parameter(Mandatory)]
        [string]$SignToolPath
    )

    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "Official AMD catalog is missing: $CatalogPath"
    }

    if (-not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) {
        throw "SignTool is missing: $SignToolPath"
    }

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        # Native stderr must be captured as output rather than promoted to a
        # terminating PowerShell error before LASTEXITCODE can be inspected.
        $ErrorActionPreference = 'Continue'

        $RegistrationOutput = @(
            & $SignToolPath `
                catdb `
                /v `
                /u `
                $CatalogPath 2>&1
        )

        $RegistrationExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    foreach ($Line in $RegistrationOutput) {
        Write-Host $Line
    }

    if ($RegistrationExitCode -ne 0) {
        throw (
            'SignTool catalog registration failed with exit code ' +
            "$RegistrationExitCode.`n" +
            ($RegistrationOutput -join "`n")
        )
    }

    Write-Host (
        '[PASS] SignTool registered the exact original AMD catalog ' +
        'with a unique database name'
    )
}

if (-not ('LegionGoCatalogQueryNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LegionGoCatalogQueryNative
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CATALOG_INFO
    {
        public UInt32 cbStruct;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string wszCatalogFile;
    }

    [DllImport(
        "wintrust.dll",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CryptCATAdminAcquireContext2(
        out IntPtr phCatAdmin,
        IntPtr pgSubsystem,
        string pwszHashAlgorithm,
        IntPtr pStrongHashPolicy,
        UInt32 dwFlags
    );

    [DllImport("wintrust.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CryptCATAdminCalcHashFromFileHandle2(
        IntPtr hCatAdmin,
        IntPtr hFile,
        ref UInt32 pcbHash,
        byte[] pbHash,
        UInt32 dwFlags
    );

    [DllImport(
        "wintrust.dll",
        EntryPoint = "CryptCATAdminEnumCatalogFromHash",
        SetLastError = true
    )]
    public static extern IntPtr CryptCATAdminEnumCatalogFromHashFirst(
        IntPtr hCatAdmin,
        byte[] pbHash,
        UInt32 cbHash,
        UInt32 dwFlags,
        IntPtr phPrevCatInfo
    );

    [DllImport(
        "wintrust.dll",
        EntryPoint = "CryptCATAdminEnumCatalogFromHash",
        SetLastError = true
    )]
    public static extern IntPtr CryptCATAdminEnumCatalogFromHashNext(
        IntPtr hCatAdmin,
        byte[] pbHash,
        UInt32 cbHash,
        UInt32 dwFlags,
        ref IntPtr phPrevCatInfo
    );

    [DllImport(
        "wintrust.dll",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CryptCATCatalogInfoFromContext(
        IntPtr hCatInfo,
        ref CATALOG_INFO psCatInfo,
        UInt32 dwFlags
    );

    [DllImport("wintrust.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CryptCATAdminReleaseCatalogContext(
        IntPtr hCatAdmin,
        IntPtr hCatInfo,
        UInt32 dwFlags
    );

    [DllImport("wintrust.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CryptCATAdminReleaseContext(
        IntPtr hCatAdmin,
        UInt32 dwFlags
    );
}
'@
            "'@"
@'
}

function Get-RegisteredCatalogsForFile {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Catalog member file is missing: $LiteralPath"
    }

    [IntPtr]$AdminContext = [IntPtr]::Zero
    [IntPtr]$CatalogContext = [IntPtr]::Zero
    $CatalogPaths =
        New-Object 'System.Collections.Generic.List[string]'
    $Stream = $null

    try {
        $Acquired =
            [LegionGoCatalogQueryNative]::CryptCATAdminAcquireContext2(
                [ref]$AdminContext,
                [IntPtr]::Zero,
                'SHA256',
                [IntPtr]::Zero,
                0
            )

        if (-not $Acquired) {
            $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw (
                'CryptCATAdminAcquireContext2 failed with Win32 error ' +
                $Code + '.'
            )
        }

        $Stream = [IO.File]::Open(
            $LiteralPath,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite
        )

        $FileHandle = $Stream.SafeFileHandle.DangerousGetHandle()
        [uint32]$HashLength = 0

        [void][LegionGoCatalogQueryNative]::CryptCATAdminCalcHashFromFileHandle2(
            $AdminContext,
            $FileHandle,
            [ref]$HashLength,
            $null,
            0
        )

        if ($HashLength -eq 0) {
            $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw (
                'Unable to determine catalog hash length. Win32 error ' +
                $Code + '.'
            )
        }

        $Hash = New-Object byte[] $HashLength

        $Calculated =
            [LegionGoCatalogQueryNative]::CryptCATAdminCalcHashFromFileHandle2(
                $AdminContext,
                $FileHandle,
                [ref]$HashLength,
                $Hash,
                0
            )

        if (-not $Calculated) {
            $Code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw (
                'Catalog-member hash calculation failed with Win32 error ' +
                $Code + '.'
            )
        }

        $CatalogContext =
            [LegionGoCatalogQueryNative]::CryptCATAdminEnumCatalogFromHashFirst(
                $AdminContext,
                $Hash,
                $HashLength,
                0,
                [IntPtr]::Zero
            )

        while ($CatalogContext -ne [IntPtr]::Zero) {
            $CatalogInfo =
                New-Object LegionGoCatalogQueryNative+CATALOG_INFO

            $CatalogInfo.cbStruct =
                [Runtime.InteropServices.Marshal]::SizeOf(
                    [type][LegionGoCatalogQueryNative+CATALOG_INFO]
                )

            $InfoRead =
                [LegionGoCatalogQueryNative]::CryptCATCatalogInfoFromContext(
                    $CatalogContext,
                    [ref]$CatalogInfo,
                    0
                )

            if (-not $InfoRead) {
                $Code =
                    [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw (
                    'CryptCATCatalogInfoFromContext failed with Win32 ' +
                    'error ' + $Code + '.'
                )
            }

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $CatalogInfo.wszCatalogFile
                )
            ) {
                $CatalogPaths.Add($CatalogInfo.wszCatalogFile)
            }

            # CryptCATAdminEnumCatalogFromHash consumes/releases the
            # previous enumeration context when it is supplied through
            # phPrevCatInfo. Only the currently returned context may be
            # released explicitly. Retaining and releasing every prior
            # handle corrupts the process heap.
            [IntPtr]$PreviousContext = $CatalogContext

            $CatalogContext =
                [LegionGoCatalogQueryNative]::CryptCATAdminEnumCatalogFromHashNext(
                    $AdminContext,
                    $Hash,
                    $HashLength,
                    0,
                    [ref]$PreviousContext
                )
        }

        return @(
            $CatalogPaths |
                Select-Object -Unique
        )
    }
    finally {
        if ($null -ne $Stream) {
            $Stream.Dispose()
        }

        # A nonzero value remains only when enumeration exits abnormally
        # before the next call consumes the current context.
        if ($CatalogContext -ne [IntPtr]::Zero) {
            [void][LegionGoCatalogQueryNative]::CryptCATAdminReleaseCatalogContext(
                $AdminContext,
                $CatalogContext,
                0
            )
        }

        if ($AdminContext -ne [IntPtr]::Zero) {
            [void][LegionGoCatalogQueryNative]::CryptCATAdminReleaseContext(
                $AdminContext,
                0
            )
        }
    }
}

try {
    Write-Host 'Legion Go AMD 26.6.2 Toolkit'
    Write-Host 'Phase 1: Install the corrected driver and prepare normal signing'
    Write-Host ''

    Write-Host '=== LOAD VERIFIED BUILD STATE ==='

    if (-not (Test-Path -LiteralPath $VerificationResultPath -PathType Leaf)) {
        throw (
            'Script 1 verification result is missing: ' +
            $VerificationResultPath
        )
    }

    $Verification =
        Get-Content -LiteralPath $VerificationResultPath -Raw |
            ConvertFrom-Json

    $VerificationSuccess =
        Get-FirstPropertyValue -Object $Verification -Names @(
            'Verified'
            'Passed'
            'Success'
            'Complete'
            'ExactMatch'
            'ExactUnsignedPackageReproduced'
        )

    if (-not (Test-RecordedSuccess -Value $VerificationSuccess)) {
        throw (
            'Script 1 did not record successful package verification. ' +
            "Resolved success value: $VerificationSuccess"
        )
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $CatalogSigningStatePath `
                -PathType Leaf
        )
    ) {
        throw (
            'Script 1 Phase 4 catalog-signing state is missing: ' +
            $CatalogSigningStatePath
        )
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $BootPreparationResultPath `
                -PathType Leaf
        )
    ) {
        throw (
            'Script 1 boot-preparation result is missing: ' +
            $BootPreparationResultPath
        )
    }

    $SigningInput =
        Get-Content -LiteralPath $CatalogSigningStatePath -Raw |
            ConvertFrom-Json

    $BootPreparation =
        Get-Content -LiteralPath $BootPreparationResultPath -Raw |
            ConvertFrom-Json

    if (
        $BootPreparation.ReadyForDriverInstall -ne $true -or
        $BootPreparation.SecureBootEnabled -ne $false -or
        $BootPreparation.TestSigningConfiguredOn -ne $true
    ) {
        throw (
            'Script 1 did not record a completed Secure Boot/Test Signing ' +
            'preparation.'
        )
    }

    # Script 1 can run under Windows PowerShell 5.1 or PowerShell 7.
    # A CIM DateTime written directly through ConvertTo-Json is serialized
    # differently by those engines. Comparing BootTimeWhenConfigured after
    # deserialization can therefore mix UTC and local wall-clock values.
    # UpdatedAt is deliberately written as an ISO-8601 round-trip timestamp
    # and represents the moment Test Signing was configured, so it is the
    # reliable reboot boundary.
    if ([string]::IsNullOrWhiteSpace([string]$BootPreparation.UpdatedAt)) {
        throw (
            'Script 1 boot-preparation state does not contain UpdatedAt; ' +
            'the reboot boundary cannot be proven safely.'
        )
    }

    $TestSigningConfiguredAt =
        [datetime]$BootPreparation.UpdatedAt

    $CurrentBootTime =
        (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

    $ConfiguredBootTime =
        Get-FirstPropertyValue -Object $BootPreparation -Names @(
            'BootTimeWhenConfigured'
        )

    if ($null -eq $ConfiguredBootTime) {
        $ConfiguredBootTime = ''
    }

    if ($CurrentBootTime -le $TestSigningConfiguredAt) {
        throw (
            'Windows has not rebooted since Script 1 configured Test ' +
            'Signing. Reboot before running Script 2 Phase 1.'
        )
    }

    $DriverPackageRoot =
        Resolve-DriverPackageRoot `
            -ExplicitRoot $SignedPackageRoot `
            -SigningState $SigningInput `
            -VerificationState $Verification

    $DriverInf = Join-Path $DriverPackageRoot 'u0201589.inf'
    $LocalCatalog = Join-Path $DriverPackageRoot 'u0201589.cat'
    $KernelSource = Join-Path $DriverPackageRoot 'B026175\amdkmdag.sys'
    $AmgcfPath = Join-Path $DriverPackageRoot 'B026175\amdgcf.dat'
    $AtiicdxxPath = Join-Path $DriverPackageRoot 'B026175\atiicdxx.dat'
    $UnexpectedPackageCcc2Path =
        Join-Path $DriverPackageRoot 'B026175\ccc2_install.exe'

    Write-Host "Verification result: $VerificationResultPath"
    Write-Host "Signing state:       $CatalogSigningStatePath"
    Write-Host "Boot preparation:    $BootPreparationResultPath"
    Write-Host "Current boot:        $CurrentBootTime"
    Write-Host "Driver package root: $DriverPackageRoot"

    Write-Host ''
    Write-Host '=== VERIFY FIXED CANONICAL PACKAGE FILES ==='

    [void](Assert-Hash `
        -LiteralPath $DriverInf `
        -ExpectedHash $ExpectedInfHash `
        -Label 'Canonical u0201589.inf')

    [void](Assert-Hash `
        -LiteralPath $KernelSource `
        -ExpectedHash $ExpectedKernelHash `
        -Label 'Canonical B026175\amdkmdag.sys')

    [void](Assert-Hash `
        -LiteralPath $AmgcfPath `
        -ExpectedHash $ExpectedAmgcfHash `
        -Label 'Canonical B026175\amdgcf.dat')

    [void](Assert-Hash `
        -LiteralPath $AtiicdxxPath `
        -ExpectedHash $ExpectedAtiicdxxHash `
        -Label 'Canonical B026175\atiicdxx.dat')

    if (
        Test-Path `
            -LiteralPath $UnexpectedPackageCcc2Path `
            -PathType Leaf
    ) {
        throw (
            'The signed driver package incorrectly contains ' +
            'B026175\ccc2_install.exe. The validated package boundary is ' +
            '125 driver files plus the per-user CAT only; CCC2 must remain ' +
            'a separate official-source asset.'
        )
    }

    Write-Host '[PASS] Signed driver package excludes ccc2_install.exe'

    if (-not (Test-Path -LiteralPath $LocalCatalog -PathType Leaf)) {
        throw "Per-user signed catalog is missing: $LocalCatalog"
    }

    $LocalCatalogHash = Get-SHA256 -LiteralPath $LocalCatalog
    $LocalCatalogSignatureBeforeTrust =
        Get-AuthenticodeSignature -LiteralPath $LocalCatalog

    $CatalogSignerCertificate =
        $LocalCatalogSignatureBeforeTrust.SignerCertificate

    $StateThumbprint =
        Get-FirstPropertyValue -Object $SigningInput -Names @(
            'CatalogSignerThumbprint'
            'CertificateThumbprint'
            'SignerThumbprint'
            'Thumbprint'
        )

    $CatalogSignerThumbprint = if (
        $null -ne $CatalogSignerCertificate
    ) {
        [string]$CatalogSignerCertificate.Thumbprint
    }
    else {
        [string]$StateThumbprint
    }

    if ([string]::IsNullOrWhiteSpace($CatalogSignerThumbprint)) {
        throw (
            'The per-user catalog signer thumbprint could not be resolved ' +
            'from the CAT signature or signing state.'
        )
    }

    if (
        -not [string]::IsNullOrWhiteSpace([string]$StateThumbprint) -and
        [string]$StateThumbprint -ne $CatalogSignerThumbprint
    ) {
        throw (
            'Catalog signer thumbprint does not match the signing state. ' +
            "State=$StateThumbprint; CAT=$CatalogSignerThumbprint"
        )
    }

    $StateCatalogHash =
        Get-FirstPropertyValue -Object $SigningInput -Names @(
            'SignedCatalogSHA256'
            'CatalogSHA256'
            'SignedCatalogHash'
            'CatalogHash'
        )

    if (
        -not [string]::IsNullOrWhiteSpace([string]$StateCatalogHash) -and
        [string]$StateCatalogHash -ne $LocalCatalogHash
    ) {
        throw (
            'Signed catalog hash does not match the signing state. ' +
            "State=$StateCatalogHash; Actual=$LocalCatalogHash"
        )
    }

    Write-Host '[PASS] Dynamic per-user catalog resolved'
    Write-Host "       SHA256:    $LocalCatalogHash"
    Write-Host "       Thumbprint: $CatalogSignerThumbprint"
    Write-Host (
        '       Pre-trust signature status: ' +
        $LocalCatalogSignatureBeforeTrust.Status
    )

    $ResolvedCertificatePath =
        Find-PublicCertificate `
            -ExplicitPath $PublicCertificatePath `
            -SigningState $SigningInput `
            -VerificationState $Verification `
            -PackageRoot $DriverPackageRoot `
            -ExpectedThumbprint $CatalogSignerThumbprint

    if ([string]::IsNullOrWhiteSpace($ResolvedCertificatePath)) {
        throw (
            'Unable to resolve the public certificate matching catalog ' +
            "signer $CatalogSignerThumbprint."
        )
    }

    $Certificate =
        [Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $ResolvedCertificatePath
        )

    if ($Certificate.Thumbprint -ne $CatalogSignerThumbprint) {
        throw (
            'Public certificate thumbprint does not match the CAT signer. ' +
            "CER=$($Certificate.Thumbprint); CAT=$CatalogSignerThumbprint"
        )
    }

    if ($Certificate.HasPrivateKey) {
        throw (
            'The public CER unexpectedly exposes a private key: ' +
            $ResolvedCertificatePath
        )
    }

    $CertificateHash = Get-SHA256 -LiteralPath $ResolvedCertificatePath

    $StateCertificateHash =
        Get-FirstPropertyValue -Object $SigningInput -Names @(
            'CertificateSHA256'
            'PublicCertificateSHA256'
            'CerSHA256'
            'CertificateHash'
        )

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$StateCertificateHash
        ) -and
        [string]$StateCertificateHash -ne $CertificateHash
    ) {
        throw (
            'Public certificate hash does not match the signing state. ' +
            "State=$StateCertificateHash; Actual=$CertificateHash"
        )
    }

    Write-Host '[PASS] Per-user public certificate resolved'
    Write-Host "       Path:       $ResolvedCertificatePath"
    Write-Host "       SHA256:     $CertificateHash"
    Write-Host "       Subject:    $($Certificate.Subject)"
    Write-Host "       Thumbprint: $($Certificate.Thumbprint)"

    Write-Host ''
    Write-Host '=== VERIFY SEPARATE OFFICIAL CCC2 ASSET ==='

    $OfficialCcc2Candidates =
        @(
            $OfficialCcc2Path
            ([string](Get-FirstPropertyValue `
                -Object $SigningInput `
                -Names @(
                    'OfficialCcc2Path'
                    'Ccc2InstallerPath'
                    'NativeInstallerPath'
                )))
            ([string](Get-FirstPropertyValue `
                -Object $Verification `
                -Names @(
                    'OfficialCcc2Path'
                    'Ccc2InstallerPath'
                    'NativeInstallerPath'
                )))
        ) |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            } |
            Select-Object -Unique

    if (@($OfficialCcc2Candidates).Count -eq 0) {
        throw (
            'Script 1 Phase 3/02B state contains no candidate path for the ' +
            'separate official AMD 26.6.2 ccc2_install.exe.'
        )
    }

    $ResolvedOfficialCcc2 =
        Resolve-ExistingFile `
            -Candidates ([string[]]@($OfficialCcc2Candidates)) `
            -ExpectedHash $ExpectedCcc2Hash

    if ([string]::IsNullOrWhiteSpace($ResolvedOfficialCcc2)) {
        throw (
            'Unable to resolve the separate official AMD 26.6.2 ' +
            'ccc2_install.exe from Script 1 Phase 3/02B state. Expected SHA-256: ' +
            $ExpectedCcc2Hash
        )
    }

    $OfficialCcc2Item =
        Get-Item -LiteralPath $ResolvedOfficialCcc2

    if ([int64]$OfficialCcc2Item.Length -ne $ExpectedCcc2Length) {
        throw (
            'Official ccc2_install.exe length mismatch. Expected ' +
            $ExpectedCcc2Length + '; actual ' +
            $OfficialCcc2Item.Length + '.'
        )
    }

    $OfficialCcc2Signature =
        Get-AuthenticodeSignature -LiteralPath $ResolvedOfficialCcc2

    if (
        $OfficialCcc2Signature.Status -ne 'Valid' -or
        $null -eq $OfficialCcc2Signature.SignerCertificate -or
        $OfficialCcc2Signature.SignerCertificate.Subject -notmatch
            '^CN=Advanced Micro Devices,'
    ) {
        throw (
            'The separate official ccc2_install.exe does not have the ' +
            'expected valid AMD signature.'
        )
    }

    Write-Host '[PASS] Separate official AMD CCC2 asset verified'
    Write-Host "       Path:   $ResolvedOfficialCcc2"
    Write-Host "       SHA256: $ExpectedCcc2Hash"
    Write-Host "       Length: $($OfficialCcc2Item.Length)"

    $OfficialCatalogCandidates = @(
        $OfficialCatalogPath
        (Get-FirstPropertyValue -Object $SigningInput -Names @(
            'OfficialCatalogPath'
            'OriginalCatalogPath'
            'SourceCatalogPath'
            'AmdOfficialCatalogPath'
        ))
        (Get-FirstPropertyValue -Object $Verification -Names @(
            'OfficialCatalogPath'
            'OriginalCatalogPath'
            'SourceCatalogPath'
            'AmdOfficialCatalogPath'
        ))
    ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        } |
        ForEach-Object { [string]$_ } |
        Select-Object -Unique

    $OfficialSearchRoots = @(
        (Get-FirstPropertyValue -Object $SigningInput -Names @(
            'SourceRoot'
            'OfficialSourceRoot'
            'ExtractedSourceRoot'
            'SourceDisplayRoot'
            'OfficialDisplayRoot'
        ))
        (Get-FirstPropertyValue -Object $Verification -Names @(
            'SourceRoot'
            'OfficialSourceRoot'
            'ExtractedSourceRoot'
            'SourceDisplayRoot'
            'OfficialDisplayRoot'
        ))
        'C:\AMD\LegionGo-26.6.2'
    ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        } |
        ForEach-Object { [string]$_ } |
        Select-Object -Unique

    $ResolvedOfficialCatalog =
        Find-ExactCatalog `
            -ExpectedHash $ExpectedOfficialCatalogHash `
            -CandidateFiles ([string[]]@($OfficialCatalogCandidates)) `
            -SearchRoots ([string[]]@($OfficialSearchRoots))

    if ([string]::IsNullOrWhiteSpace($ResolvedOfficialCatalog)) {
        throw (
            'Unable to locate AMD''s original Microsoft-signed ' +
            'u0201589.cat with SHA-256 ' +
            $ExpectedOfficialCatalogHash + '.'
        )
    }

    $OfficialCatalogHash =
        Assert-Hash `
            -LiteralPath $ResolvedOfficialCatalog `
            -ExpectedHash $ExpectedOfficialCatalogHash `
            -Label 'Original Microsoft-signed AMD u0201589.cat'

    $OfficialSignature =
        Get-AuthenticodeSignature -LiteralPath $ResolvedOfficialCatalog

    if ($OfficialSignature.Status -ne 'Valid') {
        throw (
            'Original AMD catalog signature is invalid: ' +
            $OfficialSignature.Status
        )
    }

    if (
        $null -eq $OfficialSignature.SignerCertificate -or
        $OfficialSignature.SignerCertificate.Subject -notmatch
            '^CN=Microsoft Windows Hardware Compatibility Publisher,'
    ) {
        throw (
            'Unexpected original AMD catalog signer: ' +
            $OfficialSignature.SignerCertificate.Subject
        )
    }

    Write-Host '[PASS] Original AMD catalog signer is Microsoft WHCP'
    Write-Host "       $($OfficialSignature.SignerCertificate.Subject)"

    $ResolvedSignToolPath =
        [string](
            Get-FirstPropertyValue `
                -Object $SigningInput `
                -Names @('SignToolPath')
        )

    if (
        [string]::IsNullOrWhiteSpace($ResolvedSignToolPath) -or
        -not (
            Test-Path `
                -LiteralPath $ResolvedSignToolPath `
                -PathType Leaf
        )
    ) {
        throw (
            'Script 1 signing state does not resolve an existing SignTool: ' +
            $ResolvedSignToolPath
        )
    }

    $SignToolSignature =
        Get-AuthenticodeSignature -LiteralPath $ResolvedSignToolPath

    if (
        $SignToolSignature.Status -ne 'Valid' -or
        $null -eq $SignToolSignature.SignerCertificate -or
        $SignToolSignature.SignerCertificate.Subject -notmatch
            '^CN=Microsoft '
    ) {
        throw (
            'The Script 1 SignTool does not have the expected valid ' +
            'Microsoft signature: ' +
            $ResolvedSignToolPath
        )
    }

    Write-Host '[PASS] Script 1 Microsoft SignTool resolved'
    Write-Host "       $ResolvedSignToolPath"

    Write-Host ''
    Write-Host '=== NORMALIZE CATALOG SIGNING STATE ==='

    $CanonicalSigningState = [ordered]@{}

    if ($null -ne $SigningInput) {
        foreach ($Property in $SigningInput.PSObject.Properties) {
            $CanonicalSigningState[$Property.Name] = $Property.Value
        }
    }

    $CanonicalSigningState['SchemaVersion'] = 2
    $CanonicalSigningState['Workflow'] = 'LegionGo-AMD-26.6.2'
    $CanonicalSigningState['StateType'] = 'PerUserDriverCatalogSigning'
    $CanonicalSigningState['NormalizedAt'] = (Get-Date).ToString('o')
    $CanonicalSigningState['PackageRoot'] = $DriverPackageRoot
    $CanonicalSigningState['SignedCatalogPath'] = $LocalCatalog
    $CanonicalSigningState['SignedCatalogSHA256'] = $LocalCatalogHash
    $CanonicalSigningState['CatalogSignerThumbprint'] =
        $CatalogSignerThumbprint
    $CanonicalSigningState['CatalogSignerSubject'] =
        $Certificate.Subject
    $CanonicalSigningState['CertificatePath'] =
        $ResolvedCertificatePath
    $CanonicalSigningState['CertificateSHA256'] =
        $CertificateHash
    $CanonicalSigningState['CertificateThumbprint'] =
        $Certificate.Thumbprint
    $CanonicalSigningState['CertificateSubject'] =
        $Certificate.Subject
    $CanonicalSigningState['OfficialCatalogPath'] =
        $ResolvedOfficialCatalog
    $CanonicalSigningState['OfficialCatalogSHA256'] =
        $OfficialCatalogHash
    $CanonicalSigningState['OfficialCatalogRegistrationMethod'] =
        'SignTool catdb /v /u'
    $CanonicalSigningState['SignToolPath'] =
        $ResolvedSignToolPath
    $CanonicalSigningState['OfficialCcc2Path'] =
        $ResolvedOfficialCcc2
    $CanonicalSigningState['OfficialCcc2SHA256'] =
        $ExpectedCcc2Hash
    $CanonicalSigningState['OfficialCcc2Length'] =
        $ExpectedCcc2Length
    $CanonicalSigningState['OfficialCcc2IncludedInPackage'] =
        $false
    $CanonicalSigningState['VerificationResultPath'] =
        $VerificationResultPath
    $CanonicalSigningState['InstalledDriverModified'] = $false

    $CanonicalSigningState |
        ConvertTo-Json -Depth 12 |
        Set-Content `
            -LiteralPath $CatalogSigningStatePath `
            -Encoding UTF8

    Write-Host '[PASS] Canonical signing state preserved'
    Write-Host "       $CatalogSigningStatePath"

    Write-Host ''
    Write-Host '=== VERIFY REQUIRED BOOT STATE ==='

    try {
        $SecureBootEnabled = Confirm-SecureBootUEFI
    }
    catch {
        throw "Unable to query Secure Boot: $($_.Exception.Message)"
    }

    $BcdBefore = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    $TestSigningEnabled =
        $BcdBefore -match '(?im)^\s*testsigning\s+Yes\s*$'

    Write-Host "Secure Boot enabled: $SecureBootEnabled"
    Write-Host "Test Signing enabled: $TestSigningEnabled"

    if ($SecureBootEnabled) {
        throw 'Secure Boot is enabled. Script 2 Phase 1 requires Secure Boot to be off.'
    }

    if (-not $TestSigningEnabled) {
        # Recovery path: a prior Script 2 Phase 1 run may already have configured
        # Test Signing OFF after successfully installing and validating the
        # exact target driver, but then failed before writing result state.
        $RecoveryGpuDriver = Get-GpuDriver
        $RecoveryGpuEntity = Get-GpuEntity
        $RecoveryInfPath =
            Join-Path $env:windir "INF\$($RecoveryGpuDriver.InfName)"
        $RecoveryInfHash = if (
            Test-Path -LiteralPath $RecoveryInfPath -PathType Leaf
        ) {
            Get-SHA256 -LiteralPath $RecoveryInfPath
        }
        else {
            ''
        }

        $RecoveryTargetActive =
            [string]$RecoveryGpuDriver.DriverVersion -eq
                $ExpectedTargetVersion -and
            $RecoveryInfHash -eq $ExpectedInfHash -and
            [string]$RecoveryGpuEntity.Status -eq 'OK' -and
            [int]$RecoveryGpuEntity.ConfigManagerErrorCode -eq 0

        if (-not $RecoveryTargetActive) {
            throw (
                'Test Signing is disabled and the exact target driver is ' +
                'not already active. Run Script 1 and complete its ' +
                'Windows reboot.'
            )
        }

        Write-Host (
            '[PASS] Test Signing is already configured off for the next ' +
            'boot and the exact target driver is active; continuing ' +
            'Script 2 Phase 1 recovery'
        )
    }
    else {
        Write-Host '[PASS] Secure Boot is off and Test Signing is on'
    }

    Write-Host ''
    Write-Host '=== VERIFY LEGION GO OEM BASELINE ==='

    $GpuDriverBefore = Get-GpuDriver
    $GpuEntityBefore = Get-GpuEntity
    $ActiveInfPathBefore =
        Join-Path $env:windir "INF\$($GpuDriverBefore.InfName)"

    $ActiveInfHashBefore = if (
        Test-Path -LiteralPath $ActiveInfPathBefore -PathType Leaf
    ) {
        Get-SHA256 -LiteralPath $ActiveInfPathBefore
    }
    else {
        'MISSING'
    }

    [pscustomobject]@{
        DeviceName      = $GpuDriverBefore.DeviceName
        DeviceID        = $GpuDriverBefore.DeviceID
        ActiveINF       = $GpuDriverBefore.InfName
        DriverVersion   = $GpuDriverBefore.DriverVersion
        ActiveInfSHA256 = $ActiveInfHashBefore
        Status          = $GpuEntityBefore.Status
        ProblemCode     = $GpuEntityBefore.ConfigManagerErrorCode
    } | Format-List

    $TargetAlreadyActive =
        $GpuDriverBefore.DriverVersion -eq $ExpectedTargetVersion -and
        $ActiveInfHashBefore -eq $ExpectedInfHash

    if (-not $TargetAlreadyActive) {
        if ($GpuDriverBefore.DriverVersion -ne $ExpectedOemVersion) {
            throw (
                'Unexpected starting display-driver version: ' +
                $GpuDriverBefore.DriverVersion +
                ". Expected Lenovo OEM $ExpectedOemVersion."
            )
        }

        if ($ActiveInfHashBefore -ne $ExpectedOemInfHash) {
            throw (
                'Starting Lenovo OEM INF hash is not the validated baseline: ' +
                $ActiveInfHashBefore
            )
        }

        if (
            $GpuEntityBefore.Status -ne 'OK' -or
            $GpuEntityBefore.ConfigManagerErrorCode -ne 0
        ) {
            throw (
                'Starting GPU is unhealthy: status ' +
                $GpuEntityBefore.Status +
                ', code ' +
                $GpuEntityBefore.ConfigManagerErrorCode
            )
        }

        $ExtensionState =
            Get-LenovoExtensionState `
                -DeviceInstanceId $GpuDriverBefore.DeviceID

        if (-not $ExtensionState.InventoryCreated) {
            throw (
                'PnPUtil could not create the structured driver inventory. ' +
                "ExitCode=$($ExtensionState.ExitCode)"
            )
        }

        if (-not $ExtensionState.Attached) {
            throw (
                'The required Lenovo extension is not attached to the GPU. ' +
                "Expected $ExpectedExtensionName " +
                "$ExpectedExtensionVersion."
            )
        }

        Write-Host (
            '[PASS] Validated Lenovo OEM baseline and extension are present'
        )
        Write-Host "       Inventory: $PnPInventoryPath"
    }
    else {
        Write-Host (
            '[PASS] Exact target driver is already active; ' +
            'continuing idempotently'
        )
    }

    Write-Host ''
    Write-Host '=== IMPORT PER-USER DRIVER CERTIFICATE ==='

    Import-Certificate `
        -FilePath $ResolvedCertificatePath `
        -CertStoreLocation 'Cert:\LocalMachine\Root' |
        Out-Null

    Import-Certificate `
        -FilePath $ResolvedCertificatePath `
        -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' |
        Out-Null

    foreach ($Store in @(
        'Cert:\LocalMachine\Root'
        'Cert:\LocalMachine\TrustedPublisher'
    )) {
        $Found =
            Get-ChildItem -LiteralPath $Store |
                Where-Object Thumbprint -EQ $CatalogSignerThumbprint |
                Select-Object -First 1

        if ($null -eq $Found) {
            throw "Certificate import was not confirmed in $Store"
        }

        Write-Host "[PASS] $Store"
        Write-Host "       $($Found.Subject)"
    }

    $LocalCatalogSignature =
        Get-AuthenticodeSignature -LiteralPath $LocalCatalog

    if ($LocalCatalogSignature.Status -ne 'Valid') {
        throw (
            'Per-user driver catalog signature is not valid after trust ' +
            "import: $($LocalCatalogSignature.Status)"
        )
    }

    if (
        $null -eq $LocalCatalogSignature.SignerCertificate -or
        $LocalCatalogSignature.SignerCertificate.Thumbprint -ne
            $CatalogSignerThumbprint
    ) {
        throw (
            'Per-user driver catalog signer changed unexpectedly after trust ' +
            'import.'
        )
    }

    Write-Host '[PASS] Per-user modified driver catalog signature is valid'

    Write-Host ''
    Write-Host '=== STAGE CORRECTED 26.6.2 PACKAGE ==='

    $StageOutput = & pnputil.exe /add-driver $DriverInf 2>&1
    $StageExitCode = $LASTEXITCODE

    $StageOutput | ForEach-Object { Write-Host $_ }
    Write-Host "PnPUtil exit code: $StageExitCode"

    if ($StageExitCode -notin 0, 259, 3010) {
        throw "Driver staging failed with exit code $StageExitCode"
    }

    $PublishedMatches = @(
        Get-ChildItem `
            -LiteralPath "$env:windir\INF" `
            -File `
            -Filter 'oem*.inf' |
        Where-Object {
            (Get-SHA256 -LiteralPath $_.FullName) -eq $ExpectedInfHash
        }
    )

    if ($PublishedMatches.Count -lt 1) {
        throw (
            'The exact corrected INF was not found in C:\Windows\INF ' +
            'after staging.'
        )
    }

    Write-Host 'Matching published INF file(s):'

    foreach ($Match in $PublishedMatches) {
        Write-Host "  $($Match.Name)"
    }

    if (-not $TargetAlreadyActive) {
        Write-Host ''
        Write-Host '=== FORCE-BIND EXACT LEGION GO HARDWARE ID ==='

        if (-not ('LegionGoNewDevInstall' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LegionGoNewDevInstall
{
    [DllImport(
        "newdev.dll",
        CharSet = CharSet.Unicode,
        SetLastError = true,
        EntryPoint = "UpdateDriverForPlugAndPlayDevicesW"
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UpdateDriver(
        IntPtr hwndParent,
        string hardwareId,
        string fullInfPath,
        UInt32 installFlags,
        out bool rebootRequired
    );
}
'@
            "'@"
@'
        }

        $DriverRebootRequired = $false

        $InstallSucceeded =
            [LegionGoNewDevInstall]::UpdateDriver(
                [IntPtr]::Zero,
                $HardwareId,
                $DriverInf,
                1,
                [ref]$DriverRebootRequired
            )

        $InstallError =
            [Runtime.InteropServices.Marshal]::GetLastWin32Error()

        Write-Host "Update succeeded: $InstallSucceeded"
        Write-Host "Win32 error:     $InstallError"
        Write-Host "Reboot required: $DriverRebootRequired"

        if (-not $InstallSucceeded) {
            $Message =
                [ComponentModel.Win32Exception]::new(
                    $InstallError
                ).Message

            throw (
                'Forced driver installation failed: ' +
                "$Message ($InstallError)"
            )
        }

        $ActivationDeadline = (Get-Date).AddSeconds(60)

        while ((Get-Date) -lt $ActivationDeadline) {
            Start-Sleep -Seconds 2

            try {
                $ObservedDriver = Get-GpuDriver
                $ObservedInfPath =
                    Join-Path $env:windir "INF\$($ObservedDriver.InfName)"

                $ObservedInfHash = if (
                    Test-Path -LiteralPath $ObservedInfPath -PathType Leaf
                ) {
                    Get-SHA256 -LiteralPath $ObservedInfPath
                }
                else {
                    'MISSING'
                }

                if (
                    $ObservedDriver.DriverVersion -eq
                        $ExpectedTargetVersion -and
                    $ObservedInfHash -eq $ExpectedInfHash
                ) {
                    break
                }
            }
            catch {
                # The device can briefly disappear while PnP converges.
            }
        }
    }

    Write-Host ''
    Write-Host '=== VERIFY ACTIVE GPU AND KERNEL DRIVER ==='

    $GpuDriverAfter = Get-GpuDriver
    $GpuEntityAfter = Get-GpuEntity
    $ActiveInfPathAfter =
        Join-Path $env:windir "INF\$($GpuDriverAfter.InfName)"

    $ActiveInfHashAfter = if (
        Test-Path -LiteralPath $ActiveInfPathAfter -PathType Leaf
    ) {
        Get-SHA256 -LiteralPath $ActiveInfPathAfter
    }
    else {
        'MISSING'
    }

    [pscustomobject]@{
        DeviceName      = $GpuDriverAfter.DeviceName
        DeviceID        = $GpuDriverAfter.DeviceID
        ActiveINF       = $GpuDriverAfter.InfName
        DriverVersion   = $GpuDriverAfter.DriverVersion
        ActiveInfSHA256 = $ActiveInfHashAfter
        Status          = $GpuEntityAfter.Status
        ProblemCode     = $GpuEntityAfter.ConfigManagerErrorCode
    } | Format-List

    if ($GpuDriverAfter.DriverVersion -ne $ExpectedTargetVersion) {
        throw (
            'Target driver is not active: ' +
            $GpuDriverAfter.DriverVersion
        )
    }

    if ($ActiveInfHashAfter -ne $ExpectedInfHash) {
        throw (
            'Active published INF hash mismatch: ' +
            $ActiveInfHashAfter
        )
    }

    if (
        $GpuEntityAfter.Status -ne 'OK' -or
        $GpuEntityAfter.ConfigManagerErrorCode -ne 0
    ) {
        throw (
            'GPU is unhealthy after installation: status ' +
            $GpuEntityAfter.Status +
            ', code ' +
            $GpuEntityAfter.ConfigManagerErrorCode
        )
    }

    $GpuEnumPath =
        'HKLM:\SYSTEM\CurrentControlSet\Enum\' +
        $GpuDriverAfter.DeviceID

    $GpuEnumValues = Get-ItemProperty -LiteralPath $GpuEnumPath
    $KernelServiceName = [string]$GpuEnumValues.Service

    if ([string]::IsNullOrWhiteSpace($KernelServiceName)) {
        throw 'The active GPU device has no kernel service assignment.'
    }

    $KernelService =
        Get-CimInstance Win32_SystemDriver |
            Where-Object Name -EQ $KernelServiceName |
            Select-Object -First 1

    if ($null -eq $KernelService) {
        throw "GPU kernel service was not found: $KernelServiceName"
    }

    $KernelPath = Resolve-KernelPath -RawPath $KernelService.PathName

    [void](Assert-Hash `
        -LiteralPath $KernelPath `
        -ExpectedHash $ExpectedKernelHash `
        -Label 'Loaded amdkmdag.sys')

    if (
        $KernelService.State -ne 'Running' -or
        -not $KernelService.Started
    ) {
        throw (
            'GPU kernel service is not running: ' +
            $KernelServiceName
        )
    }

    Write-Host "[PASS] Kernel service $KernelServiceName is running"

    Write-Host ''
    Write-Host '=== REGISTER ORIGINAL MICROSOFT-SIGNED AMD CATALOG ==='

    $PreRegisteredCatalogPaths =
        @(Get-RegisteredCatalogsForFile -LiteralPath $KernelPath)

    $OfficialCatalogAlreadyRegistered = $false

    foreach ($PreRegisteredPath in $PreRegisteredCatalogPaths) {
        if (
            -not (
                Test-Path `
                    -LiteralPath $PreRegisteredPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        if (
            (Get-SHA256 -LiteralPath $PreRegisteredPath) -ne
                $ExpectedOfficialCatalogHash
        ) {
            continue
        }

        $PreRegisteredSignature =
            Get-AuthenticodeSignature -LiteralPath $PreRegisteredPath

        if (
            $PreRegisteredSignature.Status -eq 'Valid' -and
            $null -ne $PreRegisteredSignature.SignerCertificate -and
            $PreRegisteredSignature.SignerCertificate.Subject -match
                '^CN=Microsoft Windows Hardware Compatibility Publisher,'
        ) {
            $OfficialCatalogAlreadyRegistered = $true
            break
        }
    }

    if ($OfficialCatalogAlreadyRegistered) {
        Write-Host (
            '[PASS] Exact original AMD catalog is already registered; ' +
            'continuing idempotently'
        )
    }
    else {
        Register-OfficialCatalog `
            -CatalogPath $ResolvedOfficialCatalog `
            -SignToolPath $ResolvedSignToolPath
    }

    $RegisteredCatalogPaths =
        @(Get-RegisteredCatalogsForFile -LiteralPath $KernelPath)

    $RegisteredOfficialCatalogs = @()

    foreach ($RegisteredPath in $RegisteredCatalogPaths) {
        if (-not (Test-Path -LiteralPath $RegisteredPath -PathType Leaf)) {
            continue
        }

        if (
            (Get-SHA256 -LiteralPath $RegisteredPath) -eq
            $ExpectedOfficialCatalogHash
        ) {
            $RegisteredSignature =
                Get-AuthenticodeSignature -LiteralPath $RegisteredPath

            $RegisteredOfficialCatalogs += [pscustomobject]@{
                Path            = $RegisteredPath
                SHA256          = $ExpectedOfficialCatalogHash
                SignatureStatus = [string]$RegisteredSignature.Status
                SignerSubject   = if (
                    $null -ne $RegisteredSignature.SignerCertificate
                ) {
                    [string]$RegisteredSignature.SignerCertificate.Subject
                }
                else {
                    ''
                }
            }
        }
    }

    if ($RegisteredOfficialCatalogs.Count -lt 1) {
        throw (
            'The original AMD catalog was not enumerated for the loaded ' +
            'kernel after registration.'
        )
    }

    $InvalidRegisteredOfficial = @(
        $RegisteredOfficialCatalogs |
            Where-Object {
                $_.SignatureStatus -ne 'Valid' -or
                $_.SignerSubject -notmatch
                    '^CN=Microsoft Windows Hardware Compatibility Publisher,'
            }
    )

    if ($InvalidRegisteredOfficial.Count -gt 0) {
        throw (
            'The registered original AMD catalog did not retain a valid ' +
            'Microsoft WHCP signature.'
        )
    }

    Write-Host (
        '[PASS] Original AMD catalog is registered for the loaded kernel'
    )

    foreach ($Registered in $RegisteredOfficialCatalogs) {
        Write-Host "       $($Registered.Path)"
    }

    Write-Host ''
    Write-Host '=== CONFIGURE TEST SIGNING OFF ==='

    & bcdedit.exe /set testsigning off

    if ($LASTEXITCODE -ne 0) {
        throw (
            'Failed to disable Test Signing. Exit code: ' +
            $LASTEXITCODE
        )
    }

    $BcdAfter = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    $TestSigningStillConfiguredOn =
        $BcdAfter -match '(?im)^\s*testsigning\s+Yes\s*$'

    if ($TestSigningStillConfiguredOn) {
        throw (
            'BCDEdit returned successfully, but Test Signing is still ' +
            'configured on.'
        )
    }

    Write-Host '[PASS] Test Signing is configured off for the next boot'

    $RegisteredOfficialLocations = @(
        $RegisteredOfficialCatalogs |
            ForEach-Object Path
    )

    $InstallResult = [ordered]@{
        SchemaVersion                    = 2
        Workflow                         = 'LegionGo-AMD-26.6.2'
        Installed                        = $true
        InstalledAt                      = (Get-Date).ToString('o')
        PackageRoot                      = $DriverPackageRoot
        ActiveINF                        = $GpuDriverAfter.InfName
        DriverVersion                    = $GpuDriverAfter.DriverVersion
        ActiveInfSHA256                  = $ActiveInfHashAfter
        KernelService                    = $KernelServiceName
        KernelPath                       = $KernelPath
        KernelSHA256                     =
            (Get-SHA256 -LiteralPath $KernelPath)
        LocalCatalogPath                 = $LocalCatalog
        LocalCatalogSHA256               = $LocalCatalogHash
        LocalCatalogSignerThumbprint     =
            $CatalogSignerThumbprint
        PublicCertificatePath            =
            $ResolvedCertificatePath
        PublicCertificateSHA256          =
            $CertificateHash
        CatalogSigningStatePath          =
            $CatalogSigningStatePath
        BootPreparationResultPath        =
            $BootPreparationResultPath
        BootTimeWhenConfigured           =
            $ConfiguredBootTime
        CurrentBootTime                  =
            $CurrentBootTime
        PnPInventoryPath                 =
            $PnPInventoryPath
        OfficialCatalogSourcePath        =
            $ResolvedOfficialCatalog
        OfficialCatalogSHA256            =
            $ExpectedOfficialCatalogHash
        OfficialCatalogLocations         =
            $RegisteredOfficialLocations
        OfficialCatalogRegistrationMethod =
            'SignTool catdb /v /u'
        SignToolPath                      =
            $ResolvedSignToolPath
        OfficialCcc2Path                  =
            $ResolvedOfficialCcc2
        OfficialCcc2SHA256                =
            $ExpectedCcc2Hash
        OfficialCcc2Length                =
            $ExpectedCcc2Length
        OfficialCcc2IncludedInPackage     = $false
        TestSigningWasEnabledThisBoot     = $true
        TestSigningConfiguredOffNextBoot = $true
        SecureBootStillOff                = $true
        NextStage                         =
            '04-Verify-Driver-And-Enter-SecureBoot-Setup'
        LogPath                           = $LogPath
    }

    $InstallResult |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            -LiteralPath $ResultPath `
            -Encoding UTF8

    $State = [ordered]@{
        SchemaVersion                    = 2
        Workflow                         = 'LegionGo-AMD-26.6.2'
        Stage                            =
            'Awaiting-TestSigning-Off-Reboot'
        UpdatedAt                        = (Get-Date).ToString('o')
        PackageRoot                      = $DriverPackageRoot
        ActiveINF                        = $GpuDriverAfter.InfName
        DriverVersion                    = $GpuDriverAfter.DriverVersion
        KernelService                    = $KernelServiceName
        CatalogSigningStatePath          =
            $CatalogSigningStatePath
        BootPreparationResultPath        =
            $BootPreparationResultPath
        PnPInventoryPath                 =
            $PnPInventoryPath
        LocalCatalogSignerThumbprint     =
            $CatalogSignerThumbprint
        OfficialCatalogRegistrationMethod =
            'SignTool catdb /v /u'
        SignToolPath                      =
            $ResolvedSignToolPath
        OfficialCcc2Path                  =
            $ResolvedOfficialCcc2
        OfficialCcc2IncludedInPackage     = $false
        TestSigningWasEnabledThisBoot     = $true
        TestSigningConfiguredOffNextBoot = $true
        SecureBootEnabled                = $false
        NextStage                        = $InstallResult.NextStage
        ResultPath                       = $ResultPath
        LogPath                          = $LogPath
    }

    $State |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            -LiteralPath $StatePath `
            -Encoding UTF8

    Write-Host ''
    Write-Host '=== PHASE 1 COMPLETE ==='
    Write-Host "Active INF:       $($GpuDriverAfter.InfName)"
    Write-Host "Driver version:   $($GpuDriverAfter.DriverVersion)"
    Write-Host "Kernel service:   $KernelServiceName"
    Write-Host "Local CAT SHA256: $LocalCatalogHash"
    Write-Host "CAT signer:       $CatalogSignerThumbprint"
    Write-Host "Official CCC2:    $ResolvedOfficialCcc2"
    Write-Host "Result file:      $ResultPath"
    Write-Host "Signing state:    $CatalogSigningStatePath"
    Write-Host "State file:       $StatePath"
    Write-Host "Log file:         $LogPath"

    if (-not $NoReboot) {
        throw (
            'This internal component must be launched by Script 2 so the ' +
            'public wrapper can request restart confirmation safely.'
        )
    }

    Write-Host (
        'Windows restart deferred to the Script 2 public wrapper.'
    )
    return
}
finally {
    Stop-Transcript | Out-Null
}
'@
        )
    }
    'Phase-02-Verify-Normal-Signing.ps1' = [ordered]@{
        SHA256 = '5C20E1FE3D98C6BAB6A8FDA3A8B361B1B2EBF768B4581C361163FAEB58EB337B'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 2 of Script 2 in the Legion Go AMD 26.6.2 Toolkit.

Run after Script 2 Phase 1 has rebooted Windows with Test Signing configured OFF.

Actions:
  - Verify Script 2 Phase 1 recorded the exact validated driver installation.
  - Load and validate the dynamic per-user catalog-signing state.
  - Verify Test Signing is OFF.
  - Verify the corrected 26.6.2 driver survived the reboot.
  - Verify the exact running AMD kernel and its Driver Store package.
  - Verify the per-user local catalog and certificate trust survived reboot.
  - Verify AMD's official Microsoft-signed catalog remains registered for
    the loaded kernel through the Windows catalog API.
  - Verify the Lenovo extension using structured PnPUtil XML inventory.
  - Verify AMDUWP is present and healthy.
  - Check relevant Code Integrity and GPU startup errors since this boot.
  - Save workflow state.

This phase does not change Secure Boot and does not install AMD Software.
#>

[CmdletBinding()]
param(
    [string]$InstallResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\driver-install-result.json',

    [string]$CatalogSigningStatePath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\catalog-signing-state.json'
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
Set-StrictMode -Version 2.0

$WorkflowRoot = 'C:\ProgramData\LegionGo-AMD-26.6.2'
$StatePath = Join-Path $WorkflowRoot 'workflow-state.json'
$ResultPath = Join-Path $WorkflowRoot 'post-testsigning-validation.json'
$LogRoot = Join-Path $WorkflowRoot 'Logs'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogPath = Join-Path $LogRoot "04-Verify-TestSigning-Off-$Timestamp.log"
$PnPInventoryPath =
    Join-Path $LogRoot "04-PnP-Driver-Inventory-$Timestamp.xml"

$ExpectedInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'

$ExpectedKernelHash =
    'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'

$ExpectedOfficialCatalogHash =
    '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'

$ExpectedDriverVersion = '32.0.31021.1015'
$ExpectedExtensionOriginalName = 'amduw23e.inf'
$ExpectedExtensionVersion = '32.0.23017.1001'
$ExpectedExtensionClassGuid = '{e2f84ce7-8efa-411c-aa69-97454ca4cb57}'

$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'
$GpuHardwareToken = 'VEN_1002&DEV_15BF&SUBSYS_381217AA'

$WorkflowAcl = Protect-WorkflowStateDirectory -Path $WorkflowRoot

New-Item -ItemType Directory -Path $WorkflowRoot, $LogRoot -Force |
    Out-Null

Start-Transcript -LiteralPath $LogPath -Force | Out-Null

function Get-SHA256 {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    return (
        Get-FileHash `
            -LiteralPath $LiteralPath `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()
}

function Get-OptionalProperty {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
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

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Details = ''
    )

    if (-not $Condition) {
        if ([string]::IsNullOrWhiteSpace($Details)) {
            throw $Message
        }

        throw "$Message`n$Details"
    }

    Write-Host "[PASS] $Message"

    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        Write-Host "       $Details"
    }
}

function Get-GpuDriver {
    $Matches = @(
        Get-CimInstance Win32_PnPSignedDriver |
            Where-Object DeviceID -Like $GpuPattern
    )

    if ($Matches.Count -ne 1) {
        throw (
            'Expected exactly one Legion Go GPU driver; found ' +
            $Matches.Count + '.'
        )
    }

    return $Matches[0]
}

function Get-GpuEntity {
    $Matches = @(
        Get-CimInstance Win32_PnPEntity |
            Where-Object DeviceID -Like $GpuPattern
    )

    if ($Matches.Count -ne 1) {
        throw (
            'Expected exactly one Legion Go GPU device; found ' +
            $Matches.Count + '.'
        )
    }

    return $Matches[0]
}

function Resolve-KernelPath {
    param(
        [Parameter(Mandatory)]
        [string]$RawPath
    )

    $Resolved = $RawPath.Trim('"')
    $Resolved = $Resolved -replace '^(?i)\\SystemRoot', $env:windir
    $Resolved = $Resolved -replace '^(?i)System32\\', "$env:windir\System32\"
    $Resolved = $Resolved -replace '^(?i)\\\?\?\\', ''

    return $Resolved
}

function Get-LocalMachineCertificate {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Root', 'TrustedPublisher')]
        [string]$StoreName,

        [Parameter(Mandatory)]
        [string]$Thumbprint
    )

    return Get-ChildItem `
        -LiteralPath "Cert:\LocalMachine\$StoreName" `
        -ErrorAction SilentlyContinue |
        Where-Object Thumbprint -EQ $Thumbprint |
        Select-Object -First 1
}

function Get-ValidatedDriverStorePackage {
    $Matches = @(
        Get-ChildItem `
            -LiteralPath "$env:windir\System32\DriverStore\FileRepository" `
            -Directory `
            -ErrorAction Stop |
            Where-Object {
                $InfPath = Join-Path $_.FullName 'u0201589.inf'

                (
                    Test-Path -LiteralPath $InfPath -PathType Leaf
                ) -and
                (
                    Get-SHA256 -LiteralPath $InfPath
                ) -eq $ExpectedInfHash
            }
    )

    if ($Matches.Count -lt 1) {
        return $null
    }

    return $Matches[0]
}

function Get-AmduwpState {
    $Devices = @(
        Get-CimInstance Win32_PnPEntity |
            Where-Object {
                $_.DeviceID -match '(?i)^SWD\\DRIVERENUM\\AMDUWP&'
            }
    )

    $HealthyDevices = @(
        $Devices |
            Where-Object {
                $_.Status -eq 'OK' -and
                $_.ConfigManagerErrorCode -eq 0
            }
    )

    return [pscustomobject]@{
        Devices = $Devices
        Present = ($Devices.Count -gt 0)
        Healthy = (
            $Devices.Count -gt 0 -and
            $HealthyDevices.Count -eq $Devices.Count
        )
    }
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
            MatchingRecords = @()
            InventoryPath = $PnPInventoryPath
        }
    }

    [xml]$Inventory = Get-Content -LiteralPath $PnPInventoryPath -Raw

    # PnPUtil emits title-cased element names on current Windows builds.
    # XPath local-name comparisons are case-sensitive, so accept both forms.
    $DriverNodes = @(
        $Inventory.SelectNodes(
            '//*[local-name()="Driver" or local-name()="driver"]'
        )
    )

    if ($DriverNodes.Count -eq 0) {
        if ($null -ne $Inventory.PnpUtil) {
            $DriverNodes = @($Inventory.PnpUtil.Driver)
        }
        elseif ($null -ne $Inventory.pnputil) {
            $DriverNodes = @($Inventory.pnputil.driver)
        }
    }

    $MatchingRecords = @()

    foreach ($DriverNode in $DriverNodes) {
        $OriginalName = [string]$DriverNode.OriginalName
        $DriverVersionText = [string]$DriverNode.DriverVersion
        $ClassGuid = [string]$DriverNode.ClassGuid

        $DeviceNodes = @(
            $DriverNode.SelectNodes(
                './*[local-name()="Devices" or local-name()="devices"]' +
                '/*[local-name()="Device" or local-name()="device"]'
            )
        )

        $MatchingDeviceIds = @()

        foreach ($DeviceNode in $DeviceNodes) {
            $InstanceId = [string]$DeviceNode.GetAttribute('InstanceId')

            if (
                -not [string]::IsNullOrWhiteSpace($InstanceId) -and
                (
                    $InstanceId -ieq $DeviceInstanceId -or
                    $InstanceId -like "*$GpuHardwareToken*"
                )
            ) {
                $MatchingDeviceIds += $InstanceId
            }
        }

        $NameMatch =
            $OriginalName -ieq $ExpectedExtensionOriginalName

        $VersionMatch =
            $DriverVersionText -match [regex]::Escape(
                $ExpectedExtensionVersion
            )

        $ClassMatch =
            $ClassGuid -ieq $ExpectedExtensionClassGuid

        $DeviceMatch = $MatchingDeviceIds.Count -gt 0

        if ($NameMatch -and $VersionMatch -and $ClassMatch -and $DeviceMatch) {
            $MatchingRecords += [pscustomobject]@{
                PublishedName = [string]$DriverNode.GetAttribute('DriverName')
                OriginalName = $OriginalName
                Version = $ExpectedExtensionVersion
                VersionText = $DriverVersionText
                ClassGuid = $ClassGuid
                DeviceIDs = $MatchingDeviceIds
                RawXml = [string]$DriverNode.OuterXml
            }
        }
    }

    return [pscustomobject]@{
        InventoryCreated = $true
        ExitCode = $Process.ExitCode
        Attached = ($MatchingRecords.Count -gt 0)
        MatchingRecords = $MatchingRecords
        InventoryPath = $PnPInventoryPath
    }
}

function Get-RegisteredCatalogsForFile {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Catalog member file is missing: $LiteralPath"
    }

    $DriverCatalogRoot =
        Join-Path `
            "$env:windir\System32\CatRoot" `
            '{F750E6C3-38EE-11D1-85E5-00C04FC295EE}'

    if (-not (Test-Path -LiteralPath $DriverCatalogRoot -PathType Container)) {
        throw "Driver catalog database was not found: $DriverCatalogRoot"
    }

    $CatalogMatches = @(
        Get-ChildItem `
            -LiteralPath $DriverCatalogRoot `
            -File `
            -Filter '*.cat' `
            -ErrorAction Stop |
            ForEach-Object {
                try {
                    if (
                        (Get-SHA256 -LiteralPath $_.FullName) -eq
                        $ExpectedOfficialCatalogHash
                    ) {
                        $_
                    }
                }
                catch {
                }
            }
    )

    if ($CatalogMatches.Count -eq 0) {
        return @()
    }

    $SignToolPath =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'SignToolPath')

    if (
        [string]::IsNullOrWhiteSpace($SignToolPath) -or
        -not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)
    ) {
        throw "SignTool was not found: $SignToolPath"
    }

    $VerificationCatalog = $CatalogMatches[0].FullName

    $SignToolOutput = @(
        & $SignToolPath `
            verify `
            /kp `
            /v `
            /c $VerificationCatalog `
            $LiteralPath 2>&1
    )

    $SignToolExitCode = $LASTEXITCODE

    if ($SignToolExitCode -ne 0) {
        throw (
            'The registered official AMD catalog did not validate the ' +
            "loaded kernel under kernel-mode policy. Exit code: " +
            "$SignToolExitCode`n" +
            ($SignToolOutput -join "`n")
        )
    }

    Write-Host '[PASS] SignTool verified the loaded kernel in the official AMD catalog'
    Write-Host "       Catalog: $VerificationCatalog"
    Write-Host "       Kernel:  $LiteralPath"

    return @(
        $CatalogMatches |
            ForEach-Object FullName |
            Select-Object -Unique
    )
}

try {
    Write-Host 'Legion Go AMD 26.6.2 Toolkit'
    Write-Host 'Phase 2: Verify the corrected driver under normal signing'
    Write-Host ''

    $BootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

    Write-Host '=== LOAD PHASE 1 RESULT ==='

    Assert-Condition `
        -Condition (
            Test-Path -LiteralPath $InstallResultPath -PathType Leaf
        ) `
        -Message 'Script 2 Phase 1 result exists' `
        -Details $InstallResultPath

    $InstallResult =
        Get-Content -LiteralPath $InstallResultPath -Raw |
            ConvertFrom-Json

    Assert-Condition `
        -Condition (
            (Get-OptionalProperty `
                -Object $InstallResult `
                -Name 'Installed') -eq $true
        ) `
        -Message 'Script 2 Phase 1 recorded a successful driver installation'

    Assert-Condition `
        -Condition (
            [string](Get-OptionalProperty `
                -Object $InstallResult `
                -Name 'DriverVersion') -eq $ExpectedDriverVersion
        ) `
        -Message 'Script 2 Phase 1 recorded the expected driver version' `
        -Details (
            [string](Get-OptionalProperty `
                -Object $InstallResult `
                -Name 'DriverVersion')
        )

    Assert-Condition `
        -Condition (
            [string](Get-OptionalProperty `
                -Object $InstallResult `
                -Name 'ActiveInfSHA256') -eq $ExpectedInfHash
        ) `
        -Message 'Script 2 Phase 1 recorded the expected active INF hash'

    Assert-Condition `
        -Condition (
            [string](Get-OptionalProperty `
                -Object $InstallResult `
                -Name 'KernelSHA256') -eq $ExpectedKernelHash
        ) `
        -Message 'Script 2 Phase 1 recorded the expected kernel hash'

    $Stage03InstalledAt =
        [datetime](Get-OptionalProperty `
            -Object $InstallResult `
            -Name 'InstalledAt')

    Assert-Condition `
        -Condition ($BootTime -gt $Stage03InstalledAt) `
        -Message 'Windows rebooted after Script 2 Phase 1 disabled Test Signing' `
        -Details (
            "Stage03InstalledAt=$Stage03InstalledAt; " +
            "CurrentBoot=$BootTime"
        )

    $RecordedSigningStatePath =
        [string](Get-OptionalProperty `
            -Object $InstallResult `
            -Name 'CatalogSigningStatePath')

    if (-not [string]::IsNullOrWhiteSpace($RecordedSigningStatePath)) {
        $CatalogSigningStatePath = $RecordedSigningStatePath
    }

    Write-Host ''
    Write-Host '=== LOAD DYNAMIC CATALOG-SIGNING STATE ==='

    Assert-Condition `
        -Condition (
            Test-Path `
                -LiteralPath $CatalogSigningStatePath `
                -PathType Leaf
        ) `
        -Message 'Catalog-signing state exists' `
        -Details $CatalogSigningStatePath

    $SigningState =
        Get-Content -LiteralPath $CatalogSigningStatePath -Raw |
            ConvertFrom-Json

    $ExpectedLocalCatalogHash =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'SignedCatalogSHA256')

    $ExpectedSignerThumbprint =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'CatalogSignerThumbprint')

    if ([string]::IsNullOrWhiteSpace($ExpectedSignerThumbprint)) {
        $ExpectedSignerThumbprint =
            [string](Get-OptionalProperty `
                -Object $SigningState `
                -Name 'CertificateThumbprint')
    }

    Assert-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace(
                $ExpectedLocalCatalogHash
            )
        ) `
        -Message 'Signing state contains the per-user CAT hash'

    Assert-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace(
                $ExpectedSignerThumbprint
            )
        ) `
        -Message 'Signing state contains the per-user signer thumbprint'

    Write-Host ''
    Write-Host '=== BOOT TRUST STATE ==='

    try {
        $SecureBootEnabled = Confirm-SecureBootUEFI
    }
    catch {
        throw "Unable to query Secure Boot: $($_.Exception.Message)"
    }

    $BcdOutput = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"

    $TestSigningEnabled =
        $BcdOutput -match '(?im)^\s*testsigning\s+Yes\s*$'

    Write-Host "Secure Boot enabled: $SecureBootEnabled"
    Write-Host "Test Signing enabled: $TestSigningEnabled"

    Assert-Condition `
        -Condition (-not $TestSigningEnabled) `
        -Message 'Test Signing is disabled after the Script 2 Phase 1 reboot'

    Write-Host ''
    Write-Host '=== ACTIVE GPU AFTER REBOOT ==='

    $GpuDriver = Get-GpuDriver
    $GpuEntity = Get-GpuEntity
    $ActiveInfPath = Join-Path $env:windir "INF\$($GpuDriver.InfName)"

    Assert-Condition `
        -Condition (
            Test-Path -LiteralPath $ActiveInfPath -PathType Leaf
        ) `
        -Message 'Active published INF exists' `
        -Details $ActiveInfPath

    $ActiveInfHash = Get-SHA256 -LiteralPath $ActiveInfPath

    [pscustomobject]@{
        DeviceName      = $GpuDriver.DeviceName
        DeviceID        = $GpuDriver.DeviceID
        ActiveINF       = $GpuDriver.InfName
        DriverVersion   = $GpuDriver.DriverVersion
        ActiveInfSHA256 = $ActiveInfHash
        Status          = $GpuEntity.Status
        ProblemCode     = $GpuEntity.ConfigManagerErrorCode
    } | Format-List

    Assert-Condition `
        -Condition (
            $GpuDriver.DriverVersion -eq $ExpectedDriverVersion
        ) `
        -Message 'Corrected 26.6.2 driver survived reboot' `
        -Details "DriverVersion=$($GpuDriver.DriverVersion)"

    Assert-Condition `
        -Condition ($ActiveInfHash -eq $ExpectedInfHash) `
        -Message 'Active INF hash survived reboot' `
        -Details "SHA256=$ActiveInfHash"

    Assert-Condition `
        -Condition (
            $GpuEntity.Status -eq 'OK' -and
            $GpuEntity.ConfigManagerErrorCode -eq 0
        ) `
        -Message 'GPU is healthy after reboot' `
        -Details (
            "Status=$($GpuEntity.Status); " +
            "ProblemCode=$($GpuEntity.ConfigManagerErrorCode)"
        )

    Write-Host ''
    Write-Host '=== DRIVER STORE AND PER-USER CATALOG ==='

    $DriverStorePackage = Get-ValidatedDriverStorePackage

    $DriverStoreDetails = ''

    if ($null -ne $DriverStorePackage) {
        $DriverStoreDetails = [string]$DriverStorePackage.FullName
    }

    Assert-Condition `
        -Condition ($null -ne $DriverStorePackage) `
        -Message 'Validated display package remains in Driver Store' `
        -Details $DriverStoreDetails

    $DriverStorePath = $DriverStorePackage.FullName
    $LocalCatalogPath = Join-Path $DriverStorePath 'u0201589.cat'

    Assert-Condition `
        -Condition (
            Test-Path -LiteralPath $LocalCatalogPath -PathType Leaf
        ) `
        -Message 'Per-user catalog remains in the Driver Store' `
        -Details $LocalCatalogPath

    $LocalCatalogHash = Get-SHA256 -LiteralPath $LocalCatalogPath
    $LocalCatalogSignature =
        Get-AuthenticodeSignature -LiteralPath $LocalCatalogPath

    $ActualSignerThumbprint = ''

    if ($null -ne $LocalCatalogSignature.SignerCertificate) {
        $ActualSignerThumbprint =
            [string]$LocalCatalogSignature.SignerCertificate.Thumbprint
    }

    Assert-Condition `
        -Condition (
            $LocalCatalogHash -eq $ExpectedLocalCatalogHash
        ) `
        -Message 'Per-user catalog hash matches signing state' `
        -Details "SHA256=$LocalCatalogHash"

    Assert-Condition `
        -Condition (
            $LocalCatalogSignature.Status -eq 'Valid' -and
            $ActualSignerThumbprint -eq $ExpectedSignerThumbprint
        ) `
        -Message 'Per-user catalog signature remains valid' `
        -Details (
            "Status=$($LocalCatalogSignature.Status); " +
            "Thumbprint=$ActualSignerThumbprint"
        )

    $RootCertificate =
        Get-LocalMachineCertificate `
            -StoreName Root `
            -Thumbprint $ExpectedSignerThumbprint

    $PublisherCertificate =
        Get-LocalMachineCertificate `
            -StoreName TrustedPublisher `
            -Thumbprint $ExpectedSignerThumbprint

    Assert-Condition `
        -Condition (
            $null -ne $RootCertificate -and
            $null -ne $PublisherCertificate
        ) `
        -Message 'Per-user catalog signer remains trusted' `
        -Details (
            "Root=$($null -ne $RootCertificate); " +
            "TrustedPublisher=$($null -ne $PublisherCertificate)"
        )

    Write-Host ''
    Write-Host '=== RUNNING GPU KERNEL SERVICE ==='

    $GpuEnumPath =
        'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $GpuDriver.DeviceID

    $GpuEnumValues = Get-ItemProperty -LiteralPath $GpuEnumPath
    $KernelServiceName = [string]$GpuEnumValues.Service

    Assert-Condition `
        -Condition (
            -not [string]::IsNullOrWhiteSpace($KernelServiceName)
        ) `
        -Message 'GPU has a kernel-service assignment' `
        -Details $KernelServiceName

    $KernelService =
        Get-CimInstance Win32_SystemDriver |
            Where-Object Name -EQ $KernelServiceName |
            Select-Object -First 1

    Assert-Condition `
        -Condition ($null -ne $KernelService) `
        -Message 'GPU kernel service exists' `
        -Details $KernelServiceName

    $KernelPath = Resolve-KernelPath -RawPath $KernelService.PathName

    Assert-Condition `
        -Condition (
            Test-Path -LiteralPath $KernelPath -PathType Leaf
        ) `
        -Message 'Running AMD kernel file exists' `
        -Details $KernelPath

    $KernelHash = Get-SHA256 -LiteralPath $KernelPath
    $KernelVersion = (Get-Item -LiteralPath $KernelPath).VersionInfo.FileVersion

    [pscustomobject]@{
        ServiceName = $KernelServiceName
        State       = $KernelService.State
        Started     = $KernelService.Started
        KernelPath  = $KernelPath
        FileVersion = $KernelVersion
        SHA256      = $KernelHash
    } | Format-List

    Assert-Condition `
        -Condition (
            $KernelService.State -eq 'Running' -and
            $KernelService.Started
        ) `
        -Message 'GPU kernel service is running' `
        -Details "Service=$KernelServiceName"

    Assert-Condition `
        -Condition ($KernelHash -eq $ExpectedKernelHash) `
        -Message 'Loaded amdkmdag.sys hash matches' `
        -Details "SHA256=$KernelHash"

    Assert-Condition `
        -Condition (
            $KernelVersion -match (
                '(?<!\d)' +
                [regex]::Escape($ExpectedDriverVersion) +
                '(?!\d)'
            )
        ) `
        -Message 'Loaded amdkmdag.sys version matches' `
        -Details "FileVersion=$KernelVersion"

    Assert-Condition `
        -Condition (
            $KernelPath.StartsWith(
                $DriverStorePath,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) `
        -Message 'Kernel is loaded from the validated Driver Store package' `
        -Details $KernelPath

    Write-Host ''
    Write-Host '=== OFFICIAL MICROSOFT-SIGNED AMD CATALOG ==='

    $RegisteredCatalogPaths =
        @(Get-RegisteredCatalogsForFile -LiteralPath $KernelPath)

    $OfficialCatalogMatches = @()

    foreach ($RegisteredCatalogPath in $RegisteredCatalogPaths) {
        if (
            -not (
                Test-Path `
                    -LiteralPath $RegisteredCatalogPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        $RegisteredCatalogHash =
            Get-SHA256 -LiteralPath $RegisteredCatalogPath

        if ($RegisteredCatalogHash -ne $ExpectedOfficialCatalogHash) {
            continue
        }

        $RegisteredSignature =
            Get-AuthenticodeSignature `
                -LiteralPath $RegisteredCatalogPath

        $RegisteredSigner = ''

        if ($null -ne $RegisteredSignature.SignerCertificate) {
            $RegisteredSigner =
                [string]$RegisteredSignature.SignerCertificate.Subject
        }

        $OfficialCatalogMatches += [pscustomobject]@{
            Path            = $RegisteredCatalogPath
            SHA256          = $RegisteredCatalogHash
            SignatureStatus = [string]$RegisteredSignature.Status
            SignerSubject   = $RegisteredSigner
            Valid           = (
                $RegisteredSignature.Status -eq 'Valid' -and
                $RegisteredSigner -match
                    '^CN=Microsoft Windows Hardware Compatibility Publisher,'
            )
        }
    }

    Assert-Condition `
        -Condition ($OfficialCatalogMatches.Count -gt 0) `
        -Message (
            'Official AMD catalog remains registered for the loaded kernel'
        ) `
        -Details (
            ($OfficialCatalogMatches |
                ForEach-Object Path) -join '; '
        )

    $InvalidOfficialCatalogs = @(
        $OfficialCatalogMatches |
            Where-Object Valid -EQ $false
    )

    Assert-Condition `
        -Condition ($InvalidOfficialCatalogs.Count -eq 0) `
        -Message 'Registered official AMD catalog signature remains valid' `
        -Details (
            ($OfficialCatalogMatches |
                ForEach-Object {
                    "$($_.SignatureStatus):$($_.SignerSubject)"
                }) -join '; '
        )

    Write-Host ''
    Write-Host '=== LENOVO EXTENSION ATTACHMENT ==='

    $ExtensionState =
        Get-LenovoExtensionState `
            -DeviceInstanceId $GpuDriver.DeviceID

    Assert-Condition `
        -Condition $ExtensionState.InventoryCreated `
        -Message 'Structured PnP driver inventory was created' `
        -Details (
            "ExitCode=$($ExtensionState.ExitCode); " +
            "Inventory=$($ExtensionState.InventoryPath)"
        )

    Assert-Condition `
        -Condition $ExtensionState.Attached `
        -Message 'Required Lenovo extension remains attached to the GPU' `
        -Details (
            "INF=$ExpectedExtensionOriginalName; " +
            "Version=$ExpectedExtensionVersion; " +
            "Matches=$($ExtensionState.MatchingRecords.Count)"
        )

    Write-Host ''
    Write-Host '=== AMDUWP COMPONENT ==='

    $AmduwpState = Get-AmduwpState

    $AmduwpState.Devices |
        Select-Object Name, DeviceID, Status, ConfigManagerErrorCode |
        Format-List

    Assert-Condition `
        -Condition $AmduwpState.Healthy `
        -Message 'AMDUWP is present and healthy' `
        -Details (
            "Present=$($AmduwpState.Present); " +
            "DeviceCount=$($AmduwpState.Devices.Count)"
        )

    Write-Host ''
    Write-Host '=== RELEVANT ERRORS SINCE CURRENT BOOT ==='

    $CodeIntegrityEvents = @(
        Get-WinEvent `
            -FilterHashtable @{
                LogName   =
                    'Microsoft-Windows-CodeIntegrity/Operational'
                StartTime = $BootTime
                Level     = 2, 3
            } `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Message -match (
                    '(?i)' +
                    'amdkmdag|u0201589|oem\d+\.inf|' +
                    'VEN_1002|DEV_15BF'
                )
            }
    )

    $SystemEvents = @(
        Get-WinEvent `
            -FilterHashtable @{
                LogName   = 'System'
                StartTime = $BootTime
                Level     = 2, 3
            } `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProviderName -match
                    '(?i)Kernel-PnP|Display|amdkmdag' -and
                $_.Message -match
                    '(?i)amdkmdag|u0201589|VEN_1002|DEV_15BF'
            }
    )

    $RelevantEvents = @($CodeIntegrityEvents) + @($SystemEvents)

    if ($RelevantEvents.Count -gt 0) {
        $RelevantEvents |
            Select-Object `
                TimeCreated,
                ProviderName,
                Id,
                LevelDisplayName,
                Message |
            Format-List
    }
    else {
        Write-Host 'None found.'
    }

    Assert-Condition `
        -Condition ($RelevantEvents.Count -eq 0) `
        -Message (
            'No relevant Code Integrity or GPU startup errors since boot'
        ) `
        -Details "EventCount=$($RelevantEvents.Count)"

    $OfficialCatalogLocations = @(
        $OfficialCatalogMatches |
            ForEach-Object Path
    )

    $AmduwpDeviceIDs = @(
        $AmduwpState.Devices |
            ForEach-Object DeviceID
    )

    $ValidationResult = [ordered]@{
        SchemaVersion                 = 2
        Workflow                      = 'LegionGo-AMD-26.6.2'
        Validated                     = $true
        ValidatedAt                   = (Get-Date).ToString('o')
        BootTime                      = $BootTime
        Stage03InstalledAt             = $Stage03InstalledAt
        RebootAfterStage03Confirmed    = $true
        SecureBootEnabled             = $SecureBootEnabled
        TestSigningEnabled            = $false
        ActiveINF                     = $GpuDriver.InfName
        DriverVersion                 = $GpuDriver.DriverVersion
        ActiveInfSHA256               = $ActiveInfHash
        DriverStorePackage            = $DriverStorePath
        LocalCatalogPath              = $LocalCatalogPath
        LocalCatalogSHA256            = $LocalCatalogHash
        LocalCatalogSignerThumbprint  = $ActualSignerThumbprint
        CatalogSigningStatePath       = $CatalogSigningStatePath
        KernelService                 = $KernelServiceName
        KernelPath                    = $KernelPath
        KernelSHA256                  = $KernelHash
        OfficialCatalogLocations      = $OfficialCatalogLocations
        LenovoExtensionAttached       = $ExtensionState.Attached
        PnPInventoryPath              = $PnPInventoryPath
        AMDUWPDeviceIDs               = $AmduwpDeviceIDs
        AMDUWPHealthy                 = $AmduwpState.Healthy
        RelevantErrorCount            = $RelevantEvents.Count
        NextStage                     = '05-Install-Native-AMD-Software-And-Reboot'
        LogPath                       = $LogPath
    }

    $ValidationResult |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $ResultPath -Encoding UTF8

    $State = [ordered]@{
        SchemaVersion                 = 2
        Workflow                      = 'LegionGo-AMD-26.6.2'
        Stage                         = 'Ready-For-Native-AMD-Software'
        UpdatedAt                     = (Get-Date).ToString('o')
        ActiveINF                     = $GpuDriver.InfName
        DriverVersion                 = $GpuDriver.DriverVersion
        KernelService                 = $KernelServiceName
        CatalogSigningStatePath       = $CatalogSigningStatePath
        LocalCatalogSignerThumbprint  = $ActualSignerThumbprint
        LenovoExtensionAttached       = $ExtensionState.Attached
        AMDUWPHealthy                 = $AmduwpState.Healthy
        TestSigningEnabled            = $false
        SecureBootEnabled             = $SecureBootEnabled
        NextStage                     = $ValidationResult.NextStage
        ResultPath                    = $ResultPath
        LogPath                       = $LogPath
    }

    $State |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $StatePath -Encoding UTF8

    Write-Host ''
    Write-Host '=== PHASE 2 COMPLETE ==='
    Write-Host "Result file: $ResultPath"
    Write-Host "State file:  $StatePath"
    Write-Host "Log file:    $LogPath"

    Write-Host ''

    if ($SecureBootEnabled) {
        Write-Host (
            'Secure Boot is enabled. Script 3 may continue.'
        )
    }
    else {
        Write-Host (
            'Secure Boot remains disabled by user choice. Script 3 may ' +
            'continue with Secure Boot either OFF or ON.'
        )
    }

    Write-Host 'Run Script 3 next.'

}
finally {
    Stop-Transcript | Out-Null
}
'@
        )
    }
    'lib\Security-Hardening.ps1' = [ordered]@{
        SHA256 = '49D4E18DE24850D41AFB532EDEA04DFAD33C7B94A42A1CE6FA1237A1D81800CF'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#Requires -Version 5.1

function Get-WorkflowSecurityPrincipalSid {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('System', 'Administrators', 'Users', 'AuthenticatedUsers', 'Everyone')]
        [string]$Name
    )

    $Map = @{
        System             = 'S-1-5-18'
        Administrators     = 'S-1-5-32-544'
        Users              = 'S-1-5-32-545'
        AuthenticatedUsers = 'S-1-5-11'
        Everyone           = 'S-1-1-0'
    }

    return [System.Security.Principal.SecurityIdentifier]::new($Map[$Name])
}

function Set-SecureDirectoryAcl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$AllowStandardUsersReadExecute
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    New-Item -ItemType Directory -Path $FullPath -Force | Out-Null

    $Acl = [System.Security.AccessControl.DirectorySecurity]::new()
    $Acl.SetAccessRuleProtection($true, $false)

    $Administrators = Get-WorkflowSecurityPrincipalSid -Name Administrators
    $System = Get-WorkflowSecurityPrincipalSid -Name System
    $Users = Get-WorkflowSecurityPrincipalSid -Name Users

    $Inheritance =
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit

    $Propagation = [System.Security.AccessControl.PropagationFlags]::None
    $Allow = [System.Security.AccessControl.AccessControlType]::Allow

    $Acl.SetOwner($Administrators)

    foreach ($Identity in @($System, $Administrators)) {
        $Rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $Identity,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            $Inheritance,
            $Propagation,
            $Allow
        )

        [void]$Acl.AddAccessRule($Rule)
    }

    if ($AllowStandardUsersReadExecute) {
        $ReadRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $Users,
            [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
            $Inheritance,
            $Propagation,
            $Allow
        )

        [void]$Acl.AddAccessRule($ReadRule)
    }

    Set-Acl -LiteralPath $FullPath -AclObject $Acl

    return Get-SecureDirectoryAclState `
        -Path $FullPath `
        -AllowStandardUsersReadExecute:$AllowStandardUsersReadExecute
}

function Get-SecureDirectoryAclState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$AllowStandardUsersReadExecute
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)

    if (-not (Test-Path -LiteralPath $FullPath -PathType Container)) {
        return [pscustomobject]@{
            Path                  = $FullPath
            Exists                = $false
            InheritanceProtected  = $false
            SystemFullControl     = $false
            AdministratorsFullControl = $false
            StandardUsersReadExecute  = $false
            StandardUsersWritable     = $true
            Secure                = $false
            Sddl                  = $null
        }
    }

    $Acl = Get-Acl -LiteralPath $FullPath
    $SystemSid = (Get-WorkflowSecurityPrincipalSid -Name System).Value
    $AdministratorsSid =
        (Get-WorkflowSecurityPrincipalSid -Name Administrators).Value
    $UsersSid = (Get-WorkflowSecurityPrincipalSid -Name Users).Value

    $UntrustedSids = @(
        $UsersSid
        (Get-WorkflowSecurityPrincipalSid -Name AuthenticatedUsers).Value
        (Get-WorkflowSecurityPrincipalSid -Name Everyone).Value
    )

    $WriteMask =
        [System.Security.AccessControl.FileSystemRights]::Write -bor
        [System.Security.AccessControl.FileSystemRights]::Modify -bor
        [System.Security.AccessControl.FileSystemRights]::FullControl -bor
        [System.Security.AccessControl.FileSystemRights]::Delete -bor
        [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership

    $Rules = @(
        $Acl.GetAccessRules(
            $true,
            $true,
            [System.Security.Principal.SecurityIdentifier]
        )
    )

    $SystemFull = $false
    $AdministratorsFull = $false
    $UsersRead = $false
    $StandardUsersWritable = $false

    foreach ($Rule in $Rules) {
        if (
            $Rule.AccessControlType -ne
                [System.Security.AccessControl.AccessControlType]::Allow
        ) {
            continue
        }

        $Sid = $Rule.IdentityReference.Value
        $Rights = [System.Security.AccessControl.FileSystemRights]$Rule.FileSystemRights

        if (
            $Sid -eq $SystemSid -and
            (($Rights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq
                [System.Security.AccessControl.FileSystemRights]::FullControl)
        ) {
            $SystemFull = $true
        }

        if (
            $Sid -eq $AdministratorsSid -and
            (($Rights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq
                [System.Security.AccessControl.FileSystemRights]::FullControl)
        ) {
            $AdministratorsFull = $true
        }

        if (
            $Sid -eq $UsersSid -and
            (($Rights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq
                [System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
        ) {
            $UsersRead = $true
        }

        if (
            $Sid -in $UntrustedSids -and
            (($Rights -band $WriteMask) -ne 0)
        ) {
            $StandardUsersWritable = $true
        }
    }

    $Secure =
        [bool]$Acl.AreAccessRulesProtected -and
        $SystemFull -and
        $AdministratorsFull -and
        (-not $StandardUsersWritable) -and
        (
            (-not $AllowStandardUsersReadExecute) -or
            $UsersRead
        )

    return [pscustomobject]@{
        Path                       = $FullPath
        Exists                     = $true
        InheritanceProtected       = [bool]$Acl.AreAccessRulesProtected
        SystemFullControl          = $SystemFull
        AdministratorsFullControl  = $AdministratorsFull
        StandardUsersReadExecute   = $UsersRead
        StandardUsersWritable      = $StandardUsersWritable
        Secure                     = $Secure
        Sddl                       = $Acl.Sddl
    }
}

function Protect-WorkflowStateDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $State = Set-SecureDirectoryAcl -Path $Path

    if (-not $State.Secure) {
        throw "Failed to secure workflow state directory: $Path"
    }

    return $State
}

function Protect-WorkflowWorkspaceDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $State = Set-SecureDirectoryAcl -Path $Path

    if (-not $State.Secure) {
        throw "Failed to secure workflow workspace directory: $Path"
    }

    return $State
}

function Protect-WorkflowProgramDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $State = Set-SecureDirectoryAcl `
        -Path $Path `
        -AllowStandardUsersReadExecute

    if (-not $State.Secure) {
        throw "Failed to secure installed program directory: $Path"
    }

    return $State
}
'@
        )
    }
}

Write-Host ''
Write-Host 'Legion Go AMD 26.6.2 Toolkit' -ForegroundColor White
Write-Host 'Script 2 of 4: Install and verify the corrected driver' `
    -ForegroundColor White
Write-Host ''
Write-Host 'Embedded payload format: Readable plain text'
Write-Host 'Install confirmation: Required'
Write-Host 'Windows restart confirmation: Required'
Write-Host 'Forced application closure: Disabled'
Write-Host 'Secure Boot changes: Not performed by Script 2'
Write-Host "State directory: $StateRoot"
Write-Host ''

Write-Host '=== VERIFY EMBEDDED WORKFLOW COMPONENTS ===' `
    -ForegroundColor White

New-Item -ItemType Directory -Path $InternalRoot -Force | Out-Null

foreach ($RelativePath in $EmbeddedPayload.Keys) {
    $Entry = $EmbeddedPayload[$RelativePath]
    $Destination = Join-Path $InternalRoot $RelativePath
    $Bytes = Convert-PlainTextPayloadToBytes -Entry $Entry
    $ExpectedHash = [string]$Entry.SHA256
    $PayloadHash = (
        [BitConverter]::ToString(
            [Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)
        ) -replace '-', ''
    ).ToUpperInvariant()

    if ($PayloadHash -ne $ExpectedHash) {
        throw @"
Embedded plain-text payload verification failed before write.
File:     $RelativePath
Expected: $ExpectedHash
Actual:   $PayloadHash
"@
    }

    $NeedsWrite = $true

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if ((Get-SHA256 -LiteralPath $Destination) -eq $ExpectedHash) {
            $NeedsWrite = $false
        }
    }

    if ($NeedsWrite) {
        Write-AtomicBytes -Bytes $Bytes -LiteralPath $Destination
    }

    $WrittenHash = Get-SHA256 -LiteralPath $Destination

    if ($WrittenHash -ne $ExpectedHash) {
        throw @"
Embedded plain-text payload verification failed after write.
File:     $RelativePath
Expected: $ExpectedHash
Actual:   $WrittenHash
"@
    }

    $Label = switch ($RelativePath) {
        'Phase-01-Install-Corrected-Driver.ps1' {
            'Phase 1 corrected-driver installation component'
        }
        'Phase-02-Verify-Normal-Signing.ps1' {
            'Phase 2 normal-signing verification component'
        }
        'lib\Security-Hardening.ps1' {
            'Security hardening library'
        }
        default { $RelativePath }
    }

    Write-Host "[PASS] $Label"
}

$Phase01Path =
    Join-Path $InternalRoot 'Phase-01-Install-Corrected-Driver.ps1'
$Phase02Path =
    Join-Path $InternalRoot 'Phase-02-Verify-Normal-Signing.ps1'

if (Test-Phase02Complete) {
    Write-Host ''
    Write-Host (
        '[PASS] Saved validation and the live system both prove normal-' +
        'signing persistence.'
    ) -ForegroundColor Green
    Write-Script02Pass
    return
}

if (-not (Test-Phase01Complete)) {
    foreach ($RequiredStatePath in @(
        $PayloadVerificationPath
        $CatalogSigningStatePath
        $BootPreparationResultPath
    )) {
        if (-not (Test-Path -LiteralPath $RequiredStatePath -PathType Leaf)) {
            throw (
                'Script 1 state is incomplete. Missing required file: ' +
                $RequiredStatePath
            )
        }
    }

    $CurrentState = Get-LiveDriverState

    Write-Host ''
    Write-Host '=== PRE-INSTALL LIVE STATE ===' -ForegroundColor White

    if ($CurrentState.QuerySucceeded) {
        [pscustomobject]@{
            DeviceName = $CurrentState.DeviceName
            ActiveINF = $CurrentState.ActiveINF
            DriverVersion = $CurrentState.DriverVersion
            ActiveInfSHA256 = $CurrentState.ActiveInfSHA256
            KernelSHA256 = $CurrentState.KernelSHA256
            Status = $CurrentState.Status
            ProblemCode = $CurrentState.ProblemCode
        } | Format-List
    }
    else {
        Write-Host "[WARN] Live GPU query failed: $($CurrentState.Error)" `
            -ForegroundColor Yellow
    }

    Write-Host '=== INSTALLATION RISK CONFIRMATION ===' `
        -ForegroundColor Yellow
    Write-Host (
        'Script 2 will modify the installed display driver, Driver Store, ' +
        'LocalMachine certificate trust, catalog registration, and the ' +
        'Test Signing boot setting.'
    )
    Write-Host (
        'The display may briefly reset. A Windows restart is required after ' +
        'installation.'
    )

    if (-not (Confirm-UserAction -Prompt 'Install the corrected driver now?')) {
        Write-Host ''
        Write-Host '[INFO] Driver installation was declined; nothing changed.'
        return
    }

    Invoke-InternalPhase `
        -DisplayName 'PHASE 1 — INSTALL THE CORRECTED DRIVER' `
        -ScriptPath $Phase01Path `
        -PhaseArguments @(
            '-VerificationResultPath'
            $PayloadVerificationPath
            '-CatalogSigningStatePath'
            $CatalogSigningStatePath
            '-BootPreparationResultPath'
            $BootPreparationResultPath
            '-NoReboot'
        )

    if (-not (Test-Phase01Complete)) {
        throw (
            'Phase 1 did not leave a successful result that matches the ' +
            'currently active GPU, INF, and loaded kernel.'
        )
    }

    Request-WindowsRestart
    return
}

$InstallResult = Read-JsonFile -LiteralPath $InstallResultPath
$InstalledAt =
    Convert-ToDateTime -Value (
        Get-OptionalProperty -Object $InstallResult -Name 'InstalledAt'
    )

if ($null -eq $InstalledAt) {
    throw (
        'Phase 1 result exists, but InstalledAt cannot be read safely: ' +
        $InstallResultPath
    )
}

$CurrentBoot =
    (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

if ($CurrentBoot -le $InstalledAt) {
    Write-Host ''
    Write-Host '[INFO] Windows has not restarted since Phase 1 completed.' `
        -ForegroundColor Yellow
    Write-Host "Phase 1 installed at: $InstalledAt"
    Write-Host "Current boot:         $CurrentBoot"
    Request-WindowsRestart
    return
}

Invoke-InternalPhase `
    -DisplayName 'PHASE 2 — VERIFY NORMAL-SIGNING PERSISTENCE' `
    -ScriptPath $Phase02Path `
    -PhaseArguments @(
        '-InstallResultPath'
        $InstallResultPath
        '-CatalogSigningStatePath'
        $CatalogSigningStatePath
    )

if (-not (Test-Phase02Complete)) {
    throw (
        'Phase 2 did not leave a successful result that agrees with the ' +
        'live driver, loaded kernel, GPU health, current boot, and normal ' +
        'signing state.'
    )
}

Write-Script02Pass
