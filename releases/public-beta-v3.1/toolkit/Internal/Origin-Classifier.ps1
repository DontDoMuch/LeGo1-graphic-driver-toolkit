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


function ConvertTo-DriverVersionSafe {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)
    try {
        if ([string]::IsNullOrWhiteSpace($Value)) { return [version]'0.0' }
        return [version]$Value
    } catch {
        return [version]'0.0'
    }
}

function Select-LegionGoExtensionAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$Extensions,
        [AllowNull()][string]$ActiveDriverVersion = ''
    )

    if (@($Extensions).Count -eq 0) { return $null }

    $Matching = @(
        $Extensions | Where-Object {
            [string](Get-OptionalPropertyValue -InputObject $_ -Name 'DriverVersion') -eq [string]$ActiveDriverVersion
        }
    )
    $Pool = if ($Matching.Count -gt 0) { $Matching } else { @($Extensions) }

    return @(
        $Pool |
        Sort-Object `
            @{Expression={
                $Raw=[string](Get-OptionalPropertyValue -InputObject $_ -Name 'DriverDateSort')
                if ($Raw -match '^[0-9]{8}$') { [int64]$Raw } else { [int64]0 }
            };Descending=$true}, `
            @{Expression={
                ConvertTo-DriverVersionSafe -Value ([string](Get-OptionalPropertyValue -InputObject $_ -Name 'DriverVersion'))
            };Descending=$true}, `
            @{Expression={[string](Get-OptionalPropertyValue -InputObject $_ -Name 'PublishedInf')};Descending=$false} |
        Select-Object -First 1
    )[0]
}

function Resolve-LegionGoAmdOrigin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Gpu,
        [AllowNull()]$CnMetadata,
        [AllowNull()][object[]]$LenovoExtensions = @(),
        [bool]$EmbeddedLenovoSemanticsPass = $false,
        [bool]$VerifiedPriorToolkitDisplayPass = $false,
        [bool]$VerifiedLenovoOemDisplayPass = $false,
        [bool]$AllowStructurallyScopedGo1Origin = $true,
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
    $ExpectedLenovoExtensionId = '{07A2A561-D001-4503-B239-EF2FE0379EFB}'

    if ($Extensions.Count -gt 0) {
        $NonExtensionClass = @(
            $Extensions | Where-Object {
                [string](Get-OptionalPropertyValue -InputObject $_ -Name 'ClassName') -ine 'Extension'
            }
        )
        if ($NonExtensionClass.Count -gt 0) {
            $Reasons.Add('At least one staged amduw23e package is not an Extension-class INF; refusing to treat it as removable Go 1 extension lineage material.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidExtensionStructure'
                OriginArchitecture = 'UnsupportedExtensionStructure'
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

        $MissingLineage = @(
            $Extensions | Where-Object {
                [string]::IsNullOrWhiteSpace([string](Get-OptionalPropertyValue -InputObject $_ -Name 'ExtensionId'))
            }
        )
        if ($MissingLineage.Count -gt 0) {
            $Reasons.Add('At least one staged amduw23e package has no parseable ExtensionId; refusing to guess which extension lineage is authoritative.')
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

        $Lineages = @(
            $Extensions |
            ForEach-Object {
                ([string](Get-OptionalPropertyValue -InputObject $_ -Name 'ExtensionId')).ToUpperInvariant()
            } |
            Select-Object -Unique
        )
        if ($Lineages.Count -ne 1) {
            $Reasons.Add(('Multiple distinct standalone Lenovo amduw23e ExtensionId lineages are present ({0}); origin is genuinely ambiguous.' -f ($Lineages -join ', ')))
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

        if ([string]$Lineages[0] -ne $ExpectedLenovoExtensionId) {
            $Reasons.Add(('Standalone amduw23e ExtensionId {0} is not the validated original-Legion-Go Lenovo lineage {1}.' -f [string]$Lineages[0],$ExpectedLenovoExtensionId))
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidForeignExtension'
                OriginArchitecture = 'UnsupportedExtensionLineage'
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

        $ForeignRows = @(
            $Extensions | Where-Object {
                -not [bool](Get-OptionalPropertyValue -InputObject $_ -Name 'TargetsLegionGo')
            }
        )
        if ($ForeignRows.Count -gt 0) {
            $Reasons.Add('At least one staged amduw23e package in the validated Lenovo ExtensionId lineage does not target the original Legion Go; refusing a broad extension cleanup.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidForeignExtension'
                OriginArchitecture = 'UnsupportedExtensionScope'
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

        $Extension = Select-LegionGoExtensionAuthority -Extensions $Extensions -ActiveDriverVersion $ActiveDriverVersion
        if ($Extensions.Count -gt 1) {
            $Warnings.Add(
                ('Multiple staged amduw23e package generations share the same validated Go 1 Lenovo-derived ExtensionId. Treating them as one versioned lineage; authoritative member={0} DriverVer={1}; all lineage members will be exported and removed for the merged target.' -f `
                    [string](Get-OptionalPropertyValue -InputObject $Extension -Name 'PublishedInf'), `
                    [string](Get-OptionalPropertyValue -InputObject $Extension -Name 'DriverVersion'))
            )
        }

        $UnknownSemanticRows = @(
            $Extensions | Where-Object {
                -not [bool](Get-OptionalPropertyValue -InputObject $_ -Name 'SemanticCompatible')
            }
        )
        if ($UnknownSemanticRows.Count -gt 0) {
            $Warnings.Add(
                ('{0} amduw23e lineage member(s) do not reproduce the toolkit''s known Lenovo semantic-marker profile. Their Extension class, exact Go 1 applicability, and shared Lenovo-derived ExtensionId are structurally valid, so semantic differences are preserved as provenance evidence rather than treated as an origin failure.' -f $UnknownSemanticRows.Count)
            )
        }
    }

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
    # for these exact prior-toolkit identities. The extension itself must still target the original Legion Go, belong to the validated
    # Lenovo-derived ExtensionId lineage, and be attached. Semantic-marker differences are advisory.
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
            $Warnings.Add(
                'The authoritative same-lineage Go 1 extension does not reproduce the toolkit''s known Lenovo semantic-marker profile. Because the active display is an exact prior toolkit base and the extension is structurally scoped to the exact Go 1 Lenovo-derived ExtensionId, the package is treated as structurally scoped Go 1 lineage material for export/removal rather than rejected.'
            )
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
                'AMD CN DriverVersion metadata differs from the standalone extension; CN metadata is supplemental and does not override the exact prior-toolkit display identity plus structurally scoped Go 1 extension lineage.'
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
            StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
            StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
            Reasons = $Reasons.ToArray()
            Warnings = $Warnings.ToArray()
        }
    }

    # Standalone-extension architecture.
    #
    # Safety boundary:
    # - the active target device is healthy AMD;
    # - every amduw23e row has already been proven Extension-class;
    # - every row targets the exact original Legion Go;
    # - every row belongs to the exact Lenovo-derived ExtensionId lineage.
    #
    # Semantic marker profiles and DriverVer equality are provenance signals,
    # not prerequisites for safely classifying a structurally scoped Go 1 lineage.
    # This behavior is not a compatibility/support claim for any external project.
    # The entire scoped lineage is exported before removal.
    if ($ExtState.Present) {
        if (-not $ExtState.Attached) {
            $Reasons.Add('The authoritative Go 1 amduw23e lineage member is not attached to the target GPU.')
            return [pscustomobject][ordered]@{
                OriginAcceptable = $false
                OriginKind = 'InvalidStandaloneExtension'
                OriginArchitecture = 'StandaloneExtension'
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

        $KnownLegacyShape = (
            $ExtState.SemanticCompatible -and
            ($ExtState.ActiveDriverVersionMatches -or $VerifiedLenovoOemDisplayPass)
        )

        if ($KnownLegacyShape) {
            if (-not $ExtState.ActiveDriverVersionMatches) {
                $Warnings.Add(
                    'Standalone Go 1 extension DriverVer differs from the active display. The active display is the exact frozen Lenovo OEM base and the extension is structurally scoped to the exact Lenovo-derived Go 1 lineage, so the mismatch is retained as provenance evidence rather than treated as a false origin failure.'
                )
            }
            if ([string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion)) {
                $Warnings.Add('AMD CN DriverVersion metadata is absent; CN metadata is supplemental for origin classification.')
            }
            elseif (-not $ExtState.CnDriverVersionMatches) {
                $Warnings.Add('AMD CN DriverVersion metadata differs from the standalone Go 1 extension; CN metadata is supplemental for origin classification.')
            }

            return [pscustomobject][ordered]@{
                OriginAcceptable = $true
                OriginKind = 'LegacyStandaloneExtension'
                OriginArchitecture = 'LegacyStandaloneExtension'
                ExtensionDisposition = 'ExportThenRemove'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        if ($AllowStructurallyScopedGo1Origin) {
            if (-not $ExtState.SemanticCompatible) {
                $Warnings.Add(
                    'The authoritative Go 1 extension has custom/unrecognized semantic contents. This is permitted for interoperability because its Extension class, exact Go 1 applicability, and Lenovo-derived ExtensionId lineage are structurally validated; the original package is exported before removal.'
                )
            }
            if (-not $ExtState.ActiveDriverVersionMatches) {
                $Warnings.Add(
                    'The authoritative Go 1 extension DriverVer differs from the active AMD display DriverVersion. This is permitted for a structurally scoped Go 1 origin; version mismatch is evidence, not proof of an invalid origin.'
                )
            }
            if ([string]::IsNullOrWhiteSpace($ExtState.CnDriverVersion)) {
                $Warnings.Add('AMD CN DriverVersion metadata is absent; this does not invalidate a structurally scoped compatible Go 1 origin.')
            }
            elseif (-not $ExtState.CnDriverVersionMatches) {
                $Warnings.Add('AMD CN DriverVersion metadata differs from the Go 1 extension; CN metadata is supplemental and does not override the live device/lineage scope.')
            }

            return [pscustomobject][ordered]@{
                OriginAcceptable = $true
                OriginKind = 'ScopedGo1StandaloneExtension'
                OriginArchitecture = 'ScopedGo1StandaloneExtension'
                ExtensionDisposition = 'ExportThenRemove'
                GpuHealthPass = $true
                EmbeddedLenovoSemanticsPass = $false
                StandaloneExtensionPresent = $true
                StandaloneExtensionSemanticPass = $ExtState.SemanticCompatible
                StandaloneExtensionVersionCoherent = $ExtState.ActiveDriverVersionMatches
                Reasons = $Reasons.ToArray()
                Warnings = $Warnings.ToArray()
            }
        }

        $Reasons.Add('A structurally valid Go 1 standalone extension origin is present, but compatible structurally scoped Go 1 origins are disabled by release policy.')
        return [pscustomobject][ordered]@{
            OriginAcceptable = $false
            OriginKind = 'UnscopedGo1OriginRejected'
            OriginArchitecture = 'ScopedGo1StandaloneExtension'
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

    if ($AllowStructurallyScopedGo1Origin) {
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
