#requires -Version 5.1
<#
Reusable origin-classification contract for Legion Go AMD merged-driver releases.

Design goal:
- Legacy OEM/prior-toolkit states may legitimately depend on standalone amduw23e.
- A verified merged-toolkit display INF embeds the Lenovo-required semantics and
  therefore does not require standalone amduw23e.
- If a verified merged state is later contaminated by a stale amduw23e package,
  the stale extension is a rollback/export + cleanup target, not an origin-fatal
  CN DriverVersion metadata is supplemental; legacy coherence is established
  by the active display DriverVersion matching the attached Lenovo extension.
- PnP health is always authoritative. Code 43 can never classify as healthy.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-OptionalPropertyValue {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if ($null -eq $InputObject) { return $null }
    $Property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $null }
    return $Property.Value
}

function Test-LegionGoGpuHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Gpu,
        [switch]$AllowUnknownHasProblem
    )

    $Status = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'Status')
    $ProblemRaw = Get-OptionalPropertyValue -InputObject $Gpu -Name 'ProblemCode'
    $HasProblemRaw = Get-OptionalPropertyValue -InputObject $Gpu -Name 'HasProblem'

    $ProblemCode = if ($null -eq $ProblemRaw) { -1 } else { [int]$ProblemRaw }

    if ($Status -ne 'OK') { return $false }
    if ($ProblemCode -ne 0) { return $false }

    if ($null -eq $HasProblemRaw) {
        return [bool]$AllowUnknownHasProblem
    }

    return (-not [bool]$HasProblemRaw)
}

function Test-MicrosoftBasicOrigin {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Gpu)

    $Provider = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'Provider')
    $Service = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'Service')
    $InfName = [IO.Path]::GetFileName([string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'ActiveINF'))

    return (
        $Provider -match '^Microsoft' -and
        $Service -ieq 'BasicDisplay' -and
        ($InfName -ieq 'display.inf' -or $InfName -ieq 'basicdisplay.inf')
    )
}

function Test-AmdProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Gpu)
    $Provider = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'Provider')
    return [bool]($Provider -match 'AMD|Advanced Micro Devices')
}

function Get-DriverVersionFromInfText {
    [CmdletBinding()]
    param([AllowNull()][string]$InfText)

    if ([string]::IsNullOrWhiteSpace($InfText)) { return '' }

    $Match = [regex]::Match(
        $InfText,
        '(?im)^\s*DriverVer\s*=\s*[^,\r\n]+,\s*([0-9.]+)\s*$'
    )
    if (-not $Match.Success) { return '' }
    return [string]$Match.Groups[1].Value
}

function Test-EmbeddedLenovoSemantics {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$ActiveInfText,
        [string[]]$RequiredMarkers = @()
    )

    if ([string]::IsNullOrWhiteSpace($ActiveInfText)) { return $false }
    if ($RequiredMarkers.Count -eq 0) { return $false }

    foreach ($Marker in $RequiredMarkers) {
        if ([string]::IsNullOrWhiteSpace([string]$Marker)) { continue }
        if ($ActiveInfText.IndexOf(
            [string]$Marker,
            [StringComparison]::OrdinalIgnoreCase
        ) -lt 0) {
            return $false
        }
    }

    return $true
}

