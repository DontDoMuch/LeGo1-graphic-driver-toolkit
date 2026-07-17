#requires -Version 5.1
<#
.SYNOPSIS
    Legion Go AMD 26.6.4 Toolkit — Script 1 of 4.

    Verifies the required environment, builds the corrected display-driver
    package, signs it locally, and prepares Windows Test Signing.

.DESCRIPTION
    This script supports the original Lenovo Legion Go GPU identity:

      PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA

    Place one official AMD 26.6.4 Windows 11 installer beside this script.

    The toolkit discovers a valid AMD-signed 26.6.4 container, records its
    actual identity, extracts it, and accepts it only when the exact target
    display source payload is present. It does not download AMD or Lenovo
    software and does not accept AMD's EULA on the user's behalf.

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
      C:\ProgramData\LegionGo-AMD-26.6.4

    Workspace:
      C:\AMD\LegionGo-26.6.4

    This is an independent, unofficial compatibility toolkit. It is not
    affiliated with, authorized by, sponsored by, or endorsed by AMD, Lenovo,
    or Microsoft.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StateRoot = Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'
$WorkspaceRoot = Join-Path $env:SystemDrive 'AMD\LegionGo-26.6.4'
$InternalRoot = Join-Path $StateRoot 'Toolkit-Script-01\Internal'
$WindowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

$ReferenceInstallerName =
    'whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe'
$ExpectedInstallerVersion = '26.6.4.0'

