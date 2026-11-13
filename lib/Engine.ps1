# WinTune engine: catalog, templates, state, apply and restore.

# The bundled single-file .exe prepends $script:EmbeddedCatalog / $script:EmbeddedTemplates before this
# code; keep them if already set, otherwise default to "run from the source files on disk".
if (-not (Get-Variable -Scope Script -Name EmbeddedCatalog   -ErrorAction SilentlyContinue)) { $script:EmbeddedCatalog   = $null }
if (-not (Get-Variable -Scope Script -Name EmbeddedTemplates -ErrorAction SilentlyContinue)) { $script:EmbeddedTemplates = @{} }
if (-not (Get-Variable -Scope Script -Name EmbeddedIcon      -ErrorAction SilentlyContinue)) { $script:EmbeddedIcon      = $null }
if (-not (Get-Variable -Scope Script -Name EmbeddedEngine    -ErrorAction SilentlyContinue)) { $script:EmbeddedEngine    = $null }

$script:AppRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { $null }
$script:DataDir = Join-Path $env:ProgramData 'WinTune'
$script:StateFile = Join-Path $script:DataDir 'state.json'
$script:LogDir  = Join-Path $script:DataDir 'logs'
$script:CatalogFile = if ($script:AppRoot) { Join-Path $script:AppRoot 'data\tweaks.psd1' } else { $null }
$script:CustomFile  = Join-Path $script:DataDir 'custom-tweaks.json'   # user-created registry tweaks
$script:SettingsFile = Join-Path $script:DataDir 'settings.json'       # small UI prefs (e.g. dark mode)
# Dev: templates live beside the source. Bundle (no source on disk): user templates live under ProgramData.
$script:TemplateDir = if ($script:AppRoot -and (Test-Path (Join-Path $script:AppRoot 'templates'))) {
    Join-Path $script:AppRoot 'templates'
} else { Join-Path $script:DataDir 'templates' }
$script:LogSink   = $null      # optional scriptblock the GUI sets to receive log lines
$script:AppxCache = $null
$script:CatalogCache = $null
$script:ErrorCount = 0         # running count of logged errors, used to tell which tweaks failed
$script:LastSummary = $null    # result of the most recent Invoke-WinTune run
$script:Build     = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber

foreach ($d in $script:DataDir, $script:LogDir, $script:TemplateDir) {
    if (-not (Test-Path $d)) { try { New-Item -ItemType Directory -Path $d -Force | Out-Null } catch {} }
}

# ---------------------------------------------------------------- logging
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if ($Level -eq 'ERROR') { $script:ErrorCount++ }
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    # Only write to the console in CLI mode. In the GUI (and the compiled -noConsole exe) a LogSink
    # is set, and Write-Host there would surface as a message box per line - so route it to the sink only.
    if ($script:LogSink) { & $script:LogSink $line } else { Write-Host $line }
    try { Add-Content -Path (Join-Path $script:LogDir ((Get-Date -Format 'yyyyMMdd') + '.log')) -Value $line -ErrorAction Stop } catch {}
}

function Has { param($Hash, [string]$Key) $Hash -is [hashtable] -and $Hash.ContainsKey($Key) -and $null -ne $Hash[$Key] }

# ---------------------------------------------------------------- small UI settings
function Get-Setting {
    param([string]$Name, $Default = $null)
    if (-not (Test-Path $script:SettingsFile)) { return $Default }
    try { $s = Get-Content -Raw -Path $script:SettingsFile | ConvertFrom-Json; if ($s.PSObject.Properties.Name -contains $Name) { return $s.$Name } } catch {}
    $Default
}
function Save-Setting {
    param([string]$Name, $Value)
    $s = [ordered]@{}
    if (Test-Path $script:SettingsFile) { try { (Get-Content -Raw -Path $script:SettingsFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $s[$_.Name] = $_.Value } } catch {} }
    $s[$Name] = $Value
    try { ConvertTo-Json -InputObject $s | Set-Content -Path $script:SettingsFile -Encoding UTF8 } catch {}
}

# ---------------------------------------------------------------- catalog & templates
function Get-Catalog {
    if ($script:CatalogCache) { return $script:CatalogCache }
    if ($script:CatalogFile -and (Test-Path $script:CatalogFile)) {
        $base = @((Import-PowerShellDataFile -Path $script:CatalogFile).Tweaks)
    } elseif ($script:EmbeddedCatalog) {
        $tmp = Join-Path $script:DataDir '_catalog.psd1'
        Set-Content -Path $tmp -Value $script:EmbeddedCatalog -Encoding UTF8
        $base = @((Import-PowerShellDataFile -Path $tmp).Tweaks)
    } else { throw 'WinTune tweak catalog not found.' }
    $script:CatalogCache = @($base + (Get-CustomTweaks))
    $script:CatalogCache
}