function Get-ExtensionSemanticState {
    [CmdletBinding()]
    param(
        [AllowNull()]$Extension,
        [AllowNull()]$CnMetadata,
        [AllowNull()][string]$ActiveDriverVersion = ''
    )

    if ($null -eq $Extension) {
        return [pscustomobject][ordered]@{
            Present = $false
            TargetsLegionGo = $false
            SemanticCompatible = $false
            Attached = $false
            DriverVersion = ''
            ActiveDriverVersion = [string]$ActiveDriverVersion
            ActiveDriverVersionMatches = $false
            CnDriverVersion = [string](Get-OptionalPropertyValue -InputObject $CnMetadata -Name 'DriverVersion')
            CnDriverVersionMatches = $false
        }
    }

    $Targets = [bool](Get-OptionalPropertyValue -InputObject $Extension -Name 'TargetsLegionGo')
    $Semantic = [bool](Get-OptionalPropertyValue -InputObject $Extension -Name 'SemanticCompatible')
    $AttachedRaw = Get-OptionalPropertyValue -InputObject $Extension -Name 'Attached'
    $Attached = if ($null -eq $AttachedRaw) { $true } else { [bool]$AttachedRaw }
    $ExtVersion = [string](Get-OptionalPropertyValue -InputObject $Extension -Name 'DriverVersion')
    $CnVersion = [string](Get-OptionalPropertyValue -InputObject $CnMetadata -Name 'DriverVersion')

    return [pscustomobject][ordered]@{
        Present = $true
        TargetsLegionGo = $Targets
        SemanticCompatible = $Semantic
        Attached = $Attached
        DriverVersion = $ExtVersion
        ActiveDriverVersion = [string]$ActiveDriverVersion
        ActiveDriverVersionMatches = (
            -not [string]::IsNullOrWhiteSpace($ExtVersion) -and
            -not [string]::IsNullOrWhiteSpace([string]$ActiveDriverVersion) -and
            $ExtVersion -eq [string]$ActiveDriverVersion
        )
        CnDriverVersion = $CnVersion
        CnDriverVersionMatches = (
            -not [string]::IsNullOrWhiteSpace($ExtVersion) -and
            -not [string]::IsNullOrWhiteSpace($CnVersion) -and
            $ExtVersion -eq $CnVersion
        )
    }
}

