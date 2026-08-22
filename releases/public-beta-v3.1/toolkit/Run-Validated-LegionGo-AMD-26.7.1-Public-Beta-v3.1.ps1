#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$Launcher = Join-Path $Root 'Install-LegionGo-AMD-26.7.1.ps1'
$Files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1' | Where-Object { $_.FullName -ne $PSCommandPath })
$Failures = 0
$ParserEvidencePath = Join-Path (Join-Path $env:USERPROFILE 'Downloads') ('LegionGo-AMD-26.7.1-Public-Beta-v3.1-Parser-Gate-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$ParserTranscriptStarted = $false
try { Start-Transcript -LiteralPath $ParserEvidencePath -Force | Out-Null; $ParserTranscriptStarted = $true } catch {}

Write-Host '========================================================================'
Write-Host ' LEGION GO AMD 26.7.1 RC2zp - INDEPENDENT PARSER GATE'
Write-Host '========================================================================'

function Get-ParserGateBar([int]$Percent) {
    $Width=28
    if($Percent-lt0){$Percent=0};if($Percent-gt100){$Percent=100}
    $Filled=[int][Math]::Floor(($Percent/100.0)*$Width)
    return ('['+('#'*$Filled)+('-'*($Width-$Filled))+']')
}
$ParserIndex=0
$ParserTotal=$Files.Count
Write-Host ("[PROGRESS] {0}   0% PARSER GATE :: 0/{1} scripts" -f (Get-ParserGateBar 0),$ParserTotal)

foreach ($File in $Files) {
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors) | Out-Null
    if (@($Errors).Count -eq 0) {
        Write-Host ('[PASS] {0}' -f $File.Name) -ForegroundColor Green
    }
    else {
        $Failures++
        Write-Host ('[FAIL] {0} :: Errors={1}' -f $File.Name,@($Errors).Count) -ForegroundColor Red
        foreach ($E in @($Errors)) {
            Write-Host ('       Line {0}, column {1}: {2}' -f $E.Extent.StartLineNumber,$E.Extent.StartColumnNumber,$E.Message) -ForegroundColor Red
        }
    }
    $ParserIndex++
    $ParserPercent=if($ParserTotal-gt0){[int][Math]::Floor(($ParserIndex*100.0)/$ParserTotal)}else{100}
    Write-Host ("[PROGRESS] {0} {1,3}% PARSER GATE :: {2}/{3} scripts" -f (Get-ParserGateBar $ParserPercent),$ParserPercent,$ParserIndex,$ParserTotal)
    try{Write-Progress -Activity 'Independent PowerShell parser gate' -Status ("{0}/{1} scripts" -f $ParserIndex,$ParserTotal) -PercentComplete $ParserPercent}catch{}
}
try{Write-Progress -Activity 'Independent PowerShell parser gate' -Completed}catch{}

if ($Failures -ne 0) {
    if ($ParserTranscriptStarted) { try { Stop-Transcript | Out-Null } catch {}; $ParserTranscriptStarted = $false }
    Write-Host ''
    Write-Host ('[EVIDENCE] Parser failure transcript: {0}' -f $ParserEvidencePath) -ForegroundColor Yellow
    Write-Host '[BLOCKED] Launcher was NOT started; no driver state was changed.' -ForegroundColor Red
    try { [void](Read-Host 'Press Enter to close') } catch {}
    exit 1
}

if ($ParserTranscriptStarted) { try { Stop-Transcript | Out-Null } catch {}; $ParserTranscriptStarted = $false }
Remove-Item -LiteralPath $ParserEvidencePath -Force -ErrorAction SilentlyContinue
Write-Host '[PASS] Independent parser gate complete. Starting launcher.' -ForegroundColor Green
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Launcher
exit $LASTEXITCODE