# User-created registry tweaks live in a JSON file under ProgramData and merge into the catalog.
function ConvertFrom-CustomJson {
    param($J)
    $reg = foreach ($r in @($J.reg)) { @{ P = $r.path; T = $r.type; V = @{ "$($r.name)" = $r.value } } }
    @{ Id = $J.id; Name = $J.name; Category = $(if ($J.category) { $J.category } else { 'Custom' })
       Risk = $(if ($J.risk) { $J.risk } else { 'med' }); Desc = $J.desc; Custom = $true; Reg = @($reg) }
}
function Get-CustomTweaks {
    if (-not (Test-Path $script:CustomFile)) { return @() }
    try { $j = Get-Content -Raw -Path $script:CustomFile | ConvertFrom-Json } catch { return @() }
    @(@($j) | Where-Object { $_ } | ForEach-Object { ConvertFrom-CustomJson $_ })
}
function Save-CustomTweak {
    param([string]$Name, [string]$Category, [string]$Risk, [string]$Desc, [string]$RegPath, [string]$ValueName, [string]$Type, $Value)
    if (-not $Name)    { throw 'A name is required.' }
    if (-not $RegPath) { throw 'A registry path is required.' }
    if ($RegPath -notmatch '^HK(LM|CU):\\') { throw 'Registry path must start with HKLM:\ or HKCU:\' }
    if (-not $ValueName) { $ValueName = '(default)' }
    if ($Type -in 'DWord', 'QWord') { $Value = [int64]$Value }
    $slug = ($Name -replace '[^\w]', '').ToLower(); if (-not $slug) { $slug = 'tweak' }
    $entry = [ordered]@{ id = "custom.$slug.$(Get-Random -Maximum 99999)"; name = $Name
                         category = $(if ($Category) { $Category } else { 'Custom' }); risk = $(if ($Risk) { $Risk } else { 'med' })
                         desc = $Desc; reg = @(@{ path = $RegPath; type = $Type; name = $ValueName; value = $Value }) }
    $all = @()
    if (Test-Path $script:CustomFile) { try { $all = @(Get-Content -Raw -Path $script:CustomFile | ConvertFrom-Json) } catch {} }
    $all += [pscustomobject]$entry
    ConvertTo-Json -InputObject @($all) -Depth 6 | Set-Content -Path $script:CustomFile -Encoding UTF8
    $script:CatalogCache = $null
    Write-Log "Added custom tweak '$Name' -> $($entry.id)"
    $entry.id
}
function Remove-CustomTweak {
    param([string]$Id)
    if (-not (Test-Path $script:CustomFile)) { return }
    $all = @(Get-Content -Raw -Path $script:CustomFile | ConvertFrom-Json) | Where-Object { $_.id -ne $Id }
    ConvertTo-Json -InputObject @($all) -Depth 6 | Set-Content -Path $script:CustomFile -Encoding UTF8
    $script:CatalogCache = $null
    Write-Log "Removed custom tweak $Id"
}

function Get-Tweak { param([string]$Id) Get-Catalog | Where-Object { $_.Id -eq $Id } | Select-Object -First 1 }

function ConvertTo-TemplateObj { param($Json, $File, [bool]$ForceBuiltIn, [string]$Key)
    $order = if ($null -ne $Json.order) { [int]$Json.order } else { 100 }
    [pscustomobject]@{ Name = $Json.name; Description = $Json.description; Tweaks = @($Json.tweaks)
                       File = $File; BuiltIn = ($ForceBuiltIn -or [bool]$Json.builtIn); Order = $order; Key = $Key }
}

function Get-Templates {
    $onDisk = @()
    if (Test-Path $script:TemplateDir) {
        $onDisk = @(Get-ChildItem -Path $script:TemplateDir -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
            try { ConvertTo-TemplateObj (Get-Content -Raw $_.FullName | ConvertFrom-Json) $_.FullName $false $_.BaseName.ToLower() }
            catch { Write-Log "Skipping bad template $($_.Name): $_" 'WARN' }
        })
    }
    $diskKeys = @($onDisk | ForEach-Object { $_.Key })
    $embedded = @(foreach ($k in $script:EmbeddedTemplates.Keys) {
        if ($diskKeys -contains $k) { continue }
        try { ConvertTo-TemplateObj ($script:EmbeddedTemplates[$k] | ConvertFrom-Json) $null $true $k } catch {}
    })
    @($onDisk + $embedded) | Sort-Object Order, Name
}

function Save-Template {
    param([string]$Name, [string]$Description, [string[]]$TweakIds)
    $safe = ($Name -replace '[^\w\- ]', '').Trim() -replace ' ', '-'
    if (-not $safe) { throw 'Template name is empty.' }
    if ($script:EmbeddedTemplates.ContainsKey($safe.ToLower())) { throw "'$Name' is the name of a built-in template. Choose another name." }
    $file = Join-Path $script:TemplateDir ($safe.ToLower() + '.json')
    if (Test-Path $file) {
        $existing = Get-Content -Raw $file | ConvertFrom-Json
        if ($existing.builtIn) { throw "'$Name' would overwrite a built-in template. Choose another name." }
    }
    $obj = [ordered]@{ name = $Name; description = $Description; created = (Get-Date).ToString('s'); tweaks = @($TweakIds) }
    ConvertTo-Json -InputObject $obj -Depth 5 | Set-Content -Path $file -Encoding UTF8
    Write-Log "Saved template '$Name' ($($TweakIds.Count) tweaks) -> $file"
    $file
}

function Remove-Template {
    param([string]$File)
    $j = Get-Content -Raw $File | ConvertFrom-Json
    if ($j.builtIn) { throw 'Built-in templates cannot be deleted.' }
    Remove-Item -LiteralPath $File -Force
    Write-Log "Deleted template '$($j.name)'"
}

# ---------------------------------------------------------------- state (what we changed + original values)
function Read-State {
    $s = [ordered]@{}
    if (Test-Path $script:StateFile) {
        try {
            $o = Get-Content -Raw $script:StateFile | ConvertFrom-Json
            foreach ($p in $o.PSObject.Properties) { $s[$p.Name] = $p.Value }
        } catch { Write-Log "State file unreadable: $_" 'ERROR' }
    }
    $s
}

