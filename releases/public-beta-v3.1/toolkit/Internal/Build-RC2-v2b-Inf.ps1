#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OfficialInfPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ExpectedOfficialHash='4A6C871BDF2287398E8BFC23511BBA2408A47D7874E3C5C5DE0A1575E21E754F'
$ExpectedIntermediateHash='A5FA34998C1B181A682727EB10EE18531EB2B5873AD8B40F0D104C6738ED0E83'
$ExpectedFinalHash='9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409'
function Hash([string]$P){ return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant() }
function Replace-Exact([string]$Text,[string]$Old,[string]$New,[int]$ExpectedCount=1){
    $Count=([regex]::Matches($Text,[regex]::Escape($Old))).Count
    if($Count -ne $ExpectedCount){throw "Replacement count mismatch. Expected=$ExpectedCount Actual=$Count Old=$Old"}
    return $Text.Replace($Old,$New)
}
function Replace-InSection([string]$Text,[string]$Section,[string]$Old,[string]$New){
    $Start=$Text.IndexOf($Section,[StringComparison]::Ordinal)
    if($Start-lt0){throw "Section not found: $Section"}
    $End=$Text.IndexOf("`r`n[",$Start+$Section.Length,[StringComparison]::Ordinal)
    if($End-lt0){throw "Section end not found: $Section"}
    $Chunk=$Text.Substring($Start,$End-$Start)
    if(([regex]::Matches($Chunk,[regex]::Escape($Old))).Count-ne1){throw "Section replacement count mismatch: $Section / $Old"}
    $Chunk=$Chunk.Replace($Old,$New)
    return $Text.Substring(0,$Start)+$Chunk+$Text.Substring($End)
}
if((Hash $OfficialInfPath)-ne $ExpectedOfficialHash){throw 'Official INF hash mismatch.'}
$Bytes=[IO.File]::ReadAllBytes($OfficialInfPath)
$Text=[Text.Encoding]::GetEncoding(1252).GetString($Bytes)
if(-not $Text.EndsWith("`r`n")){throw 'Official INF newline contract changed.'}
$Text=Replace-Exact $Text 'DriverVer=07/24/2026, 32.0.31035.1003' 'DriverVer=07/28/2026,32.0.31035.1003'
$Anchor='"%AMD15BF.1%" = ati2mtag_Phoenix, PCI\VEN_1002&DEV_15BF&SUBSYS_16771025&REV_C1'
$Legion='"%AMD15BF.1%" = ati2mtag_Phoenix, PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$Text=Replace-Exact $Text $Anchor ($Anchor+"`r`n"+$Legion)
$Text=Replace-InSection $Text '[ati2mtag_Phoenix]' 'DelReg = ati2mtag_RemoveDeviceSettings' ("DelReg = ati2mtag_RemoveDeviceSettings`r`nAddReg = LegionGo_26_7_1_OEM_Settings")
$Text=Replace-Exact $Text "CopyINF = .\amdcp\amdcp.inf`r`n" '' 10
$Text=Replace-Exact $Text "CopyINF=amduw23e.inf`r`n" '' 10
$Comp='[ati2mtag_Phoenix.Components]'+"`r`n"+'AddComponent = AMDCP,,AMDCPComponent'
$Text=Replace-Exact $Text $Comp ('[ati2mtag_Phoenix.Components]'+"`r`n"+'AddComponent = AMDUWP,,AMDUWPComponent'+"`r`n"+'AddComponent = AMDCP,,AMDCPComponent')
$Fd='[FDANSComponent]'
$Text=Replace-Exact $Text $Fd ('[AMDUWPComponent]'+"`r`n"+'ComponentIDs=VID1002&PID0001'+"`r`n`r`n"+$Fd)
$OemLines = @(
    '[LegionGo_26_7_1_OEM_Settings]'
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
)
$Text=$Text+"`r`n`r`n"+(($OemLines)-join "`r`n")
$Parent=Split-Path -Parent $OutputPath; New-Item -ItemType Directory -Path $Parent -Force|Out-Null
$Unicode=New-Object Text.UnicodeEncoding -ArgumentList $false,$true
[IO.File]::WriteAllText($OutputPath,$Text,$Unicode)
if((Hash $OutputPath)-ne $ExpectedIntermediateHash){throw "Intermediate RC2 INF did not reproduce exact A5FA hash: $(Hash $OutputPath)"}
$Text=[Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($OutputPath),2,[IO.File]::ReadAllBytes($OutputPath).Length-2)
$Text=Replace-Exact $Text $Legion '"%AMD15BF.1%" = ati2mtag_Phoenix_LegionGo, PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
$Text=Replace-InSection $Text '[ati2mtag_Phoenix]' 'AddReg = LegionGo_26_7_1_OEM_Settings' '; RC2 v2: Legion Go OEM settings moved to dedicated HWID DDInstall'
$FamilyLines = @(
    '; ============================================================'
    '; Legion Go exact-HWID merged DDInstall family'
    '; Sealed RC2 + compact Lenovo-required delta'
    '; AMD defaults preserved for ColorVibrance and RS overlay'
    '; ============================================================'
    '[ati2mtag_Phoenix_LegionGo]'
    'FeatureScore=CF'
    'CopyFiles=DS.Graphics'
    'CopyFiles=DS.Graphics2'
    'CopyFiles=DS.System32'
    'CopyFiles=DS.SysWow64'
    'CopyFiles = R300.AMDKMPFD'
    'AddReg = ati2mtag_SoftwareDeviceSettings'
    'AddReg = ati2mtag_NAVIA_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Phoenix_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Post_EG'
    'AddReg = ati2mtag_MultiUVD_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Mobile_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Mobile_NONPX_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Mobile_PX_SoftwareDeviceSettings'
    'AddReg = ati2mtag_Mobile_PXAA_SoftwareDeviceSettings'
    'AddReg = ati2mtag_PXAA'
    'AddReg = ati2mtag_Manhattan_PX'
    'AddReg = ati2mtag_PXAA_IGPU_Only_2ID'
    'AddReg = ati2mtag_DSUMD'
    'AddReg = ati2mtag_DSUMD_GFX10_3Plus'
    'AddReg = LegionGo_26_7_1_Lenovo_Delta'
    'DelReg = ati2mtag_RemoveDeviceSettings'
    'AddReg = LegionGo_26_7_1_OEM_Settings'
    'AddReg = MFTENCRegister'
    'AddReg = MFTDECRegister'
    'AddReg = MFTMJPEGRegister'
    'AddReg = MFTHEVCRegister'
    'CopyINF = .\amdxe\amdxe.inf'
    'CopyINF = .\amdfendr\amdfendr.inf'
    'AddPowerSetting = PowerSlider'
    'CopyINF = .\amdfdans\amdfdans.inf'
    'CopyFiles = R300.MFTAV1'
    'AddReg = MFTAV1Register'
    'CopyINF = .\amdocl\amdocl.inf'
    'CopyINF = .\amdwin\amdwin-u0202643.inf'
    'CopyINF = .\amdogl\amdogl.inf'
    'CopyINF = .\amdvlk\amdvlk.inf'
    ''
    ''
    '[ati2mtag_Phoenix_LegionGo.Services]'
    'AddService = amduw23g-202643-a144ae36, 0x00000002, ati2mtag_KMD_DS, R300_EventLog_Inst'
    'AddService = AMD External Events Utility, 0x00000800, Ati2evxx_Generic_Service_Inst, Ati2evxx_EventLog_Inst, APPLICATION, ATIeRecord'
    ''
    ''
    '[ati2mtag_Phoenix_LegionGo.HW]'
    'AddReg = atikmdag_MSI_HardwareDeviceSettings'
    ''
    ''
    '[ati2mtag_Phoenix_LegionGo.Software]'
    ''
    ''
    '[ati2mtag_Phoenix_LegionGo.Components]'
    'AddComponent = AMDUWP,,AMDUWPComponent'
    'AddComponent = AMDCP,,AMDCPComponent'
    'AddComponent = AMDFDANS,,FDANSComponent'
    'AddComponent = AMDOCL,,AMDOCLComponent'
    'AddComponent = AMDWIN,,AMDWINComponent'
    'AddComponent = AMDOGL,,AMDOGLComponent'
    'AddComponent = AMDVLK,,AMDVLKComponent'
    ''
    ''
    '[ati2mtag_Phoenix_LegionGo.GeneralConfigData]'
    'MaximumDeviceMemoryConfiguration=128'
    'MaximumNumberOfDevices=4'
    ''
    ''
    '[LegionGo_26_7_1_Lenovo_Delta]'
    'HKR,,DALNonStandardModesBCD5,%REG_BINARY%,07,20,12,80,00,00,00,00,08,00,12,80,00,00,00,00,09,00,16,00,00,00,00,00,10,00,16,00,00,00,00,00,10,80,19,20,00,00,00,00,12,00,19,20,00,00,00,00,14,40,25,60,00,00,00,00'
    'HKR,,DALRestrictedModesBCD5,%REG_BINARY%,16,00,12,00,00,00,00,00,12,80,10,24,00,00,00,00'
    'HKR,,HotkeysDisabled,%REG_DWORD%,0x1'
    'HKR,,dvr_ui_component_na,%REG_SZ%,true'
    'HKR,,DFPFreeSyncDefault,%REG_DWORD%,1'
    'HKR,,PP_WaitOnRegisterTimeout,%REG_DWORD%,0x2710'
    'HKR,,AllowWebContent,%REG_SZ%,false'
    'HKR,,LogoUrl,%REG_SZ%,hide'
    'HKR,,SystemTray,%REG_SZ%,false'
    'HKR,,DALRULE_ALLOWMONITORRANGELIMITMODESCRT,%REG_DWORD%,0'
    'HKR,,ToggleRsHotkey,%REG_SZ%,none'
    'HKR,,LCDFreeSyncDefault,%REG_DWORD%,0x7'
    'HKR,,PP_UserVariBrightLevel,%REG_DWORD%,2'
    'HKR,,Dal_UserVariBrightLevel,%REG_DWORD%,2'
    ''
    ''
)
$Family=(($FamilyLines)-join "`r`n")
$Text=Replace-Exact $Text '[Strings]' ("`r`n"+$Family+'[Strings]')
[IO.File]::WriteAllText($OutputPath,$Text,$Unicode)
$Final=Hash $OutputPath
if($Final-ne $ExpectedFinalHash){throw "Final v2b INF reconstruction failed. Expected=$ExpectedFinalHash Actual=$Final"}
[pscustomobject]@{Path=$OutputPath;SHA256=$Final;Length=(Get-Item $OutputPath).Length;Exact=$true}
