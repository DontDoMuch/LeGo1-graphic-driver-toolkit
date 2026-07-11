#requires -Version 5.1
<#
.SYNOPSIS
    Legion Go AMD 26.6.2 Toolkit — Script 1 of 4.

    Verifies the required environment, builds the corrected display-driver
    package, signs it locally, and prepares Windows Test Signing.

.DESCRIPTION
    This script supports the original Lenovo Legion Go GPU identity:

      PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA

    Place the exact AMD 26.6.2 installer beside this script:

      whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe

    The toolkit verifies the installer filename, length, SHA-256 identity, and
    AMD digital signature. It does not download AMD or Lenovo software and
    does not accept AMD's EULA on the user's behalf.

    Script 1 normally runs twice.

    First run:
      - verifies the Legion Go and required tools;
      - asks for confirmation before installing any missing prerequisites;
      - verifies and extracts the local AMD installer;
      - builds the corrected driver package;
      - creates a unique local signing certificate and catalog;
      - enables Test Signing; and
      - asks for confirmation before restarting Windows.

    Second run, after Windows starts in Test Signing mode:
      - verifies that the required restart occurred;
      - confirms Test Signing is active; and
      - records that Script 2 may continue.

    If Secure Boot is enabled, the script records its current state and asks
    before restarting into UEFI firmware settings. Secure Boot must be disabled
    before Test Signing can become active.

    Script 1 does not install or bind the corrected display driver. Script 2
    performs that operation.

    Embedded workflow components are reconstructed into the protected state
    directory and verified against their declared SHA-256 identities before
    execution. PowerShell 7 is used for the package-build phase because
    amdgcf.dat must be written as UTF-8 without a byte-order mark. Windows
    PowerShell 5.1 is used for the remaining phases.

.NOTES
    Run from an administrator account. If the current process is not elevated,
    the script opens a User Account Control prompt and restarts itself with
    administrative rights.

    State directory:
      C:\ProgramData\LegionGo-AMD-26.6.2

    Workspace:
      C:\AMD\LegionGo-26.6.2

    This is an independent, unofficial compatibility toolkit. It is not
    affiliated with, authorized by, sponsored by, or endorsed by AMD, Lenovo,
    or Microsoft.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StateRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'
$WorkspaceRoot = Join-Path $env:SystemDrive 'AMD\LegionGo-26.6.2'
$InternalRoot = Join-Path $StateRoot 'Toolkit-Script-01\Internal'
$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$ExpectedInstallerName =
    'whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe'

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
            $PartText =
                ([string]$Part) -replace "`r`n", "`n"

            $PartText -replace "`r", "`n"
        }
    )

    $Text = $NormalizedParts -join "`n"

    if ([bool]$Entry.TrailingNewline) {
        $Text += "`n"
    }

    switch ([string]$Entry.LineEnding) {
        'LF' {
            break
        }
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

    $Encoding =
        [Text.UTF8Encoding]::new([bool]$Entry.Utf8Bom)

    $Preamble = $Encoding.GetPreamble()
    $ContentBytes = $Encoding.GetBytes($Text)
    $Bytes =
        New-Object byte[] (
            $Preamble.Length + $ContentBytes.Length
        )

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

function Invoke-EmbeddedPhase {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$HostPath,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter()]
        [string[]]$PhaseArguments = @()
    )

    if (-not (Test-Path -LiteralPath $HostPath -PathType Leaf)) {
        throw "Required PowerShell host is missing: $HostPath"
    }

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Embedded phase script is missing: $ScriptPath"
    }

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host $DisplayName -ForegroundColor White
    Write-Host ('=' * 72) -ForegroundColor White
    Write-Host ''

    & $HostPath `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ScriptPath `
        @PhaseArguments

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        throw "$DisplayName failed with exit code $ExitCode."
    }
}

function Test-Phase02Complete {
    $AuditPath = Join-Path $StateRoot 'source-package-audit.json'
    $Audit = Read-JsonFile -LiteralPath $AuditPath

    if ($null -eq $Audit -or -not [bool]$Audit.AuditPassed) {
        return $false
    }

    $SourceRoot = [string]$Audit.Paths.SourceRoot

    return (
        -not [string]::IsNullOrWhiteSpace($SourceRoot) -and
        (Test-Path -LiteralPath $SourceRoot -PathType Container)
    )
}