function Save-State { param($State) ConvertTo-Json -InputObject $State -Depth 10 | Set-Content -Path $script:StateFile -Encoding UTF8 }

# ---------------------------------------------------------------- registry helpers
function Expand-Reg {
    param($Tweak)
    foreach ($r in @($Tweak.Reg)) {
        if (-not $r) { continue }
        foreach ($k in $r.V.Keys) { [pscustomobject]@{ Path = $r.P; Name = $k; Type = $r.T; Value = $r.V[$k] } }
    }
}

function Get-RegCurrent {
    param([string]$Path, [string]$Name)
    $o = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Value = $null; Type = $null }
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]$o }
    $key = Get-Item -LiteralPath $Path
    if ($Name -eq '(default)') {
        $o.Exists = $true; $o.Value = $key.GetValue(''); $o.Type = 'String'
    } elseif ($key.GetValueNames() -contains $Name) {
        $o.Exists = $true
        $o.Value  = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
        $o.Type   = $key.GetValueKind($Name).ToString()
    }
    [pscustomobject]$o
}

function Test-AccessDenied { param($Err) $Err.Exception -is [UnauthorizedAccessException] -or $Err.Exception -is [System.Security.SecurityException] -or "$($Err.Exception.Message)" -match 'unauthori[sz]ed|denied' }

function Set-RegValue {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        if ($Name -eq '(default)') { Set-Item -LiteralPath $Path -Value ([string]$Value) -ErrorAction Stop; return }
        $v = switch ($Type) {
            'Binary'      { [byte[]]@($Value) }
            'MultiString' { [string[]]@($Value) }
            'DWord'       { [int]$Value }
            'QWord'       { [long]$Value }
            default       { $Value }
        }
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType $Type -Value $v -Force -ErrorAction Stop | Out-Null
    } catch {
        if (Test-AccessDenied $_) {
            Write-Log "  $Path\$Name is protected by Windows on this build and was not changed. Turn off the feature that guards it (e.g. Tamper Protection for Defender), or use the matching Settings toggle." 'WARN'
        } else { throw }
    }
}

function Remove-RegValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ($Name -eq '(default)') {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        $parent = Split-Path -Parent $Path
        $pk = Get-Item -LiteralPath $parent -ErrorAction SilentlyContinue
        if ($pk -and $pk.SubKeyCount -eq 0 -and $pk.ValueCount -eq 0) { Remove-Item -LiteralPath $parent -Force }
    } elseif ((Get-Item -LiteralPath $Path).GetValueNames() -contains $Name) {
        try { Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop }
        catch { if (-not (Test-AccessDenied $_)) { throw } }
    }
}

# ---------------------------------------------------------------- service helpers
$script:SvcWordToSc = @{ auto = 'auto'; delayed = 'delayed-auto'; manual = 'demand'; disabled = 'disabled' }

function Get-SvcInfo {
    param([string]$Name)
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path $k)) { return $null }
    $p = Get-ItemProperty $k
    $delayed = ($p.PSObject.Properties.Name -contains 'DelayedAutostart') -and $p.DelayedAutostart -eq 1
    $word = switch ([int]$p.Start) { 2 { if ($delayed) { 'delayed' } else { 'auto' } } 3 { 'manual' } 4 { 'disabled' } default { 'system' } }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    [pscustomobject]@{ Name = $Name; Start = $word; Running = [bool]($svc -and $svc.Status -eq 'Running') }
}

function Set-SvcStart {
    param([string]$Name, [string]$Word)
    if ($Word -eq 'system') { return }
    $out = & sc.exe config $Name start= $script:SvcWordToSc[$Word] 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sc.exe config $Name failed: $out" }
}

# ---------------------------------------------------------------- task helpers
# All scheduled tasks are loaded once and indexed by full path; a per-task Get-ScheduledTask is slow
# and was the main cost of a status refresh. Reset-Cache clears this between refreshes.
$script:TaskCache = $null
function Get-TaskAll {
    if ($null -eq $script:TaskCache) {
        $script:TaskCache = @{}
        foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) { $script:TaskCache[($t.TaskPath + $t.TaskName)] = $t }
    }
    $script:TaskCache
}
function Get-TaskObj { param([string]$Full) (Get-TaskAll)[$Full] }