function Resolve-AdjacentAmdInstaller {
    $Candidates = @(
        Get-ChildItem `
            -LiteralPath $PSScriptRoot `
            -Filter '*.exe' `
            -File `
            -ErrorAction SilentlyContinue |
            ForEach-Object {
                $Signature = Get-AuthenticodeSignature -LiteralPath $_.FullName
                $FileVersion = [string]$_.VersionInfo.FileVersion
                $ProductVersion = [string]$_.VersionInfo.ProductVersion
                $Signer = if ($Signature.SignerCertificate) {
                    [string]$Signature.SignerCertificate.Subject
                }
                else {
                    ''
                }

                if (
                    $Signature.Status -eq 'Valid' -and
                    $Signer -match '^CN=Advanced Micro Devices,' -and
                    $FileVersion -eq $ExpectedInstallerVersion -and
                    $ProductVersion -eq $ExpectedInstallerVersion
                ) {
                    [pscustomobject]@{
                        Item = $_
                        SignatureStatus = [string]$Signature.Status
                        Signer = $Signer
                        FileVersion = $FileVersion
                        ProductVersion = $ProductVersion
                        ReferenceNameMatch = [bool](
                            $_.Name -ieq $ReferenceInstallerName
                        )
                    }
                }
            }
    )

    if ($Candidates.Count -eq 0) {
        throw @"
No compatible official AMD 26.6.4 Windows 11 installer was found beside this
script.

Place one AMD-signed installer for version 26.6.4.0 beside the toolkit scripts
and run Script 1 again. The validated reference filename is:

$ReferenceInstallerName

The outer EXE name, length, and hash are not the target contract. Script 1 will
extract the selected container and require the exact validated 26.6.4 display
source payload before continuing.
"@
    }

    $Preferred = @(
        $Candidates |
            Sort-Object `
                @{Expression={ if ($_.ReferenceNameMatch) { 0 } else { 1 } }},
                @{Expression={$_.Item.FullName.Length}},
                @{Expression={$_.Item.FullName}}
    )

    if (
        $Candidates.Count -gt 1 -and
        @($Candidates | Where-Object ReferenceNameMatch).Count -ne 1
    ) {
        $Observed = @(
            $Candidates |
                ForEach-Object { $_.Item.FullName }
        ) -join "`r`n"

        throw @"
More than one compatible AMD 26.6.4 installer was found beside Script 1, and
there is no single canonical reference filename to select deterministically.
Leave only one installer beside the toolkit and rerun Script 1.

Observed candidates:
$Observed
"@
    }

    return $Preferred[0]
}

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

$ResolvedInstaller = Resolve-AdjacentAmdInstaller
$AdjacentInstallerPath = $ResolvedInstaller.Item.FullName

Write-Host (
    'Selected AMD 26.6.4 installer container: ' +
    $AdjacentInstallerPath
)
Write-Host "Installer signer: $($ResolvedInstaller.Signer)"
Write-Host (
    'Canonical reference filename: ' +
    $ResolvedInstaller.ReferenceNameMatch
)

$EmbeddedPayload = [ordered]@{
    # Exact Public Beta v2.0 components stored as readable plain text.
    'Phase-01-Check-Prerequisites.ps1' = [ordered]@{
        SHA256 = 'CA466464EF4FC7B86C76D5C333901826887D3C12EBB63FFDB2C64C9A97BC4584'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 1 prerequisite checker for Script 1 of the Legion Go AMD 26.6.4 Toolkit.

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
        -WorkspaceRoot 'D:\LegionGo-AMD-26.6.4'
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StateRoot = (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceRoot = (Join-Path $env:SystemDrive 'AMD\LegionGo-26.6.4'),

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
$ProjectName = 'Legion Go AMD 26.6.4'
$ScriptVersion = '1.0'
$RequiredGpuHardwareIdPrefix = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA'
$MinimumWindowsBuild = 22000
$MinimumPowerShellVersion = [version]'7.4.0'
$PreferredFallbackWindowsKitBuild = 28000
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

    $versionDirectories = foreach (
        $directory in Get-ChildItem `
            -LiteralPath $binRoot `
            -Directory `
            -ErrorAction SilentlyContinue
    ) {
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
            Sort-Object Version -Descending
    )

    foreach ($entry in $versionDirectories) {
        # Use paired tools from the same Windows Kit version. A version is
        # accepted by capability, not by a fixed minimum build number.
        $inf2Cat = Join-Path `
            $entry.Directory.FullName `
            'x86\Inf2Cat.exe'

        $signTool = Join-Path `
            $entry.Directory.FullName `
            'x64\signtool.exe'

        $pairExists = (
            (Test-Path -LiteralPath $inf2Cat -PathType Leaf) -and
            (Test-Path -LiteralPath $signTool -PathType Leaf)
        )

        if (-not $pairExists) {
            continue
        }

        $inf2CatTest = Test-ToolCommand `
            -Path $inf2Cat `
            -Arguments @('/?') `
            -ExpectedPattern 'Inf2Cat'

        $signToolTest = Test-ToolCommand `
            -Path $signTool `
            -Arguments @('/?') `
            -ExpectedPattern 'SignTool'

        if ($inf2CatTest.Success -and $signToolTest.Success) {
            return [pscustomobject]@{
                KitVersion   = $entry.Version
                Inf2CatPath  = [string]$inf2Cat
                SignToolPath = [string]$signTool
                Inf2CatTest  = $inf2CatTest
                SignToolTest = $signToolTest
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

    $inf2CatTest = if ($kitPair) {
        $kitPair.Inf2CatTest
    }
    else {
        $null
    }

    $signToolTest = if ($kitPair) {
        $kitPair.SignToolTest
    }
    else {
        $null
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
            MatchesPreferredFallbackBuild = [bool](
                $kitPair -and
                $kitPair.KitVersion.Build -ge $PreferredFallbackWindowsKitBuild
            )
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
            $Dependencies.WindowsKit.Inf2CatWorks -and
            $Dependencies.WindowsKit.SignToolWorks
        )
        Detail = $(if ($Dependencies.WindowsKit.Present) {
            "Kit $($Dependencies.WindowsKit.KitVersion); Inf2Cat=$($Dependencies.WindowsKit.Inf2CatPath); SignTool=$($Dependencies.WindowsKit.SignToolPath)"
        } else {
            "No functional paired x86 Inf2Cat and x64 SignTool installation was found"
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
        $dependencies.WindowsKit.Inf2CatWorks -and
        $dependencies.WindowsKit.SignToolWorks
    ) {
        Write-Status PASS "Windows Kit $($dependencies.WindowsKit.KitVersion)"
        Write-Status PASS "Inf2Cat: $($dependencies.WindowsKit.Inf2CatPath)"
        Write-Status PASS "SignTool: $($dependencies.WindowsKit.SignToolPath)"
    }
    else {
        Write-Status FAIL 'A functional paired x86 Inf2Cat and x64 SignTool installation was not found'
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
            PreferredFallbackWindowsKitBuild = $PreferredFallbackWindowsKitBuild
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
        SHA256 = '3C73BF3614CF8169746797ED63FC1E478E187965B85A95F915A18D4BB0639DF9'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 2 source verification, extraction, and identity audit for Script 1
    of the Legion Go AMD 26.6.4 Toolkit.

.DESCRIPTION
    Consumes the prerequisite-state.json written by Phase 1 and requires the
    user-supplied official AMD 26.6.4 Windows 11 installer selected by the
    wrapper. It verifies the container's AMD signature and release version,
    records its actual identity, extracts it into a unique project-controlled
    workspace with 7-Zip, and audits the exact WT6A_INF target source needed by
    the remaining build and signing phases.

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
    Required local path to the AMD-signed 26.6.4.0 source container selected
    by the wrapper. The extracted target payload, not one outer EXE identity,
    controls final acceptance.

.PARAMETER StateRoot
    Persistent project state directory created by Phase 1.

.PARAMETER WorkspaceRoot
    Optional workspace override. When omitted, Phase 1's verified workspace is
    used.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
      .\Phase-02-Verify-Extract-And-Audit-AMD-Source.ps1 `
      -AmdInstallerPath 'D:\Downloads\whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AmdInstallerPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StateRoot = (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'),

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

# The outer AMD EXE is an extraction container. Its actual identity is recorded,
# while the exact extracted target payload remains the release contract.
$ProjectName = 'Legion Go AMD 26.6.4'
$ScriptVersion = '1.0'

$ReferenceInstallerFileName =
    'whql-amd-software-adrenalin-edition-26.6.4-win11-b.exe'
$ReferenceInstallerLength = [int64]890946264
$ReferenceInstallerSha256 =
    'E83A1B0E0F62BC7B171D5CA1F5EA38A12A3F9C221F5386853937645A66AD9C29'
$ReferenceInstallerSignerThumbprint =
    '33D35682079E201671B738B7209B4586103BC271'

$ExpectedInstallerVersion = '26.6.4.0'
$ExpectedInstallerSignerSubjectPattern =
    '^CN=Advanced Micro Devices,'

# Exact functional 26.6.4 WT6A_INF identities. The total source-tree
# count is reference telemetry because unrelated extra files are excluded by
# the canonical 123-file manifest and exact output verification.
$ReferenceDisplaySourceFileCount = 194

$ExpectedOfficialInfSha256 =
    '25F6724F57BA8CC9CF9C54EE6E6EF0DAF257F38ED0303B3F7227A40E69E9F6A1'

$ExpectedOfficialCatalogSha256 =
    'F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C'

$ExpectedKernelSha256 =
    '3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F'

$ExpectedAmdgcfSha256 =
    '6552B360432EE95B3C85ADD28CB2551BBFB2497C6569D13378F750EF06527724'

$ExpectedAtiicdxxSha256 =
    'DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F'

$ReferenceSourceCcc2Length = [int64]242564056
$ReferenceSourceCcc2Sha256 =
    '391DE7F9095843794B25243245F4BB324694CE2D2C67FBF4F33C63CCA0F64954'

$RequiredGpuHardwareId =
    'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA'

$ExpectedDriverVersion = '32.0.31021.5001'

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
The required AMD 26.6.4 installer was not found at the local path supplied by
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

    $referenceInstallerIdentityMatch = [bool](
        $installerItem.Name -ieq $ReferenceInstallerFileName -and
        [int64]$installerItem.Length -eq $ReferenceInstallerLength -and
        $installerHash -eq $ReferenceInstallerSha256 -and
        $signerThumbprint -eq $ReferenceInstallerSignerThumbprint
    )

    $installerChecks = @(
        [pscustomobject]@{
            Name   = 'Authenticode status'
            Pass   = [bool]($installerSignature.Status -eq 'Valid')
            Detail = [string]$installerSignature.Status
        }
        [pscustomobject]@{
            Name   = 'AMD signer subject'
            Pass   = [bool](
                $signerSubject -match $ExpectedInstallerSignerSubjectPattern
            )
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

    Write-Status INFO "Installer name: $($installerItem.Name)"
    Write-Status INFO "Installer length: $($installerItem.Length)"
    Write-Status INFO "Installer SHA-256: $installerHash"
    Write-Status INFO "Installer signer thumbprint: $signerThumbprint"
    Write-Status INFO (
        'Canonical reference container identity match: ' +
        $referenceInstallerIdentityMatch
    )

    if (@($installerChecks | Where-Object { -not $_.Pass }).Count -gt 0) {
        throw (
            'The selected AMD installer is not a valid AMD-signed 26.6.4.0 ' +
            'container. Extraction was not attempted.'
        )
    }

    Write-Host ''
    Write-Host '=== EXTRACT VERIFIED AMD PACKAGE ===' -ForegroundColor White
    $sourceRoot = Join-Path $WorkspaceRoot "Source-$runId"
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

    $displaySourceReferenceCountMatch = [bool](
        $displaySourceFileCount -eq $ReferenceDisplaySourceFileCount
    )

    if ($displaySourceReferenceCountMatch) {
        Write-Status PASS (
            'WT6A_INF source file count matches the validated reference: ' +
            $displaySourceFileCount
        )
    }
    else {
        Write-Status INFO (
            'WT6A_INF source file count differs from the validated reference. ' +
            "Reference=$ReferenceDisplaySourceFileCount; " +
            "Actual=$displaySourceFileCount. " +
            'The exact functional source identities and canonical manifest ' +
            'remain mandatory; unrelated extra files are ignored.'
        )
    }

    Write-Host ''
    Write-Host '=== AUDIT EXACT DISPLAY SOURCE PACKAGE ===' -ForegroundColor White

    $criticalFiles = @(
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\u0202082.inf' -ExpectedSha256 $ExpectedOfficialInfSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\u0202082.cat' -ExpectedSha256 $ExpectedOfficialCatalogSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026218\amdkmdag.sys' -ExpectedSha256 $ExpectedKernelSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026218\amdgcf.dat' -ExpectedSha256 $ExpectedAmdgcfSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026218\atiicdxx.dat' -ExpectedSha256 $ExpectedAtiicdxxSha256
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\B026218\ccc2_install.exe'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\amdwin\amdwin-u0202082.inf'
        Get-FileIdentity -Root $sourceRoot -RelativePath 'Packages\Drivers\Display\WT6A_INF\amdwin\amdwin-u0202082.cat'
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

    $sourceInfPath = Join-Path $sourceRoot 'Packages\Drivers\Display\WT6A_INF\u0202082.inf'
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

    $sourceCcc2Path = Join-Path $sourceRoot 'Packages\Drivers\Display\WT6A_INF\B026218\ccc2_install.exe'
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

    $sourceCcc2ReferenceMatch = [bool](
        $sourceCcc2Hash -eq $ReferenceSourceCcc2Sha256 -and
        (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) -and
        [int64](Get-Item -LiteralPath $sourceCcc2Path).Length -eq
            $ReferenceSourceCcc2Length
    )
    $sourceCcc2Compatible = [bool](
        (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) -and
        $sourceCcc2Signature -and
        $sourceCcc2Signature.Status -eq 'Valid' -and
        $sourceCcc2Signature.SignerCertificate -and
        $sourceCcc2Signature.SignerCertificate.Subject -match
            '^CN=Advanced Micro Devices,'
    )

    $sourceCcc2Identity = [pscustomobject]@{
        Path                    = $sourceCcc2Path
        Exists                  = [bool](Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf)
        Length                  = $(if (Test-Path -LiteralPath $sourceCcc2Path -PathType Leaf) { [int64](Get-Item -LiteralPath $sourceCcc2Path).Length } else { $null })
        SHA256                  = $sourceCcc2Hash
        ReferenceSHA256         = $ReferenceSourceCcc2Sha256
        ReferenceLength         = $ReferenceSourceCcc2Length
        ReferenceIdentityMatch  = $sourceCcc2ReferenceMatch
        CompatibleExtractionWrapper = $sourceCcc2Compatible
        SignatureStatus         = $(if ($sourceCcc2Signature) { [string]$sourceCcc2Signature.Status } else { $null })
        SignerSubject           = $(if ($sourceCcc2Signature -and $sourceCcc2Signature.SignerCertificate) { [string]$sourceCcc2Signature.SignerCertificate.Subject } else { $null })
        IncludedInDriverPackage = $false
    }

    if ($sourceCcc2Compatible) {
        Write-Status PASS (
            'AMD-signed ccc2 extraction wrapper accepted; actual identity ' +
            "recorded. ReferenceIdentityMatch=$sourceCcc2ReferenceMatch"
        )
    }
    else {
        throw (
            'The separate ccc2_install.exe is missing or does not have a ' +
            'valid AMD Authenticode signature.'
        )
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
            ReferenceName            = $ReferenceInstallerFileName
            ActualName               = $installerItem.Name
            FullName                 = $installerItem.FullName
            Length                   = [int64]$installerItem.Length
            SHA256                   = $installerHash
            SignatureStatus          = [string]$installerSignature.Status
            SignerSubject            = $signerSubject
            SignerThumbprint         = $signerThumbprint
            FileVersion              = $installerVersion
            ProductVersion           = $productVersion
            CompatibleSignedContainer = $true
            ReferenceIdentityMatch   = $referenceInstallerIdentityMatch
        }
        Paths = [ordered]@{
            StateRoot      = [System.IO.Path]::GetFullPath($StateRoot)
            WorkspaceRoot  = $WorkspaceRoot
            ExtractionRoot = $sourceRoot
            SourceRoot     = $displaySourceRoot
            OfficialDisplayRoot = $displaySourceRoot
            OfficialCatalogPath = (
                Join-Path $displaySourceRoot 'u0202082.cat'
            )
            OfficialCcc2Path = (
                Join-Path $displaySourceRoot 'B026218\ccc2_install.exe'
            )
            PrerequisiteState = $prerequisiteStatePath
            ScriptPath     = $PSCommandPath
            LogPath        = $logPath
            ExtractStdOut  = $extractResult.StdOutPath
            ExtractStdErr  = $extractResult.StdErrPath
        }
        Extraction = [ordered]@{
            SevenZipPath                   = $sevenZipPath
            ExitCode                       = $extractResult.ExitCode
            ExtractionFileCount            = $sourceFileCount
            DisplaySourceFileCount         = $displaySourceFileCount
            ReferenceDisplaySourceFileCount = $ReferenceDisplaySourceFileCount
            DisplaySourceReferenceCountMatch = $displaySourceReferenceCountMatch
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
        SHA256 = '235DAEC8D793C56FCC00BB0F776541EF81B71895C6D51816FBA7840EBB376508'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 7.2

<#
Phase 3 of Script 1 in the Legion Go AMD 26.6.4 Toolkit.

Consumes the exact official AMD 26.6.4 "-b" WT6A_INF source audited by
Phase 2, reproduces the canonical 125-file unsigned Legion Go driver package,
and writes payload-verification.json for Phase 4 and Script 2.

The unsigned driver package contains:
  - 123 byte-for-byte official AMD files
  - deterministically rebuilt u0202082.inf
  - deterministically rebuilt B026218\amdgcf.dat

It intentionally does not contain:
  - u0202082.cat
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
        (Join-Path $env:ProgramData 'LegionGo-AMD-26.6.4'),

    [string]$SourceAuditPath,

    [string]$SourceRoot,

    [string]$OutputRoot,

    [string]$BuildBase = 'C:\AMD\LegionGo-26.6.4'
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
Set-StrictMode -Version Latest

# Reference count for the fully validated source container. It is
# telemetry only; exact required source files and exact output remain enforced.
$ReferenceOfficialSourceFileCount = 194
$ExpectedUnsignedFileCount = 125
$ExpectedUnchangedFileCount = 123

$ExpectedOfficialInfHash =
    '25F6724F57BA8CC9CF9C54EE6E6EF0DAF257F38ED0303B3F7227A40E69E9F6A1'

$ExpectedCanonicalInfHash =
    '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'

$ExpectedOfficialDatHash =
    '6552B360432EE95B3C85ADD28CB2551BBFB2497C6569D13378F750EF06527724'

$ExpectedCanonicalDatHash =
    'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'

$ExpectedOfficialCatalogHash =
    'F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C'

$ReferenceCcc2Hash =
    '391DE7F9095843794B25243245F4BB324694CE2D2C67FBF4F33C63CCA0F64954'

$ReferenceCcc2Length = [int64]242564056

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataManifestPath =
    Join-Path $ScriptRoot 'data\Canonical-Unchanged-Files.json'
$InfBuilderPath =
    Join-Path $ScriptRoot 'lib\Build-Canonical-Inf.ps1'
$DatBuilderPath =
    Join-Path $ScriptRoot 'lib\Build-Canonical-AmdGcfDat.ps1'

$ExpectedBuilderAssetHashes = [ordered]@{
    'data\Canonical-Unchanged-Files.json' =
        '9E3CD19EC26B0D3A6B115EE688DD893F26C5201AD835D442CE33F080FE5F6196'

    'lib\Build-Canonical-AmdGcfDat.ps1' =
        '2AA4145BA26FD88F14BB160C6B8B73EFE2E5699D68E373B2DE505A95153E8B6B'

    'lib\Build-Canonical-Inf.ps1' =
        '0175648198DCF78FCD2C4E2A621BA1E2FC04A5C042CD113185238D01671BEDAC'
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

    $OfficialSourceReferenceCountMatch = [bool](
        $OfficialFiles.Count -eq $ReferenceOfficialSourceFileCount
    )

    if ($OfficialSourceReferenceCountMatch) {
        Write-Host (
            '[PASS] Official source file count matches the validated reference: ' +
            $OfficialFiles.Count
        )
    }
    else {
        Write-Host (
            '[INFO] Official source file count differs from the validated ' +
            'reference. Reference=' + $ReferenceOfficialSourceFileCount +
            '; Actual=' + $OfficialFiles.Count +
            '. Exact manifest files and exact package output remain mandatory.'
        )
    }

    $OfficialInfPath =
        Join-Path $ResolvedSourceRoot 'u0202082.inf'
    $OfficialDatPath =
        Join-Path $ResolvedSourceRoot 'B026218\amdgcf.dat'
    $OfficialCatalogPath =
        Join-Path $ResolvedSourceRoot 'u0202082.cat'
    $OfficialCcc2Path =
        Join-Path $ResolvedSourceRoot 'B026218\ccc2_install.exe'

    [void](Assert-FileHash `
        -LiteralPath $OfficialInfPath `
        -ExpectedHash $ExpectedOfficialInfHash `
        -Label 'Official u0202082.inf')

    [void](Assert-FileHash `
        -LiteralPath $OfficialDatPath `
        -ExpectedHash $ExpectedOfficialDatHash `
        -Label 'Official B026218\amdgcf.dat')

    [void](Assert-FileHash `
        -LiteralPath $OfficialCatalogPath `
        -ExpectedHash $ExpectedOfficialCatalogHash `
        -Label 'Official Microsoft-signed u0202082.cat')

    if (-not (Test-Path -LiteralPath $OfficialCcc2Path -PathType Leaf)) {
        throw "Required ccc2 extraction wrapper is missing: $OfficialCcc2Path"
    }

    $Ccc2Item = Get-Item -LiteralPath $OfficialCcc2Path
    $OfficialCcc2Hash = Get-SHA256 -LiteralPath $OfficialCcc2Path
    $OfficialCcc2Length = [int64]$Ccc2Item.Length
    $OfficialCcc2ReferenceMatch = [bool](
        $OfficialCcc2Hash -eq $ReferenceCcc2Hash -and
        $OfficialCcc2Length -eq $ReferenceCcc2Length
    )

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

    Write-Host (
        '[PASS] Exact driver source identities and signatures match; ' +
        'AMD-signed CCC2 wrapper identity was recorded dynamically.'
    )

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

    if ([int]$Manifest.officialSourceFileCount -ne $ReferenceOfficialSourceFileCount) {
        throw 'The exact embedded manifest has an unexpected reference source count.'
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
        Join-Path $ResolvedOutputRoot 'u0202082.inf'

    $DatOutputPath =
        Join-Path $ResolvedOutputRoot 'B026218\amdgcf.dat'

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
        Join-Path $ResolvedOutputRoot 'u0202082.cat'

    if (Test-Path -LiteralPath $CatalogInOutput) {
        throw (
            'The unsigned driver package must not contain u0202082.cat.'
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

    $ExpectedByPath['u0202082.inf'] =
        [pscustomobject]@{
            Length = [int64](Get-Item -LiteralPath $InfOutputPath).Length
            SHA256 = $ExpectedCanonicalInfHash
        }

    $ExpectedByPath['B026218\amdgcf.dat'] =
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
        'LEGION GO AMD 26.6.4 TOOLKIT - PHASE 3'
        'UNSIGNED CANONICAL DRIVER PACKAGE BUILD AND VERIFICATION'
        ''
        "GeneratedAt: $((Get-Date).ToString('o'))"
        "SourceAuditPath: $SourceAuditPath"
        "SourceRoot: $ResolvedSourceRoot"
        "OutputRoot: $ResolvedOutputRoot"
        ''
        "OfficialSourceFileCount: $($OfficialFiles.Count)"
        "ReferenceOfficialSourceFileCount: $ReferenceOfficialSourceFileCount"
        "OfficialSourceReferenceCountMatch: $OfficialSourceReferenceCountMatch"
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
        "OfficialCcc2SHA256: $OfficialCcc2Hash"
        "OfficialCcc2Length: $OfficialCcc2Length"
        "OfficialCcc2ReferenceIdentityMatch: $OfficialCcc2ReferenceMatch"
        "OfficialCcc2IncludedInDriverPackage: False"
        ''
        "ExternalPackageManifestPath: $ExternalPackageManifestPath"
        "ExternalPackageManifestSHA256: $ExternalPackageManifestHash"
        ''
        'RESULT: Exact 125-file unsigned driver package reproduced from the audited AMD 26.6.4 target source.'
    )

    [IO.File]::WriteAllLines(
        $ReportPath,
        $ReportLines,
        [Text.UTF8Encoding]::new($true)
    )

    $VerificationResult = [ordered]@{
        SchemaVersion                    = 2
        Workflow                         = 'LegionGo-AMD-26.6.4'
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
        ReferenceOfficialSourceFileCount = $ReferenceOfficialSourceFileCount
        OfficialSourceReferenceCountMatch = $OfficialSourceReferenceCountMatch
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
        OfficialCcc2SHA256               = $OfficialCcc2Hash
        OfficialCcc2Length               = $OfficialCcc2Length
        OfficialCcc2ReferenceIdentityMatch = $OfficialCcc2ReferenceMatch
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
        Workflow                         = 'LegionGo-AMD-26.6.4'
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
        Workflow               = 'LegionGo-AMD-26.6.4'
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
        SHA256 = '443685E494B303B9BAD28B98E0CE876B01E206D692DA0338E807186030740A03'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 4 of Script 1 in the Legion Go AMD 26.6.4 Toolkit.

Consumes the exact 125-file unsigned canonical package produced by Phase 3,
creates a unique non-exportable local code-signing certificate, generates
and signs u0202082.cat, trusts the public certificate locally, and writes the
dynamic signing state consumed by Scripts 2 through 4.

The official AMD ccc2_install.exe and original Microsoft-signed catalog are
verified from Phase 3's official-source paths and recorded separately. They
are not copied into the 125/126-file driver package.

This script does not install or bind the display driver.
#>

[CmdletBinding()]
param(
    [string]$UnsignedRoot,

    [string]$BuildBase = 'C:\AMD\LegionGo-26.6.4',

    [string]$WorkflowRoot =
        'C:\ProgramData\LegionGo-AMD-26.6.4',

    [string]$VerificationResultPath =
        'C:\ProgramData\LegionGo-AMD-26.6.4\payload-verification.json'
)

$ErrorActionPreference = 'Stop'

$SecurityHelperPath = Join-Path $PSScriptRoot 'lib\Security-Hardening.ps1'
if (-not (Test-Path -LiteralPath $SecurityHelperPath -PathType Leaf)) {
    throw "Security helper is missing: $SecurityHelperPath"
}
. $SecurityHelperPath
$PSNativeCommandUseErrorActionPreference = $false

$ExpectedUnsignedFileCount = 125
$ExpectedInfHash = '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'
$ExpectedDatHash = 'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'
$ExpectedSysHash = '3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F'
$ExpectedIcdHash = 'DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F'
$ExpectedOfficialCatalogHash = 'F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C'

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
$CerPath = Join-Path $CertificateRoot 'LegionGo-AMD-26.6.4-Local-Driver.cer'

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

$RecordedOfficialCcc2Hash =
    [string]$VerificationResult.OfficialCcc2SHA256
$RecordedOfficialCcc2Length =
    [int64]$VerificationResult.OfficialCcc2Length

if (
    [string]::IsNullOrWhiteSpace($RecordedOfficialCcc2Hash) -or
    $RecordedOfficialCcc2Length -le 0
) {
    throw (
        'Phase 3 did not record the accepted CCC2 wrapper hash and length.'
    )
}

$OfficialCcc2Hash = Assert-FileHash `
    -Path $OfficialCcc2Path `
    -ExpectedHash $RecordedOfficialCcc2Hash `
    -Description 'Recorded AMD-signed ccc2 extraction wrapper'

$OfficialCcc2Item = Get-Item -LiteralPath $OfficialCcc2Path
$OfficialCcc2Length = [int64]$OfficialCcc2Item.Length

if ($OfficialCcc2Length -ne $RecordedOfficialCcc2Length) {
    throw @"
Recorded ccc2_install.exe length changed.
Recorded: $RecordedOfficialCcc2Length
Actual:   $OfficialCcc2Length
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
    -Description 'Separate official Microsoft-signed AMD u0202082.cat'

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

$ExistingCatalog = Join-Path $UnsignedRoot 'u0202082.cat'

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
        Join-Path $PackageRoot 'B026218\ccc2_install.exe'

    if (Test-Path -LiteralPath $UnexpectedCcc2InPackage -PathType Leaf) {
        throw (
            'The 125-file driver package unexpectedly contains ' +
            'ccc2_install.exe. CCC2 must remain a separate official-source asset.'
        )
    }

    $InfPath = Join-Path $PackageRoot 'u0202082.inf'
    $DatPath = Join-Path $PackageRoot 'B026218\amdgcf.dat'
    $SysPath = Join-Path $PackageRoot 'B026218\amdkmdag.sys'
    $IcdPath = Join-Path $PackageRoot 'B026218\atiicdxx.dat'
    $CatPath = Join-Path $PackageRoot 'u0202082.cat'

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
        'CN=LegionGo AMD 26.6.4 Local Driver ' +
        $Timestamp
    )

    $Certificate = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $CertificateSubject `
        -FriendlyName 'LegionGo AMD 26.6.4 Local Catalog Signing' `
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
        Workflow                      = 'LegionGo-AMD-26.6.4'
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
        OfficialCcc2Length            = $OfficialCcc2Length
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
        'LEGION GO AMD 26.6.4 TOOLKIT - PHASE 4'
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
        "OfficialCcc2Length: $OfficialCcc2Length"
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
        SHA256 = '68AE86D3BA8C1BC5856F5F628406179C30DFB6024942EA2F3E5D78C2088A2CC0'
        Utf8Bom = $false
        LineEnding = 'CRLF'
        TrailingNewline = $true
        ContentParts = @(
@'
#requires -RunAsAdministrator
#requires -Version 5.1

<#
Phase 5 of Script 1 in the Legion Go AMD 26.6.4 Toolkit.

First run:
  - verifies the signed package and a compatible Legion Go graphics state;
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
        'C:\ProgramData\LegionGo-AMD-26.6.4\payload-verification.json',

    [string]$CatalogSigningStatePath =
        'C:\ProgramData\LegionGo-AMD-26.6.4\catalog-signing-state.json',

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

$WorkflowRoot = 'C:\ProgramData\LegionGo-AMD-26.6.4'
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
    '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'
$ExpectedExtensionClassGuid = '{e2f84ce7-8efa-411c-aa69-97454ca4cb57}'
$ExpectedExtensionId = '{07A2A561-D001-4503-B239-EF2FE0379EFB}'
$ExpectedExtensionTargetHardwareId =
    'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$ExpectedExtensionCatalogSignerPattern =
    'Microsoft Windows Hardware Compatibility Publisher'
$GpuPattern = 'PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA*'

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


function Get-ExtensionPropertyValue {
    param(
        [AllowNull()]$Object,
        [Parameter(Mandatory)][string]$Name
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

function Normalize-InfLine {
    param([AllowEmptyString()][string]$Line)

    if ($null -eq $Line) {
        return ''
    }

    $WithoutComment = ($Line -split ';', 2)[0]
    return (($WithoutComment -replace '\s+', '').ToLowerInvariant())
}

function Get-InfValue {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines = @(),

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($Line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }

        $Match = [regex]::Match(
            $Line,
            ('^\s*' + [regex]::Escape($Name) + '\s*=\s*([^;\r\n]+)'),
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )

        if ($Match.Success) {
            return $Match.Groups[1].Value.Trim().Trim('"')
        }
    }

    return ''
}

function Resolve-LenovoExtensionPackage {
    param(
        [Parameter(Mandatory)][string]$OriginalName,
        [Parameter(Mandatory)][string]$PublishedInfPath
    )

    $PublishedHash = Get-SHA256 -LiteralPath $PublishedInfPath
    $Repository = Join-Path $env:windir 'System32\DriverStore\FileRepository'
    $Stem = [IO.Path]::GetFileNameWithoutExtension($OriginalName)
    $Pattern = Join-Path $Repository ($Stem + '.inf_*\' + $OriginalName)

    foreach ($Candidate in @(
        Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue
    )) {
        if ((Get-SHA256 -LiteralPath $Candidate.FullName) -eq $PublishedHash) {
            return [pscustomobject]@{
                InfPath = $Candidate.FullName
                PackageRoot = Split-Path -Parent $Candidate.FullName
                InfSHA256 = $PublishedHash
            }
        }
    }

    return $null
}

function Get-LenovoReleaseTargets {
    param([Parameter(Mandatory)][string]$DeviceId)

    $EnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$DeviceId"
    $DriverKey = [string](
        Get-ItemProperty -LiteralPath $EnumPath -ErrorAction Stop
    ).Driver

    if ([string]::IsNullOrWhiteSpace($DriverKey)) {
        throw 'Unable to resolve the active display class key.'
    }

    $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$DriverKey"
    $Video0 = [string](
        Get-ItemProperty `
            -LiteralPath 'HKLM:\HARDWARE\DEVICEMAP\VIDEO' `
            -ErrorAction Stop
    ).'\Device\Video0'

    $Match = [regex]::Match(
        $Video0,
        'Control\\Video\\(?<Guid>\{[0-9A-Fa-f-]+\})\\0000'
    )

    if (-not $Match.Success) {
        throw "Video0 is not mapped to the AMD stack: $Video0"
    }

    $Guid = $Match.Groups['Guid'].Value
    $Targets = @($ClassPath)
    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'HARDWARE\DEVICEMAP\VIDEO'
    )

    if ($null -eq $Key) {
        throw 'Unable to open the runtime video map.'
    }

    try {
        foreach ($ValueName in $Key.GetValueNames()) {
            if ($ValueName -notmatch '^\\Device\\Video\d+$') {
                continue
            }

            $Mapping = [string]$Key.GetValue($ValueName)
            $MappingMatch = [regex]::Match(
                $Mapping,
                'Control\\Video\\' + [regex]::Escape($Guid) +
                    '\\(?<Subkey>\d{4})$'
            )

            if ($MappingMatch.Success) {
                $Targets +=
                    "HKLM:\SYSTEM\CurrentControlSet\Control\Video\$Guid\$($MappingMatch.Groups['Subkey'].Value)"
            }
        }
    }
    finally {
        $Key.Dispose()
    }

    return @($Targets | Sort-Object -Unique)
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
            Compatible = $false
            MatchingRecords = @()
            FailureReasons = @('PnPInventoryUnavailable')
            InventoryPath = $PnPInventoryPath
        }
    }

    [xml]$Inventory = Get-Content -LiteralPath $PnPInventoryPath -Raw
    $DriverNodes = @(
        $Inventory.SelectNodes(
            '//*[local-name()="Driver" or local-name()="driver"]'
        )
    )
    $AttachedCandidates = @()
    $CompatibleRecords = @()
    $Failures = @()

    foreach ($DriverNode in $DriverNodes) {
        $ClassGuid = [string]$DriverNode.ClassGuid
        if ($ClassGuid -ine $ExpectedExtensionClassGuid) {
            continue
        }

        $MatchingDeviceIds = @()
        foreach ($DeviceNode in @(
            $DriverNode.SelectNodes(
                './*[local-name()="Devices" or local-name()="devices"]' +
                '/*[local-name()="Device" or local-name()="device"]'
            )
        )) {
            $InstanceId = [string]$DeviceNode.GetAttribute('InstanceId')
            if (
                -not [string]::IsNullOrWhiteSpace($InstanceId) -and
                $InstanceId -ieq $DeviceInstanceId
            ) {
                $MatchingDeviceIds += $InstanceId
            }
        }

        if ($MatchingDeviceIds.Count -eq 0) {
            continue
        }

        $PublishedName = [string]$DriverNode.GetAttribute('DriverName')
        $OriginalName = [string]$DriverNode.OriginalName
        $DriverVersionText = [string]$DriverNode.DriverVersion
        $AttachedCandidates += $PublishedName
        $RecordFailures = @()
        $PublishedInfPath = Join-Path $env:windir "INF\$PublishedName"

        if (-not (Test-Path -LiteralPath $PublishedInfPath -PathType Leaf)) {
            $Failures += "${PublishedName}:PublishedInfMissing"
            continue
        }

        $Package = Resolve-LenovoExtensionPackage `
            -OriginalName $OriginalName `
            -PublishedInfPath $PublishedInfPath

        if ($null -eq $Package) {
            $Failures += "${PublishedName}:DriverStorePackageUnresolved"
            continue
        }

        $InfText = Get-Content -LiteralPath $Package.InfPath -Raw
        $InfLines = @($InfText -split "`r?`n")
        $NormalizedLines = @(
            $InfLines |
                ForEach-Object { Normalize-InfLine -Line $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $Class = Get-InfValue -Lines $InfLines -Name 'Class'
        $InfClassGuid = Get-InfValue -Lines $InfLines -Name 'ClassGUID'
        $ExtensionId = Get-InfValue -Lines $InfLines -Name 'ExtensionId'
        $CatalogName = Get-InfValue -Lines $InfLines -Name 'CatalogFile'
        $DriverVer = Get-InfValue -Lines $InfLines -Name 'DriverVer'
        $VersionMatch = [regex]::Match($DriverVer, ',\s*(?<Version>[^,]+)$')
        $DriverVersion = if ($VersionMatch.Success) {
            $VersionMatch.Groups['Version'].Value.Trim()
        }
        else {
            ''
        }

        $RequiredInstallDirectives = @(
            'AddReg=ati2mtag_SoftwareDeviceSettings'
            'AddReg=ati2mtag_NAVIA_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Phoenix_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Post_EG'
            'AddReg=ati2mtag_MultiUVD_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_NONPX_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_PX_SoftwareDeviceSettings'
            'AddReg=ati2mtag_Mobile_PXAA_SoftwareDeviceSettings'
            'AddReg=ati2mtag_PXAA'
            'AddReg=ati2mtag_Manhattan_PX'
            'AddReg=ati2mtag_PXAA_IGPU_Only_2ID'
            'AddReg=ati2mtag_DSUMD'
            'DelReg=ati2mtag_RemoveDeviceSettings'
        )

        $RequiredRegistryDirectives = @(
            'HKR,,DalFeatureEnablePsrSU,%REG_DWORD%,0'
            'HKR,,DalDisableZ10,%REG_DWORD%,1'
            'HKR,,EnableswGCForceAtcL24KbWa,%REG_DWORD%,1'
            'HKR,,EnableswGCFakeCGCG,%REG_DWORD%,1'
            'HKR,,DalEmbeddedIntegerScalingSupport,%REG_DWORD%,1'
            'HKR,,DalPSRFeatureEnable,%REG_DWORD%,0'
            'HKR,,DalWirelessDisplaySupport,%REG_DWORD%,1'
            'HKR,,DalDetectRequireHpdHigh,%REG_DWORD%,0'
            'HKR,,DisableFBCSupport,%REG_DWORD%,1'
            'HKR,,BDC7EDEA37E855EFFD36,%REG_BINARY%,59,79,07,9B'
            'HKR,,BDC7EDEA40E855EFFDFB,%REG_BINARY%,59,79,07,9B'
            'HKR,,PP_UserVariBrightLevel,%REG_DWORD%,2'
            'HKR,,Dal_UserVariBrightLevel,%REG_DWORD%,2'
            'HKR,,PXSplashScreen,%REG_DWORD%,0'
            'HKR,,DALNonStandardModesBCD5,%REG_BINARY%,07,20,12,80,00,00,00,00,08,00,12,80,00,00,00,00,09,00,16,00,00,00,00,00,10,00,16,00,00,00,00,00,10,80,19,20,00,00,00,00,12,00,19,20,00,00,00,00,14,40,25,60,00,00,00,00'
            'HKR,,ProblemReportUrl,%REG_SZ%,show'
            'HKR,,DALRestrictedModesBCD5,%REG_BINARY%,16,00,12,00,00,00,00,00,12,80,10,24,00,00,00,00'
            'HKR,,HotkeysDisabled,%REG_DWORD%,0x1'
            'HKR,,dvr_ui_component_na,%REG_SZ%,true'
            'HKR,,DFPFreeSyncDefault,%REG_DWORD%,1'
            'HKR,,PP_WaitOnRegisterTimeout,%REG_DWORD%,0x2710'
            'HKR,,mobile_runtime_component_NA,%REG_SZ%,true'
            'HKR,,AllowWebContent,%REG_SZ%,false'
            'HKR,,LogoUrl,%REG_SZ%,hide'
            'HKR,,SystemTray,%REG_SZ%,false'
            'HKR,,DalWFDEnable,%REG_DWORD%,1'
            'HKR,"UMD\DXVA",ColorVibrance_DEF,%REG_SZ%,40'
            'HKR,"UMD\DXVA",ColorVibrance_ENABLE_DEF,%REG_SZ%,0'
            'HKR,,DALRULE_ALLOWMONITORRANGELIMITMODESCRT,%REG_DWORD%,0'
            'HKR,,ToggleRsHotkey,%REG_SZ%,none'
            'HKR,,LCDFreeSyncDefault,%REG_DWORD%,0x7'
            'HKR,,ShowRSOverlay,%REG_SZ%,false'
        )

        if ($Class -ine 'Extension') { $RecordFailures += 'ExtensionClass' }
        if ($InfClassGuid -ine $ExpectedExtensionClassGuid) { $RecordFailures += 'ExtensionClassGuid' }
        if ($ExtensionId -ine $ExpectedExtensionId) { $RecordFailures += 'ExtensionId' }
        if ($NormalizedLines -notcontains 'ati="advancedmicrodevices,inc."') { $RecordFailures += 'AmdProviderString' }
        $TargetIdNormalized = Normalize-InfLine -Line $ExpectedExtensionTargetHardwareId
        if (@($NormalizedLines | Where-Object { $_ -like "*$TargetIdNormalized*" }).Count -eq 0) {
            $RecordFailures += 'TargetHardwareId'
        }

        foreach ($Directive in @($RequiredInstallDirectives + $RequiredRegistryDirectives)) {
            if ($NormalizedLines -notcontains (Normalize-InfLine -Line $Directive)) {
                $RecordFailures += 'MissingDirective:' + $Directive
            }
        }

        foreach ($PatternName in @(
            'CopyFiles'
            'AddService'
            'ServiceBinary'
            'RegisterDlls'
            'CoInstallers32'
        )) {
            if ($InfText -match ('(?im)^\s*' + [regex]::Escape($PatternName) + '\s*=')) {
                $RecordFailures += 'UnexpectedRuntimeDirective:' + $PatternName
            }
        }

        $CatalogPath = Join-Path $Package.PackageRoot $CatalogName
        $CatalogSignature = if (Test-Path -LiteralPath $CatalogPath -PathType Leaf) {
            Get-AuthenticodeSignature -LiteralPath $CatalogPath
        }
        else {
            $null
        }
        $CatalogSigner = if (
            $null -ne $CatalogSignature -and
            $null -ne $CatalogSignature.SignerCertificate
        ) {
            [string]$CatalogSignature.SignerCertificate.Subject
        }
        else {
            ''
        }
        if (
            $null -eq $CatalogSignature -or
            [string]$CatalogSignature.Status -ne 'Valid' -or
            $CatalogSigner -notmatch $ExpectedExtensionCatalogSignerPattern
        ) {
            $RecordFailures += 'CatalogTrust'
        }

        $PackageFiles = @(
            Get-ChildItem -LiteralPath $Package.PackageRoot -File -Recurse
        )
        $ExecutableExtensions = @(
            '.sys', '.dll', '.exe', '.msi', '.msix', '.appx', '.com', '.ocx'
        )
        if (@($PackageFiles | Where-Object {
            $ExecutableExtensions -contains $_.Extension.ToLowerInvariant()
        }).Count -gt 0) {
            $RecordFailures += 'ExecutablePayload'
        }

        $CN = Get-ItemProperty `
            -LiteralPath 'HKLM:\SOFTWARE\AMD\CN' `
            -ErrorAction SilentlyContinue
        $RawCNVersion = [string](
            Get-ExtensionPropertyValue -Object $CN -Name 'CNVersion'
        )
        $RawCNDriverVersion = [string](
            Get-ExtensionPropertyValue -Object $CN -Name 'DriverVersion'
        )
        $CNVersionPresent =
            -not [string]::IsNullOrWhiteSpace($RawCNVersion)
        $CNDriverVersionPresent =
            -not [string]::IsNullOrWhiteSpace($RawCNDriverVersion)
        $CNMetadataState = if (
            $CNVersionPresent -and
            $CNDriverVersionPresent
        ) {
            'Present'
        }
        elseif (
            -not $CNVersionPresent -and
            -not $CNDriverVersionPresent
        ) {
            'Absent'
        }
        else {
            'Partial'
        }

        if ($CNMetadataState -eq 'Partial') {
            $RecordFailures += 'CNMetadataPartial'
        }
        if (
            $CNMetadataState -eq 'Present' -and
            $RawCNDriverVersion -ne $DriverVersion
        ) {
            $RecordFailures += 'CNDriverVersionMismatch'
        }

        $ReleaseRows = @()
        try {
            foreach ($Target in @(Get-LenovoReleaseTargets -DeviceId $DeviceInstanceId)) {
                $Value = ''
                try {
                    $Value = [string](
                        Get-ItemProperty `
                            -LiteralPath $Target `
                            -Name 'ReleaseVersion' `
                            -ErrorAction Stop
                    ).ReleaseVersion
                }
                catch {
                    $Value = ''
                }
                $ReleaseRows += [pscustomobject]@{
                    Path = $Target
                    Value = $Value
                    Present = -not [string]::IsNullOrWhiteSpace($Value)
                }
            }
        }
        catch {
            $RecordFailures += 'ReleaseTargetsUnresolved'
        }

        $DistinctReleaseValues = @(
            $ReleaseRows |
                Where-Object Present |
                Select-Object -ExpandProperty Value -Unique
        )
        $StableReleaseVersion = if ($DistinctReleaseValues.Count -eq 1) {
            [string]$DistinctReleaseValues[0]
        }
        else {
            ''
        }
        if (
            $ReleaseRows.Count -eq 0 -or
            @($ReleaseRows | Where-Object { -not $_.Present }).Count -gt 0 -or
            $DistinctReleaseValues.Count -ne 1
        ) {
            $RecordFailures += 'ReleaseVersionInconsistent'
        }

        $ReleaseVersionMatch = [regex]::Match(
            $StableReleaseVersion,
            '^(?<CNVersion>\d+(?:\.\d+){3})-.+-Lenovo$',
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $ReleaseCNVersion = if ($ReleaseVersionMatch.Success) {
            [string]$ReleaseVersionMatch.Groups['CNVersion'].Value
        }
        else {
            ''
        }

        if (
            [string]::IsNullOrWhiteSpace($StableReleaseVersion) -or
            -not $ReleaseVersionMatch.Success
        ) {
            $RecordFailures += 'ReleaseVersionProvenance'
        }
        if (
            $CNMetadataState -eq 'Present' -and
            $RawCNVersion -ne $ReleaseCNVersion
        ) {
            $RecordFailures += 'CNReleaseVersionMismatch'
        }

        $CNVersion = if ($CNMetadataState -eq 'Present') {
            $RawCNVersion
        }
        else {
            $ReleaseCNVersion
        }
        $CNDriverVersion = if ($CNMetadataState -eq 'Present') {
            $RawCNDriverVersion
        }
        else {
            $DriverVersion
        }

        if (
            [string]::IsNullOrWhiteSpace($CNVersion) -or
            [string]::IsNullOrWhiteSpace($CNDriverVersion)
        ) {
            $RecordFailures += 'CNMetadataUnresolved'
        }

        $ReleaseMetadataAdvisories = @(
            $RecordFailures |
                Where-Object {
                    $_ -in @(
                        'ReleaseTargetsUnresolved'
                        'ReleaseVersionInconsistent'
                        'ReleaseVersionProvenance'
                        'CNReleaseVersionMismatch'
                    )
                }
        )
        $RecordFailures = @(
            $RecordFailures |
                Where-Object { $_ -notin $ReleaseMetadataAdvisories }
        )

        if ($RecordFailures.Count -eq 0) {
            $CompatibleRecords += [pscustomobject]@{
                ReleaseMetadataAdvisories = @($ReleaseMetadataAdvisories)
                PublishedName = $PublishedName
                OriginalName = $OriginalName
                Version = $DriverVersion
                VersionText = $DriverVersionText
                ClassGuid = $InfClassGuid
                ExtensionId = $ExtensionId
                DeviceIDs = $MatchingDeviceIds
                InfPath = $Package.InfPath
                InfSHA256 = $Package.InfSHA256
                CatalogPath = $CatalogPath
                CatalogSHA256 = Get-SHA256 -LiteralPath $CatalogPath
                CatalogSigner = $CatalogSigner
                PackageRoot = $Package.PackageRoot
                PackageFileCount = $PackageFiles.Count
                CNVersion = $CNVersion
                CNDriverVersion = $CNDriverVersion
                RawCNVersion = $RawCNVersion
                RawCNDriverVersion = $RawCNDriverVersion
                CNMetadataState = $CNMetadataState
                StableReleaseVersion = $StableReleaseVersion
                ReleaseTargets = @($ReleaseRows)
                RequiredRegistryDirectiveCount = $RequiredRegistryDirectives.Count
                SemanticCompatible = $true
            }
        }
        else {
            $Failures += "${PublishedName}:" + ($RecordFailures -join ',')
        }
    }

    return [pscustomobject]@{
        InventoryCreated = $true
        ExitCode = $Process.ExitCode
        Attached = ($AttachedCandidates.Count -gt 0)
        Compatible = ($CompatibleRecords.Count -eq 1)
        MatchingRecords = @($CompatibleRecords)
        FailureReasons = @($Failures)
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

    $SignedInfPath = Join-Path $PackageRoot 'u0202082.inf'
    $UnexpectedCcc2Path =
        Join-Path $PackageRoot 'B026218\ccc2_install.exe'

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
    Write-Host '=== COMPATIBLE LEGION GO STARTING STATE ==='

    $GpuDriver = Get-GpuDriver
    $GpuEntity = Get-GpuEntity
    $ActiveInfPath = Join-Path $env:windir "INF\$($GpuDriver.InfName)"

    if (-not (Test-Path -LiteralPath $ActiveInfPath -PathType Leaf)) {
        throw "Active display INF is missing: $ActiveInfPath"
    }

    $ActiveInfHash = Get-SHA256 -LiteralPath $ActiveInfPath

    if (
        [string]$GpuEntity.Status -ne 'OK' -or
        [int]$GpuEntity.ConfigManagerErrorCode -ne 0
    ) {
        throw (
            'The starting Legion Go GPU is unhealthy: status ' +
            [string]$GpuEntity.Status +
            ', code ' +
            [string]$GpuEntity.ConfigManagerErrorCode
        )
    }

    $GpuEnumPath =
        'HKLM:\SYSTEM\CurrentControlSet\Enum\' +
        [string]$GpuDriver.DeviceID

    $GpuEnumValues = Get-ItemProperty -LiteralPath $GpuEnumPath
    $KernelServiceName = [string]$GpuEnumValues.Service

    if ([string]::IsNullOrWhiteSpace($KernelServiceName)) {
        throw 'The starting GPU device has no kernel service assignment.'
    }

    $KernelService =
        Get-CimInstance Win32_SystemDriver |
            Where-Object Name -EQ $KernelServiceName |
            Select-Object -First 1

    if ($null -eq $KernelService) {
        throw "Starting GPU kernel service was not found: $KernelServiceName"
    }

    $KernelPath = Resolve-KernelPath -RawPath $KernelService.PathName

    if (-not (Test-Path -LiteralPath $KernelPath -PathType Leaf)) {
        throw "Starting GPU kernel file is missing: $KernelPath"
    }

    if ([IO.Path]::GetFileName($KernelPath) -ine 'amdkmdag.sys') {
        throw "Unexpected starting GPU kernel file: $KernelPath"
    }

    if (
        [string]$KernelService.State -ne 'Running' -or
        -not [bool]$KernelService.Started
    ) {
        throw (
            'The starting AMD GPU kernel service is not running: ' +
            $KernelServiceName
        )
    }

    $KernelHash = Get-SHA256 -LiteralPath $KernelPath
    $DriverIsSigned = [bool]$GpuDriver.IsSigned
    $DriverSigner = [string]$GpuDriver.Signer
    $KernelSignature = Get-AuthenticodeSignature -LiteralPath $KernelPath
    $KernelSignatureValid =
        [string]$KernelSignature.Status -eq 'Valid' -and
        $null -ne $KernelSignature.SignerCertificate
    $KernelSigner = if ($KernelSignatureValid) {
        [string]$KernelSignature.SignerCertificate.Subject
    }
    else {
        ''
    }

    if (
        -not $DriverIsSigned -or
        [string]::IsNullOrWhiteSpace($DriverSigner)
    ) {
        if (-not $KernelSignatureValid) {
            throw (
                'The starting display package is not recorded by Windows as ' +
                'signed, and the active AMD kernel signature is not valid.'
            )
        }

        Write-Warning (
            'Windows does not record the starting display package as signed. ' +
            'Accepting the supported prior-toolkit path because the GPU is ' +
            'healthy and the active amdkmdag.sys signature is valid. Signer: ' +
            $KernelSigner
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

    if (-not $ExtensionState.Compatible) {
        throw (
            'No semantically compatible Lenovo Legion Go extension is ' +
            'attached to the GPU. Failures: ' +
            (@($ExtensionState.FailureReasons) -join ' | ')
        )
    }

    $ExtensionRecord = @($ExtensionState.MatchingRecords)[0]

    $StartingDisplayState = [ordered]@{
        DeviceName = [string]$GpuDriver.DeviceName
        DeviceID = [string]$GpuDriver.DeviceID
        Provider = [string]$GpuDriver.DriverProviderName
        ActiveINF = [string]$GpuDriver.InfName
        DriverVersion = [string]$GpuDriver.DriverVersion
        ActiveInfSHA256 = $ActiveInfHash
        Status = [string]$GpuEntity.Status
        ProblemCode = [int]$GpuEntity.ConfigManagerErrorCode
        KernelService = $KernelServiceName
        KernelPath = $KernelPath
        KernelSHA256 = $KernelHash
        DriverIsSigned = $DriverIsSigned
        DriverSigner = $DriverSigner
        KernelSignatureValid = $KernelSignatureValid
        KernelSigner = $KernelSigner
        LenovoExtensionSemanticCompatible = $true
        LenovoExtensionReleaseMetadataAdvisories =
            @($ExtensionRecord.ReleaseMetadataAdvisories)
        LenovoExtensionOriginalName =
            [string]$ExtensionRecord.OriginalName
        LenovoExtensionPublishedName =
            [string]$ExtensionRecord.PublishedName
        LenovoExtensionVersion =
            [string]$ExtensionRecord.Version
        LenovoExtensionClassGuid =
            [string]$ExtensionRecord.ClassGuid
        LenovoExtensionId =
            [string]$ExtensionRecord.ExtensionId
        LenovoExtensionInfSHA256 =
            [string]$ExtensionRecord.InfSHA256
        LenovoExtensionCatalogSHA256 =
            [string]$ExtensionRecord.CatalogSHA256
        LenovoExtensionCatalogSigner =
            [string]$ExtensionRecord.CatalogSigner
        LenovoCNVersion =
            [string]$ExtensionRecord.CNVersion
        LenovoCNDriverVersion =
            [string]$ExtensionRecord.CNDriverVersion
        LenovoStableReleaseVersion =
            [string]$ExtensionRecord.StableReleaseVersion
        CompatibilityPolicy =
            'Healthy AMD display stack with semantically compatible Lenovo extension'
    }

    [pscustomobject]$StartingDisplayState | Format-List

    Write-Host (
        '[PASS] Compatible Legion Go graphics state and validated Lenovo ' +
        'extension are present'
    )

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
            Workflow = 'LegionGo-AMD-26.6.4'
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
            LenovoExtensionSemanticCompatible = $true
            StartingDisplayState = $StartingDisplayState
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
                'Legion Go AMD 26.6.4: disable Secure Boot in UEFI, ' +
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
            Workflow = 'LegionGo-AMD-26.6.4'
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
            LenovoExtensionSemanticCompatible = $true
            StartingDisplayState = $StartingDisplayState
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
        Workflow = 'LegionGo-AMD-26.6.4'
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
            LenovoExtensionSemanticCompatible = $true
        StartingDisplayState = $StartingDisplayState
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
            'Legion Go AMD 26.6.4: rebooting once to activate Test Signing. ' +
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
        SHA256 = '9E3CD19EC26B0D3A6B115EE688DD893F26C5201AD835D442CE33F080FE5F6196'
        Utf8Bom = $false
        LineEnding = 'LF'
        TrailingNewline = $false
        ContentParts = @(
@'
{
  "schemaVersion": 1,
  "description": "Files copied unchanged from the official AMD 26.6.4 -b WT6A_INF package into the canonical Legion Go display-driver package.",
  "officialSourceFileCount": 194,
  "canonicalSignedFileCount": 126,
  "unchangedFileCount": 123,
  "rebuiltFiles": [
    {
      "relativePath": "u0202082.inf",
      "officialSha256": "25F6724F57BA8CC9CF9C54EE6E6EF0DAF257F38ED0303B3F7227A40E69E9F6A1",
      "canonicalSha256": "73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034"
    },
    {
      "relativePath": "B026218\\amdgcf.dat",
      "officialSha256": "6552B360432EE95B3C85ADD28CB2551BBFB2497C6569D13378F750EF06527724",
      "canonicalSha256": "AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200"
    }
  ],
  "generatedFile": {
    "relativePath": "u0202082.cat",
    "officialSha256": "F3077CF13DDE0673D39D03F56A99AF583BA18CCCDC617FCC2E042121BD4F737C",
    "historicalCanonicalSha256": null,
    "note": "Public Beta v2.0 regenerates and signs this catalog with a per-user certificate, so its final hash is expected to differ. No shared 26.6.4 local-catalog hash exists before installation."
  },
  "unchangedFiles": [
    {
      "relativePath": "B026218\\amd_fidelityfx_dx12.dll",
      "length": 6667280,
      "sha256": "DDC77E882287022862D5E30954D3EB82948A86F48CEF5C0940694D44AAF83D40"
    },
    {
      "relativePath": "B026218\\amd_opencl32.dll",
      "length": 214032,
      "sha256": "F642721A786FF6654885FDB526FAD483C23C6B1F60E490B7BAA2A21157DBF501"
    },
    {
      "relativePath": "B026218\\amd_opencl64.dll",
      "length": 244752,
      "sha256": "BA0AE4616A3AF6FFBB1D2C5772E2C755761211AD1704243CBE305C36F3EC6BA3"
    },
    {
      "relativePath": "B026218\\amdadlx32.dll",
      "length": 4801040,
      "sha256": "8D864A6B802F5D2B0CF83D7FF8F0752E6865023EF79176D70086358B209F9274"
    },
    {
      "relativePath": "B026218\\amdadlx64.dll",
      "length": 5224976,
      "sha256": "EE66701829A7ECE251C2F184114D0C1EC6F0A7AFC58E78BC5A2B1E0D7544707C"
    },
    {
      "relativePath": "B026218\\AMDADLXServ.exe",
      "length": 438288,
      "sha256": "2EF9FAF8162370B175D673B3B59449F5EBFDE832C5D937C85A8CD89855B89983"
    },
    {
      "relativePath": "B026218\\AMDADLXServPS.dll",
      "length": 236560,
      "sha256": "7671B64A461AE01FB7A210527EA5115E93FBEBC5209B1007457890007CF97B11"
    },
    {
      "relativePath": "B026218\\AMDADLXServPS32.dll",
      "length": 120336,
      "sha256": "3E68BCF749042C8F1BF9E45F0E707011E6CD2B786B511A8F524135B819EEC7FA"
    },
    {
      "relativePath": "B026218\\AMDav1Enc32.dll",
      "length": 2285584,
      "sha256": "C1E23158B36D31F2EC28B3E2D743EFE8DD9FBA1F3DB7008B181EDC1391C32790"
    },
    {
      "relativePath": "B026218\\AMDav1Enc64.dll",
      "length": 2370576,
      "sha256": "A5B29D920ACD0C835FFEB4E5DA166A98AF1C475A368C87133FD8F55DE0D0CFB1"
    },
    {
      "relativePath": "B026218\\amdave32.dll",
      "length": 146832,
      "sha256": "45BB6F1BDC26D71F4AE2E17786F995D5664D4FD6388F373E98D25241E04AC6D3"
    },
    {
      "relativePath": "B026218\\amdave64.dll",
      "length": 167160,
      "sha256": "408E88D9CF8E208023F0336170B72C31F5F0BA46CAECF053BF37B8BE61B2C2BF"
    },
    {
      "relativePath": "B026218\\amdcc.dll",
      "length": 4449824,
      "sha256": "D9F38F90354C01D80F82A2E55DAB33E7A11EACC2FDE3DEA082DA85FBD81F8AD6"
    },
    {
      "relativePath": "B026218\\amdefctb.dat",
      "length": 515238,
      "sha256": "BDB7D795E7BC809B2D752C8D71320D0A50321FAE9491EEDDF6720CD98FED5B5A"
    },
    {
      "relativePath": "B026218\\amdenc32.dll",
      "length": 1255440,
      "sha256": "24080ECEE6DFC0D50FFFEC8AC1C254F16DA26AC0125F6ABE9AFE2A8EFAF0DA40"
    },
    {
      "relativePath": "B026218\\amdenc64.dll",
      "length": 1424432,
      "sha256": "83AF94D26A98A6390706A883FD97CB2CCDA5880A696BA1CBB6E26E91AC1FBBD4"
    },
    {
      "relativePath": "B026218\\amdept.dat",
      "length": 42028,
      "sha256": "886694CA1DDD0BDFCFD6D2A6EC8E0C77B9DB29C41222204EF54531E7085FDC80"
    },
    {
      "relativePath": "B026218\\amdgfxinfo32.dll",
      "length": 457232,
      "sha256": "EBD621DF229BF3027F57EA6238F46DB1D81299D9376B0AC0CD321F1DBC88B750"
    },
    {
      "relativePath": "B026218\\amdgfxinfo64.dll",
      "length": 597520,
      "sha256": "FE1DA2B824E72FD5FDADB8CF13CF0BC311725EC48C9059696804C9DCE4EC9ABA"
    },
    {
      "relativePath": "B026218\\AMDh264Enc32.dll",
      "length": 2289184,
      "sha256": "0768C319ECC8277217B848603609F94077373C32A2E7B3DA5C66FE30F6BCBCBC"
    },
    {
      "relativePath": "B026218\\AMDh264Enc64.dll",
      "length": 2365888,
      "sha256": "820B4E215A23852F6A238F5BCA0BE02DBD742465F7F7AF7D6FA7222719DCDCCB"
    },
    {
      "relativePath": "B026218\\AMDh265Enc32.dll",
      "length": 2271488,
      "sha256": "63E51F7ED0ACCA7C60E082F87BBDCCB6DB3C5968B2C48B89B03A6DF91FB7F7E5"
    },
    {
      "relativePath": "B026218\\AMDh265Enc64.dll",
      "length": 2352288,
      "sha256": "9CD46AD813961283DFA200367495510490AB5BE1329BD52E33DDE3EE94773FD5"
    },
    {
      "relativePath": "B026218\\amdhdl32.dll",
      "length": 125472,
      "sha256": "C04EFF095353E621AE5B8A5B68225EA127905176A299775F7F94E48A96795707"
    },
    {
      "relativePath": "B026218\\amdhdl64.dll",
      "length": 146392,
      "sha256": "42343671F82E58C982A56307764FB8D7F5504F385127B86F5F3172CA7ED1EABB"
    },
    {
      "relativePath": "B026218\\amdicdxx.dat",
      "length": 1716978,
      "sha256": "5DA952C500304745CFE5B63E005BDB9233381BD24451358EAC953A7B7CBDCA12"
    },
    {
      "relativePath": "B026218\\amdihk32.dll",
      "length": 216592,
      "sha256": "3AF15897702812E85837ED919C75CCDB584C77780AFADB997F81433ACA39FA58"
    },
    {
      "relativePath": "B026218\\amdihk64.dll",
      "length": 269232,
      "sha256": "1A81C78C78F5A333F48C7ED234DBBFA6F06273BA6059E769BE7AA261C3DD5AE9"
    },
    {
      "relativePath": "B026218\\AMDInstallManager.msi",
      "length": 66519040,
      "sha256": "0BC42A0B88841E9E629832437DD0ADE61C26802B85B9102FCAE5970CE9F2B4E6"
    },
    {
      "relativePath": "B026218\\AMDKernelEvents.mc",
      "length": 21730,
      "sha256": "D93EADCEAA84AF4265B61DFD6A37F3DA5294433F5B418F17BD6C136CD5ABE841"
    },
    {
      "relativePath": "B026218\\amdkmdag.sys",
      "length": 84134928,
      "sha256": "3253532B1D397A18E221E6AB0CE7113724C4A45DE7797C7112E06A0D5F0AD10F"
    },
    {
      "relativePath": "B026218\\amdlvr32.dll",
      "length": 998416,
      "sha256": "B8515F9D95AF6552D551799F235D9DBDF6C02158BD4D15AE3641586022295562"
    },
    {
      "relativePath": "B026218\\amdlvr64.dll",
      "length": 1184784,
      "sha256": "763B6FCF7C8CFE757382BBCF3233848E3DF5BB7B995229690F19BAC8335940F1"
    },
    {
      "relativePath": "B026218\\amdmiracast.dll",
      "length": 180248,
      "sha256": "192CC0AA1B58259E64B850D14973D10D9E007BFA7B9E483118DD8195DAA85ED6"
    },
    {
      "relativePath": "B026218\\amdmmpal32.dll",
      "length": 2100752,
      "sha256": "114AB9E235B7A7CD6DE0D6B71366C4EC4F3086DED4EAE0555A4697364D8D9BAE"
    },
    {
      "relativePath": "B026218\\amdmmpal64.dll",
      "length": 2379792,
      "sha256": "700CA316E7DFEF08EA8611817D8833E2729EAB342D9EB6E6917FC4D0D2771CD8"
    },
    {
      "relativePath": "B026218\\amdpcom32.dll",
      "length": 132864,
      "sha256": "2471ED035DCF0C663EA6FA201EE850317C4876611CD852382C070770CBCBAF7A"
    },
    {
      "relativePath": "B026218\\amdpcom64.dll",
      "length": 156848,
      "sha256": "2DB5DE8250E35D118EA69C275A8AF5216A52E931855A7F8C6A38A7A57FE3A845"
    },
    {
      "relativePath": "B026218\\amdsacli32.dll",
      "length": 552976,
      "sha256": "FF245E3771490AA4B09DF7EC1393C421476331D0327CC732635A70C565690CB4"
    },
    {
      "relativePath": "B026218\\amdsacli64.dll",
      "length": 620520,
      "sha256": "767073335CCC2B284A055A523250AAF415B979E36C6B491C8FB73291CE470CF7"
    },
    {
      "relativePath": "B026218\\amdsasrv64.dll",
      "length": 1334288,
      "sha256": "96243FB5CF96B5F05627CB2080E193BA20043A9763D17D27C8635192B2D32251"
    },
    {
      "relativePath": "B026218\\amduve32.dll",
      "length": 170880,
      "sha256": "D164B26B160536280F753B9A3CAC75236F857F9D05B7F64497148E06D84CB6DF"
    },
    {
      "relativePath": "B026218\\amduve64.dll",
      "length": 199480,
      "sha256": "6CA9A34923E39C78CD4A96A1E1BA0A668CDAEE78B8F01B9592F3AA7E51987153"
    },
    {
      "relativePath": "B026218\\amdxc32.dll",
      "length": 69712024,
      "sha256": "1D63A11D6B5E9B0370531FAB41C041E9EDD0B0807E0216FA5F6A42E61565AEA4"
    },
    {
      "relativePath": "B026218\\amdxc64.dll",
      "length": 78202176,
      "sha256": "CC32AB53E1ABE5F6A48E41A02EEB7E349FBDF63CAF97C9B7826442375E423D55"
    },
    {
      "relativePath": "B026218\\amdxc64.so",
      "length": 122155464,
      "sha256": "F2392DC968B7C33F65004D1F16F86269BAB50DC3CC469C362D4AEE4CDE4B4F1B"
    },
    {
      "relativePath": "B026218\\amdxcffx64.dll",
      "length": 66830768,
      "sha256": "96FF9DC2984FFE832DE1599B374D554EB86122436A808EF0020E615EBC1EBBA9"
    },
    {
      "relativePath": "B026218\\amdxcstub32.dll",
      "length": 121824,
      "sha256": "FA67940ECFB022E813C7792A553C67D0995357E95FCABB49166267A4C28D126A"
    },
    {
      "relativePath": "B026218\\amdxcstub64.dll",
      "length": 141640,
      "sha256": "FC1D0A699C3D85FEB31AFBDE89FB5DDF3136B318FF303B5D9C92B9FB015BD9A2"
    },
    {
      "relativePath": "B026218\\amdxn32.dll",
      "length": 34454544,
      "sha256": "830F102C9E31B0A919F527F39A612A516A47F3A893BB472ADFF55EFB2C37CA56"
    },
    {
      "relativePath": "B026218\\amdxn64.dll",
      "length": 40476688,
      "sha256": "803032C5B8CDF2E2786335A7E967D4339F41AD088DD97C0701D40A009090A2A4"
    },
    {
      "relativePath": "B026218\\amdxx32.dll",
      "length": 41892600,
      "sha256": "E03717A312061D5A8BF305194F8F10996FE39F6F272DE20D3955642191E46330"
    },
    {
      "relativePath": "B026218\\amdxx64.dll",
      "length": 47384568,
      "sha256": "BFE54098D1AF6C842FE232227C3B723F21A72EA10564D3F8D5C1608E04463BF9"
    },
    {
      "relativePath": "B026218\\amf-mft-mjpeg-decoder32.dll",
      "length": 1402048,
      "sha256": "8FF62C92A611E3BF34A2CCAB6435D8428E33A4BED3BCD3145623AF34DB0556B1"
    },
    {
      "relativePath": "B026218\\amf-mft-mjpeg-decoder64.dll",
      "length": 1724592,
      "sha256": "AD9092525459DE3A0513E3B1BEE034A78CA199D0DAC2F3E75D6BABD858F49782"
    },
    {
      "relativePath": "B026218\\amf-pa-ml32.dll",
      "length": 344592,
      "sha256": "AD71D6E7D5190381CB63CC120878E10C9248A0977F9188CB038FAD08AF91B0FB"
    },
    {
      "relativePath": "B026218\\amf-pa-ml64.dll",
      "length": 377872,
      "sha256": "991B65BE6E2534A53AB7FECC5FF2B26212F96998BF259382B175198E2B51CE40"
    },
    {
      "relativePath": "B026218\\amfrt32.dll",
      "length": 129552,
      "sha256": "C47359F26127EF4685CE57665EADAC163A391A4302BF21EB339D5E442DC70DDA"
    },
    {
      "relativePath": "B026218\\amfrt64.dll",
      "length": 160784,
      "sha256": "F9145439BFF783253200E123D1313E3D1A01769F4BC4E378FD0464C18AF36F90"
    },
    {
      "relativePath": "B026218\\amfrtdrv32.dll",
      "length": 19405328,
      "sha256": "5DEA8DF02F886C0CFF65E6A284CD502868BE35FE6F4ED884DAB06D6F75E7F03C"
    },
    {
      "relativePath": "B026218\\amfrtdrv64.dll",
      "length": 20524048,
      "sha256": "EB93663A6D5E3D607C2F172A1740BEFE11CC633447F20FC957671EE7393F697C"
    },
    {
      "relativePath": "B026218\\atiadlxx.dll",
      "length": 2508304,
      "sha256": "4DE435D474C2CE775829725FFB8B5B37076132544AAFFD1AC9F3B1F98359DDE1"
    },
    {
      "relativePath": "B026218\\atiadlxy.dll",
      "length": 2062352,
      "sha256": "0B942586FA777A80F4018378AD7D1FC3989765863F36C88855C7D7E69B351B09"
    },
    {
      "relativePath": "B026218\\atiapfxx.blb",
      "length": 552992,
      "sha256": "C7868479DACEE9A26CD7BA86510CFF483E0F80A771EFA2FF7F5C93CCBEA30628"
    },
    {
      "relativePath": "B026218\\atidemgy.dll",
      "length": 473616,
      "sha256": "A0DB728CB6F78E8C6CD0870255FAD9672D3AE409B57184813AC2AEEF95DFA482"
    },
    {
      "relativePath": "B026218\\atidx9loader32.dll",
      "length": 119824,
      "sha256": "661B98A4C6442899400AFB0A4B708E74AB6B5E180185F91EDE097C3C58211CF6"
    },
    {
      "relativePath": "B026218\\atidx9loader64.dll",
      "length": 138768,
      "sha256": "D9AA3E4EF1143F91695649A459C0F909D9A83A3C634A306085DC624795FABB66"
    },
    {
      "relativePath": "B026218\\atidxxstub32.dll",
      "length": 106176,
      "sha256": "32E982C75B574A1E0F6F5A3F734EEC8A17EAC6D47528DAD0BE340BABA6875291"
    },
    {
      "relativePath": "B026218\\atidxxstub64.dll",
      "length": 128408,
      "sha256": "B6FA2BB2809AF09904694C350741F099ABAD502E6789438C18EE6C92F24951DA"
    },
    {
      "relativePath": "B026218\\atieah32.exe",
      "length": 429584,
      "sha256": "0527188A8C21282C4CCB46CFE532E11A4C9735F049C96DF69B2651B6EA46B6E3"
    },
    {
      "relativePath": "B026218\\atieah64.exe",
      "length": 565256,
      "sha256": "A07A7A1946B8D2B2C96D9245417BE948C8046F958A6F035573C42D8AAE9D2995"
    },
    {
      "relativePath": "B026218\\atieclxx.exe",
      "length": 1067536,
      "sha256": "2E6FECC22676C92AF0352D8C39733D8C4F6D70DC0207458A79C4B44E2F984608"
    },
    {
      "relativePath": "B026218\\atiesrxx.exe",
      "length": 682512,
      "sha256": "E5E4BECE501E02560BC6869DABF3AB671C4A8C1FDF6584EA2992D74A83EB4B9C"
    },
    {
      "relativePath": "B026218\\atig6pxx.dll",
      "length": 187920,
      "sha256": "D3F03BC3D69EB075954FEEC3F216318B8DD5BD4E37CEF18FD4B4C2A7ED29FD7B"
    },
    {
      "relativePath": "B026218\\atiglpxx.dll",
      "length": 160784,
      "sha256": "6A0ED0924814FE22D274E9616A333A75CAA00943356EB0234CE16E41423A331A"
    },
    {
      "relativePath": "B026218\\atiicdxx.dat",
      "length": 737410,
      "sha256": "DA435045306DB0C8C0CA29A6CA2121534C1CAD7EA916BE500CD72FE672A1D95F"
    },
    {
      "relativePath": "B026218\\atimpc32.dll",
      "length": 132864,
      "sha256": "AF470696D75977646960CEF5341BDA56BA4B6023A2B609D7C787DA3B67E73FBA"
    },
    {
      "relativePath": "B026218\\atimpc64.dll",
      "length": 156848,
      "sha256": "EBD609E0BD7F762602C5421EC6A4FCBE92D989EA0A63BDD31FC8D2D295880EEE"
    },
    {
      "relativePath": "B026218\\atimuixx.dll",
      "length": 200720,
      "sha256": "C8D5409BA47FDEA70A20C629F2EE3CA3605171DA78E302BD03A993F2E8848D64"
    },
    {
      "relativePath": "B026218\\atisamu32.dll",
      "length": 152080,
      "sha256": "3539625D5A7C9B45AF41F372B61CFCDEDB59C17D1DA20531CAF407705427F3CB"
    },
    {
      "relativePath": "B026218\\atisamu64.dll",
      "length": 187920,
      "sha256": "650FF1C8D9836056B1561B00A58372E1AF091D1717261131E42EBFC2A7BD68AB"
    },
    {
      "relativePath": "B026218\\ativvaxy_cik_nd.dat",
      "length": 234416,
      "sha256": "15B132C7947B2FD93DADC9E48278332D455A03957E7E948938F6EB7BC54F572D"
    },
    {
      "relativePath": "B026218\\ativvaxy_cik.dat",
      "length": 234676,
      "sha256": "4E5986C9A62243D556523D6E3E72CB414EB275A104853B2436FA20E0D55994BD"
    },
    {
      "relativePath": "B026218\\ativvaxy_cz_nd.dat",
      "length": 272928,
      "sha256": "D043E8FE127BF5E25C43CDF945834F3D37261AB47C65D05605A09E83D5C89FC4"
    },
    {
      "relativePath": "B026218\\ativvaxy_el_nd.dat",
      "length": 376224,
      "sha256": "CD11D2ABC62D90BDDD580CEEC25BAFC20962FB381923ADE87E74CD9E66873D0C"
    },
    {
      "relativePath": "B026218\\ativvaxy_FJ_nd.dat",
      "length": 267984,
      "sha256": "94744405991474810F96B7401E1A13062BB6B2D217F87D161CC285FD53D94496"
    },
    {
      "relativePath": "B026218\\ativvaxy_FJ.dat",
      "length": 268244,
      "sha256": "5D29280832A9AF0FE48DE5EE0C177B2DE885B8FB9431FD53D8BB5348C26FCB7B"
    },
    {
      "relativePath": "B026218\\ativvaxy_gl_nd.dat",
      "length": 381984,
      "sha256": "C91BDBE922E1404120D4217664EAD5F038B2E3A620D7A2D7FAE2DD7ECDA86990"
    },
    {
      "relativePath": "B026218\\ativvaxy_nv.dat",
      "length": 404288,
      "sha256": "B12AD7392BFA0439FA1759403F29022740F2AA8DE67BFA2D4285C05AA994AA8C"
    },
    {
      "relativePath": "B026218\\ativvaxy_rv.dat",
      "length": 366304,
      "sha256": "2CF886FE3A8530D09EAB3D535FEB62CBD795E33B84E00F22B26905446816C9B1"
    },
    {
      "relativePath": "B026218\\ativvaxy_stn_nd.dat",
      "length": 278432,
      "sha256": "8C09DD21260D7FFC959220D59379CA2A4F17559FE94D92B63CBF9E8A639D0A4C"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn3_1.dat",
      "length": 572112,
      "sha256": "643C2A57629EC80F68AAE64763947913EC4B57AFBF12854869E0EFB2088E36F1"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn3.dat",
      "length": 579856,
      "sha256": "A507DBA341207CF7C444006A846EFD69AC6E34945CA925257B693B71EE4E5C47"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn4_0_a_1.dat",
      "length": 395408,
      "sha256": "1170239117C7312659A8757EA8A51A7162011EEC85879F7C5180CDBD230017E7"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn4_0_a.dat",
      "length": 395408,
      "sha256": "0C9982277801271E2CF1A3F09940DC252ECE5C12EBBB5DDD8D17933FFDAA058C"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn4.dat",
      "length": 395408,
      "sha256": "0B7ABE3D6EC2F60699564E354E825A8B3BE1533C83B27D0E8D0B3132B1BFDF79"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn5_3.dat",
      "length": 439888,
      "sha256": "C7A7C540D5A362A6AE3CD58C80346BA22D66B8332622DEA8A4F02C48AE785D52"
    },
    {
      "relativePath": "B026218\\ativvaxy_vcn5.dat",
      "length": 437776,
      "sha256": "E6572B372DB1AEAAA09D39CDABE4FBE690CDEEBF8CCCB052A4A0FC2D12E47B49"
    },
    {
      "relativePath": "B026218\\ativvaxy_vg.dat",
      "length": 572112,
      "sha256": "D3107EE99F32408D0E5017A7B4597DC15305D0CCDE816FC9349902352ACBC7BE"
    },
    {
      "relativePath": "B026218\\ativvaxy_vg20_nd.dat",
      "length": 384800,
      "sha256": "B86D15BCE79A5CBD31B384CB86D56573BB1A0E002797E1487FB539323BDF6529"
    },
    {
      "relativePath": "B026218\\ativvaxy_vg20.dat",
      "length": 379200,
      "sha256": "B06A2F8E6110EF13B13D36C293FA7A793D1AA736CDD4258A89E45A25D111971A"
    },
    {
      "relativePath": "B026218\\ativvaxy_vi_nd.dat",
      "length": 324928,
      "sha256": "FB927ACC1C213597B63735BC776ABF08354884DAA2E11A5C19D9EC5BA9423C53"
    },
    {
      "relativePath": "B026218\\ativvaxy_vi.dat",
      "length": 325188,
      "sha256": "870622DCF18E92654E070D01666022D12938E24E537A15CB076E62D5BC335F96"
    },
    {
      "relativePath": "B026218\\ativvsva.dat",
      "length": 157144,
      "sha256": "E698410E1B8E5B2875AA8B4D01FE6E4F0BF354F40D92925C4E3503D7FD1EC208"
    },
    {
      "relativePath": "B026218\\ativvsvl.dat",
      "length": 204952,
      "sha256": "F35A4644D926183D38815207E338E7919CBDD2B1BDB8164074E47B74EA1CF150"
    },
    {
      "relativePath": "B026218\\detoured32.dll",
      "length": 14208,
      "sha256": "CCBE6FEA8BAD9BE1CBD55A8FB0AED38AD8D72FDC805857593E41A04D1C93334B"
    },
    {
      "relativePath": "B026218\\detoured64.dll",
      "length": 14208,
      "sha256": "9C96374EF97599F80AAA01D78D6900078B43ED08BA0A39B9F416EC0C27DE6E91"
    },
    {
      "relativePath": "B026218\\EEURestart.exe",
      "length": 531984,
      "sha256": "E89281A6CEF8F594BB5140DCCA27CEA4745A8697B681DF877E535D789A28237D"
    },
    {
      "relativePath": "B026218\\featuresync.dll",
      "length": 1138192,
      "sha256": "32889D3F587B4992498C70A23E5DC0A6FB90FD87EBA8AF488A6CA72DD412F1A0"
    },
    {
      "relativePath": "B026218\\GameManager32.dll",
      "length": 488976,
      "sha256": "8E4C7565450A4207542788C29C87ABAD57214DC45E7FBD51B68D1C21EA7EC43F"
    },
    {
      "relativePath": "B026218\\GameManager64.dll",
      "length": 641040,
      "sha256": "BCB9A240505CE58C183E12C62E62C58D797299AA29DC478085EB06D380A45629"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_10_sy1_10.bin",
      "length": 373296,
      "sha256": "8696B1C3952A7BA6FA58497B4C5A38B3BB2EE7C53369AEF3D580BD86FD623F23"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_20_sy1_20.bin",
      "length": 373296,
      "sha256": "C1E25B983F0ED64621D448263B5A6B1638D97F3CFC9C21C736CA301F6BAFBD49"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_30_sy1_30.bin",
      "length": 373296,
      "sha256": "174F422D1888B0F12CE16F509CF31CF751C557624EB4A2E45C2E99EA00F0FF82"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_40_sy1_40.bin",
      "length": 373296,
      "sha256": "65D3532608FD7EF591F5748927318AA291F8A16D9ADDFEDF617BC2FF8FBBE082"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_50_sy1_50.bin",
      "length": 373296,
      "sha256": "3E6DDC01FD90203B4E5770126727C9B9626F44A6B0B5BC5F35F7497066AAB629"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_60_sy1_60.bin",
      "length": 373296,
      "sha256": "05141D10A1C55F4EA49090C5B1C9A4F7D54AE9A5DB8A4DB6F60D2789A9036825"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_70_sy1_70.bin",
      "length": 373296,
      "sha256": "4FE9E51115B4DB5CD024DB40C5850302A1F5F32A92FD99719C601A49CE7E4756"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_80_sy1_80.bin",
      "length": 373296,
      "sha256": "C865948EB7C35E16F360419CF2621B6C6CDA98A24D6795A90855900794A574D4"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx1_90_sy1_90.bin",
      "length": 373296,
      "sha256": "8EC6B810BCDC4FE0D376DFBD392AD02F2DDEBE3D4D3FE89BFF8068B0BEA84AEF"
    },
    {
      "relativePath": "B026218\\H9_EASU_sx2_00_sy2_00.bin",
      "length": 373296,
      "sha256": "084942A2723ECDC8E4CF713A8CED91E8A19AA4E3F3BF6171DB4F5DB7CF7974DA"
    },
    {
      "relativePath": "B026218\\libamdenc64.so",
      "length": 1662960,
      "sha256": "375ADC2E4B1183C6D98C4620C7DB4E05E6E38FABDF10D057799C1698A8BEDDA6"
    },
    {
      "relativePath": "B026218\\regamdcomp.exe",
      "length": 301584,
      "sha256": "A8961E2BBCE9DC771B2C77CC08EEBADCF680807374188C3860997E75D7CF7C23"
    }
  ]
}
'@
        )
    }
    'lib\Build-Canonical-AmdGcfDat.ps1' = [ordered]@{
        SHA256 = '2AA4145BA26FD88F14BB160C6B8B73EFE2E5699D68E373B2DE505A95153E8B6B'
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

$OfficialDat = Join-Path $SourceRoot 'B026218\amdgcf.dat'
$ExpectedOfficialHash = '6552B360432EE95B3C85ADD28CB2551BBFB2497C6569D13378F750EF06527724'
$ExpectedCanonicalHash = 'AE63690CEE4D802E0F9CC8DE43207754068351F57C754BFDDF72049B4438C200'
$OfficialReleaseVersion = '26.10.21.05-260626a-202082C-AMD-Software-Adrenalin-Edition'
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
        SHA256 = '0175648198DCF78FCD2C4E2A621BA1E2FC04A5C042CD113185238D01671BEDAC'
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

$OfficialInf = Join-Path $SourceRoot 'u0202082.inf'
$ExpectedOfficialHash = '25F6724F57BA8CC9CF9C54EE6E6EF0DAF257F38ED0303B3F7227A40E69E9F6A1'
$ExpectedCanonicalHash = '73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034'

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
    -OldValue "CatalogFile=u0202082.cat`r`n" `
    -NewValue "CatalogFile=u0202082.cat`n" `
    -Description 'CatalogFile line ending'

$Text = Replace-ExactOnce `
    -Text $Text `
    -OldValue "DriverVer=06/28/2026, 32.0.31021.5001`r`n" `
    -NewValue "DriverVer=07/08/2026,32.0.31021.5001`n" `
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
        "AddReg = LegionGo_26_6_4_OEM_Settings`r`n"
    ) `
    -Description 'Phoenix Legion Go OEM AddReg insertion point'

$CopyInfLines = @(
    "CopyINF = .\amdxe\amdxe.inf`r`n"
    "CopyINF = .\amdfendr\amdfendr.inf`r`n"
    "CopyINF = .\amdcp\amdcp.inf`r`n"
    "CopyINF = .\amdfdans\amdfdans.inf`r`n"
    "CopyINF = .\amdocl\amdocl.inf`r`n"
    "CopyINF = .\amdwin\amdwin-u0202082.inf`r`n"
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
        'HKR,,ReleaseVersion,,"26.10.21.05-260626a-202082C-AMD-Software-Adrenalin-Edition"' +
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
    '[LegionGo_26_6_4_OEM_Settings]'
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

$ExpectedTextLength = 1080774

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
Write-Host 'Legion Go AMD 26.6.4 Toolkit' -ForegroundColor White
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