function Resolve-LegionGoAmdOrigin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Gpu,
        [AllowNull()]$CnMetadata,
        [AllowNull()][object[]]$LenovoExtensions = @(),
        [bool]$EmbeddedLenovoSemanticsPass = $false,
        [bool]$VerifiedPriorToolkitDisplayPass = $false,
        [bool]$AllowGenericThirdPartyDisplay = $true,
        [switch]$AllowUnknownHasProblem
    )

    $Reasons = New-Object System.Collections.Generic.List[string]
    $Warnings = New-Object System.Collections.Generic.List[string]

    $Healthy = Test-LegionGoGpuHealth -Gpu $Gpu -AllowUnknownHasProblem:$AllowUnknownHasProblem
    $AmdProvider = Test-AmdProvider -Gpu $Gpu
    $MicrosoftBasic = Test-MicrosoftBasicOrigin -Gpu $Gpu
    $ActiveDriverVersion = [string](Get-OptionalPropertyValue -InputObject $Gpu -Name 'DriverVersion')

    $Extensions = @($LenovoExtensions)
    $Extension = $null

    if ($Extensions.Count -gt 1) {
        $Reasons.Add('Multiple standalone Lenovo amduw23e packages are present; origin is ambiguous.')
        return [pscustomobject][ordered]@{
            OriginAcceptable = $false
            OriginKind = 'InvalidAmbiguousExtension'
            OriginArchitecture = 'Ambiguous'
            ExtensionDisposition = 'Reject'
            GpuHealthPass = $Healthy
            EmbeddedLenovoSemanticsPass = $EmbeddedLenovoSemanticsPass
            StandaloneExtensionPresent = $true
            StandaloneExtensionSemanticPass = $false
            StandaloneExtensionVersionCoherent = $false
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    if ($Extensions.Count -eq 1) { $Extension = $Extensions[0] }
    $ExtState = Get-ExtensionSemanticState -Extension $Extension -CnMetadata $CnMetadata -ActiveDriverVersion $ActiveDriverVersion

    if (-not $Healthy) {
        $Reasons.Add('GPU health contract failed: Status must be OK, ProblemCode must be 0, and HasProblem must be False.')
        return [pscustomobject][ordered]@{
            OriginAcceptable = $false
            OriginKind = 'InvalidUnhealthy'
            OriginArchitecture = 'Unhealthy'
            ExtensionDisposition = 'None'
            GpuHealthPass = $false
            EmbeddedLenovoSemanticsPass = $EmbeddedLenovoSemanticsPass
            StandaloneExtensionPresent = $ExtState.Present
            StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    if ($MicrosoftBasic) {
        if ($ExtState.Present) {
            $Warnings.Add('Standalone Lenovo extension is staged while Microsoft Basic Display is active; preserve/export it as rollback material before any cleanup.')
        }
        return [pscustomobject][ordered]@{
            OriginAcceptable = $true
            OriginKind = 'MicrosoftBasic'
            OriginArchitecture = 'MicrosoftBasic'
            ExtensionDisposition = if ($ExtState.Present) { 'ExportThenRemoveIfTargetReleaseMergesLenovoSemantics' } else { 'None' }
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $false
            StandaloneExtensionPresent = $ExtState.Present
            StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    if (-not $AmdProvider) {
        $Reasons.Add('Healthy display origin is neither supported Microsoft Basic nor AMD.')
        return [pscustomobject][ordered]@{
            OriginAcceptable = $false
            OriginKind = 'UnsupportedProvider'
            OriginArchitecture = 'Unsupported'
            ExtensionDisposition = 'Reject'
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $EmbeddedLenovoSemanticsPass
            StandaloneExtensionPresent = $ExtState.Present
            StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    # Merged-toolkit state is authoritative when the embedded Lenovo contract is
    # independently verified. A standalone extension is not required.
    if ($EmbeddedLenovoSemanticsPass) {
        if ($ExtState.Present) {
            if (-not $ExtState.TargetsLegionGo) {
                $Reasons.Add('A standalone amduw23e package exists but does not target the original Legion Go.')
                return [pscustomobject][ordered]@{
                    OriginAcceptable = $false
                    OriginKind = 'InvalidForeignExtension'
                    OriginArchitecture = 'MergedEmbedded'
                    ExtensionDisposition = 'Reject'
                    GpuHealthPass = $true
                    EmbeddedLenovoSemanticsPass = $true
                    StandaloneExtensionPresent = $true
                    StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
                    StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                    Reasons = $Reasons.ToArray()
                    Warnings = $Warnings.ToArray()
                }
            }

            if (-not $ExtState.ActiveDriverVersionMatches) {
                $Warnings.Add(
                    'Standalone Lenovo extension DriverVer differs from the active merged display DriverVersion. The active display independently passes the embedded Lenovo semantics contract, so the extension is stale cleanup material.'
                )
            }
            else {
                $Warnings.Add(
                    'Standalone Lenovo extension is redundant because Lenovo semantics are already embedded in the active merged display INF.'
                )
            }
            if (-not [string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion) -and -not $ExtState.CnDriverVersionMatches) {
                $Warnings.Add(
                    'AMD CN DriverVersion metadata differs from the standalone extension; CN metadata is supplemental and does not override the verified active display/embedded-semantics contract.'
                )
            }

            return [pscustomobject][ordered]@{
                OriginAcceptable = $true
                OriginKind = 'MergedEmbeddedWithStaleExtension'
                OriginArchitecture = 'MergedEmbedded'
                ExtensionDisposition = 'ExportThenRemoveStale'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $true
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        return [pscustomobject][ordered]@{
            OriginAcceptable = $true
            OriginKind = 'MergedEmbedded'
            OriginArchitecture = 'MergedEmbedded'
            ExtensionDisposition = 'None'
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $true
            StandaloneExtensionPresent = $false
            StandaloneExtensionSemanticPass = $false
            StandaloneExtensionVersionCoherent = $false
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    # Exact public 26.6.2 / 26.6.4 toolkit bases are recognized separately
    # from the current embedded-Lenovo contract. Those older toolkit releases
    # intentionally keep a standalone Lenovo amduw23e extension attached even
    # though its DriverVer remains at the Lenovo OEM generation. Therefore
    # version equality between the active display and extension is NOT required
    # for these exact prior-toolkit identities. The extension itself must still
    # target the original Legion Go, pass semantic validation, and be attached.
    if ($VerifiedPriorToolkitDisplayPass) {
        if (-not $ExtState.Present) {
            $Reasons.Add('The exact prior public toolkit display base is active but its required standalone Lenovo amduw23e extension is absent.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidPriorToolkitMissingExtension'
                OriginArchitecture = 'VerifiedPriorToolkitStandaloneExtension'
                ExtensionDisposition = 'Reject'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $false
                StandaloneExtensionSemanticPass = $false
                StandaloneExtensionVersionCoherent = $false
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if (-not $ExtState.TargetsLegionGo) {
            $Reasons.Add('The standalone amduw23e package beside the exact prior public toolkit display does not target the original Legion Go.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidForeignExtension'
                OriginArchitecture = 'VerifiedPriorToolkitStandaloneExtension'
                ExtensionDisposition = 'Reject'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if (-not $ExtState.SemanticCompatible) {
            $Reasons.Add('The standalone Lenovo extension required by the exact prior public toolkit display failed semantic validation.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidStandaloneExtension'
                OriginArchitecture = 'VerifiedPriorToolkitStandaloneExtension'
                ExtensionDisposition = 'Reject'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $false
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if (-not $ExtState.Attached) {
            $Reasons.Add('The standalone Lenovo extension required by the exact prior public toolkit display is not attached to the target GPU.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidStandaloneExtension'
                OriginArchitecture = 'VerifiedPriorToolkitStandaloneExtension'
                ExtensionDisposition = 'Reject'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $true
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if (-not $ExtState.ActiveDriverVersionMatches) {
            $Warnings.Add(
                'Standalone Lenovo extension DriverVer differs from the active exact prior-toolkit display DriverVersion. This is the expected public 26.6.2/26.6.4 architecture; the extension remains the Lenovo-semantic component and will be exported before the 26.7.1 merged transition removes it.'
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion) -and -not $ExtState.CnDriverVersionMatches) {
            $Warnings.Add(
                'AMD CN DriverVersion metadata differs from the standalone extension; CN metadata is supplemental and does not override the exact prior-toolkit display identity plus validated Lenovo extension.'
            )
        }

        return [pscustomobject][ordered]@{
            OriginAcceptable = $true
            OriginKind = 'VerifiedPriorToolkitWithStandaloneExtension'
            OriginArchitecture = 'VerifiedPriorToolkitStandaloneExtension'
            ExtensionDisposition = 'ExportThenRemoveForMergedTarget'
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $false
            StandaloneExtensionPresent = $true
            StandaloneExtensionSemanticPass = $true
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    # Legacy architecture: Lenovo semantics live in the attached extension.
    if ($ExtState.Present) {
        if (
            $ExtState.TargetsLegionGo -and
            $ExtState.SemanticCompatible -and
            $ExtState.Attached -and
            $ExtState.ActiveDriverVersionMatches
        ) {
            if ([string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion)) {
                $Warnings.Add('AMD CN DriverVersion metadata is absent; legacy Lenovo extension coherence is validated against the active display DriverVersion.')
            }
            elseif (-not $ExtState.CnDriverVersionMatches) {
                $Warnings.Add('AMD CN DriverVersion metadata differs from the standalone Lenovo extension; CN metadata is supplemental for legacy-origin classification.')
            }
            return [pscustomobject][ordered]@{
                OriginAcceptable = $true
                OriginKind = 'LegacyStandaloneExtension'
                OriginArchitecture = 'LegacyStandaloneExtension'
                ExtensionDisposition = 'ExportThenRemove'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $true
                StandaloneExtensionVersionCoherent = $true
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if (-not $ExtState.TargetsLegionGo) { $Reasons.Add('Standalone Lenovo extension does not target the original Legion Go.') }
        if (-not $ExtState.SemanticCompatible) { $Reasons.Add('Standalone Lenovo extension failed semantic validation.') }
        if (-not $ExtState.Attached) { $Reasons.Add('Standalone Lenovo extension is not attached to the target GPU.') }
        if (-not $ExtState.ActiveDriverVersionMatches) { $Reasons.Add('Standalone Lenovo extension DriverVer does not match the active AMD display DriverVersion.') }
        if ([string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion)) {
            $Warnings.Add('AMD CN DriverVersion metadata is absent; legacy Lenovo extension coherence is validated against the active display DriverVersion.')
        }
        elseif (-not $ExtState.CnDriverVersionMatches) {
            $Warnings.Add('AMD CN DriverVersion metadata differs from the standalone Lenovo extension; CN metadata is supplemental for legacy-origin classification.')
        }

        return [pscustomobject][ordered]@{
            OriginAcceptable = $false
            OriginKind = 'InvalidStandaloneExtension'
            OriginArchitecture = 'LegacyStandaloneExtension'
            ExtensionDisposition = 'Reject'
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $false
            StandaloneExtensionPresent = $true
            StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    if ($AllowGenericThirdPartyDisplay) {
        $Warnings.Add('Healthy AMD origin has neither verified embedded Lenovo semantics nor a validated standalone Lenovo extension. Accepting only as generic ThirdPartyDisplay by explicit release policy.')
        return [pscustomobject][ordered]@{
            OriginAcceptable = $true
            OriginKind = 'ThirdPartyDisplay'
            OriginArchitecture = 'GenericAmd'
            ExtensionDisposition = 'None'
            GpuHealthPass = $true
            EmbeddedLenovoSemanticsPass = $false
            StandaloneExtensionPresent = $false
            StandaloneExtensionSemanticPass = $false
            StandaloneExtensionVersionCoherent = $false
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    $Reasons.Add('Generic AMD origin is not allowed by this release policy.')
    return [pscustomobject][ordered]@{
        OriginAcceptable = $false
        OriginKind = 'UnsupportedGenericAmd'
        OriginArchitecture = 'GenericAmd'
        ExtensionDisposition = 'Reject'
        GpuHealthPass = $true
        EmbeddedLenovoSemanticsPass = $false
        StandaloneExtensionPresent = $false
        StandaloneExtensionSemanticPass = $false
        StandaloneExtensionVersionCoherent = $false
        Reasons = $Reasons.ToArray()
        Warnings = $Warnings.ToArray()
    }
}

function Add-OriginClassificationToWorkflowState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Classification
    )

    $Fields = [ordered]@{
        PreviousOriginKind = [string]$Classification.OriginKind
        PreviousOriginArchitecture = [string]$Classification.OriginArchitecture
        PreviousExtensionDisposition = [string]$Classification.ExtensionDisposition
        EmbeddedLenovoSemanticsPass = [bool]$Classification.EmbeddedLenovoSemanticsPass
        PreviousGpuHealthPass = [bool]$Classification.GpuHealthPass
        PreviousStandaloneExtensionPresent = [bool]$Classification.StandaloneExtensionPresent
        PreviousStandaloneExtensionSemanticPass = [bool]$Classification.StandaloneExtensionSemanticPass
        PreviousStandaloneExtensionVersionCoherent = [bool]$Classification.StandaloneExtensionVersionCoherent
    }

    foreach ($Pair in $Fields.GetEnumerator()) {
        $Property = $State.PSObject.Properties[$Pair.Key]
        if ($null -eq $Property) {
            $State | Add-Member -NotePropertyName $Pair.Key -NotePropertyValue $Pair.Value
        }
        else {
            $Property.Value = $Pair.Value
        }
    }

    return $State
}