# ---------------------------------------------------------------- appx helpers
function Get-AppxAll {
    if ($null -eq $script:AppxCache) {
        try { $script:AppxCache = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
        catch { $script:AppxCache = @(Get-AppxPackage) }   # non-admin fallback (current user only)
    }
    $script:AppxCache
}
function Reset-Cache { $script:AppxCache = $null; $script:ProvCache = $null; $script:TaskCache = $null }

# Provisioned packages = copies Windows installs for NEW user accounts. Some builds deny DISM access
# even to admins; in that case we warn once and only remove apps for existing users.
$script:ProvCache = $null
$script:ProvWarned = $false
function Get-ProvisionedAll {
    if ($null -eq $script:ProvCache) {
        try { $script:ProvCache = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }
        catch {
            $script:ProvCache = @()
            if (-not $script:ProvWarned) {
                $script:ProvWarned = $true
                Write-Log "Cannot read provisioned apps ($($_.Exception.Message)). Apps are removed for existing users only; they may be reinstalled for NEW accounts." 'WARN'
            }
        }
    }
    $script:ProvCache
}
function Find-Appx { param([string]$Pattern) @(Get-AppxAll | Where-Object { $_.Name -like $Pattern }) }

# ---------------------------------------------------------------- status
function Test-BuildOk {
    param($Tweak)
    if ((Has $Tweak 'MinBuild') -and $script:Build -lt $Tweak.MinBuild) { return $false }
    if ((Has $Tweak 'MaxBuild') -and $script:Build -gt $Tweak.MaxBuild) { return $false }
    $true
}

# Returns: Applied | Not applied | Not installed | N/A
function Get-TweakStatus {
    param($Tweak, $State = (Read-State))
    if (-not (Test-BuildOk $Tweak)) { return 'N/A' }
    $checks = 0; $ok = $true

    foreach ($r in Expand-Reg $Tweak) {
        $checks++
        $c = Get-RegCurrent $r.Path $r.Name
        if (-not $c.Exists -or [string]$c.Value -ne [string]$r.Value) { $ok = $false }
    }
    foreach ($s in @($Tweak.Svc)) {
        if (-not $s) { continue }
        $i = Get-SvcInfo $s.N
        if ($i) { $checks++; if ($i.Start -ne $s.Set) { $ok = $false } }
    }
    foreach ($t in @($Tweak.Tasks)) {
        if (-not $t) { continue }
        $o = Get-TaskObj $t
        if ($o) { $checks++; if ($o.State -ne 'Disabled') { $ok = $false } }
    }
    if (Has $Tweak 'Appx') {
        $checks++
        $present = @($Tweak.Appx | ForEach-Object { Find-Appx $_ })
        if ($present.Count -gt 0) { $ok = $false }
        elseif (-not $State.Contains($Tweak.Id)) { return 'Not installed' }
    }
    if (Has $Tweak 'Test') {
        $checks++
        try { if (-not [bool](Invoke-Expression $Tweak.Test)) { $ok = $false } } catch { $ok = $false }
    }
    if ($checks -eq 0) { $ok = $State.Contains($Tweak.Id) }
    if ($ok) { 'Applied' } else { 'Not applied' }
}

function Test-Reversible { param($Tweak) -not ((Has $Tweak 'Apply') -and -not (Has $Tweak 'Revert')) }

# ---------------------------------------------------------------- snapshot / apply / restore
function Get-Snapshot {
    param($Tweak)
    $snap = [ordered]@{ Reg = @(); Svc = @(); Tasks = @(); Appx = @() }
    $snap.Reg = @(Expand-Reg $Tweak | ForEach-Object { Get-RegCurrent $_.Path $_.Name })
    $snap.Svc = @(@($Tweak.Svc) | Where-Object { $_ } | ForEach-Object { Get-SvcInfo $_.N } | Where-Object { $_ })
    $snap.Tasks = @(@($Tweak.Tasks) | Where-Object { $_ } | ForEach-Object {
        $o = Get-TaskObj $_
        if ($o) { [pscustomobject]@{ Path = $_; Enabled = ($o.State -ne 'Disabled') } } })
    $snap.Appx = @(@($Tweak.Appx) | Where-Object { $_ } | ForEach-Object { Find-Appx $_ } | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; FullName = $_.PackageFullName; Location = $_.InstallLocation } })
    $snap
}

function Invoke-Tweak {
    param($Tweak, [switch]$DryRun, [switch]$Force)
    $tag = if ($DryRun) { '[DRY RUN] ' } else { '' }
    if (-not (Test-BuildOk $Tweak)) { Write-Log "$tag$($Tweak.Name): not applicable to build $script:Build, skipped" 'WARN'; return 'skipped' }
    if (-not $DryRun -and -not $Force -and (Get-TweakStatus $Tweak) -eq 'Applied') {
        Write-Log "Already applied, skipped: $($Tweak.Name)"
        return 'already'
    }
    $errBefore = $script:ErrorCount
    Write-Log "${tag}Applying: $($Tweak.Name)"

    $state = Read-State
    if (-not $DryRun -and -not $state.Contains($Tweak.Id)) {
        # Record the ORIGINAL values only the first time, so re-applying never loses them.
        $state[$Tweak.Id] = [ordered]@{ appliedAt = (Get-Date).ToString('s'); name = $Tweak.Name; snapshot = (Get-Snapshot $Tweak) }
        Save-State $state
    }

    foreach ($r in Expand-Reg $Tweak) {
        if ($DryRun) { Write-Log "  ${tag}set $($r.Path)\$($r.Name) = $($r.Value)"; continue }
        try { Set-RegValue $r.Path $r.Name $r.Type $r.Value } catch { Write-Log "  $($r.Path)\$($r.Name): $_" 'ERROR' }
    }
    foreach ($s in @($Tweak.Svc)) {
        if (-not $s) { continue }
        if (-not (Get-SvcInfo $s.N)) { Write-Log "  service $($s.N) not present, skipped"; continue }
        if ($DryRun) { Write-Log "  ${tag}service $($s.N) -> $($s.Set)"; continue }
        try {
            Set-SvcStart $s.N $s.Set
            if ($s.Set -eq 'disabled') { Stop-Service -Name $s.N -Force -ErrorAction SilentlyContinue }
        } catch { Write-Log "  service $($s.N): $_" 'ERROR' }
    }
    foreach ($t in @($Tweak.Tasks)) {
        if (-not $t) { continue }
        $o = Get-TaskObj $t
        if (-not $o) { Write-Log "  task $t not present, skipped"; continue }
        if ($DryRun) { Write-Log "  ${tag}disable task $t"; continue }
        try { $o | Disable-ScheduledTask -ErrorAction Stop | Out-Null } catch { Write-Log "  task ${t}: $_" 'ERROR' }
    }
    foreach ($a in @($Tweak.Appx)) {
        if (-not $a) { continue }
        foreach ($p in Find-Appx $a) {
            if ($DryRun) { Write-Log "  ${tag}remove app $($p.PackageFullName)"; continue }
            try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; Write-Log "  removed $($p.Name)" }
            catch { Write-Log "  remove $($p.Name): $_" 'ERROR' }
        }
        $prov = @(Get-ProvisionedAll | Where-Object { $_.DisplayName -like $a })
        foreach ($p in $prov) {
            if ($DryRun) { Write-Log "  ${tag}deprovision $($p.PackageName)"; continue }
            try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null; Write-Log "  deprovisioned $($p.DisplayName) (won't return for new users)" }
            catch { Write-Log "  deprovision $($p.DisplayName): $_" 'ERROR' }
        }
    }
    if (Has $Tweak 'Apply') {
        if ($DryRun) { Write-Log "  ${tag}run: $($Tweak.Apply)" }
        else { try { Invoke-Expression $Tweak.Apply | Out-Null } catch { Write-Log "  command: $_" 'ERROR' } }
    }
    if (Has $Tweak 'Appx') { Reset-Cache }
    if ($script:ErrorCount -gt $errBefore) { 'failed' } else { 'applied' }
}