function Test-Phase03Complete {
    $ResultPath = Join-Path $StateRoot 'payload-verification.json'
    $Result = Read-JsonFile -LiteralPath $ResultPath

    if (
        $null -eq $Result -or
        -not [bool]$Result.Verified -or
        -not [bool]$Result.Passed -or
        -not [bool]$Result.Complete
    ) {
        return $false
    }

    $PackageRoot = [string]$Result.PackageRoot

    if (
        [string]::IsNullOrWhiteSpace($PackageRoot) -or
        -not (Test-Path -LiteralPath $PackageRoot -PathType Container)
    ) {
        return $false
    }

    return (
        @(
            Get-ChildItem `
                -LiteralPath $PackageRoot `
                -Recurse `
                -File `
                -Force `
                -ErrorAction SilentlyContinue
        ).Count -eq 125
    )
}

function Test-Phase04Complete {
    $StatePath = Join-Path $StateRoot 'catalog-signing-state.json'
    $State = Read-JsonFile -LiteralPath $StatePath

    if (
        $null -eq $State -or
        -not [bool]$State.VerificationResultPresent -or
        -not [bool]$State.VerificationResultVerified -or
        [int]$State.SignedPackageFileCount -ne 126 -or
        [string]$State.CatalogAuthenticodeStatus -ne 'Valid'
    ) {
        return $false
    }

    foreach ($RequiredPath in @(
        [string]$State.PackageRoot
        [string]$State.SignedCatalogPath
        [string]$State.CertificatePath
    )) {
        if (
            [string]::IsNullOrWhiteSpace($RequiredPath) -or
            -not (Test-Path -LiteralPath $RequiredPath)
        ) {
            return $false
        }
    }

    return $true
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    return
}

if (-not (Test-Path -LiteralPath $WindowsPowerShell -PathType Leaf)) {
    throw "Windows PowerShell 5.1 host was not found: $WindowsPowerShell"
}

$AdjacentInstallerPath =
    Join-Path $PSScriptRoot $ExpectedInstallerName

if (-not (Test-Path -LiteralPath $AdjacentInstallerPath -PathType Leaf)) {
    throw @"
The required AMD 26.6.2 installer is missing:

$AdjacentInstallerPath

Download it manually from AMD's official support website, place it beside
this script and the other toolkit scripts, and run Script 1 again.

Script 1 does not download AMD software and does not accept AMD's EULA on your
behalf.
"@
}

$EmbeddedPayload = [ordered]@{
    # Exact Frozen R6 components stored as readable plain text.
    'Phase-01-Check-Prerequisites.ps1' = [ordered]@{
        SHA256 = '8F192E7B726882FFCC832817346A147AEB943E6066E222BC4AF8CAAF1B5DB2F7'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 1 prerequisite checker for Script 1 of the Legion Go AMD 26.6.2 Toolkit.

.DESCRIPTION
    Performs the fixed platform and dependency checks required before the AMD
    source package is inspected or modified.

    The script:
      - Self-elevates when needed.
      - Verifies Windows 11 x64.
      - Verifies the original Legion Go GPU hardware identity.
      - Verifies free space on the selected workspace volume.
      - Detects PowerShell 7, 7-Zip, Inf2Cat, and x64 SignTool.
      - Lists missing dependencies and asks before using WinGet.
      - Re-runs every check after installation.
      - Writes an atomic JSON prerequisite-state file for the remaining toolkit phases.

    It does not remove drivers, invoke DDU, delete C:\AMD, modify boot settings,
    install a graphics driver, or run the AMD installer.

.PARAMETER StateRoot
    Persistent project state and log directory.

.PARAMETER WorkspaceRoot
    Future extraction/build workspace. This script only validates its volume.

.PARAMETER CheckOnly
    Detect requirements but do not install missing dependencies.

.EXAMPLE
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Phase-01-Check-Prerequisites.ps1

.EXAMPLE
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Phase-01-Check-Prerequisites.ps1 `
        -WorkspaceRoot 'D:\LegionGo-AMD-26.6.2'
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StateRoot = (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceRoot = (Join-Path $env:SystemDrive 'AMD\LegionGo-26.6.2'),

    [Parameter()]
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath

# Fixed project constants. Paths are deliberately not fixed.
$ProjectName = 'Legion Go AMD 26.6.2'
$ScriptVersion = '1.0'
$RequiredGpuHardwareIdPrefix = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA'
$MinimumWindowsBuild = 22000
$MinimumPowerShellVersion = [version]'7.4.0'
$RequiredWindowsKitBuild = 28000
$MinimumFreeBytes = 12GB

$DependencyPackages = [ordered]@{
    PowerShell = 'Microsoft.PowerShell'
    SevenZip   = '7zip.7zip'
    WindowsSDK = 'Microsoft.WindowsSDK.10.0.28000'
    WindowsWDK = 'Microsoft.WindowsWDK.10.0.28000'
}

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PASS', 'FAIL', 'INFO', 'WARN')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $prefix = "[$Level]"
    switch ($Level) {
        'PASS' { Write-Host "$prefix $Message" -ForegroundColor Green }
        'FAIL' { Write-Host "$prefix $Message" -ForegroundColor Red }
        'WARN' { Write-Host "$prefix $Message" -ForegroundColor Yellow }
        default { Write-Host "$prefix $Message" -ForegroundColor Cyan }
    }
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

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-ProcessArgument {
    param([Parameter(Mandatory)][string]$Value)
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Restart-Elevated {
    if (-not $PSCommandPath) {
        throw 'Cannot self-elevate because PSCommandPath is unavailable.'
    }

    $hostCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $hostCommand) {
        $hostCommand = Get-Command powershell.exe -ErrorAction Stop
    }

    $argumentParts = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        (Quote-ProcessArgument -Value $PSCommandPath)
        '-StateRoot'
        (Quote-ProcessArgument -Value $StateRoot)
        '-WorkspaceRoot'
        (Quote-ProcessArgument -Value $WorkspaceRoot)
    )

    if ($CheckOnly) {
        $argumentParts += '-CheckOnly'
    }
    Write-Status INFO 'Administrative elevation is required. Opening a UAC prompt.'
    Start-Process -FilePath $hostCommand.Source -Verb RunAs -ArgumentList ($argumentParts -join ' ') | Out-Null
}

function Get-WorkspaceVolume {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if (-not $root) {
        throw "Unable to resolve a local volume from workspace path: $Path"
    }

    $deviceId = $root.TrimEnd('\')
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$deviceId'" -ErrorAction Stop
    if (-not $disk) {
        throw "Unable to query workspace volume: $deviceId"
    }

    return [pscustomobject]@{
        WorkspacePath = $fullPath
        DeviceId      = $deviceId
        DriveType     = [int]$disk.DriveType
        FileSystem    = [string]$disk.FileSystem
        FreeBytes     = [int64]$disk.FreeSpace
        SizeBytes     = [int64]$disk.Size
    }
}

function Get-PowerShell7 {
    $candidates =
        New-Object 'System.Collections.Generic.List[string]'

    $command =
        Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($command -and $command.Source) {
        [void]$candidates.Add([string]$command.Source)
    }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')
        (Join-Path $env:ProgramFiles 'PowerShell\7-preview\pwsh.exe')
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            [void]$candidates.Add($candidate)
        }
    }

    foreach ($path in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }

        try {
            $versionText = (
                & $path `
                    -NoProfile `
                    -Command '$PSVersionTable.PSVersion.ToString()' `
                    2>$null |
                Select-Object -First 1
            )

            $version =
                [version]([string]$versionText).Trim()

            return [pscustomobject]@{
                Path    = [string]$path
                Version = $version
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function Get-SevenZip {
    $candidates = New-Object System.Collections.Generic.List[string]

    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        [void]$candidates.Add([string]$command.Source)
    }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe' })
    )) {
        if ($candidate) {
            [void]$candidates.Add([string]$candidate)
        }
    }

    $path = $candidates |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not $path) {
        return $null
    }

    return [pscustomobject]@{
        Path    = [string]$path
        Version = [string](Get-Item -LiteralPath $path).VersionInfo.FileVersion
    }
}

function ConvertTo-KitVersion {
    param([Parameter(Mandatory)][string]$Name)

    try {
        return [version]$Name
    }
    catch {
        return $null
    }
}

function Get-WindowsKitPair {
    $binRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $binRoot -PathType Container)) {
        return $null
    }

    $versionDirectories = foreach ($directory in Get-ChildItem -LiteralPath $binRoot -Directory -ErrorAction SilentlyContinue) {
        $version = ConvertTo-KitVersion -Name $directory.Name
        if ($version) {
            [pscustomobject]@{
                Directory = $directory
                Version   = $version
            }
        }
    }

    $versionDirectories = @(
        $versionDirectories |
            Where-Object { $_.Version.Build -ge $RequiredWindowsKitBuild } |
            Sort-Object Version -Descending
    )

    foreach ($entry in $versionDirectories) {
        $inf2CatCandidates = @(
            (Join-Path $entry.Directory.FullName 'x64\Inf2Cat.exe')
            (Join-Path $entry.Directory.FullName 'x86\Inf2Cat.exe')
        )

        $inf2Cat = $inf2CatCandidates |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1

        $signTool = Join-Path $entry.Directory.FullName 'x64\signtool.exe'

        if ($inf2Cat -and (Test-Path -LiteralPath $signTool -PathType Leaf)) {
            return [pscustomobject]@{
                KitVersion   = $entry.Version
                Inf2CatPath  = [string]$inf2Cat
                SignToolPath = [string]$signTool
            }
        }
    }

    return $null
}

function Test-ToolCommand {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ExpectedPattern
    )

    $stdoutPath = Join-Path $env:TEMP ("LegionGo-ToolTest-{0}.stdout.txt" -f [guid]::NewGuid().ToString('N'))
    $stderrPath = Join-Path $env:TEMP ("LegionGo-ToolTest-{0}.stderr.txt" -f [guid]::NewGuid().ToString('N'))

    try {
        $process = Start-Process `
            -FilePath $Path `
            -ArgumentList $Arguments `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -NoNewWindow `
            -Wait `
            -PassThru

        $stdout = if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
            Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        }
        else {
            ''
        }

        $stderr = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        }
        else {
            ''
        }

        $output = (@($stdout, $stderr) | Where-Object { $_ } | Out-String).Trim()
        $exitCode = [int]$process.ExitCode

        return [pscustomobject]@{
            Success  = [bool]($output -match $ExpectedPattern -and $exitCode -in @(0, 1))
            ExitCode = $exitCode
            Output   = $output
        }
    }
    catch {
        return [pscustomobject]@{
            Success  = $false
            ExitCode = $null
            Output   = $_.Exception.Message
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-WinGet {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return [string]$command.Source
    }

    $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $aliasPath -PathType Leaf) {
        return $aliasPath
    }

    return $null
}

function Update-ProcessEnvironmentPath {
    $machinePath =
        [Environment]::GetEnvironmentVariable(
            'Path',
            [EnvironmentVariableTarget]::Machine
        )

    $userPath =
        [Environment]::GetEnvironmentVariable(
            'Path',
            [EnvironmentVariableTarget]::User
        )

    $combined =
        @(
            $machinePath
            $userPath
        ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }

    $env:Path = $combined -join ';'
}

function Invoke-WinGetInstall {
    param(
        [Parameter(Mandatory)][string]$WinGetPath,
        [Parameter(Mandatory)][string]$PackageId
    )

    Write-Status INFO "Installing missing dependency: $PackageId"

    $arguments = @(
        'install'
        '--id', $PackageId
        '--exact'
        '--source', 'winget'
        '--silent'
        '--disable-interactivity'
        '--accept-source-agreements'
        '--accept-package-agreements'
    )

    $global:LASTEXITCODE = 0
    & $WinGetPath @arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Status WARN "WinGet returned exit code $exitCode for $PackageId. The post-install re-scan will determine whether installation succeeded."
    }
}

function Get-PlatformState {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

    $gpu = Get-CimInstance Win32_PnPEntity -ErrorAction Stop |
        Where-Object {
            $_.DeviceID -and
            $_.DeviceID.StartsWith($RequiredGpuHardwareIdPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        Select-Object -First 1

    $volume = Get-WorkspaceVolume -Path $WorkspaceRoot

    return [pscustomobject]@{
        OS = [pscustomobject]@{
            Caption      = [string]$os.Caption
            Version      = [string]$os.Version
            BuildNumber  = [int]$os.BuildNumber
            ProductType  = [int]$os.ProductType
            Architecture = [string]$os.OSArchitecture
        }
        Computer = [pscustomobject]@{
            Manufacturer = [string]$computer.Manufacturer
            Model        = [string]$computer.Model
            SystemType   = [string]$computer.SystemType
        }
        GPU = $(if ($gpu) {
            [pscustomobject]@{
                Name       = [string]$gpu.Name
                DeviceID   = [string]$gpu.DeviceID
                Status     = [string]$gpu.Status
                PNPClass   = [string]$gpu.PNPClass
            }
        }
        else {
            $null
        })
        WorkspaceVolume = $volume
    }
}

function Get-DependencyState {
    $powerShell7 = Get-PowerShell7
    $sevenZip = Get-SevenZip
    $kitPair = Get-WindowsKitPair
    $wingetPath = Get-WinGet

    $sevenZipTest = $null
    if ($sevenZip) {
        $sevenZipTest = Test-ToolCommand -Path $sevenZip.Path -Arguments @('i') -ExpectedPattern '7-Zip'
    }

    $inf2CatTest = $null
    $signToolTest = $null
    if ($kitPair) {
        $inf2CatTest = Test-ToolCommand -Path $kitPair.Inf2CatPath -Arguments @('/?') -ExpectedPattern 'Inf2Cat'
        $signToolTest = Test-ToolCommand -Path $kitPair.SignToolPath -Arguments @('/?') -ExpectedPattern 'SignTool'
    }

    return [pscustomobject]@{
        WinGet = [pscustomobject]@{
            Present = [bool]$wingetPath
            Path    = $wingetPath
        }
        PowerShell7 = [pscustomobject]@{
            Present = [bool]$powerShell7
            Path    = $(if ($powerShell7) { $powerShell7.Path } else { $null })
            Version = $(if ($powerShell7) { [string]$powerShell7.Version } else { $null })
            MeetsMinimum = [bool]($powerShell7 -and $powerShell7.Version -ge $MinimumPowerShellVersion)
        }
        SevenZip = [pscustomobject]@{
            Present = [bool]$sevenZip
            Path    = $(if ($sevenZip) { $sevenZip.Path } else { $null })
            Version = $(if ($sevenZip) { $sevenZip.Version } else { $null })
            Functional = [bool]($sevenZipTest -and $sevenZipTest.Success)
            TestExitCode = $(if ($sevenZipTest) { $sevenZipTest.ExitCode } else { $null })
        }
        WindowsKit = [pscustomobject]@{
            Present      = [bool]$kitPair
            KitVersion   = $(if ($kitPair) { [string]$kitPair.KitVersion } else { $null })
            MeetsBuild   = [bool]($kitPair -and $kitPair.KitVersion.Build -ge $RequiredWindowsKitBuild)
            Inf2CatPath  = $(if ($kitPair) { $kitPair.Inf2CatPath } else { $null })
            Inf2CatWorks = [bool]($inf2CatTest -and $inf2CatTest.Success)
            SignToolPath = $(if ($kitPair) { $kitPair.SignToolPath } else { $null })
            SignToolWorks = [bool]($signToolTest -and $signToolTest.Success)
        }
    }
}

function Get-MissingDependencyPackages {
    param([Parameter(Mandatory)]$Dependencies)

    $packages = New-Object System.Collections.Generic.List[string]

    if (-not $Dependencies.PowerShell7.MeetsMinimum) {
        [void]$packages.Add($DependencyPackages.PowerShell)
    }

    if (-not ($Dependencies.SevenZip.Present -and $Dependencies.SevenZip.Functional)) {
        [void]$packages.Add($DependencyPackages.SevenZip)
    }

    $kitReady = (
        $Dependencies.WindowsKit.Present -and
        $Dependencies.WindowsKit.MeetsBuild -and
        $Dependencies.WindowsKit.Inf2CatWorks -and
        $Dependencies.WindowsKit.SignToolWorks
    )

    if (-not $kitReady) {
        [void]$packages.Add($DependencyPackages.WindowsSDK)
        [void]$packages.Add($DependencyPackages.WindowsWDK)
    }

    return @($packages | Select-Object -Unique)
}

function Test-AllRequirements {
    param(
        [Parameter(Mandatory)]$Platform,
        [Parameter(Mandatory)]$Dependencies
    )

    $checks = New-Object System.Collections.Generic.List[object]

    $checks.Add([pscustomobject]@{
        Name = 'Windows 11 client build'
        Pass = [bool](
            $Platform.OS.ProductType -eq 1 -and
            $Platform.OS.BuildNumber -ge $MinimumWindowsBuild -and
            $Platform.OS.Architecture -match '64'
        )
        Detail = "$($Platform.OS.Caption); build $($Platform.OS.BuildNumber); $($Platform.OS.Architecture)"
    })

    $checks.Add([pscustomobject]@{
        Name = 'Lenovo Legion Go GPU hardware identity'
        Pass = [bool]$Platform.GPU
        Detail = $(if ($Platform.GPU) { $Platform.GPU.DeviceID } else { "Required prefix not found: $RequiredGpuHardwareIdPrefix" })
    })

    $checks.Add([pscustomobject]@{
        Name = 'Workspace free space'
        Pass = [bool]($Platform.WorkspaceVolume.FreeBytes -ge $MinimumFreeBytes)
        Detail = ('{0:N2} GiB free on {1}; minimum {2:N0} GiB' -f (
            $Platform.WorkspaceVolume.FreeBytes / 1GB
        ), $Platform.WorkspaceVolume.DeviceId, ($MinimumFreeBytes / 1GB))
    })

    $checks.Add([pscustomobject]@{
        Name = 'PowerShell 7'
        Pass = [bool]$Dependencies.PowerShell7.MeetsMinimum
        Detail = $(if ($Dependencies.PowerShell7.Present) {
            "$($Dependencies.PowerShell7.Version) at $($Dependencies.PowerShell7.Path); minimum $MinimumPowerShellVersion"
        } else {
            "Not found; minimum $MinimumPowerShellVersion"
        })
    })

    $checks.Add([pscustomobject]@{
        Name = '7-Zip command-line tool'
        Pass = [bool]($Dependencies.SevenZip.Present -and $Dependencies.SevenZip.Functional)
        Detail = $(if ($Dependencies.SevenZip.Present) {
            "$($Dependencies.SevenZip.Version) at $($Dependencies.SevenZip.Path)"
        } else {
            'Not found'
        })
    })

    $checks.Add([pscustomobject]@{
        Name = 'Windows Kit Inf2Cat and x64 SignTool'
        Pass = [bool](
            $Dependencies.WindowsKit.Present -and
            $Dependencies.WindowsKit.MeetsBuild -and
            $Dependencies.WindowsKit.Inf2CatWorks -and
            $Dependencies.WindowsKit.SignToolWorks
        )
        Detail = $(if ($Dependencies.WindowsKit.Present) {
            "Kit $($Dependencies.WindowsKit.KitVersion); Inf2Cat=$($Dependencies.WindowsKit.Inf2CatPath); SignTool=$($Dependencies.WindowsKit.SignToolPath)"
        } else {
            "No matching SDK/WDK pair at build $RequiredWindowsKitBuild or newer"
        })
    })

    return @($checks | ForEach-Object { $_ })
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    $json = $InputObject | ConvertTo-Json -Depth 10
    $temporaryPath = "$Path.tmp.$PID.$([guid]::NewGuid().ToString('N'))"
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

    [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    exit 0
}

$StateAcl = Protect-WorkflowStateDirectory -Path $StateRoot
$WorkspaceAcl = Protect-WorkflowWorkspaceDirectory -Path $WorkspaceRoot

New-Item -ItemType Directory -Path $StateRoot -Force | Out-Null
$logRoot = Join-Path $StateRoot 'Logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logPath = Join-Path $logRoot ("Phase-01-Prerequisites-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$transcriptStarted = $false

try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true

    Write-Host "State directory:      $StateRoot"
    Write-Host "Workspace:            $WorkspaceRoot"
    Write-Host "State ACL secure:     $($StateAcl.Secure)"
    Write-Host "Workspace ACL secure: $($WorkspaceAcl.Secure)"
    Write-Host ''

    Write-Host '=== INITIAL PLATFORM CHECK ===' -ForegroundColor White
    $platform = Get-PlatformState

    Write-Status INFO "$($platform.OS.Caption), build $($platform.OS.BuildNumber), $($platform.OS.Architecture)"
    Write-Status INFO "$($platform.Computer.Manufacturer) $($platform.Computer.Model)"
    if ($platform.GPU) {
        Write-Status PASS "Required GPU identity found: $($platform.GPU.DeviceID)"
    }
    else {
        Write-Status FAIL "Required GPU identity not found: $RequiredGpuHardwareIdPrefix"
    }
    Write-Status INFO ('Workspace volume {0} {1:N2} GiB free' -f (
        $platform.WorkspaceVolume.DeviceId
    ), ($platform.WorkspaceVolume.FreeBytes / 1GB))

    Write-Host ''
    Write-Host '=== INITIAL DEPENDENCY CHECK ===' -ForegroundColor White
    $dependencies = Get-DependencyState
    $missingPackages = @(Get-MissingDependencyPackages -Dependencies $dependencies)

    if ($dependencies.PowerShell7.MeetsMinimum) {
        Write-Status PASS "PowerShell $($dependencies.PowerShell7.Version): $($dependencies.PowerShell7.Path)"
    }
    else {
        Write-Status FAIL "PowerShell $MinimumPowerShellVersion or newer not found"
    }

    if ($dependencies.SevenZip.Present -and $dependencies.SevenZip.Functional) {
        Write-Status PASS "7-Zip $($dependencies.SevenZip.Version): $($dependencies.SevenZip.Path)"
    }
    else {
        Write-Status FAIL 'A functional 7-Zip command-line tool was not found'
    }

    if (
        $dependencies.WindowsKit.Present -and
        $dependencies.WindowsKit.MeetsBuild -and
        $dependencies.WindowsKit.Inf2CatWorks -and
        $dependencies.WindowsKit.SignToolWorks
    ) {
        Write-Status PASS "Windows Kit $($dependencies.WindowsKit.KitVersion)"
        Write-Status PASS "Inf2Cat: $($dependencies.WindowsKit.Inf2CatPath)"
        Write-Status PASS "SignTool: $($dependencies.WindowsKit.SignToolPath)"
    }
    else {
        Write-Status FAIL "Matching Windows SDK/WDK build $RequiredWindowsKitBuild tools were not found or failed execution"
    }

    if ($missingPackages.Count -gt 0) {
        Write-Host ''
        Write-Host 'Missing dependency packages:' -ForegroundColor Yellow
        $missingPackages | ForEach-Object { Write-Host "  - $_" }

        if ($CheckOnly) {
            Write-Status WARN 'CheckOnly was specified; no dependency installation will be attempted.'
        }
        else {
            if (-not $dependencies.WinGet.Present) {
                throw @'
WinGet is required to install missing dependencies but was not found.
Install or repair Microsoft App Installer from the Microsoft Store, then rerun
this script. No driver or boot configuration changes were made.
'@
            "'@"
@'
            }

            Write-Host (
                'The toolkit will use WinGet only for the packages listed above.'
            ) -ForegroundColor Yellow
            $approved = Confirm-UserAction `
                -Prompt 'Install the listed dependencies now?'

            if (-not $approved) {
                Write-Status WARN 'Dependency installation was declined; no packages were installed.'
            }
            else {
                Write-Host ''
                Write-Host '=== INSTALL MISSING DEPENDENCIES ===' -ForegroundColor White

                foreach ($packageId in $missingPackages) {
                    Invoke-WinGetInstall `
                        -WinGetPath $dependencies.WinGet.Path `
                        -PackageId $packageId
                }

                Update-ProcessEnvironmentPath

                Write-Host ''
                Write-Host '=== POST-INSTALL DEPENDENCY RE-SCAN ===' -ForegroundColor White
                $dependencies = Get-DependencyState
                $missingPackages = @(Get-MissingDependencyPackages -Dependencies $dependencies)
            }
        }
    }
    else {
        Write-Status PASS 'All required dependencies were already present; nothing was installed.'
    }

    Write-Host ''
    Write-Host '=== FINAL REQUIREMENT VERIFICATION ===' -ForegroundColor White
    $checks = @(Test-AllRequirements -Platform $platform -Dependencies $dependencies)

    foreach ($check in $checks) {
        if ($check.Pass) {
            Write-Status PASS "$($check.Name): $($check.Detail)"
        }
        else {
            Write-Status FAIL "$($check.Name): $($check.Detail)"
        }
    }

    $allPassed = @($checks | Where-Object { -not $_.Pass }).Count -eq 0
    $statePath = Join-Path $StateRoot 'prerequisite-state.json'

    $state = [ordered]@{
        SchemaVersion = 2
        Project       = $ProjectName
        ScriptVersion = $ScriptVersion
        GeneratedAt   = (Get-Date).ToString('o')
        AllPassed     = $allPassed
        Constants     = [ordered]@{
            RequiredGpuHardwareIdPrefix = $RequiredGpuHardwareIdPrefix
            MinimumWindowsBuild         = $MinimumWindowsBuild
            MinimumPowerShellVersion    = [string]$MinimumPowerShellVersion
            RequiredWindowsKitBuild     = $RequiredWindowsKitBuild
            MinimumFreeBytes            = $MinimumFreeBytes
            DependencyPackages          = $DependencyPackages
        }
        Paths = [ordered]@{
            StateRoot     = [System.IO.Path]::GetFullPath($StateRoot)
            WorkspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
            ScriptPath    = $PSCommandPath
            LogPath       = $logPath
        }
        Platform     = $platform
        Dependencies = $dependencies
        Checks       = $checks
        InstalledDriverModified = $false
        CertificateStoresModified = $false
        BootConfigurationModified = $false
        NextStage = '01-Acquire-Download-Extract-And-Audit-AMD-Source'
    }

    Write-AtomicJson -InputObject $state -Path $statePath

    Write-Host ''
    if ($allPassed) {
        Write-Host 'PHASE 1 PASS: True' -ForegroundColor Green
        Write-Host "Result file: $statePath"
        Write-Host (
            'No graphics driver, certificate store, boot configuration, ' +
            'or existing workspace content was changed.'
        )
        exit 0
    }

    Write-Host 'PHASE 1 PASS: False' -ForegroundColor Red
    Write-Host "Result file: $statePath"

    if ($missingPackages.Count -gt 0) {
        Write-Host 'Still missing or nonfunctional:' -ForegroundColor Red
        $missingPackages | ForEach-Object { Write-Host "  - $_" }
    }

    exit 2
}
catch {
    Write-Host ''
    Write-Status FAIL $_.Exception.Message
    Write-Host "Log file: $logPath"
    exit 1
}
finally {
    if ($transcriptStarted) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
            # Do not mask the real result with transcript cleanup failure.
        }
    }
}
'@
        )
    }
    'Phase-02-Verify-Extract-And-Audit-AMD-Source.ps1' = [ordered]@{
        SHA256 = '626C6331E6436C63D2F2242E3605B4DB89E380C9567806C1546EFD610000DC08'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 2 source verification, extraction, and identity audit for Script 1
    of the Legion Go AMD 26.6.2 Toolkit.

.DESCRIPTION
    Consumes the prerequisite-state.json written by Phase 1 and requires the
    user-supplied official AMD 26.6.2 Windows 11 "-c" installer at the path
    provided by the wrapper. It verifies the installer's fixed package identity,
    extracts it into a unique project-controlled workspace with 7-Zip, and
    audits the exact WT6A_INF source needed by the remaining build and signing phases.

    This phase never downloads AMD software and never accepts AMD's EULA on the
    user's behalf.

    This phase does not:
      - Install an AMD graphics driver.
      - Run AMD Setup.exe or ATISetup.exe.
      - Modify any INF or catalog.
      - Create or import certificates.
      - Change Secure Boot or Test Signing.
      - Delete or reuse unrelated C:\AMD folders.

.PARAMETER AmdInstallerPath
    Required local path to the official AMD source installer supplied by the
    user. The wrapper requires this exact file beside the four public scripts.

.PARAMETER StateRoot
    Persistent project state directory created by Phase 1.

.PARAMETER WorkspaceRoot
    Optional workspace override. When omitted, Phase 1's verified workspace is
    used.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
      .\Phase-02-Verify-Extract-And-Audit-AMD-Source.ps1 `
      -AmdInstallerPath 'D:\Downloads\whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AmdInstallerPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StateRoot = (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'),

    [Parameter()]
    [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath

# Fixed identity for the currently available official AMD 26.6.2 Windows 11 package.
$ProjectName = 'Legion Go AMD 26.6.2'
$ScriptVersion = '1.0'

$ExpectedInstallerFileName =
    'whql-amd-software-adrenalin-edition-26.6.2-win11-c.exe'

$ExpectedInstallerLength = [int64]1630707976
$ExpectedInstallerSha256 =
    '3FD0073C74E0D043558087511F5624ED42D1241E852C2A9ED5AC5C80F158F893'

$ExpectedInstallerVersion = '26.6.2.0'
$ExpectedInstallerSignerThumbprint =
    '33D35682079E201671B738B7209B4586103BC271'

$ExpectedInstallerSignerSubjectPattern =
    'CN=Advanced Micro Devices'

# Exact official 26.6.2 WT6A_INF source identities.
$ExpectedDisplaySourceFileCount = 194

$ExpectedOfficialInfSha256 =
    '97C64806E91AA2EB6F2B17A94369FBB884A8048ACD9A8F9FCD59155797AC4FA6'

$ExpectedOfficialCatalogSha256 =
    '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'

$ExpectedKernelSha256 =
    'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'

$ExpectedAmdgcfSha256 =
    '740C379B33945AC60BA1C0A9386F48BAB894524018B1F5F9D2788D7E33585185'

$ExpectedAtiicdxxSha256 =
    'DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F'

$ExpectedSourceCcc2Length = [int64]242517520
$ExpectedSourceCcc2Sha256 =
    '804BB7C852E2003948D5945C99058DB58080D41692CF36CE6BDD6FC93E2ACC48'

$RequiredGpuHardwareId =
    'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA'

$ExpectedDriverVersion = '32.0.31021.1015'

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PASS', 'FAIL', 'INFO', 'WARN')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    switch ($Level) {
        'PASS' { Write-Host "[$Level] $Message" -ForegroundColor Green }
        'FAIL' { Write-Host "[$Level] $Message" -ForegroundColor Red }
        'WARN' { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
        default { Write-Host "[$Level] $Message" -ForegroundColor Cyan }
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-ProcessArgument {
    param([Parameter(Mandatory)][string]$Value)
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Restart-Elevated {
    if (-not $PSCommandPath) {
        throw 'Cannot self-elevate because PSCommandPath is unavailable.'
    }

    $hostCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $hostCommand) {
        $hostCommand = Get-Command powershell.exe -ErrorAction Stop
    }

    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        (Quote-ProcessArgument -Value $PSCommandPath)
        '-StateRoot'
        (Quote-ProcessArgument -Value $StateRoot)
    )

    if ($AmdInstallerPath) {
        $arguments += '-AmdInstallerPath'
        $arguments += (Quote-ProcessArgument -Value $AmdInstallerPath)
    }

    if ($WorkspaceRoot) {
        $arguments += '-WorkspaceRoot'
        $arguments += (Quote-ProcessArgument -Value $WorkspaceRoot)
    }

    Write-Status INFO 'Administrative elevation is required. Opening a UAC prompt.'
    Start-Process -FilePath $hostCommand.Source -Verb RunAs -ArgumentList ($arguments -join ' ') | Out-Null
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    $temporaryPath = "$Path.tmp.$PID.$([guid]::NewGuid().ToString('N'))"
    $json = $InputObject | ConvertTo-Json -Depth 12
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

    [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Resolve-AmdInstaller {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequestedPath
    )

    if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
        throw @"
The required AMD 26.6.2 installer was not found at the local path supplied by
the wrapper:

$RequestedPath

Download the installer manually from AMD's official support website, place it
beside the four toolkit scripts, and rerun Script 01.

This toolkit does not download AMD software and does not accept AMD's EULA on
your behalf.
"@
    }

    return (Resolve-Path -LiteralPath $RequestedPath -ErrorAction Stop).Path
}

function Invoke-NativeProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$LogBasePath
    )

    $stdoutPath = "$LogBasePath.stdout.txt"
    $stderrPath = "$LogBasePath.stderr.txt"

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -NoNewWindow `
        -Wait `
        -PassThru

    $stdout = if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
        Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    }
    else {
        ''
    }

    $stderr = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
        Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    }
    else {
        ''
    }

    return [pscustomobject]@{
        ExitCode   = [int]$process.ExitCode
        StdOutPath = $stdoutPath
        StdErrPath = $stderrPath
        StdOut     = [string]$stdout
        StdErr     = [string]$stderr
    }
}

function Get-FileIdentity {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath,
        [string]$ExpectedSha256,
        [Nullable[int64]]$ExpectedLength
    )

    $path = Join-Path $Root $RelativePath
    $exists = Test-Path -LiteralPath $path -PathType Leaf

    if (-not $exists) {
        return [pscustomobject]@{
            RelativePath    = $RelativePath
            FullName        = $path
            Exists          = $false
            Length          = $null
            SHA256          = $null
            ExpectedSHA256  = $ExpectedSha256
            HashMatches     = $false
            ExpectedLength  = $ExpectedLength
            LengthMatches   = $false
        }
    }

    $item = Get-Item -LiteralPath $path
    $hash = Get-Sha256 -LiteralPath $path

    return [pscustomobject]@{
        RelativePath    = $RelativePath
        FullName        = $item.FullName
        Exists          = $true
        Length          = [int64]$item.Length
        SHA256          = $hash
        ExpectedSHA256  = $ExpectedSha256
        HashMatches     = $(if ($ExpectedSha256) { $hash -eq $ExpectedSha256 } else { $null })
        ExpectedLength  = $ExpectedLength
        LengthMatches   = $(if ($null -ne $ExpectedLength) { [int64]$item.Length -eq [int64]$ExpectedLength } else { $null })
    }
}

if (-not (Test-IsAdministrator)) {
    Restart-Elevated
    exit 0
}

$prerequisiteStatePath = Join-Path $StateRoot 'prerequisite-state.json'
if (-not (Test-Path -LiteralPath $prerequisiteStatePath -PathType Leaf)) {
    throw "Phase 1 prerequisite state was not found: $prerequisiteStatePath"
}

$prerequisiteState = Get-Content -LiteralPath $prerequisiteStatePath -Raw | ConvertFrom-Json

if (-not [bool]$prerequisiteState.AllPassed) {
    throw 'Phase 1 prerequisite state does not report AllPassed=true.'
}

$sevenZipPath = [string]$prerequisiteState.Dependencies.SevenZip.Path
if (-not (Test-Path -LiteralPath $sevenZipPath -PathType Leaf)) {
    throw "The verified 7-Zip executable no longer exists: $sevenZipPath"
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = [string]$prerequisiteState.Paths.WorkspaceRoot
}

$WorkspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
$StateAcl = Protect-WorkflowStateDirectory -Path $StateRoot
$WorkspaceAcl = Protect-WorkflowWorkspaceDirectory -Path $WorkspaceRoot
New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null

$logRoot = Join-Path $StateRoot 'Logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logRoot "Phase-02-Verify-Extract-Audit-$runId.log"
$transcriptStarted = $false

try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true

    Write-Host "State directory: $StateRoot"
    Write-Host "Workspace:       $WorkspaceRoot"
    Write-Host ''

    Write-Host '=== VERIFY LOCAL AMD INSTALLER ===' -ForegroundColor White
    $resolvedInstaller = Resolve-AmdInstaller -RequestedPath $AmdInstallerPath
    $installerItem = Get-Item -LiteralPath $resolvedInstaller
    $installerHash = Get-Sha256 -LiteralPath $resolvedInstaller
    $installerSignature = Get-AuthenticodeSignature -LiteralPath $resolvedInstaller
    $installerVersion = [string]$installerItem.VersionInfo.FileVersion
    $productVersion = [string]$installerItem.VersionInfo.ProductVersion
    $signerThumbprint = if ($installerSignature.SignerCertificate) {
        [string]$installerSignature.SignerCertificate.Thumbprint
    }
    else {
        $null
    }
    $signerSubject = if ($installerSignature.SignerCertificate) {
        [string]$installerSignature.SignerCertificate.Subject
    }
    else {
        $null
    }

    $installerChecks = @(
        [pscustomobject]@{
            Name   = 'Installer length'
            Pass   = [bool]([int64]$installerItem.Length -eq $ExpectedInstallerLength)
            Detail = "Expected=$ExpectedInstallerLength; Actual=$($installerItem.Length)"
        }
        [pscustomobject]@{
            Name   = 'Installer SHA-256'
            Pass   = [bool]($installerHash -eq $ExpectedInstallerSha256)
            Detail = $installerHash
        }
        [pscustomobject]@{
            Name   = 'Authenticode status'
            Pass   = [bool]($installerSignature.Status -eq 'Valid')
            Detail = [string]$installerSignature.Status
        }
        [pscustomobject]@{
            Name   = 'AMD signer thumbprint'
            Pass   = [bool]($signerThumbprint -eq $ExpectedInstallerSignerThumbprint)
            Detail = [string]$signerThumbprint
        }
        [pscustomobject]@{
            Name   = 'AMD signer subject'
            Pass   = [bool]($signerSubject -like "$ExpectedInstallerSignerSubjectPattern*")
            Detail = [string]$signerSubject
        }
        [pscustomobject]@{
            Name   = 'File version'
            Pass   = [bool]($installerVersion -eq $ExpectedInstallerVersion)
            Detail = $installerVersion
        }
        [pscustomobject]@{
            Name   = 'Product version'
            Pass   = [bool]($productVersion -eq $ExpectedInstallerVersion)
            Detail = $productVersion
        }
    )

    foreach ($check in $installerChecks) {
        if ($check.Pass) {
            Write-Status PASS "$($check.Name): $($check.Detail)"
        }
        else {
            Write-Status FAIL "$($check.Name): $($check.Detail)"
        }
    }

    if ($installerItem.Name -ne $ExpectedInstallerFileName) {
        Write-Status WARN "Filename differs from the canonical AMD name, but fixed package identity will control acceptance: $($installerItem.Name)"
    }
    else {
        Write-Status PASS "Canonical filename: $($installerItem.Name)"
    }

    if (@($installerChecks | Where-Object { -not $_.Pass }).Count -gt 0) {
        throw 'The selected AMD installer failed its fixed identity contract. Extraction was not attempted.'
    }

    Write-Host ''
    Write-Host '=== EXTRACT VERIFIED AMD PACKAGE ===' -ForegroundColor White
    $sourceRoot = Join-Path $WorkspaceRoot "Source-c-$runId"
    New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

    $extractLogBase = Join-Path $logRoot "Phase-02-7Zip-Extract-$runId"
    $extractArguments = @(
        'x'
        '-y'
        '-bb1'
        ('-o' + (Quote-ProcessArgument -Value $sourceRoot))
        (Quote-ProcessArgument -Value $resolvedInstaller)
    )

    $extractResult = Invoke-NativeProcess `
        -FilePath $sevenZipPath `
        -ArgumentList $extractArguments `
        -LogBasePath $extractLogBase

    if ($extractResult.ExitCode -ne 0) {
        throw "7-Zip extraction failed with exit code $($extractResult.ExitCode). See $($extractResult.StdOutPath) and $($extractResult.StdErrPath)."
    }

    Write-Status PASS "7-Zip extraction completed: $sourceRoot"

    $displaySourceRoot =
        Join-Path $sourceRoot 'Packages\Drivers\Display\WT6A_INF'

    if (-not (Test-Path -LiteralPath $displaySourceRoot -PathType Container)) {
        throw "Required WT6A_INF source root is missing: $displaySourceRoot"
    }

    $displaySourceFileCount = @(
        Get-ChildItem `
            -LiteralPath $displaySourceRoot `
            -Recurse `
            -File `
            -Force
    ).Count

    if ($displaySourceFileCount -ne $ExpectedDisplaySourceFileCount) {
        throw (
            'WT6A_INF source file-count mismatch. ' +
            "Expected=$ExpectedDisplaySourceFileCount; " +
            "Actual=$displaySourceFileCount"
        )
    }

    Write-Status PASS "WT6A_INF source file count: $displaySourceFileCount"

    Write-Host ''
    Write-Host '=== AUDIT EXACT DISPLAY SOURCE PACKAGE ===' -ForegroundColor White

    $criticalFiles = @(
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\u0201589.inf' -ExpectedSha256 $ExpectedOfficialInfSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\u0201589.cat' -ExpectedSha256 $ExpectedOfficialCatalogSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026175\amdkmdag.sys' -ExpectedSha256 $ExpectedKernelSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026175\amdgcf.dat' -ExpectedSha256 $ExpectedAmdgcfSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026175\atiicdxx.dat' -ExpectedSha256 $ExpectedAtiicdxxSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026175\ccc2_install.exe' -ExpectedSha256 $ExpectedSourceCcc2Sha256 -ExpectedLength $ExpectedSourceCcc2Length
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\amdwin\amdwin-u0201589.inf'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\amdwin\amdwin-u0201589.cat'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Setup.exe'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Bin64\Setup.exe'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Bin64\ATISetup.exe'
    )

    foreach ($file in $criticalFiles) {
        if (-not $file.Exists) {
            Write-Status FAIL "Missing: $($file.RelativePath)"
            continue
        }

        $identityPass = $true
        if ($null -ne $file.HashMatches -and -not $file.HashMatches) {
            $identityPass = $false
        }
        if ($null -ne $file.LengthMatches -and -not $file.LengthMatches) {
            $identityPass = $false
        }

        if ($identityPass) {
            Write-Status PASS "$($file.RelativePath) | $($file.Length) bytes | $($file.SHA256)"
        }
        else {
            Write-Status FAIL "$($file.RelativePath) identity mismatch | $($file.Length) bytes | $($file.SHA256)"
        }
    }

    $sourceInfPath = Join-Path $sourceRoot 'Packages\Drivers\Display\WT6A_INF\u0201589.inf'
    if (-not (Test-Path -LiteralPath $sourceInfPath -PathType Leaf)) {
        throw 'The required source INF is missing after extraction.'
    }

    $sourceInfText = Get-Content -LiteralPath $sourceInfPath -Raw
    $driverVersionMatch = [regex]::Match(
        $sourceInfText,
        '(?im)^\s*DriverVer\s*=\s*[^,\r\n]+,\s*([0-9.]+)\s*$'
    )
    $catalogMatch = [regex]::Match(
        $sourceInfText,
        '(?im)^\s*CatalogFile(?:\.[^=]+)?\s*=\s*([^\r\n;]+)'
    )

    $sourceInfSemantics = [pscustomobject]@{
        DriverVersion             = $(if ($driverVersionMatch.Success) { $driverVersionMatch.Groups[1].Value.Trim() } else { $null })
        DriverVersionMatches      = [bool]($driverVersionMatch.Success -and $driverVersionMatch.Groups[1].Value.Trim() -eq $ExpectedDriverVersion)
        CatalogFile               = $(if ($catalogMatch.Success) { $catalogMatch.Groups[1].Value.Trim() } else { $null })
        ContainsLegionGoHardwareId = [bool]($sourceInfText -match [regex]::Escape($RequiredGpuHardwareId))
        ContainsAmduwpAddComponent = [bool]($sourceInfText -match '(?im)^\s*AddComponent\s*=\s*AMDUWP')
        ContainsAmduwpComponentId  = [bool]($sourceInfText -match 'VID1002&PID0001')
        ContainsKernelBinary       = [bool]($sourceInfText -match '(?i)amdkmdag\.sys')
    }

    if ($sourceInfSemantics.DriverVersionMatches) {
        Write-Status PASS "Source INF DriverVer: $($sourceInfSemantics.DriverVersion)"
    }
    else {
        Write-Status FAIL "Unexpected source INF DriverVer: $($sourceInfSemantics.DriverVersion)"
    }

    Write-Status INFO "Source INF already contains exact Legion Go hardware ID: $($sourceInfSemantics.ContainsLegionGoHardwareId)"
    Write-Status INFO "Source INF already contains AMDUWP AddComponent: $($sourceInfSemantics.ContainsAmduwpAddComponent)"
    Write-Status INFO "Source INF already contains AMDUWP ComponentID: $($sourceInfSemantics.ContainsAmduwpComponentId)"

    $sourceCcc2Path = Join-Path $sourceRoot 'Packages\Drivers\Display\WT6A_INF\B026175\ccc2_install.exe'
    $sourceCcc2Signature = if (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) {
        Get-AuthenticodeSignature -LiteralPath $sourceCcc2Path
    }
    else {
        $null
    }

    $sourceCcc2Hash = if (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) {
        Get-Sha256 -LiteralPath $sourceCcc2Path
    }
    else {
        $null
    }

    $sourceCcc2Identity = [pscustomobject]@{
        Path                    = $sourceCcc2Path
        Exists                  = [bool](Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf)
        Length                  = $(if (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) { [int64](Get-Item -LiteralPath $sourceCcc2Path).Length } else { $null })
        SHA256                  = $sourceCcc2Hash
        ExpectedSHA256          = $ExpectedSourceCcc2Sha256
        HashMatches             = [bool]($sourceCcc2Hash -eq $ExpectedSourceCcc2Sha256)
        ExpectedLength          = $ExpectedSourceCcc2Length
        LengthMatches           = [bool](
            (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) -and
            [int64](Get-Item -LiteralPath $sourceCcc2Path).Length -eq
                $ExpectedSourceCcc2Length
        )
        SignatureStatus         = $(if ($sourceCcc2Signature) { [string]$sourceCcc2Signature.Status } else { $null })
        SignerSubject           = $(if ($sourceCcc2Signature -and $sourceCcc2Signature.SignerCertificate) { [string]$sourceCcc2Signature.SignerCertificate.Subject } else { $null })
        IncludedInDriverPackage = $false
    }

    if (
        $sourceCcc2Identity.HashMatches -and
        $sourceCcc2Identity.LengthMatches -and
        $sourceCcc2Identity.SignatureStatus -eq 'Valid' -and
        $sourceCcc2Identity.SignerSubject -match '^CN=Advanced Micro Devices,'
    ) {
        Write-Status PASS 'The separate official ccc2_install.exe identity is exact.'
    }
    else {
        throw 'The separate official ccc2_install.exe failed identity or signature validation.'
    }

    $hardFailures = New-Object System.Collections.Generic.List[string]

    foreach ($file in $criticalFiles) {
        if (-not $file.Exists) {
            [void]$hardFailures.Add("Missing $($file.RelativePath)")
            continue
        }
        if ($null -ne $file.HashMatches -and -not $file.HashMatches) {
            [void]$hardFailures.Add("Hash mismatch $($file.RelativePath)")
        }
        if ($null -ne $file.LengthMatches -and -not $file.LengthMatches) {
            [void]$hardFailures.Add("Length mismatch $($file.RelativePath)")
        }
    }

    if (-not $sourceInfSemantics.DriverVersionMatches) {
        [void]$hardFailures.Add('Source INF DriverVer mismatch')
    }

    $sourceFileCount = @(
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction Stop
    ).Count

    $auditPath = Join-Path $StateRoot 'source-package-audit.json'
    $audit = [ordered]@{
        SchemaVersion = 2
        Project       = $ProjectName
        ScriptVersion = $ScriptVersion
        GeneratedAt   = (Get-Date).ToString('o')
        AuditPassed   = [bool]($hardFailures.Count -eq 0)
        Installer     = [ordered]@{
            FullName         = $installerItem.FullName
            CanonicalName    = $ExpectedInstallerFileName
            ActualName       = $installerItem.Name
            Length           = [int64]$installerItem.Length
            SHA256           = $installerHash
            SignatureStatus  = [string]$installerSignature.Status
            SignerSubject    = $signerSubject
            SignerThumbprint = $signerThumbprint
            FileVersion      = $installerVersion
            ProductVersion   = $productVersion
        }
        Paths = [ordered]@{
            StateRoot      = [System.IO.Path]::GetFullPath($StateRoot)
            WorkspaceRoot  = $WorkspaceRoot
            ExtractionRoot = $sourceRoot
            SourceRoot     = $displaySourceRoot
            OfficialDisplayRoot = $displaySourceRoot
            OfficialCatalogPath = (
                Join-Path $displaySourceRoot 'u0201589.cat'
            )
            OfficialCcc2Path = (
                Join-Path $displaySourceRoot 'B026175\ccc2_install.exe'
            )
            PrerequisiteState = $prerequisiteStatePath
            ScriptPath     = $PSCommandPath
            LogPath        = $logPath
            ExtractStdOut  = $extractResult.StdOutPath
            ExtractStdErr  = $extractResult.StdErrPath
        }
        Extraction = [ordered]@{
            SevenZipPath          = $sevenZipPath
            ExitCode              = $extractResult.ExitCode
            ExtractionFileCount   = $sourceFileCount
            DisplaySourceFileCount = $displaySourceFileCount
        }
        CriticalFiles      = $criticalFiles
        SourceInfSemantics = $sourceInfSemantics
        SourceCcc2         = $sourceCcc2Identity
        SourceAcquisition = [ordered]@{
            Mode                  = 'User-Supplied-Local-File'
            NetworkDownloadUsed   = $false
            EulaAcceptedByToolkit = $false
        }
        InstalledDriverModified = $false
        CertificateStoresModified = $false
        BootConfigurationModified = $false
        NextStage = '02A-Build-And-Verify-Unsigned-Driver-Package'
        HardFailures       = @($hardFailures | ForEach-Object { $_ })
    }

    Write-AtomicJson -InputObject $audit -Path $auditPath

    Write-Host ''
    if ($audit.AuditPassed) {
        Write-Host 'PHASE 2 PASS: True' -ForegroundColor Green
        Write-Host "Extraction root: $sourceRoot"
        Write-Host "Result file:     $auditPath"
        Write-Host 'No installed driver, certificate store, catalog database, or boot setting was changed.'
        exit 0
    }

    Write-Host 'PHASE 2 PASS: False' -ForegroundColor Red
    Write-Host "Result file: $auditPath"
    $hardFailures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 2
}
catch {
    Write-Host ''
    Write-Status FAIL $_.Exception.Message
    Write-Host "Log file: $logPath"
    exit 1
}
finally {
    if ($transcriptStarted) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
            # Do not mask the real result with transcript cleanup failure.
        }
    }
}
'@
        )
    }
    'Phase-03-Build-And-Verify-Driver-Package.ps1' = [ordered]@{
        SHA256 = 'EB5838595519E4B0A8D1ED037088AAB68737080F7B482C74D7222CC0AF335C0E'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 7.2

<#
Phase 3 of Script 1 in the Legion Go AMD 26.6.2 Toolkit.

Consumes the exact official AMD 26.6.2 "-c" WT6A_INF source audited by
Phase 2, reproduces the canonical 125-file unsigned Legion Go driver package,
and writes payload-verification.json for Phase 4 and Script 2.

The unsigned driver package contains:
  - 123 byte-for-byte official AMD files
  - deterministically rebuilt u0201589.inf
  - deterministically rebuilt B026175\amdgcf.dat

It intentionally does not contain:
  - u0201589.cat
  - a certificate
  - ccc2_install.exe as an added driver-package file
  - Microsoft Store/AppX software

The official source-tree ccc2_install.exe is verified and recorded separately
for Script 3. This phase does not modify the installed driver, certificate
stores, boot settings, or Secure Boot.
#>

[CmdletBinding()]
param(
    [string]$StateRoot =
        (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.2'),

    [string]$SourceAuditPath,

    [string]$SourceRoot,

    [string]$OutputRoot,

    [string]$BuildBase = 'C:\AMD\LegionGo-26.6.2'
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
Set-StrictMode -Version Latest

$ExpectedOfficialSourceFileCount = 194
$ExpectedUnsignedFileCount = 125
$ExpectedUnchangedFileCount = 123

$ExpectedOfficialInfHash =
    '97C64806E91AA2EB6F2B17A94369FBB884A8048ACD9A8F9FCD59155797AC4FA6'

$ExpectedCanonicalInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'

$ExpectedOfficialDatHash =
    '740C379B33945AC60BA1C0A9386F48BAB894524018B1F5F9D2788D7E33585185'

$ExpectedCanonicalDatHash =
    'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'

$ExpectedOfficialCatalogHash =
    '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'

$ExpectedCcc2Hash =
    '804BB7C852E2003948D5945C99058DB58080D41692CF36CE6BDD6FC93E2ACC48'

$ExpectedCcc2Length = [int64]242517520

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataManifestPath =
    Join-Path $ScriptRoot 'data\Canonical-Unchanged-Files.json'
$InfBuilderPath =
    Join-Path $ScriptRoot 'lib\Build-Canonical-Inf.ps1'
$DatBuilderPath =
    Join-Path $ScriptRoot 'lib\Build-Canonical-AmdGcfDat.ps1'

$ExpectedBuilderAssetHashes = [ordered]@{
    'data\Canonical-Unchanged-Files.json' =
        '789D38519BD9EB11A0971AD4551C85E01671D8B3328CBB48BA2E00A658A5D030'

    'lib\Build-Canonical-AmdGcfDat.ps1' =
        '8941720F7A5E3B18C6482AE846B62BCBD7A85D8900F9A6FA5768515B20056206'

    'lib\Build-Canonical-Inf.ps1' =
        '8F258D6B731141B80D18D3C062FF04A1FF9504B210A85DD4B9998262258FD756'
}

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogRoot = Join-Path $StateRoot 'Logs'
$ResultPath = Join-Path $StateRoot 'payload-verification.json'
$WorkflowStatePath = Join-Path $StateRoot 'workflow-state.json'
$LogPath = Join-Path $LogRoot "Phase-03-Build-Driver-Package-$Timestamp.log"

if ([string]::IsNullOrWhiteSpace($SourceAuditPath)) {
    $SourceAuditPath = Join-Path $StateRoot 'source-package-audit.json'
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot =
        Join-Path `
            $BuildBase `
            "Unsigned-Canonical-Package-$Timestamp"
}

$StateAcl = Protect-WorkflowStateDirectory -Path $StateRoot
$BuildAcl = Protect-WorkflowWorkspaceDirectory -Path $BuildBase

New-Item `
    -ItemType Directory `
    -Path $StateRoot, $LogRoot, $BuildBase `
    -Force |
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

function Assert-FileHash {
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
        throw @"
$Label hash mismatch.
Expected: $ExpectedHash
Actual:   $ActualHash
Path:     $LiteralPath
"@
    }

    Write-Host "[PASS] $Label"
    Write-Host "       $ActualHash"

    return $ActualHash
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $Directory = Split-Path -Parent $LiteralPath
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null

    $TemporaryPath =
        Join-Path `
            $Directory `
            (
                [IO.Path]::GetFileName($LiteralPath) +
                '.tmp-' +
                [guid]::NewGuid().ToString('N')
            )

    try {
        $Json = $InputObject | ConvertTo-Json -Depth 12
        $Encoding = [Text.UTF8Encoding]::new($false)

        [IO.File]::WriteAllText(
            $TemporaryPath,
            $Json,
            $Encoding
        )

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

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$FullName
    )

    return (
        [IO.Path]::GetRelativePath(
            $Root,
            $FullName
        ).Replace(
            '/',
            '\'
        )
    )
}

