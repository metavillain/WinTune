<#
.SYNOPSIS
  WinTune - debloat, de-crapify and tune Windows 11, with templates and per-tweak restore.

.EXAMPLE
  .\WinTune.ps1                         # GUI
  .\WinTune.ps1 -List                   # list tweaks + status (no admin needed)
  .\WinTune.ps1 -Apply base -DryRun     # preview what the Base template would do
  .\WinTune.ps1 -Apply base             # apply a template (by name or file name)
  .\WinTune.ps1 -Apply ai.copilot,ui.widgets   # apply individual tweak ids
  .\WinTune.ps1 -Restore ui.widgets     # restore one tweak
  .\WinTune.ps1 -Restore all            # restore everything WinTune changed
  .\WinTune.ps1 -SaveTemplate "Gaming" -Tweaks perf.gamedvr,apps.bing -Description "..."
  .\WinTune.ps1 -ExportDeploy .\Deploy-Base.ps1 -Tweaks base   # self-contained deployment script
  .\WinTune.ps1 -Image D:\mount -Apply base                    # apply to a mounted offline image
  .\WinTune.ps1 -Image D:\mount -Apply base -DryRun            # preview the offline changes
#>
[CmdletBinding()]
param(
    [switch]$List,
    [string[]]$Apply,
    [string[]]$Restore,
    [string]$SaveTemplate,
    [string[]]$Tweaks,
    [string]$Description = '',
    [switch]$DryRun,
    [switch]$NoRestorePoint,
    [switch]$DefaultProfile,
    [switch]$Force,
    [string]$ExportDeploy,
    [string]$Image
)

$cli      = $List -or $Apply -or $Restore -or $SaveTemplate -or $ExportDeploy -or $Image
$readOnly = $List -or $ExportDeploy -or ($DryRun -and $cli)
$isAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isCore   = $PSVersionTable.PSEdition -eq 'Core'   # Appx cmdlets need Windows PowerShell 5.1

if ($isCore -or (-not $isAdmin -and -not $readOnly)) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA')
    if (-not $cli) { $argList += @('-WindowStyle', 'Hidden') }
    $argList += @('-File', "`"$PSCommandPath`"")
    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) { if ($v) { $argList += "-$k" } }
        else { $argList += "-$k"; $argList += '"' + (@($v) -join ',') + '"' }
    }
    if ($cli) { $argList = @('-NoExit') + $argList }
    $sp = @{ FilePath = 'powershell.exe'; ArgumentList = $argList }
    if (-not $isAdmin -and -not $readOnly) { $sp.Verb = 'RunAs' }
    Start-Process @sp
    return
}

. (Join-Path $PSScriptRoot 'lib\Engine.ps1')

function Resolve-Ids {
    param([string[]]$Names)
    $Names = @($Names | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $catalog = Get-Catalog
    $ids = foreach ($n in $Names) {
        $tpl = Get-Templates | Where-Object { $_.Name -eq $n -or [IO.Path]::GetFileNameWithoutExtension($_.File) -eq $n } | Select-Object -First 1
        if ($tpl) { $tpl.Tweaks }
        elseif ($catalog | Where-Object { $_.Id -eq $n }) { $n }
        else { Write-Log "'$n' is not a template name or tweak id" 'WARN' }
    }
    @($ids | Select-Object -Unique)
}

if (-not $cli) {
    . (Join-Path $PSScriptRoot 'lib\Gui.ps1')
    Show-WinTuneGui
    return
}

if ($List) {
    $state = Read-State
    Get-Catalog | ForEach-Object {
        [pscustomobject]@{ Id = $_.Id; Category = $_.Category; Risk = $_.Risk; Status = (Get-TweakStatus $_ $state); Name = $_.Name }
    } | Format-Table -AutoSize
    Write-Host 'Templates:'
    Get-Templates | ForEach-Object { Write-Host ("  {0,-20} {1} tweaks  {2}" -f $_.Name, $_.Tweaks.Count, $_.Description) }
}
if ($SaveTemplate) { Save-Template -Name $SaveTemplate -Description $Description -TweakIds (Resolve-Ids $Tweaks) | Out-Null }
if ($ExportDeploy) { Export-DeployScript -TweakIds (Resolve-Ids $Tweaks) -Path $ExportDeploy -Name "WinTune deployment ($($Tweaks -join ','))" -SeedNewUsers:$DefaultProfile | Out-Null }
if ($Image)   { Invoke-WinTuneImage -MountPath $Image -Ids (Resolve-Ids $Apply) -DryRun:$DryRun }
elseif ($Apply) { Invoke-WinTune -Action Apply -Ids (Resolve-Ids $Apply) -DryRun:$DryRun -NoRestorePoint:$NoRestorePoint -DefaultProfile:$DefaultProfile -Force:$Force }
if ($Restore) {
    $ids = if ($Restore -contains 'all') { @((Read-State).Keys) } else { Resolve-Ids $Restore }
    Invoke-WinTune -Action Restore -Ids $ids -DryRun:$DryRun
}