function Undo-Tweak {
    param($Tweak, [switch]$DryRun)
    $tag = if ($DryRun) { '[DRY RUN] ' } else { '' }
    if (-not (Test-Reversible $Tweak)) { Write-Log "$($Tweak.Name) is one-way and cannot be restored" 'WARN'; return 'skipped' }
    $errBefore = $script:ErrorCount
    $state = Read-State
    $snap = $null
    if ($state.Contains($Tweak.Id)) { $snap = $state[$Tweak.Id].snapshot }
    else { Write-Log "  no recorded original for $($Tweak.Id); using Windows defaults" 'WARN' }
    Write-Log "${tag}Restoring: $($Tweak.Name)"

    foreach ($r in Expand-Reg $Tweak) {
        $orig = if ($snap) { @($snap.Reg) | Where-Object { $_.Path -eq $r.Path -and $_.Name -eq $r.Name } | Select-Object -First 1 }
        try {
            if ($orig -and $orig.Exists) {
                if ($DryRun) { Write-Log "  ${tag}set $($r.Path)\$($r.Name) = $($orig.Value)" }
                else { Set-RegValue $r.Path $r.Name $orig.Type $orig.Value }
            } else {
                if ($DryRun) { Write-Log "  ${tag}delete $($r.Path)\$($r.Name)" }
                else { Remove-RegValue $r.Path $r.Name }
            }
        } catch { Write-Log "  $($r.Path)\$($r.Name): $_" 'ERROR' }
    }
    foreach ($s in @($Tweak.Svc)) {
        if (-not $s -or -not (Get-SvcInfo $s.N)) { continue }
        $orig = if ($snap) { @($snap.Svc) | Where-Object { $_.Name -eq $s.N } | Select-Object -First 1 }
        $word = if ($orig) { $orig.Start } else { $s.Default }
        $run  = if ($orig) { $orig.Running } else { $word -in 'auto', 'delayed' }
        if ($DryRun) { Write-Log "  ${tag}service $($s.N) -> $word"; continue }
        try { Set-SvcStart $s.N $word; if ($run) { Start-Service -Name $s.N -ErrorAction SilentlyContinue } }
        catch { Write-Log "  service $($s.N): $_" 'ERROR' }
    }
    foreach ($t in @($Tweak.Tasks)) {
        if (-not $t) { continue }
        $o = Get-TaskObj $t
        if (-not $o) { continue }
        $orig = if ($snap) { @($snap.Tasks) | Where-Object { $_.Path -eq $t } | Select-Object -First 1 }
        $enable = if ($orig) { $orig.Enabled } else { $true }
        if (-not $enable) { continue }
        if ($DryRun) { Write-Log "  ${tag}enable task $t"; continue }
        try { $o | Enable-ScheduledTask -ErrorAction Stop | Out-Null } catch { Write-Log "  task ${t}: $_" 'ERROR' }
    }
    if (Has $Tweak 'Appx') { Restore-Appx $Tweak $snap -DryRun:$DryRun }
    if (Has $Tweak 'Revert') {
        if ($DryRun) { Write-Log "  ${tag}run: $($Tweak.Revert)" }
        else { try { Invoke-Expression $Tweak.Revert | Out-Null } catch { Write-Log "  command: $_" 'ERROR' } }
    }

    if (-not $DryRun) { $state.Remove($Tweak.Id); Save-State $state }
    if ($script:ErrorCount -gt $errBefore) { 'failed' } else { 'applied' }
}