function Resolve-AuditedSourceRoot {
    if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        return [IO.Path]::GetFullPath($SourceRoot)
    }

    if (-not (Test-Path -LiteralPath $SourceAuditPath -PathType Leaf)) {
        throw @"
Phase 2 source audit was not found:
$SourceAuditPath

Supply -SourceRoot explicitly or complete Phase 2 first.
"@
    }

    $Audit =
        Get-Content -LiteralPath $SourceAuditPath -Raw |
            ConvertFrom-Json

    if ([bool]$Audit.AuditPassed -ne $true) {
        throw 'Phase 2 source-package-audit.json does not report AuditPassed=true.'
    }

    $RecordedSourceRoot = [string]$Audit.Paths.SourceRoot

    if ([string]::IsNullOrWhiteSpace($RecordedSourceRoot)) {
        throw 'Phase 2 source audit does not contain Paths.SourceRoot.'
    }

    return [IO.Path]::GetFullPath($RecordedSourceRoot)
}

try {
    Write-Host "State directory: $StateRoot"
    Write-Host "Build workspace: $BuildBase"
    Write-Host ''

    Write-Host '=== VERIFY REQUIRED BUILD ASSETS ==='

    foreach ($RelativePath in $ExpectedBuilderAssetHashes.Keys) {
        $AssetPath = Join-Path $ScriptRoot $RelativePath

        [void](Assert-FileHash `
            -LiteralPath $AssetPath `
            -ExpectedHash $ExpectedBuilderAssetHashes[$RelativePath] `
            -Label $RelativePath)
    }

    $ResolvedSourceRoot = Resolve-AuditedSourceRoot

    if (-not (Test-Path -LiteralPath $ResolvedSourceRoot -PathType Container)) {
        throw "Official AMD source root was not found: $ResolvedSourceRoot"
    }

    $ResolvedOutputRoot = [IO.Path]::GetFullPath($OutputRoot)

    if (Test-Path -LiteralPath $ResolvedOutputRoot) {
        throw "Output root already exists: $ResolvedOutputRoot"
    }

    Write-Host ''
    Write-Host '=== OFFICIAL SOURCE ROOT ==='
    Write-Host $ResolvedSourceRoot

    $OfficialFiles = @(
        Get-ChildItem `
            -LiteralPath $ResolvedSourceRoot `
            -Recurse `
            -File `
            -Force
    )

    if ($OfficialFiles.Count -ne $ExpectedOfficialSourceFileCount) {
        throw @"
Official source file-count mismatch.
Expected: $ExpectedOfficialSourceFileCount
Actual:   $($OfficialFiles.Count)
Root:     $ResolvedSourceRoot
"@
    }

    $OfficialInfPath =
        Join-Path $ResolvedSourceRoot 'u0201589.inf'
    $OfficialDatPath =
        Join-Path $ResolvedSourceRoot 'B026175\amdgcf.dat'
    $OfficialCatalogPath =
        Join-Path $ResolvedSourceRoot 'u0201589.cat'
    $OfficialCcc2Path =
        Join-Path $ResolvedSourceRoot 'B026175\ccc2_install.exe'

    [void](Assert-FileHash `
        -LiteralPath $OfficialInfPath `
        -ExpectedHash $ExpectedOfficialInfHash `
        -Label 'Official u0201589.inf')

    [void](Assert-FileHash `
        -LiteralPath $OfficialDatPath `
        -ExpectedHash $ExpectedOfficialDatHash `
        -Label 'Official B026175\amdgcf.dat')

    [void](Assert-FileHash `
        -LiteralPath $OfficialCatalogPath `
        -ExpectedHash $ExpectedOfficialCatalogHash `
        -Label 'Official Microsoft-signed u0201589.cat')

    [void](Assert-FileHash `
        -LiteralPath $OfficialCcc2Path `
        -ExpectedHash $ExpectedCcc2Hash `
        -Label 'Official B026175\ccc2_install.exe')

    $Ccc2Item = Get-Item -LiteralPath $OfficialCcc2Path

    if ([int64]$Ccc2Item.Length -ne $ExpectedCcc2Length) {
        throw @"
Official ccc2_install.exe length mismatch.
Expected: $ExpectedCcc2Length
Actual:   $($Ccc2Item.Length)
"@
    }

    $OfficialCatalogSignature =
        Get-AuthenticodeSignature -LiteralPath $OfficialCatalogPath

    if (
        $OfficialCatalogSignature.Status -ne 'Valid' -or
        $null -eq $OfficialCatalogSignature.SignerCertificate -or
        $OfficialCatalogSignature.SignerCertificate.Subject -notmatch
            '^CN=Microsoft Windows Hardware Compatibility Publisher,'
    ) {
        throw (
            'The official AMD catalog does not have the expected valid ' +
            'Microsoft WHCP signature.'
        )
    }

    $Ccc2Signature =
        Get-AuthenticodeSignature -LiteralPath $OfficialCcc2Path

    if (
        $Ccc2Signature.Status -ne 'Valid' -or
        $null -eq $Ccc2Signature.SignerCertificate -or
        $Ccc2Signature.SignerCertificate.Subject -notmatch
            '^CN=Advanced Micro Devices,'
    ) {
        throw (
            'The official ccc2_install.exe does not have the expected ' +
            'valid AMD signature.'
        )
    }

    Write-Host '[PASS] Official source identities and signatures match'

    Write-Host ''
    Write-Host '=== LOAD 123-FILE UNCHANGED MANIFEST ==='

    $Manifest =
        Get-Content -LiteralPath $DataManifestPath -Raw |
            ConvertFrom-Json

    $UnchangedFiles = @($Manifest.unchangedFiles)

    if ($UnchangedFiles.Count -ne $ExpectedUnchangedFileCount) {
        throw @"
Unchanged-file manifest count mismatch.
Expected: $ExpectedUnchangedFileCount
Actual:   $($UnchangedFiles.Count)
"@
    }

    if ([int]$Manifest.officialSourceFileCount -ne $ExpectedOfficialSourceFileCount) {
        throw 'The embedded data manifest has an unexpected official source count.'
    }

    New-Item `
        -ItemType Directory `
        -Path $ResolvedOutputRoot `
        -Force |
        Out-Null

    Write-Host ''
    Write-Host '=== COPY 123 VERIFIED OFFICIAL FILES ==='

    $CopiedCount = 0

    foreach ($Entry in $UnchangedFiles) {
        $RelativePath = [string]$Entry.relativePath
        $ExpectedLength = [int64]$Entry.length
        $ExpectedHash = ([string]$Entry.sha256).ToUpperInvariant()

        $SourcePath = Join-Path $ResolvedSourceRoot $RelativePath
        $DestinationPath = Join-Path $ResolvedOutputRoot $RelativePath

        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "Required unchanged source file is missing: $SourcePath"
        }

        $SourceItem = Get-Item -LiteralPath $SourcePath

        if ([int64]$SourceItem.Length -ne $ExpectedLength) {
            throw @"
Source length mismatch.
Relative path: $RelativePath
Expected:      $ExpectedLength
Actual:        $($SourceItem.Length)
"@
        }

        $SourceHash = Get-SHA256 -LiteralPath $SourcePath

        if ($SourceHash -ne $ExpectedHash) {
            throw @"
Source hash mismatch.
Relative path: $RelativePath
Expected:      $ExpectedHash
Actual:        $SourceHash
"@
        }

        $DestinationDirectory = Split-Path -Parent $DestinationPath

        New-Item `
            -ItemType Directory `
            -Path $DestinationDirectory `
            -Force |
            Out-Null

        Copy-Item `
            -LiteralPath $SourcePath `
            -Destination $DestinationPath `
            -Force

        $DestinationHash = Get-SHA256 -LiteralPath $DestinationPath

        if ($DestinationHash -ne $ExpectedHash) {
            throw "Copied-file hash mismatch: $DestinationPath"
        }

        $CopiedCount++
    }

    if ($CopiedCount -ne $ExpectedUnchangedFileCount) {
        throw (
            'Copied unchanged-file count mismatch: ' +
            $CopiedCount
        )
    }

    Write-Host "[PASS] Copied $CopiedCount unchanged official files"

    Write-Host ''
    Write-Host '=== REBUILD THE TWO CANONICAL FILES ==='

    $InfOutputPath =
        Join-Path $ResolvedOutputRoot 'u0201589.inf'

    $DatOutputPath =
        Join-Path $ResolvedOutputRoot 'B026175\amdgcf.dat'

    $InfResult = & $InfBuilderPath `
        -SourceRoot $ResolvedSourceRoot `
        -OutputPath $InfOutputPath

    $DatResult = & $DatBuilderPath `
        -SourceRoot $ResolvedSourceRoot `
        -OutputPath $DatOutputPath

    if (
        [string]$InfResult.SHA256 -ne $ExpectedCanonicalInfHash -or
        [bool]$InfResult.ReproducedCanonical -ne $true
    ) {
        throw 'The deterministic INF builder did not reproduce the canonical INF.'
    }

    if (
        [string]$DatResult.SHA256 -ne $ExpectedCanonicalDatHash -or
        [bool]$DatResult.ReproducedCanonical -ne $true
    ) {
        throw 'The deterministic DAT builder did not reproduce the canonical DAT.'
    }

    Write-Host '[PASS] Rebuilt canonical INF and amdgcf.dat'

    Write-Host ''
    Write-Host '=== VERIFY EXACT 125-FILE UNSIGNED OUTPUT ==='

    $OutputFiles = @(
        Get-ChildItem `
            -LiteralPath $ResolvedOutputRoot `
            -Recurse `
            -File `
            -Force
    )

    if ($OutputFiles.Count -ne $ExpectedUnsignedFileCount) {
        throw @"
Unsigned output file-count mismatch.
Expected: $ExpectedUnsignedFileCount
Actual:   $($OutputFiles.Count)
"@
    }

    $CatalogInOutput =
        Join-Path $ResolvedOutputRoot 'u0201589.cat'

    if (Test-Path -LiteralPath $CatalogInOutput) {
        throw (
            'The unsigned driver package must not contain u0201589.cat.'
        )
    }

    $ExpectedByPath =
        [Collections.Generic.Dictionary[string, object]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

    foreach ($Entry in $UnchangedFiles) {
        $ExpectedByPath[[string]$Entry.relativePath] =
            [pscustomobject]@{
                Length = [int64]$Entry.length
                SHA256 = ([string]$Entry.sha256).ToUpperInvariant()
            }
    }

    $ExpectedByPath['u0201589.inf'] =
        [pscustomobject]@{
            Length = [int64](Get-Item -LiteralPath $InfOutputPath).Length
            SHA256 = $ExpectedCanonicalInfHash
        }

    $ExpectedByPath['B026175\amdgcf.dat'] =
        [pscustomobject]@{
            Length = [int64](Get-Item -LiteralPath $DatOutputPath).Length
            SHA256 = $ExpectedCanonicalDatHash
        }

    if ($ExpectedByPath.Count -ne $ExpectedUnsignedFileCount) {
        throw (
            'Internal expected path-set count mismatch: ' +
            $ExpectedByPath.Count
        )
    }

    $ObservedPaths =
        [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

    $PackageManifestLines =
        New-Object 'System.Collections.Generic.List[string]'

    foreach ($File in $OutputFiles) {
        $RelativePath =
            Get-NormalizedRelativePath `
                -Root $ResolvedOutputRoot `
                -FullName $File.FullName

        if (-not $ExpectedByPath.ContainsKey($RelativePath)) {
            throw "Unexpected output file: $RelativePath"
        }

        if (-not $ObservedPaths.Add($RelativePath)) {
            throw "Duplicate output path: $RelativePath"
        }

        $Expected = $ExpectedByPath[$RelativePath]
        $ActualHash = Get-SHA256 -LiteralPath $File.FullName

        if (
            [int64]$File.Length -ne [int64]$Expected.Length -or
            $ActualHash -ne [string]$Expected.SHA256
        ) {
            throw @"
Unsigned output verification failed.
Relative path: $RelativePath
Expected length: $($Expected.Length)
Actual length:   $($File.Length)
Expected SHA256: $($Expected.SHA256)
Actual SHA256:   $ActualHash
"@
        }

        $PackageManifestLines.Add(
            "$ActualHash  $RelativePath"
        )
    }

    foreach ($ExpectedPath in $ExpectedByPath.Keys) {
        if (-not $ObservedPaths.Contains($ExpectedPath)) {
            throw "Expected output file is missing: $ExpectedPath"
        }
    }

    $ExternalPackageManifestPath =
        "$ResolvedOutputRoot-SHA256-MANIFEST.txt"

    $PackageManifestLines |
        Sort-Object |
        Set-Content `
            -LiteralPath $ExternalPackageManifestPath `
            -Encoding utf8NoBOM

    $ExternalPackageManifestHash =
        Get-SHA256 -LiteralPath $ExternalPackageManifestPath

    $ReportPath =
        "$ResolvedOutputRoot-BUILD-REPORT.txt"

    $ReportLines = @(
        'LEGION GO AMD 26.6.2 TOOLKIT - PHASE 3'
        'UNSIGNED CANONICAL DRIVER PACKAGE BUILD AND VERIFICATION'
        ''
        "GeneratedAt: $((Get-Date).ToString('o'))"
        "SourceAuditPath: $SourceAuditPath"
        "SourceRoot: $ResolvedSourceRoot"
        "OutputRoot: $ResolvedOutputRoot"
        ''
        "OfficialSourceFileCount: $($OfficialFiles.Count)"
        "ManifestUnchangedFileCount: $($UnchangedFiles.Count)"
        "CopiedUnchangedFileCount: $CopiedCount"
        "RebuiltInfSHA256: $($InfResult.SHA256)"
        "RebuiltDatSHA256: $($DatResult.SHA256)"
        "UnsignedOutputFileCount: $($OutputFiles.Count)"
        "CatalogPresent: False"
        "InstalledDriverModified: False"
        ''
        "OfficialCatalogPath: $OfficialCatalogPath"
        "OfficialCatalogSHA256: $ExpectedOfficialCatalogHash"
        "OfficialCcc2Path: $OfficialCcc2Path"
        "OfficialCcc2SHA256: $ExpectedCcc2Hash"
        "OfficialCcc2IncludedInDriverPackage: False"
        ''
        "ExternalPackageManifestPath: $ExternalPackageManifestPath"
        "ExternalPackageManifestSHA256: $ExternalPackageManifestHash"
        ''
        'RESULT: Exact 125-file unsigned driver package reproduced from official AMD -c source.'
    )

    [IO.File]::WriteAllLines(
        $ReportPath,
        $ReportLines,
        [Text.UTF8Encoding]::new($true)
    )

    $VerificationResult = [ordered]@{
        SchemaVersion                    = 2
        Workflow                         = 'LegionGo-AMD-26.6.2'
        Stage                            = '02A'
        Verified                         = $true
        Passed                           = $true
        Success                          = $true
        Complete                         = $true
        ExactUnsignedPackageReproduced   = $true
        VerifiedAt                       = (Get-Date).ToString('o')
        SourceAuditPath                  = $SourceAuditPath
        SourceRoot                       = $ResolvedSourceRoot
        OfficialSourceRoot               = $ResolvedSourceRoot
        SourceDisplayRoot                = $ResolvedSourceRoot
        OfficialDisplayRoot              = $ResolvedSourceRoot
        PackageRoot                      = $ResolvedOutputRoot
        UnsignedRoot                     = $ResolvedOutputRoot
        OutputRoot                       = $ResolvedOutputRoot
        OfficialSourceFileCount          = $OfficialFiles.Count
        UnchangedSourceFileCount         = $UnchangedFiles.Count
        CopiedUnchangedFileCount         = $CopiedCount
        UnsignedOutputFileCount          = $OutputFiles.Count
        CatalogPresent                   = $false
        InfPath                          = $InfOutputPath
        InfSHA256                        = [string]$InfResult.SHA256
        DatPath                          = $DatOutputPath
        DatSHA256                        = [string]$DatResult.SHA256
        OfficialCatalogPath              = $OfficialCatalogPath
        OfficialCatalogSHA256            = $ExpectedOfficialCatalogHash
        OfficialCcc2Path                 = $OfficialCcc2Path
        OfficialCcc2SHA256               = $ExpectedCcc2Hash
        OfficialCcc2Length               = $ExpectedCcc2Length
        OfficialCcc2IncludedInPackage    = $false
        ExternalPackageManifestPath      = $ExternalPackageManifestPath
        ExternalPackageManifestSHA256    = $ExternalPackageManifestHash
        BuildReportPath                  = $ReportPath
        VerificationLog                  = $LogPath
        InstalledDriverModified          = $false
        ModifiedInstalledState           = $false
        NextStage                        =
            '02B-Create-PerUser-Catalog-And-Signing-State'
    }

    Write-AtomicJson `
        -InputObject $VerificationResult `
        -LiteralPath $ResultPath

    $WorkflowState = [ordered]@{
        SchemaVersion                    = 2
        Workflow                         = 'LegionGo-AMD-26.6.2'
        Stage                            = 'Unsigned-Package-Verified'
        UpdatedAt                        = (Get-Date).ToString('o')
        SourceRoot                       = $ResolvedSourceRoot
        PackageRoot                      = $ResolvedOutputRoot
        UnsignedRoot                     = $ResolvedOutputRoot
        PayloadVerificationPath          = $ResultPath
        OfficialCatalogPath              = $OfficialCatalogPath
        OfficialCcc2Path                 = $OfficialCcc2Path
        OfficialCcc2IncludedInPackage    = $false
        InstalledDriverModified          = $false
        NextStage                        = $VerificationResult.NextStage
        LogPath                          = $LogPath
    }

    Write-AtomicJson `
        -InputObject $WorkflowState `
        -LiteralPath $WorkflowStatePath

    Write-Host ''
    Write-Host '=== PHASE 3 RESULT ==='
    Write-Host 'PHASE 3 PASS: True' -ForegroundColor Green
    Write-Host "Package root:       $ResolvedOutputRoot"
    Write-Host "Package files:      $($OutputFiles.Count)"
    Write-Host "Payload result:     $ResultPath"
    Write-Host "Workflow state:     $WorkflowStatePath"
    Write-Host "Package manifest:   $ExternalPackageManifestPath"
    Write-Host "Build report:       $ReportPath"
    Write-Host "Official CCC2 path: $OfficialCcc2Path"
    Write-Host 'Installed state modified: False'
}
catch {
    $Failure = [ordered]@{
        SchemaVersion          = 2
        Workflow               = 'LegionGo-AMD-26.6.2'
        Stage                  = '02A'
        Verified               = $false
        FailedAt               = (Get-Date).ToString('o')
        Error                  = $_.Exception.Message
        SourceAuditPath        = $SourceAuditPath
        SourceRoot             = $SourceRoot
        OutputRoot             = $OutputRoot
        InstalledDriverModified = $false
        LogPath                = $LogPath
    }

    Write-AtomicJson `
        -InputObject $Failure `
        -LiteralPath $ResultPath

    throw
}
finally {
    Stop-Transcript | Out-Null
}
'@
        )
    }
    'Phase-04-Create-And-Sign-Local-Catalog.ps1' = [ordered]@{
        SHA256 = '2B8F89DF3E5D4B7599A9C95F3DB8A86C8789E088995B2B4B4C36CA1BE9C4FE49'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 4 of Script 1 in the Legion Go AMD 26.6.2 Toolkit.

Consumes the exact 125-file unsigned canonical package produced by Phase 3,
creates a unique non-exportable local code-signing certificate, generates
and signs u0201589.cat, trusts the public certificate locally, and writes the
dynamic signing state consumed by Scripts 2 through 4.

The official AMD ccc2_install.exe and original Microsoft-signed catalog are
verified from Phase 3's official-source paths and recorded separately. They
are not copied into the 125/126-file driver package.

This script does not install or bind the display driver.
#>

[CmdletBinding()]
param(
    [string]$UnsignedRoot,

    [string]$BuildBase = 'C:\AMD\LegionGo-26.6.2',

    [string]$WorkflowRoot =
        'C:\ProgramData\LegionGo-AMD-26.6.2',

    [string]$VerificationResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\payload-verification.json'
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
$PSNativeCommandUseErrorActionPreference = $false

$ExpectedUnsignedFileCount = 125
$ExpectedInfHash = '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'
$ExpectedDatHash = 'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'
$ExpectedSysHash = 'EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9'
$ExpectedIcdHash = 'DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F'
$ExpectedCcc2Hash = '804BB7C852E2003948D5945C99058DB58080D41692CF36CE6BDD6FC93E2ACC48'
$ExpectedCcc2Length = [int64]242517520
$ExpectedOfficialCatalogHash = '0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D'

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$RunRoot = Join-Path $BuildBase "Locally-Signed-Canonical-Package-$Timestamp"
$PackageRoot = Join-Path $RunRoot 'Package'
$CertificateRoot = Join-Path $RunRoot 'Local-Catalog-Signing-Certificate'
$ReportPath = Join-Path $RunRoot 'CATALOG-SIGNING-REPORT.txt'
$LocalStatePath = Join-Path $RunRoot 'catalog-signing-state.json'
$CanonicalStatePath = Join-Path $WorkflowRoot 'catalog-signing-state.json'
$CanonicalStateBackupPath = Join-Path `
    $WorkflowRoot `
    "catalog-signing-state.previous-$Timestamp.json"
$CerPath = Join-Path $CertificateRoot 'LegionGo-AMD-26.6.2-Local-Driver.cer'

$CertificateThumbprint = $null
$CertificateCreated = $false
$Succeeded = $false
$CanonicalStatePublished = $false
$CanonicalStatePreviouslyExisted = $false

function Test-IsAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-WindowsKitTools {
    $KitBinRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'

    if (-not (Test-Path -LiteralPath $KitBinRoot -PathType Container)) {
        throw "Windows Kits bin root not found: $KitBinRoot"
    }

    $Candidates = foreach ($Inf2CatFile in @(
        Get-ChildItem `
            -LiteralPath $KitBinRoot `
            -Recurse `
            -File `
            -Filter 'Inf2Cat.exe' `
            -ErrorAction SilentlyContinue
    )) {
        if ($Inf2CatFile.FullName -notmatch '\\x86\\Inf2Cat\.exe$') {
            continue
        }

        $VersionRoot = Split-Path `
            -Parent `
            $Inf2CatFile.DirectoryName

        $VersionText = Split-Path `
            -Leaf `
            $VersionRoot

        $Version = $null

        try {
            $Version = [version]$VersionText
        }
        catch {
            continue
        }

        $SignToolPath = Join-Path `
            $VersionRoot `
            'x64\signtool.exe'

        if (-not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) {
            continue
        }

        [pscustomobject]@{
            Version  = $Version
            Inf2Cat  = $Inf2CatFile.FullName
            SignTool = $SignToolPath
        }
    }

    $Selected = $Candidates |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $Selected) {
        throw 'No matching x86 Inf2Cat.exe and x64 SignTool.exe pair was found.'
    }

    return $Selected
}

function Get-FileHashValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file not found: $Path"
    }

    return (
        Get-FileHash `
            -LiteralPath $Path `
            -Algorithm SHA256
    ).Hash
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ExpectedHash,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $ActualHash = Get-FileHashValue -Path $Path

    if ($ActualHash -ne $ExpectedHash) {
        throw @"
$Description hash mismatch.
Path:     $Path
Expected: $ExpectedHash
Actual:   $ActualHash
"@
    }

    return $ActualHash
}

function Remove-CertificateByThumbprint {
    param(
        [Parameter(Mandatory)]
        [string]$StorePath,

        [Parameter(Mandatory)]
        [string]$Thumbprint
    )

    $CertificatePath = Join-Path `
        $StorePath `
        $Thumbprint

    if (Test-Path -LiteralPath $CertificatePath) {
        Remove-Item `
            -LiteralPath $CertificatePath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

$WorkflowAcl = Protect-WorkflowStateDirectory -Path $WorkflowRoot
$BuildAcl = Protect-WorkflowWorkspaceDirectory -Path $BuildBase

New-Item `
    -ItemType Directory `
    -Path $BuildBase, $WorkflowRoot `
    -Force |
    Out-Null

if (-not (Test-Path -LiteralPath $VerificationResultPath -PathType Leaf)) {
    throw "Phase 3 verification result not found: $VerificationResultPath"
}

$VerificationResult =
    Get-Content -LiteralPath $VerificationResultPath -Raw |
        ConvertFrom-Json

$VerificationPassed =
    [bool]$VerificationResult.Verified -and
    [bool]$VerificationResult.Passed -and
    [bool]$VerificationResult.Success -and
    [bool]$VerificationResult.Complete -and
    [bool]$VerificationResult.ExactUnsignedPackageReproduced

if (-not $VerificationPassed) {
    throw (
        'Phase 3 verification result does not record a complete, exact ' +
        'unsigned-package reproduction.'
    )
}

$RecordedUnsignedRoot = [string]$VerificationResult.PackageRoot

if ([string]::IsNullOrWhiteSpace($RecordedUnsignedRoot)) {
    $RecordedUnsignedRoot = [string]$VerificationResult.UnsignedRoot
}

if ([string]::IsNullOrWhiteSpace($RecordedUnsignedRoot)) {
    $RecordedUnsignedRoot = [string]$VerificationResult.OutputRoot
}

if ([string]::IsNullOrWhiteSpace($RecordedUnsignedRoot)) {
    throw 'Phase 3 verification result does not contain the unsigned package root.'
}

$RecordedUnsignedRoot = [IO.Path]::GetFullPath($RecordedUnsignedRoot)

if ([string]::IsNullOrWhiteSpace($UnsignedRoot)) {
    $UnsignedRoot = $RecordedUnsignedRoot
}
else {
    $UnsignedRoot = [IO.Path]::GetFullPath($UnsignedRoot)

    if (-not $UnsignedRoot.Equals(
        $RecordedUnsignedRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw @"
UnsignedRoot does not match the package verified by Phase 3.
Phase 3: $RecordedUnsignedRoot
Requested: $UnsignedRoot
"@
    }
}

if (-not (Test-Path -LiteralPath $UnsignedRoot -PathType Container)) {
    throw "Unsigned canonical package not found: $UnsignedRoot"
}

$OfficialCcc2Path = [string]$VerificationResult.OfficialCcc2Path
$OfficialCatalogPath = [string]$VerificationResult.OfficialCatalogPath
$OfficialSourceRoot = [string]$VerificationResult.SourceRoot

if ([string]::IsNullOrWhiteSpace($OfficialCcc2Path)) {
    throw 'Phase 3 verification result does not contain OfficialCcc2Path.'
}

if ([string]::IsNullOrWhiteSpace($OfficialCatalogPath)) {
    throw 'Phase 3 verification result does not contain OfficialCatalogPath.'
}

$OfficialCcc2Path = [IO.Path]::GetFullPath($OfficialCcc2Path)
$OfficialCatalogPath = [IO.Path]::GetFullPath($OfficialCatalogPath)

$OfficialCcc2Hash = Assert-FileHash `
    -Path $OfficialCcc2Path `
    -ExpectedHash $ExpectedCcc2Hash `
    -Description 'Separate official AMD 26.6.2 ccc2_install.exe'

$OfficialCcc2Item = Get-Item -LiteralPath $OfficialCcc2Path

if ([int64]$OfficialCcc2Item.Length -ne $ExpectedCcc2Length) {
    throw @"
Official ccc2_install.exe length mismatch.
Expected: $ExpectedCcc2Length
Actual:   $($OfficialCcc2Item.Length)
Path:     $OfficialCcc2Path
"@
}

$OfficialCcc2Signature =
    Get-AuthenticodeSignature -LiteralPath $OfficialCcc2Path

if (
    $OfficialCcc2Signature.Status -ne 'Valid' -or
    $null -eq $OfficialCcc2Signature.SignerCertificate -or
    $OfficialCcc2Signature.SignerCertificate.Subject -notmatch
        '^CN=Advanced Micro Devices,'
) {
    throw 'The separate official ccc2_install.exe does not have a valid AMD signature.'
}

$OfficialCatalogHash = Assert-FileHash `
    -Path $OfficialCatalogPath `
    -ExpectedHash $ExpectedOfficialCatalogHash `
    -Description 'Separate official Microsoft-signed AMD u0201589.cat'

$OfficialCatalogSignature =
    Get-AuthenticodeSignature -LiteralPath $OfficialCatalogPath

if (
    $OfficialCatalogSignature.Status -ne 'Valid' -or
    $null -eq $OfficialCatalogSignature.SignerCertificate -or
    $OfficialCatalogSignature.SignerCertificate.Subject -notmatch
        '^CN=Microsoft Windows Hardware Compatibility Publisher,'
) {
    throw 'The separate official AMD catalog does not have a valid Microsoft WHCP signature.'
}

$ExistingCatalog = Join-Path $UnsignedRoot 'u0201589.cat'

if (Test-Path -LiteralPath $ExistingCatalog) {
    throw "The unsigned source unexpectedly contains a catalog: $ExistingCatalog"
}

$UnsignedFiles = @(
    Get-ChildItem `
        -LiteralPath $UnsignedRoot `
        -Recurse `
        -File `
        -Force
)

if ($UnsignedFiles.Count -ne $ExpectedUnsignedFileCount) {
    throw @"
Unsigned package file-count mismatch.
Expected: $ExpectedUnsignedFileCount
Actual:   $($UnsignedFiles.Count)
"@
}

$Tools = Get-WindowsKitTools

$Inf2Cat = $Tools.Inf2Cat
$SignTool = $Tools.SignTool

New-Item `
    -ItemType Directory `
    -Path $PackageRoot `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $CertificateRoot `
    -Force |
    Out-Null

try {
    foreach ($Child in @(
        Get-ChildItem `
            -LiteralPath $UnsignedRoot `
            -Force
    )) {
        Copy-Item `
            -LiteralPath $Child.FullName `
            -Destination $PackageRoot `
            -Recurse `
            -Force
    }

    $CopiedFiles = @(
        Get-ChildItem `
            -LiteralPath $PackageRoot `
            -Recurse `
            -File `
            -Force
    )

    if ($CopiedFiles.Count -ne $ExpectedUnsignedFileCount) {
        throw @"
Copied unsigned package file-count mismatch.
Expected: $ExpectedUnsignedFileCount
Actual:   $($CopiedFiles.Count)
"@
    }

    $UnexpectedCcc2InPackage =
        Join-Path $PackageRoot 'B026175\ccc2_install.exe'

    if (Test-Path -LiteralPath $UnexpectedCcc2InPackage -PathType Leaf) {
        throw (
            'The 125-file driver package unexpectedly contains ' +
            'ccc2_install.exe. CCC2 must remain a separate official-source asset.'
        )
    }

    $InfPath = Join-Path $PackageRoot 'u0201589.inf'
    $DatPath = Join-Path $PackageRoot 'B026175\amdgcf.dat'
    $SysPath = Join-Path $PackageRoot 'B026175\amdkmdag.sys'
    $IcdPath = Join-Path $PackageRoot 'B026175\atiicdxx.dat'
    $CatPath = Join-Path $PackageRoot 'u0201589.cat'

    $InfHash = Assert-FileHash `
        -Path $InfPath `
        -ExpectedHash $ExpectedInfHash `
        -Description 'Canonical INF'

    $DatHash = Assert-FileHash `
        -Path $DatPath `
        -ExpectedHash $ExpectedDatHash `
        -Description 'Canonical amdgcf.dat'

    $SysHash = Assert-FileHash `
        -Path $SysPath `
        -ExpectedHash $ExpectedSysHash `
        -Description 'AMD kernel driver'

    $IcdHash = Assert-FileHash `
        -Path $IcdPath `
        -ExpectedHash $ExpectedIcdHash `
        -Description 'AMD atiicdxx.dat'

    if (-not (Get-Command New-SelfSignedCertificate -ErrorAction SilentlyContinue)) {
        throw 'New-SelfSignedCertificate is unavailable.'
    }

    $CertificateSubject = (
        'CN=LegionGo AMD 26.6.2 Local Driver ' +
        $Timestamp
    )

    $Certificate = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $CertificateSubject `
        -FriendlyName 'LegionGo AMD 26.6.2 Local Catalog Signing' `
        -CertStoreLocation 'Cert:\LocalMachine\My' `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -KeyExportPolicy NonExportable `
        -NotAfter (Get-Date).AddYears(5)

    if ($null -eq $Certificate) {
        throw 'New-SelfSignedCertificate did not return a certificate.'
    }

    $CertificateThumbprint = [string]$Certificate.Thumbprint
    $CertificateCreated = $true

    # PowerShell 7 can return a compatibility/deserialized representation
    # from Windows-only PKI cmdlets. Reopen the actual certificate from the
    # LocalMachine\My store before inspecting extensions or private-key state.
    $MyStore = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    )

    try {
        $MyStore.Open(
            [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly
        )

        $StoreMatches = $MyStore.Certificates.Find(
            [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
            $CertificateThumbprint,
            $false
        )

        if ($StoreMatches.Count -ne 1) {
            throw @"
Expected exactly one generated certificate in LocalMachine\My.
Thumbprint: $CertificateThumbprint
Found:      $($StoreMatches.Count)
"@
        }

        $Certificate = $StoreMatches[0]
    }
    finally {
        $MyStore.Close()
        $MyStore.Dispose()
    }

    if (-not $Certificate.HasPrivateKey) {
        throw 'The reopened signing certificate does not have a private key.'
    }

    $ProviderCodeSigningMatches = @(
        Get-ChildItem `
            -Path 'Cert:\LocalMachine\My' `
            -CodeSigningCert |
        Where-Object {
            $_.Thumbprint -eq $CertificateThumbprint
        }
    )

    if ($ProviderCodeSigningMatches.Count -ne 1) {
        throw @"
The generated certificate is not recognized by the Windows certificate provider as a code-signing certificate.
Thumbprint: $CertificateThumbprint
Matches:    $($ProviderCodeSigningMatches.Count)
"@
    }

    $EkuExtensions = @(
        $Certificate.Extensions |
        Where-Object {
            $_.Oid.Value -eq '2.5.29.37'
        }
    )

    if ($EkuExtensions.Count -ne 1) {
        throw @"
The generated certificate does not contain exactly one Enhanced Key Usage extension.
Found: $($EkuExtensions.Count)
"@
    }

    # Decode the existing ASN.1 extension through the documented
    # AsnEncodedData constructor. A PowerShell type cast creates an empty
    # wrapper and does not populate EnhancedKeyUsages.
    $EncodedEku = [System.Security.Cryptography.AsnEncodedData]$EkuExtensions[0]

    $EkuExtension =
        [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new(
            $EncodedEku,
            [bool]$EkuExtensions[0].Critical
        )

    $CodeSigningEku = @(
        $EkuExtension.EnhancedKeyUsages |
        Where-Object {
            $_.Value -eq '1.3.6.1.5.5.7.3.3'
        }
    )

    if ($CodeSigningEku.Count -ne 1) {
        $ObservedEkus = @(
            $EkuExtension.EnhancedKeyUsages |
            ForEach-Object {
                $_.Value
            }
        ) -join ', '

        throw @"
The generated certificate does not contain the Code Signing EKU.
Observed EKUs: $ObservedEkus
"@
    }

    Export-Certificate `
        -Cert $Certificate `
        -FilePath $CerPath `
        -Type CERT `
        -Force |
        Out-Null

    if (-not (Test-Path -LiteralPath $CerPath -PathType Leaf)) {
        throw "Public certificate export failed: $CerPath"
    }

    $CerHash = Get-FileHashValue -Path $CerPath

    Import-Certificate `
        -FilePath $CerPath `
        -CertStoreLocation 'Cert:\LocalMachine\Root' |
        Out-Null

    Import-Certificate `
        -FilePath $CerPath `
        -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' |
        Out-Null

    foreach ($StorePath in @(
        'Cert:\LocalMachine\My'
        'Cert:\LocalMachine\Root'
        'Cert:\LocalMachine\TrustedPublisher'
    )) {
        $Found = Get-ChildItem `
            -LiteralPath $StorePath |
            Where-Object {
                $_.Thumbprint -eq $CertificateThumbprint
            } |
            Select-Object -First 1

        if ($null -eq $Found) {
            throw "Generated certificate was not found in $StorePath"
        }
    }

    if (Test-Path -LiteralPath $CatPath) {
        Remove-Item `
            -LiteralPath $CatPath `
            -Force
    }

    Write-Host ''
    Write-Host '=== GENERATING CATALOG ==='

    $Inf2CatOutput = @(
        & $Inf2Cat `
            "/driver:$PackageRoot" `
            '/os:10_X64' `
            2>&1
    )

    $Inf2CatExitCode = $LASTEXITCODE

    $Inf2CatOutput |
        ForEach-Object {
            Write-Host $_
        }

    if ($Inf2CatExitCode -ne 0) {
        throw "Inf2Cat failed with exit code $Inf2CatExitCode."
    }

    if (-not (Test-Path -LiteralPath $CatPath -PathType Leaf)) {
        throw "Inf2Cat did not create the catalog: $CatPath"
    }

    $UnsignedCatalogHash = Get-FileHashValue -Path $CatPath

    Write-Host ''
    Write-Host '=== SIGNING CATALOG ==='

    $SignOutput = @(
        & $SignTool `
            sign `
            /sm `
            /s My `
            /sha1 $CertificateThumbprint `
            /fd SHA256 `
            /v `
            $CatPath `
            2>&1
    )

    $SignExitCode = $LASTEXITCODE

    $SignOutput |
        ForEach-Object {
            Write-Host $_
        }

    if ($SignExitCode -ne 0) {
        throw "SignTool signing failed with exit code $SignExitCode."
    }

    $SignedCatalogHash = Get-FileHashValue -Path $CatPath

    if ($SignedCatalogHash -eq $UnsignedCatalogHash) {
        throw 'The catalog hash did not change after signing.'
    }

    Write-Host ''
    Write-Host '=== VERIFYING CATALOG SIGNATURE ==='

    $VerifyOutput = @(
        & $SignTool `
            verify `
            /pa `
            /v `
            $CatPath `
            2>&1
    )

    $VerifyExitCode = $LASTEXITCODE

    $VerifyOutput |
        ForEach-Object {
            Write-Host $_
        }

    if ($VerifyExitCode -ne 0) {
        throw "SignTool verification failed with exit code $VerifyExitCode."
    }

    $Authenticode = Get-AuthenticodeSignature `
        -LiteralPath $CatPath

    if ($Authenticode.Status -ne 'Valid') {
        throw "Catalog Authenticode status is $($Authenticode.Status), not Valid."
    }

    if (
        $null -eq $Authenticode.SignerCertificate -or
        $Authenticode.SignerCertificate.Thumbprint -ne $CertificateThumbprint
    ) {
        throw 'The catalog signer does not match the newly generated certificate.'
    }

    # The private key is needed only while SignTool signs this one catalog.
    # Remove the generated certificate from LocalMachine\My immediately after
    # the signed catalog has been verified. Keep only the public certificate in
    # Root and TrustedPublisher so Windows can validate the installed package.
    Remove-CertificateByThumbprint `
        -StorePath 'Cert:\LocalMachine\My' `
        -Thumbprint $CertificateThumbprint

    $PrivateCertificateStillPresent = Test-Path -LiteralPath (
        Join-Path 'Cert:\LocalMachine\My' $CertificateThumbprint
    )

    if ($PrivateCertificateStillPresent) {
        throw 'The temporary private signing certificate could not be removed from LocalMachine\My.'
    }

    $SignedPackageFiles = @(
        Get-ChildItem `
            -LiteralPath $PackageRoot `
            -Recurse `
            -File `
            -Force
    )

    if ($SignedPackageFiles.Count -ne 126) {
        throw @"
Signed package file-count mismatch.
Expected: 126
Actual:   $($SignedPackageFiles.Count)
"@
    }

    $VerificationResultPresent = $true

    $State = [ordered]@{
        SchemaVersion                 = 2
        Workflow                      = 'LegionGo-AMD-26.6.2'
        StateType                     = 'PerUserDriverCatalogSigning'
        CreatedAt                     = (Get-Date).ToString('o')
        RunRoot                       = $RunRoot
        SourceRoot                    = $OfficialSourceRoot
        OfficialSourceRoot            = $OfficialSourceRoot
        UnsignedSourceRoot            = $UnsignedRoot
        UnsignedRoot                  = $UnsignedRoot
        PackageRoot                   = $PackageRoot
        SignedCatalogPath             = $CatPath
        SignedCatalogSHA256           = $SignedCatalogHash
        UnsignedCatalogSHA256         = $UnsignedCatalogHash
        CertificatePath               = $CerPath
        CertificateSHA256             = $CerHash
        PublicCerSHA256               = $CerHash
        CertificateSubject            = $Certificate.Subject
        CertificateThumbprint         = $CertificateThumbprint
        CatalogSignerSubject          = $Authenticode.SignerCertificate.Subject
        CatalogSignerThumbprint       = $Authenticode.SignerCertificate.Thumbprint
        CertificateNotBefore          = $Certificate.NotBefore.ToString('o')
        CertificateNotAfter           = $Certificate.NotAfter.ToString('o')
        CertificateHasPrivateKey      = $false
        PrivateSigningCertificateRemoved = $true
        CertificatePrivateKeyExported = $false
        CertificateStores             = @(
            'LocalMachine\Root'
            'LocalMachine\TrustedPublisher'
        )
        Inf2CatVersion                = $Tools.Version.ToString()
        Inf2CatPath                   = $Inf2Cat
        SignToolPath                  = $SignTool
        InfSHA256                     = $InfHash
        DatSHA256                     = $DatHash
        KernelSHA256                  = $SysHash
        AtiIcdSHA256                  = $IcdHash
        OfficialCatalogPath           = $OfficialCatalogPath
        OfficialCatalogSHA256         = $OfficialCatalogHash
        OfficialCcc2Path              = $OfficialCcc2Path
        OfficialCcc2SHA256            = $OfficialCcc2Hash
        OfficialCcc2Length            = $ExpectedCcc2Length
        OfficialCcc2IncludedInPackage = $false
        CatalogAuthenticodeStatus     = $Authenticode.Status.ToString()
        SignedPackageFileCount        = $SignedPackageFiles.Count
        VerificationResultPath        = $VerificationResultPath
        VerificationResultPresent     = $VerificationResultPresent
        VerificationResultVerified    = $VerificationPassed
        InstalledDriverModified       = $false
        ModifiedInstalledDriver       = $false
        ModifiedCertificateStores     = $true
        CanonicalStatePath            = $CanonicalStatePath
        LocalStatePath                = $LocalStatePath
        NextStage                    =
            '02C-Prepare-SecureBoot-And-TestSigning'
    }

    $StateJson = $State | ConvertTo-Json -Depth 8

    $StateJson |
        Set-Content `
            -LiteralPath $LocalStatePath `
            -Encoding utf8

    $CanonicalStatePreviouslyExisted =
        Test-Path -LiteralPath $CanonicalStatePath -PathType Leaf

    if ($CanonicalStatePreviouslyExisted) {
        Copy-Item `
            -LiteralPath $CanonicalStatePath `
            -Destination $CanonicalStateBackupPath `
            -Force
    }

    $StateJson |
        Set-Content `
            -LiteralPath $CanonicalStatePath `
            -Encoding utf8

    $CanonicalStatePublished = $true

    foreach ($RequiredStatePath in @(
        $LocalStatePath
        $CanonicalStatePath
    )) {
        if (-not (Test-Path -LiteralPath $RequiredStatePath -PathType Leaf)) {
            throw "Signing state was not written: $RequiredStatePath"
        }

        $WrittenState =
            Get-Content -LiteralPath $RequiredStatePath -Raw |
                ConvertFrom-Json

        if (
            [string]$WrittenState.PackageRoot -ne $PackageRoot -or
            [string]$WrittenState.SignedCatalogSHA256 -ne
                $SignedCatalogHash -or
            [string]$WrittenState.CatalogSignerThumbprint -ne
                $CertificateThumbprint -or
            [string]$WrittenState.CertificateSHA256 -ne $CerHash
        ) {
            throw "Signing-state round-trip validation failed: $RequiredStatePath"
        }
    }

    $Report = @(
        'LEGION GO AMD 26.6.2 TOOLKIT - PHASE 4'
        ''
        "RunRoot: $RunRoot"
        "PackageRoot: $PackageRoot"
        "UnsignedSourceRoot: $UnsignedRoot"
        ''
        "Inf2CatVersion: $($Tools.Version)"
        "Inf2CatPath: $Inf2Cat"
        "SignToolPath: $SignTool"
        ''
        "CertificateSubject: $($Certificate.Subject)"
        "CertificateThumbprint: $CertificateThumbprint"
        'CertificateHasPrivateKey: False'
        'PrivateSigningCertificateRemoved: True'
        'CertificatePrivateKeyExported: False'
        "PublicCertificatePath: $CerPath"
        "PublicCertificateSHA256: $CerHash"
        ''
        "CanonicalInfSHA256: $InfHash"
        "CanonicalDatSHA256: $DatHash"
        "KernelSHA256: $SysHash"
        "AtiIcdSHA256: $IcdHash"
        "OfficialCatalogPath: $OfficialCatalogPath"
        "OfficialCatalogSHA256: $OfficialCatalogHash"
        "OfficialCcc2Path: $OfficialCcc2Path"
        "OfficialCcc2SHA256: $OfficialCcc2Hash"
        "OfficialCcc2Length: $ExpectedCcc2Length"
        'OfficialCcc2IncludedInPackage: False'
        "UnsignedCatalogSHA256: $UnsignedCatalogHash"
        "SignedCatalogSHA256: $SignedCatalogHash"
        "CatalogAuthenticodeStatus: $($Authenticode.Status)"
        "CatalogSignerSubject: $($Authenticode.SignerCertificate.Subject)"
        "CatalogSignerThumbprint: $($Authenticode.SignerCertificate.Thumbprint)"
        "SignedPackageFileCount: $($SignedPackageFiles.Count)"
        "CanonicalSigningStatePath: $CanonicalStatePath"
        "LocalSigningStatePath: $LocalStatePath"
        "VerificationResultPath: $VerificationResultPath"
        "VerificationResultPresent: $VerificationResultPresent"
        "VerificationResultVerified: $VerificationPassed"
        ''
        'CertificateStoresModified: True'
        'InstalledDriverModified: False'
        ''
        '=== INF2CAT OUTPUT ==='
        $Inf2CatOutput
        ''
        '=== SIGNTOOL SIGN OUTPUT ==='
        $SignOutput
        ''
        '=== SIGNTOOL VERIFY OUTPUT ==='
        $VerifyOutput
    )

    $Report |
        Out-File `
            -LiteralPath $ReportPath `
            -Encoding utf8 `
            -Width 16384

    $Succeeded = $true

    Write-Host ''
    Write-Host '=== PHASE 4 RESULT ==='

    [pscustomobject]@{
        RunRoot                  = $RunRoot
        PackageRoot              = $PackageRoot
        Inf2CatVersion           = $Tools.Version
        UnsignedInputFileCount   = $UnsignedFiles.Count
        SignedPackageFileCount   = $SignedPackageFiles.Count
        CertificateSubject       = $Certificate.Subject
        CertificateThumbprint    = $CertificateThumbprint
        CertificateHasPrivateKey = $false
        PrivateSigningCertificateRemoved = $true
        PublicCerSHA256          = $CerHash
        UnsignedCatalogSHA256    = $UnsignedCatalogHash
        SignedCatalogSHA256      = $SignedCatalogHash
        AuthenticodeStatus       = $Authenticode.Status
        SignerMatchesCertificate = (
            $Authenticode.SignerCertificate.Thumbprint -eq
            $CertificateThumbprint
        )
        TrustedInRoot            = (
            Test-Path -LiteralPath (
                Join-Path `
                    'Cert:\LocalMachine\Root' `
                    $CertificateThumbprint
            )
        )
        TrustedPublisher         = (
            Test-Path -LiteralPath (
                Join-Path `
                    'Cert:\LocalMachine\TrustedPublisher' `
                    $CertificateThumbprint
            )
        )
        ModifiedInstalledDriver  = $false
        ModifiedCertificateStores = $true
        ReportPath               = $ReportPath
        CanonicalStatePath       = $CanonicalStatePath
        LocalStatePath           = $LocalStatePath
        VerificationResultPath   = $VerificationResultPath
        VerificationResultPresent = $VerificationResultPresent
        VerificationResultVerified = $VerificationPassed
        OfficialCatalogPath       = $OfficialCatalogPath
        OfficialCcc2Path          = $OfficialCcc2Path
        OfficialCcc2IncludedInPackage = $false
    } | Format-List

    Write-Host 'PHASE 4 PASS: True' -ForegroundColor Green
    Write-Host "Canonical state: $CanonicalStatePath"
    Write-Host "Local state:     $LocalStatePath"
    Write-Host (
        'Catalog generation, signing, trust validation, private-key removal, ' +
        'and canonical state publication completed successfully.'
    )
}
finally {
    if (-not $Succeeded) {
        if ($CanonicalStatePublished) {
            if (
                $CanonicalStatePreviouslyExisted -and
                (Test-Path `
                    -LiteralPath $CanonicalStateBackupPath `
                    -PathType Leaf)
            ) {
                Copy-Item `
                    -LiteralPath $CanonicalStateBackupPath `
                    -Destination $CanonicalStatePath `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
            else {
                Remove-Item `
                    -LiteralPath $CanonicalStatePath `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }

        if ($CertificateCreated -and $CertificateThumbprint) {
            foreach ($StorePath in @(
                'Cert:\LocalMachine\TrustedPublisher'
                'Cert:\LocalMachine\Root'
                'Cert:\LocalMachine\My'
            )) {
                Remove-CertificateByThumbprint `
                    -StorePath $StorePath `
                    -Thumbprint $CertificateThumbprint
            }
        }

        if (Test-Path -LiteralPath $RunRoot) {
            Remove-Item `
                -LiteralPath $RunRoot `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
'@
        )
    }
    'Phase-05-Prepare-Test-Signing.ps1' = [ordered]@{
        SHA256 = '1AC099AD2163B5EAF96528FCAC7FB8163CEB0C21F052AAFBB44857DD85D32EE0'
        Utf8Bom = $false
        LineEnding = 'CRLF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 5 of Script 1 in the Legion Go AMD 26.6.2 Toolkit.

First run:
  - verifies the signed package and Lenovo OEM graphics baseline;
  - records the current boot-trust state;
  - asks before restarting into UEFI if Secure Boot must be disabled;
  - enables Test Signing when Secure Boot is off; and
  - asks before restarting Windows to activate Test Signing.

Verification behavior:
  - confirms Test Signing is active in the current Windows boot;
  - accepts that active current-boot state as sufficient proof, even when
    Test Signing was enabled before the current toolkit run; and
  - marks Script 1 ready for Script 2 without requiring a redundant restart.

This phase does not install, bind, remove, or update a display driver.
#>

[CmdletBinding()]
param(
    [string]$VerificationResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\payload-verification.json',

    [string]$CatalogSigningStatePath =
        'C:\ProgramData\LegionGo-AMD-26.6.2\catalog-signing-state.json',

    [switch]$NoFirmwareReboot,

    [switch]$NoWindowsReboot
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
$ResultPath = Join-Path $WorkflowRoot 'boot-preparation-result.json'
$LogRoot = Join-Path $WorkflowRoot 'Logs'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogPath = Join-Path $LogRoot "Phase-05-Prepare-TestSigning-$Timestamp.log"
$PnPInventoryPath =
    Join-Path $LogRoot "Phase-05-PnP-Driver-Inventory-$Timestamp.xml"

$ExpectedUnsignedFileCount = 125
$ExpectedSignedFileCount = 126
$ExpectedInfHash =
    '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'
$ExpectedOemInfHash =
    '2F337E2DAD0FC1371203A846D9F0AB6EAA3FE056704956C38244D05E1E7ADB22'
$ExpectedOemVersion = '32.0.23017.1001'
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

function Get-CurrentBootTestSigningState {
    $ControlPath = 'HKLM:\SYSTEM\CurrentControlSet\Control'

    try {
        $SystemStartOptions =
            [string](
                Get-ItemPropertyValue `
                    -LiteralPath $ControlPath `
                    -Name 'SystemStartOptions' `
                    -ErrorAction Stop
            )
    }
    catch {
        throw (
            'Unable to read the current Windows boot options from ' +
            "$ControlPath\SystemStartOptions: " +
            $_.Exception.Message
        )
    }

    return [pscustomobject]@{
        Active =
            $SystemStartOptions -match
                '(?i)(^|\s)TESTSIGNING($|\s)'
        SystemStartOptions = $SystemStartOptions
    }
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

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $Directory = Split-Path -Parent $LiteralPath
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null

    $TemporaryPath =
        Join-Path `
            $Directory `
            (
                [IO.Path]::GetFileName($LiteralPath) +
                '.tmp-' +
                [guid]::NewGuid().ToString('N')
            )

    try {
        $Json = $InputObject | ConvertTo-Json -Depth 12
        $Encoding = [Text.UTF8Encoding]::new($false)

        [IO.File]::WriteAllText(
            $TemporaryPath,
            $Json,
            $Encoding
        )

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

try {
    Write-Host "State directory: $WorkflowRoot"
    Write-Host ''

    Write-Host '=== VERIFIED PACKAGE STATE ==='

    if (-not (Test-Path -LiteralPath $VerificationResultPath -PathType Leaf)) {
        throw "Phase 3 result is missing: $VerificationResultPath"
    }

    if (-not (Test-Path -LiteralPath $CatalogSigningStatePath -PathType Leaf)) {
        throw "Phase 4 signing state is missing: $CatalogSigningStatePath"
    }

    $Verification =
        Get-Content -LiteralPath $VerificationResultPath -Raw |
            ConvertFrom-Json

    $SigningState =
        Get-Content -LiteralPath $CatalogSigningStatePath -Raw |
            ConvertFrom-Json

    if (
        $Verification.Verified -ne $true -or
        $Verification.ExactUnsignedPackageReproduced -ne $true -or
        [int]$Verification.UnsignedOutputFileCount -ne
            $ExpectedUnsignedFileCount
    ) {
        throw 'Phase 3 did not record the exact 125-file unsigned package.'
    }

    $PackageRoot =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'PackageRoot')

    $CatalogPath =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'SignedCatalogPath')

    $CatalogHash =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'SignedCatalogSHA256')

    $SignerThumbprint =
        [string](Get-OptionalProperty `
            -Object $SigningState `
            -Name 'CatalogSignerThumbprint')

    if (
        [string]::IsNullOrWhiteSpace($PackageRoot) -or
        -not (Test-Path -LiteralPath $PackageRoot -PathType Container)
    ) {
        throw "Phase 4 signed package is missing: $PackageRoot"
    }

    $SignedFiles = @(
        Get-ChildItem `
            -LiteralPath $PackageRoot `
            -Recurse `
            -File `
            -Force
    )

    if ($SignedFiles.Count -ne $ExpectedSignedFileCount) {
        throw (
            'Signed package file-count mismatch. Expected 126; actual ' +
            $SignedFiles.Count + '.'
        )
    }

    $SignedInfPath = Join-Path $PackageRoot 'u0201589.inf'
    $UnexpectedCcc2Path =
        Join-Path $PackageRoot 'B026175\ccc2_install.exe'

    if (
        -not (Test-Path -LiteralPath $SignedInfPath -PathType Leaf) -or
        (Get-SHA256 -LiteralPath $SignedInfPath) -ne $ExpectedInfHash
    ) {
        throw 'The signed package does not contain the canonical INF.'
    }

    if (Test-Path -LiteralPath $UnexpectedCcc2Path -PathType Leaf) {
        throw (
            'The signed driver package incorrectly contains ' +
            'ccc2_install.exe.'
        )
    }

    if (
        [string]::IsNullOrWhiteSpace($CatalogPath) -or
        -not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)
    ) {
        throw "The per-user signed catalog is missing: $CatalogPath"
    }

    $ActualCatalogHash = Get-SHA256 -LiteralPath $CatalogPath
    $CatalogSignature = Get-AuthenticodeSignature -LiteralPath $CatalogPath
    $ActualSignerThumbprint = ''

    if ($null -ne $CatalogSignature.SignerCertificate) {
        $ActualSignerThumbprint =
            [string]$CatalogSignature.SignerCertificate.Thumbprint
    }

    if (
        $ActualCatalogHash -ne $CatalogHash -or
        $CatalogSignature.Status -ne 'Valid' -or
        $ActualSignerThumbprint -ne $SignerThumbprint
    ) {
        throw (
            'The local catalog does not match Phase 4 signing state.'
        )
    }

    $RootCertificate =
        Get-LocalMachineCertificate `
            -StoreName Root `
            -Thumbprint $SignerThumbprint

    $PublisherCertificate =
        Get-LocalMachineCertificate `
            -StoreName TrustedPublisher `
            -Thumbprint $SignerThumbprint

    if (
        $null -eq $RootCertificate -or
        $null -eq $PublisherCertificate
    ) {
        throw (
            'The per-user catalog signer is not trusted in both required ' +
            'LocalMachine certificate stores.'
        )
    }

    Write-Host '[PASS] Exact 126-file signed package is ready'
    Write-Host "       Package: $PackageRoot"
    Write-Host "       Catalog: $ActualCatalogHash"
    Write-Host "       Signer:  $SignerThumbprint"

    Write-Host ''
    Write-Host '=== LENOVO OEM GRAPHICS BASELINE ==='

    $GpuDriver = Get-GpuDriver
    $GpuEntity = Get-GpuEntity
    $ActiveInfPath = Join-Path $env:windir "INF\$($GpuDriver.InfName)"

    if (-not (Test-Path -LiteralPath $ActiveInfPath -PathType Leaf)) {
        throw "Active OEM INF is missing: $ActiveInfPath"
    }

    $ActiveInfHash = Get-SHA256 -LiteralPath $ActiveInfPath

    [pscustomobject]@{
        DeviceName = $GpuDriver.DeviceName
        DeviceID = $GpuDriver.DeviceID
        ActiveINF = $GpuDriver.InfName
        DriverVersion = $GpuDriver.DriverVersion
        ActiveInfSHA256 = $ActiveInfHash
        Status = $GpuEntity.Status
        ProblemCode = $GpuEntity.ConfigManagerErrorCode
    } | Format-List

    if (
        $GpuDriver.DriverVersion -ne $ExpectedOemVersion -or
        $ActiveInfHash -ne $ExpectedOemInfHash -or
        $GpuEntity.Status -ne 'OK' -or
        $GpuEntity.ConfigManagerErrorCode -ne 0
    ) {
        throw (
            'The machine is not on the validated Lenovo OEM graphics ' +
            'baseline required before Script 2.'
        )
    }

    $ExtensionState =
        Get-LenovoExtensionState `
            -DeviceInstanceId $GpuDriver.DeviceID

    if (-not $ExtensionState.InventoryCreated) {
        throw (
            'PnPUtil could not create the structured driver inventory. ' +
            "ExitCode=$($ExtensionState.ExitCode)"
        )
    }

    if (-not $ExtensionState.Attached) {
        throw (
            'The required Lenovo extension is not attached to the GPU. ' +
            "Expected $ExpectedExtensionOriginalName " +
            "$ExpectedExtensionVersion."
        )
    }

    Write-Host '[PASS] Lenovo OEM display driver and extension are intact'

    Write-Host ''
    Write-Host '=== BOOT TRUST PREPARATION ==='

    try {
        $SecureBootEnabled = Confirm-SecureBootUEFI
    }
    catch {
        throw "Unable to query Secure Boot: $($_.Exception.Message)"
    }

    $BcdBefore = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    $TestSigningConfiguredOn =
        $BcdBefore -match '(?im)^\s*testsigning\s+Yes\s*$'

    $CurrentBootTestSigning = Get-CurrentBootTestSigningState
    $TestSigningActiveInCurrentBoot =
        [bool]$CurrentBootTestSigning.Active

    Write-Host "Secure Boot enabled:             $SecureBootEnabled"
    Write-Host "Test Signing configured:         $TestSigningConfiguredOn"
    Write-Host (
        "Test Signing active now:          " +
        $TestSigningActiveInCurrentBoot
    )

    if ($SecureBootEnabled) {
        $Result = [ordered]@{
            SchemaVersion = 2
            Workflow = 'LegionGo-AMD-26.6.2'
            ReadyForDriverInstall = $false
            Phase = 'Awaiting-Manual-Secure-Boot-Disable'
            UpdatedAt = (Get-Date).ToString('o')
            SecureBootEnabled = $true
            TestSigningConfiguredOn = $TestSigningConfiguredOn
            TestSigningActiveInCurrentBoot =
                $TestSigningActiveInCurrentBoot
            PackageRoot = $PackageRoot
            ActiveINF = $GpuDriver.InfName
            DriverVersion = $GpuDriver.DriverVersion
            LenovoExtensionAttached = $true
            CatalogSigningStatePath = $CatalogSigningStatePath
            NextStage = 'Rerun-02C-After-Disabling-Secure-Boot'
            LogPath = $LogPath
        }

        Write-AtomicJson -InputObject $Result -LiteralPath $ResultPath
        Write-AtomicJson -InputObject $Result -LiteralPath $StatePath

        Write-Host ''
        Write-Host 'Secure Boot must be disabled manually in UEFI.'
        Write-Host (
            'After saving the firmware setting and booting Windows, run ' +
            'this same Script 1 command again.'
        )

        if ($NoFirmwareReboot) {
            Write-Host (
                'Firmware restart skipped because -NoFirmwareReboot was ' +
                'supplied.'
            )
            return
        }

        $RestartToFirmware = Confirm-UserAction `
            -Prompt 'Restart into UEFI firmware settings now?'

        if (-not $RestartToFirmware) {
            Write-Host (
                '[INFO] Firmware restart was not scheduled. Open UEFI ' +
                'manually, disable Secure Boot, start Windows, and run ' +
                'Script 1 again.'
            ) -ForegroundColor Yellow
            return
        }

        Write-Host 'Restarting into UEFI firmware settings in 10 seconds.'

        & shutdown.exe `
            /r `
            /fw `
            /t 10 `
            /c (
                'Legion Go AMD 26.6.2: disable Secure Boot in UEFI, ' +
                'then run Script 1 again.'
            )

        if ($LASTEXITCODE -ne 0) {
            throw (
                'Failed to schedule the firmware reboot. Exit code: ' +
                $LASTEXITCODE
            )
        }

        return
    }

    $CurrentBootTime =
        (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

    $ExistingResult = $null

    if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
        try {
            $ExistingResult =
                Get-Content -LiteralPath $ResultPath -Raw |
                    ConvertFrom-Json
        }
        catch {
            Write-Warning (
                'The existing Phase 5 result could not be read and will ' +
                'not be used to prove the reboot boundary: ' +
                $_.Exception.Message
            )
        }
    }

    $TestSigningChangedThisRun = $false

    if (-not $TestSigningConfiguredOn) {
        & bcdedit.exe /set testsigning on

        if ($LASTEXITCODE -ne 0) {
            throw (
                'BCDEdit failed to enable Test Signing. Exit code: ' +
                $LASTEXITCODE
            )
        }

        $TestSigningChangedThisRun = $true
    }

    $BcdAfter = (& bcdedit.exe /enum '{current}' 2>&1) -join "`n"
    $TestSigningConfiguredOn =
        $BcdAfter -match '(?im)^\s*testsigning\s+Yes\s*$'

    if (-not $TestSigningConfiguredOn) {
        throw (
            'BCDEdit returned successfully, but Test Signing was not ' +
            'confirmed as configured on.'
        )
    }

    $ExistingBoundaryText = $null
    $ExistingBoundary = $null
    $ExistingPhase = $null
    $RebootBoundaryProven = $false

    if ($null -ne $ExistingResult) {
        $ExistingBoundaryText =
            [string](
                Get-OptionalProperty `
                    -Object $ExistingResult `
                    -Name 'UpdatedAt'
            )

        $ExistingPhase =
            [string](
                Get-OptionalProperty `
                    -Object $ExistingResult `
                    -Name 'Phase'
            )

        if (-not [string]::IsNullOrWhiteSpace($ExistingBoundaryText)) {
            try {
                $ExistingBoundary = [datetime]$ExistingBoundaryText
            }
            catch {
                $ExistingBoundary = $null
            }
        }

        if (
            -not $TestSigningChangedThisRun -and
            $null -ne $ExistingBoundary -and
            $CurrentBootTime -gt $ExistingBoundary -and
            $ExistingPhase -in @(
                'Awaiting-TestSigning-On-Reboot',
                'Ready-For-Driver-Install'
            )
        ) {
            $RebootBoundaryProven = $true
        }
    }

    $ActiveCurrentBootAccepted =
        (
            -not $TestSigningChangedThisRun -and
            $TestSigningActiveInCurrentBoot
        )

    if ($RebootBoundaryProven -or $ActiveCurrentBootAccepted) {
        $ConfiguredBootTime =
            Get-OptionalProperty `
                -Object $ExistingResult `
                -Name 'BootTimeWhenConfigured'

        $BoundarySource = 'Recorded-Workflow-Restart'
        $CompatibleBoundaryText = $ExistingBoundaryText

        if (-not $RebootBoundaryProven) {
            # Test Signing is already active in the Windows boot that is
            # currently running. That is stronger evidence than a pending BCD
            # setting and proves that a restart occurred at some point after
            # Test Signing was enabled. Script 2 still expects UpdatedAt to be
            # earlier than the current boot, so use a compatibility boundary
            # immediately before the actual boot time and record its source.
            $BoundarySource = 'Current-Boot-SystemStartOptions'
            $CompatibleBoundaryText =
                $CurrentBootTime.AddTicks(-1).ToString('o')
            $ConfiguredBootTime = $CurrentBootTime
        }

        $Result = [ordered]@{
            SchemaVersion = 4
            Workflow = 'LegionGo-AMD-26.6.2'
            ReadyForDriverInstall = $true
            Phase = 'Ready-For-Driver-Install'
            UpdatedAt = $CompatibleBoundaryText
            ReadyVerifiedAt = (Get-Date).ToString('o')
            BootTimeWhenConfigured = $ConfiguredBootTime
            BootTimeWhenVerified = $CurrentBootTime
            SecureBootEnabled = $false
            TestSigningConfiguredOn = $true
            TestSigningActiveInCurrentBoot = $true
            TestSigningRebootProven = $true
            RebootProofSource = $BoundarySource
            SystemStartOptions =
                $CurrentBootTestSigning.SystemStartOptions
            PackageRoot = $PackageRoot
            ActiveINF = $GpuDriver.InfName
            DriverVersion = $GpuDriver.DriverVersion
            ActiveInfSHA256 = $ActiveInfHash
            LenovoExtensionAttached = $true
            CatalogSigningStatePath = $CatalogSigningStatePath
            NextStage = '03-Install-Driver-Register-Catalog-And-Reboot'
            LogPath = $LogPath
        }

        Write-AtomicJson -InputObject $Result -LiteralPath $ResultPath
        Write-AtomicJson -InputObject $Result -LiteralPath $StatePath

        Write-Host '[PASS] Test Signing is active in the current Windows boot'

        if ($RebootBoundaryProven) {
            Write-Host (
                '[PASS] Required restart after enabling Test Signing is proven'
            )
        }
        else {
            Write-Host (
                '[PASS] Active current-boot state accepted; no redundant ' +
                'restart is required'
            )
        }

        Write-Host "Result file: $ResultPath"
        Write-Host 'PHASE 5 PASS: True' -ForegroundColor Green
        Write-Host 'Script 1 has completed successfully.'
        Write-Host 'Run Script 2 next.'
        return
    }

    # Test Signing is configured but is not active in the current boot.
    # Record one boundary and request exactly one restart. The next Script 1
    # run will prove that restart and will not restart again.
    $ConfigurationBoundary = (Get-Date).ToString('o')

    $Result = [ordered]@{
        SchemaVersion = 3
        Workflow = 'LegionGo-AMD-26.6.2'
        ReadyForDriverInstall = $false
        Phase = 'Awaiting-TestSigning-On-Reboot'
        UpdatedAt = $ConfigurationBoundary
        BootTimeWhenConfigured = $CurrentBootTime
        SecureBootEnabled = $false
        TestSigningConfiguredOn = $true
        TestSigningActiveInCurrentBoot =
            $TestSigningActiveInCurrentBoot
        TestSigningChangedThisRun = $TestSigningChangedThisRun
        TestSigningRebootProven = $false
        PackageRoot = $PackageRoot
        ActiveINF = $GpuDriver.InfName
        DriverVersion = $GpuDriver.DriverVersion
        ActiveInfSHA256 = $ActiveInfHash
        LenovoExtensionAttached = $true
        CatalogSigningStatePath = $CatalogSigningStatePath
        NextStage = 'Rerun-02C-After-Windows-Reboot'
        LogPath = $LogPath
    }

    Write-AtomicJson -InputObject $Result -LiteralPath $ResultPath
    Write-AtomicJson -InputObject $Result -LiteralPath $StatePath

    if ($TestSigningChangedThisRun) {
        Write-Host '[PASS] Test Signing was configured on for the next boot'
    }
    else {
        Write-Host '[INFO] Test Signing is configured but not active now'
        Write-Host (
            '[INFO] One Windows restart is required before Script 2'
        )
    }

    Write-Host "Result file: $ResultPath"

    if ($NoWindowsReboot) {
        Write-Host (
            'Windows restart skipped because -NoWindowsReboot was supplied. ' +
            'Do not run Script 2 yet. Restart Windows, then run Script 1 again.'
        )
        return
    }

    Write-Host ''
    Write-Host (
        'A Windows restart is required to activate Test Signing. Save your ' +
        'work and close open applications. After Windows starts, run ' +
        'Script 1 again.'
    ) -ForegroundColor Yellow

    $RestartWindows = Confirm-UserAction `
        -Prompt 'Restart Windows now?'

    if (-not $RestartWindows) {
        Write-Host (
            '[INFO] Windows restart was not scheduled. Restart manually, ' +
            'then run Script 1 again.'
        ) -ForegroundColor Yellow
        return
    }

    Write-Host 'Windows will restart in 10 seconds.'

    & shutdown.exe `
        /r `
        /t 10 `
        /c (
            'Legion Go AMD 26.6.2: rebooting once to activate Test Signing. ' +
            'Run Script 1 again after sign-in.'
        )

    if ($LASTEXITCODE -ne 0) {
        throw (
            'Failed to schedule the Windows reboot. Exit code: ' +
            $LASTEXITCODE
        )
    }

}
finally {
    Stop-Transcript | Out-Null
}
'@
        )
    }
    'data\Canonical-Unchanged-Files.json' = [ordered]@{
        SHA256 = '789D38519BD9EB11A0971AD4551C85E01671D8B3328CBB48BA2E00A658A5D030'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $false
        ContentParts = @(
@'
{
  "schemaVersion": 1,
  "description": "Files copied unchanged from the official AMD 26.6.2 -c WT6A_INF package into the canonical Legion Go display-driver package.",
  "officialSourceFileCount": 194,
  "canonicalSignedFileCount": 126,
  "unchangedFileCount": 123,
  "rebuiltFiles": [
    {
      "relativePath": "u0201589.inf",
      "officialSha256": "97C64806E91AA2EB6F2B17A94369FBB884A8048ACD9A8F9FCD59155797AC4FA6",
      "canonicalSha256": "39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E"
    },
    {
      "relativePath": "B026175\\amdgcf.dat",
      "officialSha256": "740C379B33945AC60BA1C0A9386F48BAB894524018B1F5F9D2788D7E33585185",
      "canonicalSha256": "AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200"
    }
  ],
  "generatedFile": {
    "relativePath": "u0201589.cat",
    "officialSha256": "0AA239C38E88685568A7A1DDB36C99DF8F0E23449E28D0F21FA36CBBA536583D",
    "historicalCanonicalSha256": "0594C9E5BF2C983CC385CD413674AF724D2310CB1005EFDFD1AE254F201C58B0",
    "note": "The public workflow must regenerate and sign this catalog with a per-user certificate, so its final hash is expected to differ."
  },
  "unchangedFiles": [
    {
      "relativePath": "B026175\\amd_fidelityfx_dx12.dll",
      "length": 6667280,
      "sha256": "6D9AB669A6CDD12304A90BF60228E09C5101A7B216DECAB39FD899C0986F34E4"
    },
    {
      "relativePath": "B026175\\amd_opencl32.dll",
      "length": 214032,
      "sha256": "1E4F496B76D9DDCD500348AFE02E36AE48DD285D1B7F813C8E32BCBA247285CD"
    },
    {
      "relativePath": "B026175\\amd_opencl64.dll",
      "length": 244744,
      "sha256": "E226825CFA28B54D04CAB7A0FE63F3FE29A4D1B088FB75E547DF04F7C55A7E6E"
    },
    {
      "relativePath": "B026175\\amdadlx32.dll",
      "length": 4801032,
      "sha256": "8B19C903FD47AAAC51559B66630549E100EFC10758A76F0C949A2B849BBDAD7A"
    },
    {
      "relativePath": "B026175\\amdadlx64.dll",
      "length": 5224968,
      "sha256": "DB5552DE8A6B247F720F0A96FE4F57E0C9FC80BCAF329F4DDBA9103DB4379D5B"
    },
    {
      "relativePath": "B026175\\AMDADLXServ.exe",
      "length": 438288,
      "sha256": "C5DD7CC075EF7091E0A50AD732159248283DE179E222B7F5ED005E42B71D2B68"
    },
    {
      "relativePath": "B026175\\AMDADLXServPS.dll",
      "length": 236560,
      "sha256": "639A6DBF007A9D514FF6C4748AD4EC482C4FE1844063D28DAD428F99DA5FF231"
    },
    {
      "relativePath": "B026175\\AMDADLXServPS32.dll",
      "length": 120336,
      "sha256": "0547CBD00012B043FCC3835301E456ACFAF19193737B48EA27B15A955671B44F"
    },
    {
      "relativePath": "B026175\\AMDav1Enc32.dll",
      "length": 2285584,
      "sha256": "39C5E3F467CC7BAA348BF04645848027D58661F0BBA0F5B02F091003CEC8AACB"
    },
    {
      "relativePath": "B026175\\AMDav1Enc64.dll",
      "length": 2370576,
      "sha256": "FA7657FA155507B4EB155BE981DE9A14549D0F7C63EF1575FAE266CF481CF9D4"
    },
    {
      "relativePath": "B026175\\amdave32.dll",
      "length": 146832,
      "sha256": "2C13B5D783EBDF6E059FA87BB853566EC2057840B687CB286AD0E1280C07C865"
    },
    {
      "relativePath": "B026175\\amdave64.dll",
      "length": 167160,
      "sha256": "9E94A7493682FD64C23F8B5764362B84C962577671436361E23609159ABC06F5"
    },
    {
      "relativePath": "B026175\\amdcc.dll",
      "length": 4449816,
      "sha256": "711B412C50DD4664EF14AA910974668BF4D89DEBAD89A578F88A4F996931BE8A"
    },
    {
      "relativePath": "B026175\\amdefctb.dat",
      "length": 515238,
      "sha256": "BDB7D795E7BC809B2D752C8D71320D0A50321FAE9491EEDDF6720CD98FED5B5A"
    },
    {
      "relativePath": "B026175\\amdenc32.dll",
      "length": 1255432,
      "sha256": "8B1EDE9C3E2CC237E49AFCE35660E99BCC2DD1C59643F86FE7E426233DE2A373"
    },
    {
      "relativePath": "B026175\\amdenc64.dll",
      "length": 1424424,
      "sha256": "C8BDFBF350B99BABEA71C7009273F75E310EDE8DE7F509DC0E6381725CE7A384"
    },
    {
      "relativePath": "B026175\\amdept.dat",
      "length": 42028,
      "sha256": "B6A9FADE79FD0ED57A54057725AF66D4648C9CBD58800EB9FEB54CEE460A681E"
    },
    {
      "relativePath": "B026175\\amdgfxinfo32.dll",
      "length": 457224,
      "sha256": "F5FDDFF7B71962744D8528690749496EEFAE149D97BD9E63DFBFAC1D276FE8DB"
    },
    {
      "relativePath": "B026175\\amdgfxinfo64.dll",
      "length": 597520,
      "sha256": "D13F2732E64BCE3A8E9E98AE1FAA631D9917EA8C69C4657E1130B3F2E9C0CE7B"
    },
    {
      "relativePath": "B026175\\AMDh264Enc32.dll",
      "length": 2289184,
      "sha256": "5A5FFBFD97C7D2EAE7A59286BD85807D563AA5529297E2E24E71F80585529D86"
    },
    {
      "relativePath": "B026175\\AMDh264Enc64.dll",
      "length": 2365888,
      "sha256": "7C267D9CAF2C94C92ECBD2B76C99C41A90F585C75D1AD908B9A40AD047307F9D"
    },
    {
      "relativePath": "B026175\\AMDh265Enc32.dll",
      "length": 2271488,
      "sha256": "4D2846BFEB62A853A8BD06CC1778E6500A1B645B3B87CD27FC98C64D94878F20"
    },
    {
      "relativePath": "B026175\\AMDh265Enc64.dll",
      "length": 2352288,
      "sha256": "326F0EEF33BDC59C06E89A4088C323548DEDA2333BA9A0057D42C2FB3B7DC90F"
    },
    {
      "relativePath": "B026175\\amdhdl32.dll",
      "length": 125472,
      "sha256": "73F7ADC2C91D4C41D3397FAA1C8A9D9FFF89D50858BF9F34B8BE51EF55C7529F"
    },
    {
      "relativePath": "B026175\\amdhdl64.dll",
      "length": 146384,
      "sha256": "2143FDA82C733D485A97A214FE5A256D7EC36EFD0A47A43D39D0FFD78E46EDAB"
    },
    {
      "relativePath": "B026175\\amdicdxx.dat",
      "length": 1716978,
      "sha256": "5DA952C500304745CFE5B63E005BDB9233381BD24451358EAC953A7B7CBDCA12"
    },
    {
      "relativePath": "B026175\\amdihk32.dll",
      "length": 216592,
      "sha256": "F9DF22EFF4AFD3A5B100C6B63C24D999A0E3CEA34A321D3F783A2EAE23551401"
    },
    {
      "relativePath": "B026175\\amdihk64.dll",
      "length": 269232,
      "sha256": "B1A433D5D701A11786E04FB0936AFABEB87FDA99B51C7785F534CFAF10801B26"
    },
    {
      "relativePath": "B026175\\AMDInstallManager.msi",
      "length": 66519040,
      "sha256": "40D91081DBDC370A24E41BA951C86C1E903D2568BD8AE6723AFE16356A154177"
    },
    {
      "relativePath": "B026175\\AMDKernelEvents.mc",
      "length": 21730,
      "sha256": "D93EADCEAA84AF4265B61DFD6A37F3DA5294433F5B418F17BD6C136CD5ABE841"
    },
    {
      "relativePath": "B026175\\amdkmdag.sys",
      "length": 84134416,
      "sha256": "EC5E1DF54FEA3A307BD69D5E091E6841A6E9AF2780F0C8C919350A9627D9F6A9"
    },
    {
      "relativePath": "B026175\\amdlvr32.dll",
      "length": 998416,
      "sha256": "3DC190233401F3DB8751066BF5AEDCF7AE28AB2732645CECCD174EB67787689A"
    },
    {
      "relativePath": "B026175\\amdlvr64.dll",
      "length": 1184784,
      "sha256": "FD7FED59C3DBBEBB8792F4B4B198E4422369A147887F3665DFA84460935686BD"
    },
    {
      "relativePath": "B026175\\amdmiracast.dll",
      "length": 180240,
      "sha256": "8320D61F520C7FFC6DDB65EAB46CBA4869AEEEEEEE2C7C31210C929CE0C6A6BD"
    },
    {
      "relativePath": "B026175\\amdmmpal32.dll",
      "length": 2100752,
      "sha256": "7631B9B3D717DDDE19872648747A5F521BFD5D26D1499E48736B2ADB3AC9C9B2"
    },
    {
      "relativePath": "B026175\\amdmmpal64.dll",
      "length": 2379792,
      "sha256": "701C133BDD5270A1328FEE7E8DCCB346AAC6459754396B716895570B64A500B8"
    },
    {
      "relativePath": "B026175\\amdpcom32.dll",
      "length": 132856,
      "sha256": "55B7C35CD525B8E4C490E204493369E4260825C52D96F72C7A778248B10502FD"
    },
    {
      "relativePath": "B026175\\amdpcom64.dll",
      "length": 156840,
      "sha256": "627F6C6C592055F866635AFB4A31E39987E0207488CB5251E72FBA65555CE881"
    },
    {
      "relativePath": "B026175\\amdsacli32.dll",
      "length": 552968,
      "sha256": "D6D30FF26A37863870205F5364F6840A6A997975966117C65FC54B1951CBFC59"
    },
    {
      "relativePath": "B026175\\amdsacli64.dll",
      "length": 620512,
      "sha256": "8F15BAFBFB7AADDD902C7AFFA73C7A1DC7610E3E8921BE05A2CDBC28449538D0"
    },
    {
      "relativePath": "B026175\\amdsasrv64.dll",
      "length": 1334288,
      "sha256": "99042011CB0984A461692AABFE7343E19DABC4B57F2AA9DB986FD0A8A309CAA0"
    },
    {
      "relativePath": "B026175\\amduve32.dll",
      "length": 170880,
      "sha256": "D2C1BA4EB340912481FFA995083196233E4F854382C69B9D8927AB87E4A8476B"
    },
    {
      "relativePath": "B026175\\amduve64.dll",
      "length": 199472,
      "sha256": "9CD458506159DA96872064B293A7338FEAE630A837313FE86923B4F15D2C2C55"
    },
    {
      "relativePath": "B026175\\amdxc32.dll",
      "length": 69712024,
      "sha256": "763C53FB193452746CF3C7100439244D1A98C4743285D1E35333D40114D84D45"
    },
    {
      "relativePath": "B026175\\amdxc64.dll",
      "length": 78202168,
      "sha256": "A38E02E954C59B6C2281E6A49CD798BB08594FD51C4DD401890511D0BFA470CD"
    },
    {
      "relativePath": "B026175\\amdxc64.so",
      "length": 122155464,
      "sha256": "B9A3C4A076B633FF3E47DB9BDC8E3D5F1892C6494E80EE6A98A901A38B4874ED"
    },
    {
      "relativePath": "B026175\\amdxcffx64.dll",
      "length": 66830768,
      "sha256": "A2B136B6AFFD35A49B141A936BE935F7D5DDC8D8F9B8C9AFBE62FF9DDB2538A0"
    },
    {
      "relativePath": "B026175\\amdxcstub32.dll",
      "length": 121816,
      "sha256": "BFAF53978DBD1B59BEE0529377412F235F5C20E3045EF1129358B9DC27F06C66"
    },
    {
      "relativePath": "B026175\\amdxcstub64.dll",
      "length": 141632,
      "sha256": "14AD3AF900235F593056A16E261B0A14E520AFF03EE44A00CA20E2101291161B"
    },
    {
      "relativePath": "B026175\\amdxn32.dll",
      "length": 34454544,
      "sha256": "A9753CC8585C9E41F11F5A2BA1DB65F1091C974B7C8ED75A7E865AFD54A1AC57"
    },
    {
      "relativePath": "B026175\\amdxn64.dll",
      "length": 40476688,
      "sha256": "E25B733CA5E0AEF05E51A7F7AF5E56C624B88C9054486C3B2C6B11C81F5FA87A"
    },
    {
      "relativePath": "B026175\\amdxx32.dll",
      "length": 41892600,
      "sha256": "FED1C2836DB97F524C7212C639D4DEED1E6EBB5CD2C1447DBAF921F5BDA2B113"
    },
    {
      "relativePath": "B026175\\amdxx64.dll",
      "length": 47384560,
      "sha256": "85A8D111B5958BABEC3FF2E969AB2AF7D0237D9B8C11C294298BD9F2AF0FF7E3"
    },
    {
      "relativePath": "B026175\\amf-mft-mjpeg-decoder32.dll",
      "length": 1402048,
      "sha256": "D57780F40212C4B9930050CEFCA415A40FF3A4CC744CB3995668AE779F42174B"
    },
    {
      "relativePath": "B026175\\amf-mft-mjpeg-decoder64.dll",
      "length": 1724592,
      "sha256": "2B3BE5BCC2BEE16585148C6A79DBFA60C0AC614E922E1F420E844B3D5CED99E4"
    },
    {
      "relativePath": "B026175\\amf-pa-ml32.dll",
      "length": 344592,
      "sha256": "03EE60EFFCD6062AD9FA3CDDA83D8B8B672BAEAE8D3480E7EEA9F2D45208FC24"
    },
    {
      "relativePath": "B026175\\amf-pa-ml64.dll",
      "length": 377872,
      "sha256": "0B8B8AD822B4BC7F5908117CF6BBC8F8FE0BD4B605749AD6A4159DED9F95C756"
    },
    {
      "relativePath": "B026175\\amfrt32.dll",
      "length": 129552,
      "sha256": "0B3780D13503887B19CE579D9C93F5AC38E6AA5BDCA06B13E07B106558D4AE7B"
    },
    {
      "relativePath": "B026175\\amfrt64.dll",
      "length": 160784,
      "sha256": "B23A88B57D1BCDD3A4B75AB0F14A3B9DDA5C29F3CF70F3AF3F8EFC44530FEF52"
    },
    {
      "relativePath": "B026175\\amfrtdrv32.dll",
      "length": 19405832,
      "sha256": "DA9C9C12BA590EC3799B66C5C398B9ED65A6C9E97B6C9B8906DF9476093BCB14"
    },
    {
      "relativePath": "B026175\\amfrtdrv64.dll",
      "length": 20524040,
      "sha256": "F77B4C0BB793DF10CBFE09CC4F311E8F898461A8AD6BC689E4A4CFD744D1D191"
    },
    {
      "relativePath": "B026175\\atiadlxx.dll",
      "length": 2508304,
      "sha256": "7674A453A55BA0A14BAAD6EABAC19884D6320C0CBA57A00E45E5593348F29B9E"
    },
    {
      "relativePath": "B026175\\atiadlxy.dll",
      "length": 2062352,
      "sha256": "0BF7D28D7B50DC3F8F7EA4DA32C05E385A440DE7121F85531245171E2A585C2A"
    },
    {
      "relativePath": "B026175\\atiapfxx.blb",
      "length": 552992,
      "sha256": "0D5D0502C2CF3797B420EAEE134EA30E53A867753997CB0B53038DEAD2688786"
    },
    {
      "relativePath": "B026175\\atidemgy.dll",
      "length": 473608,
      "sha256": "CE5CC7CF1FD1E7075F30FD9A9C7D1D5838D041883A4ADC2875BE8AA193A2561F"
    },
    {
      "relativePath": "B026175\\atidx9loader32.dll",
      "length": 119824,
      "sha256": "ABAEFF5F23767F912C485149B3B77502F95318F40EBE3B9291662A422CA9610A"
    },
    {
      "relativePath": "B026175\\atidx9loader64.dll",
      "length": 138768,
      "sha256": "D8E853BE0DD20F8F62B1614444095A1E1CE0B90E6F61E57D80A9BED81E29499A"
    },
    {
      "relativePath": "B026175\\atidxxstub32.dll",
      "length": 106176,
      "sha256": "EA842702C3A872DF04C79F8E6902433966614CFD58343BD49C24743AE3766D5D"
    },
    {
      "relativePath": "B026175\\atidxxstub64.dll",
      "length": 128408,
      "sha256": "696F94554CBB3312481C943139E30CE520D99F25E404D3AB753624106196B4DA"
    },
    {
      "relativePath": "B026175\\atieah32.exe",
      "length": 429576,
      "sha256": "EB1F09B3F9BB2C927520F7995CFB5D402F78401DEF3DF0DAB571E6F68996ED64"
    },
    {
      "relativePath": "B026175\\atieah64.exe",
      "length": 565264,
      "sha256": "13D4DDBE8441F305865E7DFF9AF6A4221B5C6E1743A852921F4D27DADB155F59"
    },
    {
      "relativePath": "B026175\\atieclxx.exe",
      "length": 1067536,
      "sha256": "9C44BC7CC31726A620FCCFF2B94C46BBDCC66137B7085B5E77CF62D5E51A37EF"
    },
    {
      "relativePath": "B026175\\atiesrxx.exe",
      "length": 682512,
      "sha256": "7CE33A545F5429E928C946D54C198BADB2619E768C54917A4040AC38A1DFE2A3"
    },
    {
      "relativePath": "B026175\\atig6pxx.dll",
      "length": 187920,
      "sha256": "04FD58D60D1422254D843E050B6651E8DF9C28FC0106FB4C9755AB43E6507B23"
    },
    {
      "relativePath": "B026175\\atiglpxx.dll",
      "length": 160784,
      "sha256": "4328DC1F2FEF0B32A508C900267F80B2585D427C5E9B2006E37B6DB87B3B785F"
    },
    {
      "relativePath": "B026175\\atiicdxx.dat",
      "length": 737410,
      "sha256": "DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F"
    },
    {
      "relativePath": "B026175\\atimpc32.dll",
      "length": 132864,
      "sha256": "275FDAC92204AA5D1416102A4ADF1AC41A142CFC7424052533652D419CB88DCD"
    },
    {
      "relativePath": "B026175\\atimpc64.dll",
      "length": 156840,
      "sha256": "B4EFDC3EEE0F5486523784357ADBF19D69B9FF63C26DE527713F476D541D093B"
    },
    {
      "relativePath": "B026175\\atimuixx.dll",
      "length": 200720,
      "sha256": "1CCC005F05C4294DB67E3E495A3085F8410D28BF4ACCA6FF76B0E400DF957822"
    },
    {
      "relativePath": "B026175\\atisamu32.dll",
      "length": 152080,
      "sha256": "FAE97F4479D7F7F708DC6C973F0575448D7DD7772919A124FB9FD3AC892BE321"
    },
    {
      "relativePath": "B026175\\atisamu64.dll",
      "length": 187912,
      "sha256": "2AEFBE91D2192A600931843A313C643B76045217655C31BDEB232AB1A6266ADA"
    },
    {
      "relativePath": "B026175\\ativvaxy_cik_nd.dat",
      "length": 234416,
      "sha256": "15B132C7947B2FD93DADC9E48278332D455A03957E7E948938F6EB7BC54F572D"
    },
    {
      "relativePath": "B026175\\ativvaxy_cik.dat",
      "length": 234676,
      "sha256": "4E5986C9A62243D556523D6E3E72CB414EB275A104853B2436FA20E0D55994BD"
    },
    {
      "relativePath": "B026175\\ativvaxy_cz_nd.dat",
      "length": 272928,
      "sha256": "D043E8FE127BF5E25C43CDF945834F3D37261AB47C65D05605A09E83D5C89FC4"
    },
    {
      "relativePath": "B026175\\ativvaxy_el_nd.dat",
      "length": 376224,
      "sha256": "CD11D2ABC62D90BDDD580CEEC25BAFC20962FB381923ADE87E74CD9E66873D0C"
    },
    {
      "relativePath": "B026175\\ativvaxy_FJ_nd.dat",
      "length": 267984,
      "sha256": "94744405991474810F96B7401E1A13062BB6B2D217F87D161CC285FD53D94496"
    },
    {
      "relativePath": "B026175\\ativvaxy_FJ.dat",
      "length": 268244,
      "sha256": "5D29280832A9AF0FE48DE5EE0C177B2DE885B8FB9431FD53D8BB5348C26FCB7B"
    },
    {
      "relativePath": "B026175\\ativvaxy_gl_nd.dat",
      "length": 381984,
      "sha256": "C91BDBE922E1404120D4217664EAD5F038B2E3A620D7A2D7FAE2DD7ECDA86990"
    },
    {
      "relativePath": "B026175\\ativvaxy_nv.dat",
      "length": 404288,
      "sha256": "B12AD7392BFA0439FA1759403F29022740F2AA8DE67BFA2D4285C05AA994AA8C"
    },
    {
      "relativePath": "B026175\\ativvaxy_rv.dat",
      "length": 366304,
      "sha256": "2CF886FE3A8530D09EAB3D535FEB62CBD795E33B84E00F22B26905446816C9B1"
    },
    {
      "relativePath": "B026175\\ativvaxy_stn_nd.dat",
      "length": 278432,
      "sha256": "8C09DD21260D7FFC959220D59379CA2A4F17559FE94D92B63CBF9E8A639D0A4C"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn3_1.dat",
      "length": 572112,
      "sha256": "643C2A57629EC80F68AAE64763947913EC4B57AFBF12854869E0EFB2088E36F1"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn3.dat",
      "length": 579856,
      "sha256": "A507DBA341207CF7C444006A846EFD69AC6E34945CA925257B693B71EE4E5C47"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn4_0_a_1.dat",
      "length": 395408,
      "sha256": "1170239117C7312659A8757EA8A51A7162011EEC85879F7C5180CDBD230017E7"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn4_0_a.dat",
      "length": 395408,
      "sha256": "0C9982277801271E2CF1A3F09940DC252ECE5C12EBBB5DDD8D17933FFDAA058C"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn4.dat",
      "length": 395408,
      "sha256": "0B7ABE3D6EC2F60699564E354E825A8B3BE1533C83B27D0E8D0B3132B1BFDF79"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn5_3.dat",
      "length": 439888,
      "sha256": "C7A7C540D5A362A6AE3CD58C80346BA22D66B8332622DEA8A4F02C48AE785D52"
    },
    {
      "relativePath": "B026175\\ativvaxy_vcn5.dat",
      "length": 437776,
      "sha256": "E6572B372DB1AEAAA09D39CDABE4FBE690CDEEBF8CCCB052A4A0FC2D12E47B49"
    },
    {
      "relativePath": "B026175\\ativvaxy_vg.dat",
      "length": 572112,
      "sha256": "D3107EE99F32408D0E5017A7B4597DC15305D0CCDE816FC9349902352ACBC7BE"
    },
    {
      "relativePath": "B026175\\ativvaxy_vg20_nd.dat",
      "length": 384800,
      "sha256": "B86D15BCE79A5CBD31B384CB86D56573BB1A0E002797E1487FB539323BDF6529"
    },
    {
      "relativePath": "B026175\\ativvaxy_vg20.dat",
      "length": 379200,
      "sha256": "B06A2F8E6110EF13B13D36C293FA7A793D1AA736CDD4258A89E45A25D111971A"
    },
    {
      "relativePath": "B026175\\ativvaxy_vi_nd.dat",
      "length": 324928,
      "sha256": "FB927ACC1C213597B63735BC776ABF08354884DAA2E11A5C19D9EC5BA9423C53"
    },
    {
      "relativePath": "B026175\\ativvaxy_vi.dat",
      "length": 325188,
      "sha256": "870622DCF18E92654E070D01666022D12938E24E537A15CB076E62D5BC335F96"
    },
    {
      "relativePath": "B026175\\ativvsva.dat",
      "length": 157144,
      "sha256": "E698410E1B8E5B2875AA8B4D01FE6E4F0BF354F40D92925C4E3503D7FD1EC208"
    },
    {
      "relativePath": "B026175\\ativvsvl.dat",
      "length": 204952,
      "sha256": "F35A4644D926183D38815207E338E7919CBDD2B1BDB8164074E47B74EA1CF150"
    },
    {
      "relativePath": "B026175\\detoured32.dll",
      "length": 14208,
      "sha256": "0A552A36656A65792AFA9B6AF07980C4AE723D740D2178EDE1243BCFF415F24D"
    },
    {
      "relativePath": "B026175\\detoured64.dll",
      "length": 14208,
      "sha256": "15917C56321C4DD50D7C446035F197B35FA451670E03BECFBD9DB1C30499F482"
    },
    {
      "relativePath": "B026175\\EEURestart.exe",
      "length": 531984,
      "sha256": "A2053227B7677C2E320BA08ADA2ECB4DAA53B97C079B4768AED06BC227B1427B"
    },
    {
      "relativePath": "B026175\\featuresync.dll",
      "length": 1138192,
      "sha256": "306FDED5CD70C4BFEFCB9D0FE4E59647925FF9926742C8CE56B13D8D83F40851"
    },
    {
      "relativePath": "B026175\\GameManager32.dll",
      "length": 488976,
      "sha256": "FE506CD64DF068F453C793464EFBFDB89A8423BCE767929D929886F419B820F0"
    },
    {
      "relativePath": "B026175\\GameManager64.dll",
      "length": 641040,
      "sha256": "8C46C5220E89630F7A8BA00BDA518D274688016D0A90E591DC6AD6DD7D5299FA"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_10_sy1_10.bin",
      "length": 373296,
      "sha256": "8696B1C3952A7BA6FA58497B4C5A38B3BB2EE7C53369AEF3D580BD86FD623F23"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_20_sy1_20.bin",
      "length": 373296,
      "sha256": "C1E25B983F0ED64621D448263B5A6B1638D97F3CFC9C21C736CA301F6BAFBD49"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_30_sy1_30.bin",
      "length": 373296,
      "sha256": "174F422D1888B0F12CE16F509CF31CF751C557624EB4A2E45C2E99EA00F0FF82"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_40_sy1_40.bin",
      "length": 373296,
      "sha256": "65D3532608FD7EF591F5748927318AA291F8A16D9ADDFEDF617BC2FF8FBBE082"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_50_sy1_50.bin",
      "length": 373296,
      "sha256": "3E6DDC01FD90203B4E5770126727C9B9626F44A6B0B5BC5F35F7497066AAB629"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_60_sy1_60.bin",
      "length": 373296,
      "sha256": "05141D10A1C55F4EA49090C5B1C9A4F7D54AE9A5DB8A4DB6F60D2789A9036825"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_70_sy1_70.bin",
      "length": 373296,
      "sha256": "4FE9E51115B4DB5CD024DB40C5850302A1F5F32A92FD99719C601A49CE7E4756"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_80_sy1_80.bin",
      "length": 373296,
      "sha256": "C865948EB7C35E16F360419CF2621B6C6CDA98A24D6795A90855900794A574D4"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx1_90_sy1_90.bin",
      "length": 373296,
      "sha256": "8EC6B810BCDC4FE0D376DFBD392AD02F2DDEBE3D4D3FE89BFF8068B0BEA84AEF"
    },
    {
      "relativePath": "B026175\\H9_EASU_sx2_00_sy2_00.bin",
      "length": 373296,
      "sha256": "084942A2723ECDC8E4CF713A8CED91E8A19AA4E3F3BF6171DB4F5DB7CF7974DA"
    },
    {
      "relativePath": "B026175\\libamdenc64.so",
      "length": 1662960,
      "sha256": "375ADC2E4B1183C6D98C4620C7DB4E05E6E38FABDF10D057799C1698A8BEDDA6"
    },
    {
      "relativePath": "B026175\\regamdcomp.exe",
      "length": 301584,
      "sha256": "82B4BA3278DD71E39FA3EA342ADA8C75CD7D97ACEFF026294788A1B69A0F2CAE"
    }
  ]
}
'@
        )
    }
    'lib\Build-Canonical-AmdGcfDat.ps1' = [ordered]@{
        SHA256 = '8941720F7A5E3B18C6482AE846B62BCBD7A85D8900F9A6FA5768515B20056206'
        Utf8Bom = $true
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$OfficialDat = Join-Path $SourceRoot 'B026175\amdgcf.dat'
$ExpectedOfficialHash = '740C379B33945AC60BA1C0A9386F48BAB894524018B1F5F9D2788D7E33585185'
$ExpectedCanonicalHash = 'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'
$OfficialReleaseVersion = '26.10.21.01-260615a-201589C-AMD-Software-Adrenalin-Edition'
$TargetReleaseVersion = '25.30.17.01-260108a-198040C-Lenovo'

if (-not (Test-Path -LiteralPath $OfficialDat -PathType Leaf)) {
    throw "Required official DAT not found: $OfficialDat"
}

$OutputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$OfficialHash = (
    Get-FileHash `
        -LiteralPath $OfficialDat `
        -Algorithm SHA256
).Hash

if ($OfficialHash -ne $ExpectedOfficialHash) {
    throw @"
Official DAT hash mismatch.
Expected: $ExpectedOfficialHash
Actual:   $OfficialHash
"@
}

if (-not ('AmdGcfMetroHash64DirectRepro' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;

public static class AmdGcfMetroHash64DirectRepro
{
    private const ulong K0 = 0xD6D018F5UL;
    private const ulong K1 = 0xA2AA033BUL;
    private const ulong K2 = 0x62992FC1UL;
    private const ulong K3 = 0x30BC5B29UL;

    private static ulong RotateRight(ulong value, int bits)
    {
        return (value >> bits) | (value << (64 - bits));
    }

    private static ulong ReadUInt64LE(byte[] data, int offset)
    {
        return
            ((ulong)data[offset]) |
            ((ulong)data[offset + 1] << 8) |
            ((ulong)data[offset + 2] << 16) |
            ((ulong)data[offset + 3] << 24) |
            ((ulong)data[offset + 4] << 32) |
            ((ulong)data[offset + 5] << 40) |
            ((ulong)data[offset + 6] << 48) |
            ((ulong)data[offset + 7] << 56);
    }

    private static uint ReadUInt32LE(byte[] data, int offset)
    {
        return
            ((uint)data[offset]) |
            ((uint)data[offset + 1] << 8) |
            ((uint)data[offset + 2] << 16) |
            ((uint)data[offset + 3] << 24);
    }

    private static ushort ReadUInt16LE(byte[] data, int offset)
    {
        return (ushort)(
            data[offset] |
            (data[offset + 1] << 8)
        );
    }

    public static ulong Compute(
        byte[] data,
        ulong seed,
        bool addLengthToInitialHash
    )
    {
        if (data == null)
        {
            throw new ArgumentNullException(nameof(data));
        }

        unchecked
        {
            int length = data.Length;
            int offset = 0;

            ulong hash = (seed + K2) * K0;

            if (addLengthToInitialHash)
            {
                hash += (ulong)length;
            }

            if (length >= 32)
            {
                ulong v0 = hash;
                ulong v1 = hash;
                ulong v2 = hash;
                ulong v3 = hash;

                int blockEnd = length - 32;

                while (offset <= blockEnd)
                {
                    v0 += ReadUInt64LE(data, offset) * K0;
                    offset += 8;
                    v0 = RotateRight(v0, 29) + v2;

                    v1 += ReadUInt64LE(data, offset) * K1;
                    offset += 8;
                    v1 = RotateRight(v1, 29) + v3;

                    v2 += ReadUInt64LE(data, offset) * K2;
                    offset += 8;
                    v2 = RotateRight(v2, 29) + v0;

                    v3 += ReadUInt64LE(data, offset) * K3;
                    offset += 8;
                    v3 = RotateRight(v3, 29) + v1;
                }

                v2 ^= RotateRight(
                    ((v0 + v3) * K0) + v1,
                    37
                ) * K1;

                v3 ^= RotateRight(
                    ((v1 + v2) * K1) + v0,
                    37
                ) * K0;

                v0 ^= RotateRight(
                    ((v0 + v2) * K0) + v3,
                    37
                ) * K1;

                v1 ^= RotateRight(
                    ((v1 + v3) * K1) + v2,
                    37
                ) * K0;

                hash += v0 ^ v1;
            }

            int remaining = length - offset;

            if (remaining >= 16)
            {
                ulong v0 =
                    hash +
                    (ReadUInt64LE(data, offset) * K2);

                offset += 8;

                v0 = RotateRight(v0, 29) * K3;

                ulong v1 =
                    hash +
                    (ReadUInt64LE(data, offset) * K2);

                offset += 8;

                v1 = RotateRight(v1, 29) * K3;

                v0 ^= RotateRight(v0 * K0, 21) + v1;
                v1 ^= RotateRight(v1 * K3, 21) + v0;

                hash += v1;
                remaining = length - offset;
            }

            if (remaining >= 8)
            {
                hash += ReadUInt64LE(data, offset) * K3;
                offset += 8;

                hash ^=
                    RotateRight(hash, 55) *
                    K1;

                remaining = length - offset;
            }

            if (remaining >= 4)
            {
                hash +=
                    (ulong)ReadUInt32LE(data, offset) *
                    K3;

                offset += 4;

                hash ^=
                    RotateRight(hash, 26) *
                    K1;

                remaining = length - offset;
            }

            if (remaining >= 2)
            {
                hash +=
                    (ulong)ReadUInt16LE(data, offset) *
                    K3;

                offset += 2;

                hash ^=
                    RotateRight(hash, 48) *
                    K1;

                remaining = length - offset;
            }

            if (remaining >= 1)
            {
                hash +=
                    (ulong)data[offset] *
                    K3;

                hash ^=
                    RotateRight(hash, 37) *
                    K1;
            }

            hash ^= RotateRight(hash, 28);
            hash *= K0;
            hash ^= RotateRight(hash, 29);

            return hash;
        }
    }

    public static byte[] ToBigEndianBytes(ulong value)
    {
        return new byte[]
        {
            (byte)(value >> 56),
            (byte)(value >> 48),
            (byte)(value >> 40),
            (byte)(value >> 32),
            (byte)(value >> 24),
            (byte)(value >> 16),
            (byte)(value >> 8),
            (byte)value
        };
    }
}
'@
            "'@"
@'
}

function Get-AmdGcfHeader {
    param(
        [Parameter(Mandatory)]
        [byte[]]$DatBytes,

        [Parameter(Mandatory)]
        [string]$ReleaseVersion
    )

    [byte[]]$RecordBytes = [byte[]]::new(
        $DatBytes.Length - 12
    )

    [Array]::Copy(
        $DatBytes,
        12,
        $RecordBytes,
        0,
        $RecordBytes.Length
    )

    [byte[]]$ReleaseBytes =
        [System.Text.Encoding]::ASCII.GetBytes(
            $ReleaseVersion
        )

    [byte[]]$HashInput = [byte[]]::new(
        $RecordBytes.Length +
        $ReleaseBytes.Length
    )

    [Array]::Copy(
        $RecordBytes,
        0,
        $HashInput,
        0,
        $RecordBytes.Length
    )

    [Array]::Copy(
        $ReleaseBytes,
        0,
        $HashInput,
        $RecordBytes.Length,
        $ReleaseBytes.Length
    )

    [uint64]$Digest =
        [AmdGcfMetroHash64DirectRepro]::Compute(
            $HashInput,
            0,
            $false
        )

    return [AmdGcfMetroHash64DirectRepro]::ToBigEndianBytes(
        $Digest
    )
}

function Get-HexString {
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes
    )

    return (
        $Bytes |
        ForEach-Object {
            $_.ToString('X2')
        }
    ) -join ' '
}

function Find-AmdGcfInsertionIndex {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[object]]$Records,

        [Parameter(Mandatory)]
        [int]$Key,

        [Parameter(Mandatory)]
        [int]$Value
    )

    for ($Index = 0; $Index -lt $Records.Count; $Index++) {
        if (
            $Records[$Index].Key -gt $Key -or
            (
                $Records[$Index].Key -eq $Key -and
                $Records[$Index].Value -gt $Value
            )
        ) {
            return $Index
        }
    }

    return $Records.Count
}

[byte[]]$OfficialBytes = [System.IO.File]::ReadAllBytes(
    $OfficialDat
)

[int]$OfficialCount = [BitConverter]::ToUInt32(
    $OfficialBytes,
    0
)

if ($OfficialCount -ne 223) {
    throw "Expected 223 official records; found $OfficialCount."
}

if ($OfficialBytes.Length -ne 681) {
    throw "Expected a 681-byte official DAT; found $($OfficialBytes.Length)."
}

[byte[]]$StoredOfficialHeader = [byte[]]::new(8)

[Array]::Copy(
    $OfficialBytes,
    4,
    $StoredOfficialHeader,
    0,
    8
)

[byte[]]$RecomputedOfficialHeader = Get-AmdGcfHeader `
    -DatBytes $OfficialBytes `
    -ReleaseVersion $OfficialReleaseVersion

$OfficialHeaderMatches = (
    [System.Linq.Enumerable]::SequenceEqual(
        [byte[]]$StoredOfficialHeader,
        [byte[]]$RecomputedOfficialHeader
    )
)

if (-not $OfficialHeaderMatches) {
    throw @"
MetroHash self-test failed against the official DAT.
Stored:     $(Get-HexString $StoredOfficialHeader)
Recomputed: $(Get-HexString $RecomputedOfficialHeader)
"@
}

$Records = [System.Collections.Generic.List[object]]::new()

for ($Index = 0; $Index -lt $OfficialCount; $Index++) {
    [int]$Position = 12 + (3 * $Index)

    [int]$StoredOffset = [BitConverter]::ToUInt16(
        $OfficialBytes,
        $Position
    )

    [int]$EffectiveKey = (
        $StoredOffset -
        $Position
    ) -band 0xFFFF

    $Records.Add(
        [pscustomobject]@{
            Key   = $EffectiveKey
            Value = [int]$OfficialBytes[$Position + 2]
        }
    )
}

$Initial15BF = @(
    $Records |
    Where-Object {
        $_.Key -eq 0x15BF
    }
)

$Initial15C8 = @(
    $Records |
    Where-Object {
        $_.Key -eq 0x15C8
    }
)

if ($Initial15BF.Count -ne 36) {
    throw "Expected 36 initial 0x15BF records; found $($Initial15BF.Count)."
}

if ($Initial15C8.Count -ne 16) {
    throw "Expected 16 initial 0x15C8 records; found $($Initial15C8.Count)."
}

if (
    @(
        $Records |
        Where-Object {
            $_.Key -eq 0x15BF -and
            $_.Value -eq 0x04
        }
    ).Count -ne 0
) {
    throw 'The official DAT already contains 0x15BF -> 0x04.'
}

if (
    @(
        $Records |
        Where-Object {
            $_.Key -eq 0x15C8 -and
            $_.Value -eq 0xC9
        }
    ).Count -ne 0
) {
    throw 'The official DAT already contains 0x15C8 -> 0xC9.'
}

[int]$FirstInsertionIndex = Find-AmdGcfInsertionIndex `
    -Records $Records `
    -Key 0x15BF `
    -Value 0x04

$FirstPrevious = $Records[$FirstInsertionIndex - 1]
$FirstNext = $Records[$FirstInsertionIndex]

if (
    $FirstPrevious.Key -ne 0x15BF -or
    $FirstPrevious.Value -ne 0x03 -or
    $FirstNext.Key -ne 0x15BF -or
    $FirstNext.Value -ne 0x05
) {
    throw 'Unexpected neighbors for the 0x15BF -> 0x04 insertion.'
}

$Records.Insert(
    $FirstInsertionIndex,
    [pscustomobject]@{
        Key   = 0x15BF
        Value = 0x04
    }
)

[int]$SecondInsertionIndex = Find-AmdGcfInsertionIndex `
    -Records $Records `
    -Key 0x15C8 `
    -Value 0xC9

$SecondPrevious = $Records[$SecondInsertionIndex - 1]
$SecondNext = $Records[$SecondInsertionIndex]

if (
    $SecondPrevious.Key -ne 0x15C8 -or
    $SecondPrevious.Value -ne 0xC8 -or
    $SecondNext.Key -ne 0x15C8 -or
    $SecondNext.Value -ne 0xD1
) {
    throw 'Unexpected neighbors for the 0x15C8 -> 0xC9 insertion.'
}

$Records.Insert(
    $SecondInsertionIndex,
    [pscustomobject]@{
        Key   = 0x15C8
        Value = 0xC9
    }
)

if ($Records.Count -ne 225) {
    throw "Expected 225 records after both insertions; found $($Records.Count)."
}

[byte[]]$NewDat = [byte[]]::new(
    12 + (3 * $Records.Count)
)

[byte[]]$CountBytes = [BitConverter]::GetBytes(
    [uint32]$Records.Count
)

[Array]::Copy(
    $CountBytes,
    0,
    $NewDat,
    0,
    4
)

for ($Index = 0; $Index -lt $Records.Count; $Index++) {
    [int]$Position = 12 + (3 * $Index)

    [int]$StoredOffset =
        $Records[$Index].Key +
        $Position

    if ($StoredOffset -gt 0xFFFF) {
        throw "Stored-offset overflow at record $Index."
    }

    [byte[]]$OffsetBytes = [BitConverter]::GetBytes(
        [uint16]$StoredOffset
    )

    $NewDat[$Position] = $OffsetBytes[0]
    $NewDat[$Position + 1] = $OffsetBytes[1]
    $NewDat[$Position + 2] = [byte]$Records[$Index].Value
}

[byte[]]$NewHeader = Get-AmdGcfHeader `
    -DatBytes $NewDat `
    -ReleaseVersion $TargetReleaseVersion

[Array]::Copy(
    $NewHeader,
    0,
    $NewDat,
    4,
    8
)

[System.IO.File]::WriteAllBytes(
    $OutputPath,
    $NewDat
)

$ResultHash = (
    Get-FileHash `
        -LiteralPath $OutputPath `
        -Algorithm SHA256
).Hash


$Final15BF = @(
    $Records |
    Where-Object {
        $_.Key -eq 0x15BF
    }
)

$Final15C8 = @(
    $Records |
    Where-Object {
        $_.Key -eq 0x15C8
    }
)

if ($ResultHash -ne $ExpectedCanonicalHash) {
    throw @"
Canonical DAT reconstruction failed.
Expected: $ExpectedCanonicalHash
Actual:   $ResultHash
Output:   $OutputPath
"@
}

[pscustomobject]@{
    OutputPath = $OutputPath
    Length = $NewDat.Length
    RecordCount = $Records.Count
    Header = Get-HexString $NewHeader
    Final15BFRecordCount = $Final15BF.Count
    Final15C8RecordCount = $Final15C8.Count
    SHA256 = $ResultHash
    ReproducedCanonical = $true
}
'@
        )
    }
    'lib\Build-Canonical-Inf.ps1' = [ordered]@{
        SHA256 = '8F258D6B731141B80D18D3C062FF04A1FF9504B210A85DD4B9998262258FD756'
        Utf8Bom = $true
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$OfficialInf = Join-Path $SourceRoot 'u0201589.inf'
$ExpectedOfficialHash = '97C64806E91AA2EB6F2B17A94369FBB884A8048ACD9A8F9FCD59155797AC4FA6'
$ExpectedCanonicalHash = '39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E'

if (-not (Test-Path -LiteralPath $OfficialInf -PathType Leaf)) {
    throw "Required official INF not found: $OfficialInf"
}

$OutputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Replace-ExactOnce {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$OldValue,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$NewValue,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $First = $Text.IndexOf(
        $OldValue,
        [System.StringComparison]::Ordinal
    )

    if ($First -lt 0) {
        throw "Required INF anchor not found: $Description"
    }

    $Second = $Text.IndexOf(
        $OldValue,
        $First + $OldValue.Length,
        [System.StringComparison]::Ordinal
    )

    if ($Second -ge 0) {
        throw "INF anchor was not unique: $Description"
    }

    return (
        $Text.Substring(0, $First) +
        $NewValue +
        $Text.Substring($First + $OldValue.Length)
    )
}

$OfficialHash = (
    Get-FileHash `
        -LiteralPath $OfficialInf `
        -Algorithm SHA256
).Hash

if ($OfficialHash -ne $ExpectedOfficialHash) {
    throw @"
Official INF hash mismatch.
Expected: $ExpectedOfficialHash
Actual:   $OfficialHash
"@
}

[byte[]]$OfficialBytes = [System.IO.File]::ReadAllBytes(
    $OfficialInf
)

if (
    $OfficialBytes.Length -ge 2 -and
    $OfficialBytes[0] -eq 0xFF -and
    $OfficialBytes[1] -eq 0xFE
) {
    throw 'The untouched official INF must not already be UTF-16.'
}

$Encoding1252 = [System.Text.Encoding]::GetEncoding(1252)
$Text = $Encoding1252.GetString($OfficialBytes)

# Preserve the historically validated mixed-newline output exactly.
$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue "CatalogFile=u0201589.cat`r`n" `
    -NewValue "CatalogFile=u0201589.cat`n" `
    -Description 'CatalogFile line ending'

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue "DriverVer=06/20/2026, 32.0.31021.1015`r`n" `
    -NewValue "DriverVer=07/02/2026,32.0.31021.1015`n" `
    -Description 'canonical DriverVer line'

$HardwareAnchor =
    '"%AMD15BF.1%" = ati2mtag_Phoenix, PCI\VEN_1002&DEV_15BF&SUBSYS_16771025&REV_C1' +
    "`r`n"

$HardwareLine =
    '"%AMD15BF.1%" = ati2mtag_Phoenix, PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04' +
    "`r`n"

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue $HardwareAnchor `
    -NewValue ($HardwareAnchor + $HardwareLine) `
    -Description 'Legion Go Phoenix hardware-ID insertion point'

$PhoenixStart = $Text.IndexOf(
    "[ati2mtag_Phoenix]`r`n",
    [System.StringComparison]::Ordinal
)

if ($PhoenixStart -lt 0) {
    throw 'The [ati2mtag_Phoenix] section was not found.'
}

$PhoenixEnd = $Text.IndexOf(
    "[ati2mtag_Strix]`r`n",
    $PhoenixStart,
    [System.StringComparison]::Ordinal
)

if ($PhoenixEnd -lt 0) {
    throw 'The [ati2mtag_Strix] section following Phoenix was not found.'
}

$Phoenix = $Text.Substring(
    $PhoenixStart,
    $PhoenixEnd - $PhoenixStart
)

$PhoenixDelReg = "DelReg = ati2mtag_RemoveDeviceSettings`r`n"

$Phoenix = Replace-ExactOnce `
    -Text $Phoenix `
    -OldValue $PhoenixDelReg `
    -NewValue (
        $PhoenixDelReg +
        "AddReg = LegionGo_26_6_2_OEM_Settings`r`n"
    ) `
    -Description 'Phoenix Legion Go OEM AddReg insertion point'

$CopyInfLines = @(
    "CopyINF = .\amdxe\amdxe.inf`r`n"
    "CopyINF = .\amdfendr\amdfendr.inf`r`n"
    "CopyINF = .\amdcp\amdcp.inf`r`n"
    "CopyINF = .\amdfdans\amdfdans.inf`r`n"
    "CopyINF = .\amdocl\amdocl.inf`r`n"
    "CopyINF = .\amdwin\amdwin-u0201589.inf`r`n"
    "CopyINF = .\amdogl\amdogl.inf`r`n"
    "CopyINF = .\amdvlk\amdvlk.inf`r`n"
    "CopyINF=amduw23e.inf`r`n"
)

foreach ($Line in $CopyInfLines) {
    $Phoenix = Replace-ExactOnce `
        -Text $Phoenix `
        -OldValue $Line `
        -NewValue '' `
        -Description ("Phoenix directive: {0}" -f $Line.Trim())
}

$Text = (
    $Text.Substring(0, $PhoenixStart) +
    $Phoenix +
    $Text.Substring($PhoenixEnd)
)

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue "[ati2mtag_Phoenix.Components]`r`n" `
    -NewValue (
        "[ati2mtag_Phoenix.Components]`r`n" +
        "AddComponent = AMDUWP,,AMDUWPComponent`r`n"
    ) `
    -Description 'AMDUWP AddComponent insertion'

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue "[FDANSComponent]`r`n" `
    -NewValue (
        "[AMDUWPComponent]`r`n" +
        "ComponentIDs=VID1002&PID0001`r`n" +
        "`r`n" +
        "[FDANSComponent]`r`n"
    ) `
    -Description 'AMDUWP component section insertion'

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue (
        'HKR,,ReleaseVersion,,"26.10.21.01-260615a-201589C-AMD-Software-Adrenalin-Edition"' +
        "`r`n"
    ) `
    -NewValue (
        'HKR,,ReleaseVersion,,"25.30.17.01-260108a-198040C-Lenovo"' +
        "`n"
    ) `
    -Description 'Lenovo ReleaseVersion line'

$ExpectedEnding = "[ATI.Mfg.NTamd64.6.3.1]`r`n"

if (
    -not $Text.EndsWith(
        $ExpectedEnding,
        [System.StringComparison]::Ordinal
    )
) {
    throw 'The official INF does not have the expected final section and CRLF.'
}

$OemSection = @(
    ''
    ''
    '[LegionGo_26_6_2_OEM_Settings]'
    'HKR,,DalFeatureEnablePsrSU,%REG_DWORD%,0'
    'HKR,,DalDisableZ10,%REG_DWORD%,1'
    'HKR,,EnableswGCFakeCGCG,%REG_DWORD%,1'
    'HKR,,DalEmbeddedIntegerScalingSupport,%REG_DWORD%,1'
    'HKR,,DalPSRFeatureEnable,%REG_DWORD%,0'
    'HKR,,DalWirelessDisplaySupport,%REG_DWORD%,1'
    'HKR,,DalDetectRequireHpdHigh,%REG_DWORD%,0'
    'HKR,,DisableFBCSupport,%REG_DWORD%,1'
    'HKR,,SmartDCDefMode,%REG_DWORD%,0'
    'HKR,,BDC7EDEA37E855EFFD36, %REG_BINARY%,59,79,07,9B'
    'HKR,,BDC7EDEA40E855EFFDFB, %REG_BINARY%,59,79,07,9B'
) -join "`r`n"

$Text += $OemSection

$ExpectedTextLength = 1080779

if ($Text.Length -ne $ExpectedTextLength) {
    throw @"
Unexpected reconstructed text length.
Expected: $ExpectedTextLength
Actual:   $($Text.Length)
"@
}

$Utf16LeBom = [System.Text.UnicodeEncoding]::new(
    $false,
    $true
)

[System.IO.File]::WriteAllText(
    $OutputPath,
    $Text,
    $Utf16LeBom
)


$ResultHash = (
    Get-FileHash `
        -LiteralPath $OutputPath `
        -Algorithm SHA256
).Hash

$OutputLength = (
    Get-Item -LiteralPath $OutputPath
).Length

if ($ResultHash -ne $ExpectedCanonicalHash) {
    throw @"
Canonical INF reconstruction failed.
Expected: $ExpectedCanonicalHash
Actual:   $ResultHash
Output:   $OutputPath
"@
}

[pscustomobject]@{
    OutputPath = $OutputPath
    Length = $OutputLength
    SHA256 = $ResultHash
    ReproducedCanonical = $true
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

$EmbeddedComponentLabels = @{
    'Phase-01-Check-Prerequisites.ps1' =
        'Phase 1 prerequisite checker'
    'Phase-02-Verify-Extract-And-Audit-AMD-Source.ps1' =
        'Phase 2 AMD source verifier and extractor'
    'Phase-03-Build-And-Verify-Driver-Package.ps1' =
        'Phase 3 corrected driver-package builder'
    'Phase-04-Create-And-Sign-Local-Catalog.ps1' =
        'Phase 4 local catalog and signing component'
    'Phase-05-Prepare-Test-Signing.ps1' =
        'Phase 5 Test Signing preparation component'
    'data\Canonical-Unchanged-Files.json' =
        'Canonical unchanged-file manifest'
    'lib\Build-Canonical-AmdGcfDat.ps1' =
        'Canonical amdgcf.dat builder'
    'lib\Build-Canonical-Inf.ps1' =
        'Corrected INF builder'
    'lib\Security-Hardening.ps1' =
        'Security hardening library'
}

Write-Host ''
Write-Host 'Legion Go AMD 26.6.2 Toolkit' -ForegroundColor White
Write-Host 'Script 1 of 4: Prepare and sign the driver package' `
    -ForegroundColor White
Write-Host ''
Write-Host 'Normal run count: 2 unless Test Signing is already active'
Write-Host 'Installer source: User-supplied local AMD installer'
Write-Host 'Embedded payload format: Readable plain text'
Write-Host 'Network download: Disabled'
Write-Host 'AMD EULA acceptance by toolkit: Disabled'
Write-Host 'Dependency installation: Confirmation required when needed'
Write-Host 'Firmware/Windows restart: Confirmation required'
Write-Host 'Display-driver installation: Not performed by Script 1'
Write-Host "State directory: $StateRoot"
Write-Host "Workspace:       $WorkspaceRoot"
Write-Host ''

Write-Host '=== VERIFY EMBEDDED WORKFLOW COMPONENTS ===' `
    -ForegroundColor White

New-Item -ItemType Directory -Path $InternalRoot -Force | Out-Null

foreach ($RelativePath in $EmbeddedPayload.Keys) {
    $Entry = $EmbeddedPayload[$RelativePath]
    $Destination = Join-Path $InternalRoot $RelativePath
    $NeedsWrite = $true

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $ExistingHash = Get-SHA256 -LiteralPath $Destination

        if ($ExistingHash -eq [string]$Entry.SHA256) {
            $NeedsWrite = $false
        }
    }

    if ($NeedsWrite) {
        $Bytes = Convert-PlainTextPayloadToBytes -Entry $Entry
        Write-AtomicBytes -Bytes $Bytes -LiteralPath $Destination
    }

    $WrittenHash = Get-SHA256 -LiteralPath $Destination

    if ($WrittenHash -ne [string]$Entry.SHA256) {
        throw @"
Embedded workflow-component verification failed.
File:     $RelativePath
Expected: $($Entry.SHA256)
Actual:   $WrittenHash
"@
    }

    $ComponentLabel = $EmbeddedComponentLabels[$RelativePath]

    if ([string]::IsNullOrWhiteSpace([string]$ComponentLabel)) {
        $ComponentLabel = $RelativePath
    }

    Write-Host "[PASS] $ComponentLabel"
}

$Phase01Path =
    Join-Path $InternalRoot 'Phase-01-Check-Prerequisites.ps1'
$Phase02Path =
    Join-Path $InternalRoot 'Phase-02-Verify-Extract-And-Audit-AMD-Source.ps1'
$Phase03Path =
    Join-Path $InternalRoot 'Phase-03-Build-And-Verify-Driver-Package.ps1'
$Phase04Path =
    Join-Path $InternalRoot 'Phase-04-Create-And-Sign-Local-Catalog.ps1'
$Phase05Path =
    Join-Path $InternalRoot 'Phase-05-Prepare-Test-Signing.ps1'

$Phase01Arguments = @(
    '-StateRoot'
    $StateRoot
    '-WorkspaceRoot'
    $WorkspaceRoot
)

Invoke-EmbeddedPhase `
    -DisplayName 'PHASE 1 — CHECK PREREQUISITES' `
    -HostPath $WindowsPowerShell `
    -ScriptPath $Phase01Path `
    -PhaseArguments $Phase01Arguments

$PrerequisiteStatePath = Join-Path $StateRoot 'prerequisite-state.json'
$PrerequisiteState = Read-JsonFile -LiteralPath $PrerequisiteStatePath

if ($null -eq $PrerequisiteState -or -not [bool]$PrerequisiteState.AllPassed) {
    throw 'Phase 1 did not leave a passing prerequisite-state.json.'
}

$PowerShell7Path =
    [string]$PrerequisiteState.Dependencies.PowerShell7.Path

if (
    [string]::IsNullOrWhiteSpace($PowerShell7Path) -or
    -not (Test-Path -LiteralPath $PowerShell7Path -PathType Leaf)
) {
    throw (
        'Phase 1 passed, but its recorded PowerShell 7 executable is missing.'
    )
}

if (-not (Test-Phase03Complete) -and -not (Test-Phase04Complete)) {
    if (-not (Test-Phase02Complete)) {
        $Phase02Arguments = @(
            '-StateRoot'
            $StateRoot
            '-WorkspaceRoot'
            $WorkspaceRoot
            '-AmdInstallerPath'
            $AdjacentInstallerPath
        )

        Invoke-EmbeddedPhase `
            -DisplayName 'PHASE 2 — VERIFY AND EXTRACT AMD SOURCE' `
            -HostPath $WindowsPowerShell `
            -ScriptPath $Phase02Path `
            -PhaseArguments $Phase02Arguments

        if (-not (Test-Phase02Complete)) {
            throw 'Phase 2 did not leave a passing source-package-audit.json.'
        }
    }
    else {
        Write-Host ''
        Write-Host '[PASS] Phase 2 output is already complete; skipping source extraction.' `
            -ForegroundColor Green
    }
}

if (-not (Test-Phase04Complete)) {
    if (-not (Test-Phase03Complete)) {
        Invoke-EmbeddedPhase `
            -DisplayName 'PHASE 3 — BUILD CORRECTED DRIVER PACKAGE' `
            -HostPath $PowerShell7Path `
            -ScriptPath $Phase03Path `
            -PhaseArguments @(
                '-StateRoot'
                $StateRoot
                '-BuildBase'
                $WorkspaceRoot
            )

        if (-not (Test-Phase03Complete)) {
            throw 'Phase 3 did not leave a verified 125-file package.'
        }
    }
    else {
        Write-Host ''
        Write-Host '[PASS] Phase 3 output is already complete; skipping package rebuild.' `
            -ForegroundColor Green
    }

    Invoke-EmbeddedPhase `
        -DisplayName 'PHASE 4 — CREATE AND SIGN LOCAL CATALOG' `
        -HostPath $WindowsPowerShell `
        -ScriptPath $Phase04Path `
        -PhaseArguments @(
            '-BuildBase'
            $WorkspaceRoot
            '-WorkflowRoot'
            $StateRoot
            '-VerificationResultPath'
            (Join-Path $StateRoot 'payload-verification.json')
        )

    if (-not (Test-Phase04Complete)) {
        throw 'Phase 4 did not leave a valid canonical signing state.'
    }
}
else {
    Write-Host ''
    Write-Host '[PASS] Phases 2-4 are already complete; reusing the verified source, package, and signing results.' `
        -ForegroundColor Green
}

$Phase05Arguments = @(
    '-VerificationResultPath'
    (Join-Path $StateRoot 'payload-verification.json')
    '-CatalogSigningStatePath'
    (Join-Path $StateRoot 'catalog-signing-state.json')
)

Invoke-EmbeddedPhase `
    -DisplayName 'PHASE 5 — PREPARE TEST SIGNING' `
    -HostPath $WindowsPowerShell `
    -ScriptPath $Phase05Path `
    -PhaseArguments $Phase05Arguments

$BootResultPath = Join-Path $StateRoot 'boot-preparation-result.json'
$BootResult = Read-JsonFile -LiteralPath $BootResultPath

if ($null -eq $BootResult) {
    throw 'Phase 5 did not leave boot-preparation-result.json.'
}

Write-Host ''
Write-Host ('=' * 72) -ForegroundColor White

if (
    [bool]$BootResult.ReadyForDriverInstall -and
    [string]$BootResult.Phase -eq 'Ready-For-Driver-Install'
) {
    Write-Host 'SCRIPT 1 PASS: True' -ForegroundColor Green
    Write-Host 'Ready for Script 2: True' -ForegroundColor Green
    Write-Host "Result file: $BootResultPath"
}
else {
    Write-Host 'SCRIPT 1 PASS: Pending required restart' `
        -ForegroundColor Yellow
    Write-Host "Current phase: $($BootResult.Phase)"

    switch ([string]$BootResult.Phase) {
        'Awaiting-Manual-Secure-Boot-Disable' {
            Write-Host (
                'Next action: Disable Secure Boot in UEFI, start Windows, ' +
                'then run Script 1 again.'
            ) -ForegroundColor Yellow
        }

        'Awaiting-TestSigning-On-Reboot' {
            Write-Host (
                'Next action: Restart Windows, then run Script 1 again.'
            ) -ForegroundColor Yellow
        }

        default {
            Write-Host (
                'Next action: Complete the required restart, then run ' +
                'Script 1 again.'
            ) -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'Exact rerun command:' -ForegroundColor Yellow
    Write-Host (
        'PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f
        $PSCommandPath
    ) -ForegroundColor Yellow
}

Write-Host ('=' * 72) -ForegroundColor White