function Restore-Appx {
    param($Tweak, $Snap, [switch]$DryRun)
    $tag = if ($DryRun) { '[DRY RUN] ' } else { '' }
    if ($Snap -and @($Snap.Appx | Where-Object { $_ }).Count -eq 0) {
        Write-Log "  $($Tweak.Name): app was not installed before WinTune ran - nothing to reinstall"
        return
    }
    $needStore = $true
    foreach ($p in @($Snap.Appx)) {
        if (-not $p) { continue }
        $manifest = if ($p.Location) { Join-Path $p.Location 'AppxManifest.xml' }
        if ($manifest -and (Test-Path $manifest)) {
            if ($DryRun) { Write-Log "  ${tag}re-register $($p.Name)"; $needStore = $false; continue }
            try { Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop; Write-Log "  re-registered $($p.Name)"; $needStore = $false }
            catch { Write-Log "  re-register $($p.Name) failed, will try Store" 'WARN' }
        }
    }
    if (-not $needStore) { return }
    $ids = @($Tweak.Store) | Where-Object { $_ }
    if (-not $ids) { Write-Log "  $($Tweak.Name): no Store ID known - reinstall it from the Microsoft Store manually" 'WARN'; return }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    foreach ($id in $ids) {
        if ($DryRun) { Write-Log "  ${tag}winget install $id (msstore)"; continue }
        if ($winget) {
            Write-Log "  installing $id from Microsoft Store via winget..."
            & $winget.Source install --id $id --source msstore --accept-package-agreements --accept-source-agreements --silent | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Log "  installed $id" } else { Write-Log "  winget exit $LASTEXITCODE for $id - opening Store page" 'WARN'; Start-Process "ms-windows-store://pdp/?ProductId=$id" }
        } else { Start-Process "ms-windows-store://pdp/?ProductId=$id"; Write-Log "  opened Store page for $id" }
    }
    Reset-Cache
}

# ---------------------------------------------------------------- restart explorer
function Restart-Explorer {
    Write-Log 'Restarting Explorer...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

# ---------------------------------------------------------------- seed new user accounts (Default profile)
# Writes the HKCU registry parts of the chosen tweaks into C:\Users\Default\NTUSER.DAT so that
# accounts created AFTER this runs start with them. Apply-only (not tracked for individual restore).
function Invoke-DefaultProfileSeed {
    param([string[]]$Ids, [switch]$DryRun)
    $catalog = Get-Catalog
    $picked = @($catalog | Where-Object { $_.Id -in $Ids -and (Expand-Reg $_ | Where-Object { $_.Path -like 'HKCU:*' }) })
    if (-not $picked) { return }
    $dat = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path $dat)) { Write-Log 'Default user profile hive not found; skipped new-user seeding' 'WARN'; return }
    if ($DryRun) { Write-Log "[DRY RUN] would seed $($picked.Count) tweak(s) into the Default profile for new accounts"; return }
    $hive = 'HKU\WinTuneDefault'
    $out = & reg.exe load $hive $dat 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Log "Could not load Default profile hive: $out" 'ERROR'; return }
    try {
        foreach ($t in $picked) {
            foreach ($r in (Expand-Reg $t | Where-Object { $_.Path -like 'HKCU:*' })) {
                $p = 'Registry::HKEY_USERS\WinTuneDefault' + ($r.Path -replace '^HKCU:', '')
                try { Set-RegValue $p $r.Name $r.Type $r.Value } catch { Write-Log "  default-profile $($r.Name): $_" 'WARN' }
            }
        }
        Write-Log "Seeded the Default profile with $($picked.Count) tweak(s); new accounts will inherit them"
    } finally {
        [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep -Milliseconds 400
        $u = & reg.exe unload $hive 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Log "Default hive did not unload cleanly: $u" 'WARN' }
    }
}

# ---------------------------------------------------------------- batch runner
function New-RestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description ("WinTune " + (Get-Date -Format 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'System restore point created'
    } catch { Write-Log "Restore point not created ($($_.Exception.Message)). Windows allows one every 24h by default." 'WARN' }
}

function Invoke-WinTune {
    param([ValidateSet('Apply', 'Restore')][string]$Action, [string[]]$Ids, [switch]$DryRun, [switch]$NoRestorePoint, [switch]$DefaultProfile, [switch]$Force, [scriptblock]$OnProgress)
    # Run fully unattended: never let a cmdlet's ShouldProcess/confirm pop a dialog (this also stops
    # the compiled -noConsole exe showing a Windows prompt per item), and silence progress bars.
    $ConfirmPreference = 'None'
    $ProgressPreference = 'SilentlyContinue'
    $catalog = Get-Catalog
    $byId = @{}; foreach ($c in $catalog) { $byId[$c.Id] = $c }   # O(1) lookup instead of a scan per id
    if ($Action -eq 'Apply' -and -not $DryRun -and -not $NoRestorePoint) { New-RestorePoint }
    $n = 0; $needs = @{}; $applied = 0; $already = 0; $failed = 0; $skipped = 0
    foreach ($id in $Ids) {
        $n++
        $t = $byId[$id]
        if (-not $t) { Write-Log "Unknown tweak id '$id'" 'WARN'; $failed++; continue }
        if ($OnProgress) { & $OnProgress $n $Ids.Count $t }
        $res = 'failed'
        try { $res = @(if ($Action -eq 'Apply') { Invoke-Tweak $t -DryRun:$DryRun -Force:$Force } else { Undo-Tweak $t -DryRun:$DryRun })[-1] }
        catch { Write-Log "$($t.Name): $_" 'ERROR'; $res = 'failed' }
        switch ("$res") { 'failed' { $failed++ } 'skipped' { $skipped++ } 'already' { $already++ } default { $applied++ } }
        if ((Has $t 'After')) { $needs[$t.After] = $true }
    }
    if ($Action -eq 'Apply' -and $DefaultProfile) { Invoke-DefaultProfileSeed $Ids -DryRun:$DryRun }
    $note = switch -Regex ("$($needs.Keys)") {
        'signout' { ' Sign out and back in for some changes to take full effect.'; break }
        'explorer' { ' Use "Restart Explorer" for the taskbar/Explorer changes to show.'; break }
        default { '' }
    }
    $verb = if ($Action -eq 'Apply') { 'applied' } else { 'restored' }
    $sum = "Summary: $applied of $($Ids.Count) $verb successfully"
    if ($already) { $sum += ", $already already set" }
    if ($failed)  { $sum += ", $failed failed" }
    if ($skipped) { $sum += ", $skipped skipped (not applicable)" }
    Write-Log "$sum.$note"
    $script:LastSummary = [pscustomobject]@{ Action = $Action; Total = $Ids.Count; Succeeded = $applied; AlreadySet = $already; Failed = $failed; Skipped = $skipped; DryRun = [bool]$DryRun }
    $script:LastSummary
}

# ---------------------------------------------------------------- deployment: self-contained apply script
# Raw source of the catalog and this engine, from the embedded copies in the exe or the files on disk.
function Get-CatalogText {
    if ($script:EmbeddedCatalog) { return $script:EmbeddedCatalog }
    if ($script:CatalogFile -and (Test-Path $script:CatalogFile)) { return (Get-Content -Raw -Path $script:CatalogFile) }
    throw 'Catalog source text not available.'
}
function Get-EngineText {
    if ($script:EmbeddedEngine) { return $script:EmbeddedEngine }
    $p = if ($script:AppRoot) { Join-Path $script:AppRoot 'lib\Engine.ps1' }
    if ($p -and (Test-Path $p)) { return (Get-Content -Raw -Path $p) }
    throw 'Engine source text not available (run from source, or rebuild the exe to embed it).'
}

# Writes a standalone .ps1 that applies the given tweaks with no WinTune install present. Drop it into
# SetupComplete.cmd, a RunOnce / first-logon task, MDT/SCCM, or Intune to configure new installations.
function Export-DeployScript {
    param([string[]]$TweakIds, [string]$Path, [string]$Name = 'WinTune deployment', [switch]$SeedNewUsers)
    $ids = @($TweakIds | Where-Object { $_ } | Select-Object -Unique)
    $known = (Get-Catalog).Id
    $ids = @($ids | Where-Object { $_ -in $known })
    if (-not $ids) { throw 'No known tweaks to export.' }
    $catB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-CatalogText)))
    $engine = Get-EngineText
    $idList = ($ids | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', '
    $seed = if ($SeedNewUsers) { ' -DefaultProfile' } else { '' }
    $head = @"
# ================= $Name =================
# WinTune deployment script - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') - applies $($ids.Count) tweak(s).
# Self-contained: no WinTune install needed. Run elevated (it self-elevates if double-clicked),
# or as SYSTEM from SetupComplete.cmd / a RunOnce / first-logon task / MDT-SCCM / Intune.
#   Unattended:  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$([IO.Path]::GetFileName($Path))"
# Original values are recorded to %ProgramData%\WinTune so the changes stay individually restorable on the target.
`$ErrorActionPreference = 'Continue'
`$script:EmbeddedCatalog = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$catB64'))
"@
    $tail = @"

# ---- apply ----
`$WinTuneDeployIds = @($idList)
`$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not `$admin) {
    if ([Environment]::UserInteractive) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"`$PSCommandPath`"" ; return
    } else { Write-Error 'WinTune deployment must run elevated (or as SYSTEM).' ; exit 1 }
}
Invoke-WinTune -Action Apply -Ids `$WinTuneDeployIds -NoRestorePoint$seed | Out-Null
"@
    Set-Content -Path $Path -Value ($head + "`r`n" + $engine + "`r`n" + $tail) -Encoding UTF8
    Write-Log "Exported deployment script ($($ids.Count) tweak(s)) -> $Path"
    $Path
}

# ---------------------------------------------------------------- deployment: apply to an OFFLINE image
# Applies the offline-capable parts of the chosen tweaks to a mounted Windows image (DISM mount dir or a
# mounted VHD's drive). Covers registry (HKLM + the Default user hive for HKCU tweaks), service start
# modes, and provisioned-appx removal. Scheduled-task and custom-command tweaks can't run offline and
# are reported as skipped. Changes are baked into the image, so they are not WinTune-restorable there.
$script:SvcWordToCode = @{ auto = 2; delayed = 2; manual = 3; disabled = 4 }

function Invoke-WinTuneImage {
    param([string]$MountPath, [string[]]$Ids, [switch]$DryRun)
    $sysConfig = Join-Path $MountPath 'Windows\System32\config'
    if (-not (Test-Path (Join-Path $sysConfig 'SOFTWARE'))) { throw "No Windows image found at '$MountPath' (expected Windows\System32\config\SOFTWARE)." }
    $catalog = Get-Catalog
    $tag = if ($DryRun) { '[DRY RUN] ' } else { '' }
    $hives = @{ SOFTWARE = "HKLM\WT_IMG_SOFTWARE=$(Join-Path $sysConfig 'SOFTWARE')"
                SYSTEM   = "HKLM\WT_IMG_SYSTEM=$(Join-Path $sysConfig 'SYSTEM')"
                DEFAULT  = "HKLM\WT_IMG_DEFAULT=$(Join-Path $MountPath 'Users\Default\NTUSER.DAT')" }
    $loaded = @()
    $map = @{ SOFTWARE = 'Registry::HKEY_LOCAL_MACHINE\WT_IMG_SOFTWARE'
              SYSTEM   = 'Registry::HKEY_LOCAL_MACHINE\WT_IMG_SYSTEM'
              DEFAULT  = 'Registry::HKEY_LOCAL_MACHINE\WT_IMG_DEFAULT' }
    Write-Log "${tag}Applying $($Ids.Count) tweak(s) to offline image at $MountPath"
    $applied = 0; $partial = 0; $skipped = 0
    try {
        if (-not $DryRun) {
            foreach ($h in 'SOFTWARE', 'SYSTEM', 'DEFAULT') {
                $parts = $hives[$h] -split '=', 2
                if (-not (Test-Path $parts[1])) { Write-Log "  image hive $h not found at $($parts[1]); that tweak kind will be skipped" 'WARN'; continue }
                $out = & reg.exe load $parts[0] $parts[1] 2>&1
                if ($LASTEXITCODE -eq 0) { $loaded += $parts[0] } else { Write-Log "  could not load image $h hive: $out" 'ERROR' }
            }
        }
        foreach ($id in $Ids) {
            $t = $catalog | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if (-not $t) { Write-Log "  unknown tweak '$id'" 'WARN'; continue }
            $did = $false; $couldnt = $false
            # registry
            foreach ($r in Expand-Reg $t) {
                $root = switch -Regex ($r.Path) { '^HKLM:\\SYSTEM\\' { 'SYSTEM'; break } '^HKLM:\\' { 'SOFTWARE'; break } '^HKCU:\\' { 'DEFAULT'; break } default { $null } }
                if (-not $root) { continue }
                # A loaded hive's root IS that subtree, so strip the full prefix (e.g. HKLM:\SOFTWARE\) not just HKLM:\
                $rel = switch ($root) {
                    'SOFTWARE' { $r.Path -replace '^HKLM:\\SOFTWARE\\?', '' }
                    'SYSTEM'   { $r.Path -replace '^HKLM:\\SYSTEM\\?', '' }
                    'DEFAULT'  { $r.Path -replace '^HKCU:\\?', '' }
                }
                $p = $map[$root] + '\' + $rel
                if ($DryRun) { Write-Log "  ${tag}[$root] set $rel\$($r.Name) = $($r.Value)"; $did = $true; continue }
                if ($root -notin ($loaded | ForEach-Object { ($_ -split '\\')[1] -replace 'WT_IMG_', '' })) { $couldnt = $true; continue }
                try { Set-RegValue $p $r.Name $r.Type $r.Value; $did = $true } catch { Write-Log "  $rel\$($r.Name): $_" 'ERROR'; $couldnt = $true }
            }
            # services (offline SYSTEM hive, ControlSet001)
            foreach ($s in @($t.Svc)) {
                if (-not $s) { continue }
                $code = $script:SvcWordToCode[$s.Set]
                $p = $map['SYSTEM'] + "\ControlSet001\Services\$($s.N)"
                if ($DryRun) { Write-Log "  ${tag}service $($s.N) -> $($s.Set) (Start=$code)"; $did = $true; continue }
                if ("HKLM\WT_IMG_SYSTEM" -notin $loaded) { $couldnt = $true; continue }
                if (Test-Path -LiteralPath $p) {
                    try { Set-RegValue $p 'Start' 'DWord' $code; if ($s.Set -eq 'delayed') { Set-RegValue $p 'DelayedAutostart' 'DWord' 1 }; $did = $true }
                    catch { Write-Log "  service $($s.N): $_" 'ERROR'; $couldnt = $true }
                } else { Write-Log "  service $($s.N) not in image, skipped" }
            }
            # provisioned appx removal
            if (Has $t 'Appx') {
                foreach ($a in @($t.Appx)) {
                    if ($DryRun) { Write-Log "  ${tag}deprovision packages matching $a"; $did = $true; continue }
                    $prov = @(Get-AppxProvisionedPackage -Path $MountPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $a })
                    foreach ($pk in $prov) {
                        try { Remove-AppxProvisionedPackage -Path $MountPath -PackageName $pk.PackageName -ErrorAction Stop | Out-Null; Write-Log "  deprovisioned $($pk.DisplayName)"; $did = $true }
                        catch { Write-Log "  deprovision $($pk.DisplayName): $_" 'ERROR'; $couldnt = $true }
                    }
                }
            }
            # not supported offline
            if (Has $t 'Tasks') { Write-Log "  $($t.Name): scheduled-task part can't be set offline, skipped" 'WARN'; $couldnt = $true }
            if (Has $t 'Apply') { Write-Log "  $($t.Name): custom-command part can't run offline, skipped" 'WARN'; $couldnt = $true }
            if ($did -and -not $couldnt) { $applied++ } elseif ($did) { $partial++ } else { $skipped++ }
        }
    } finally {
        if (-not $DryRun -and $loaded) {
            [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep -Milliseconds 400
            foreach ($hv in $loaded) { & reg.exe unload $hv 2>&1 | Out-Null }
        }
    }
    Write-Log "${tag}Image: $applied fully applied, $partial partial, $skipped not applicable. Commit the image (DISM /Unmount-Image /Commit) to keep the changes."
    [pscustomobject]@{ Applied = $applied; Partial = $partial; Skipped = $skipped }
}
