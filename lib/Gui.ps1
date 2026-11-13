# WinTune WPF interface.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

if (-not ('WinTuneRow' -as [type])) {
    Add-Type -ReferencedAssemblies System, WindowsBase -TypeDefinition @'
using System.ComponentModel;
public class WinTuneRow : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    void N(string p) { if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(p)); }
    public string Id { get; set; }
    public string Name { get; set; }
    public string Category { get; set; }
    public string Risk { get; set; }
    public string Description { get; set; }
    public string Needs { get; set; }
    public bool Reversible { get; set; }
    bool _c; public bool Checked { get { return _c; } set { _c = value; N("Checked"); } }
    string _s; public string Status { get { return _s; } set { _s = value; N("Status"); } }
    bool _r; public bool CanRestore { get { return _r; } set { _r = value; N("CanRestore"); } }
}
'@
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinTune - Windows 11 debloat &amp; tune" Width="1180" Height="780"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13" Background="#F3F3F3">
  <Window.Resources>
    <SolidColorBrush x:Key="AccentBrush" Color="#0B5CAD"/>
    <SolidColorBrush x:Key="MutedBrush" Color="#5A5A5A"/>

    <Style TargetType="Button" x:Key="BaseButton">
      <Setter Property="Padding" Value="12,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="#1F1F1F"/>
      <Setter Property="BorderBrush" Value="#CFCFCF"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" CornerRadius="5" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource AccentBrush}"/><Setter TargetName="bd" Property="Opacity" Value="0.9"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.75"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button" BasedOn="{StaticResource BaseButton}"/>
    <Style TargetType="Button" x:Key="AccentButton" BasedOn="{StaticResource BaseButton}"/>

    <Style TargetType="TextBlock" x:Key="SectionHead">
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="FontSize" Value="11.5"/>
      <Setter Property="Foreground" Value="{StaticResource AccentBrush}"/>
      <Setter Property="Margin" Value="0,12,0,6"/>
    </Style>

    <Style TargetType="TabItem">
      <Setter Property="Padding" Value="16,7"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <Style TargetType="CheckBox"><Setter Property="VerticalAlignment" Value="Center"/></Style>
    <Style TargetType="TextBox"><Setter Property="Padding" Value="3,2"/></Style>
  </Window.Resources>
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>

    <TabControl Grid.Row="0" Margin="0,0,0,8" x:Name="tabs">
      <TabItem Header="  Tweaks  ">
        <Grid Margin="8,10,8,8">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
      <TextBlock Text="Template:" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="SemiBold"/>
      <ComboBox x:Name="cmbTemplate" Width="280" Margin="0,0,8,0" DisplayMemberPath="Name"/>
      <Button x:Name="btnSaveTpl" Content="Save as template..."/>
      <Button x:Name="btnDelTpl" Content="Delete"/>
      <Button x:Name="btnExport" Content="Export for deployment..."/>
      <Button x:Name="btnOpenTpl" Content="Templates folder"/>
    </StackPanel>
    <TextBlock Grid.Row="1" x:Name="txtTplDesc" Foreground="#555" TextWrapping="Wrap" Margin="0,0,0,8"/>

    <DockPanel Grid.Row="2" Margin="0,0,0,6">
      <TextBlock Text="Filter:" VerticalAlignment="Center" Margin="0,0,6,0" FontWeight="SemiBold"/>
      <CheckBox DockPanel.Dock="Right" x:Name="chkHideNA" Content="Hide N/A" VerticalAlignment="Center" Margin="10,0,0,0"/>
      <CheckBox DockPanel.Dock="Right" x:Name="chkRisk" Content="Low risk only" VerticalAlignment="Center" Margin="10,0,0,0"/>
      <TextBox x:Name="txtSearch" Height="24" VerticalContentAlignment="Center"/>
    </DockPanel>

    <ListView Grid.Row="3" x:Name="lv" Background="White">
      <ListView.GroupStyle>
        <GroupStyle>
          <GroupStyle.HeaderTemplate>
            <DataTemplate><TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="14" Foreground="#0B5CAD" Margin="2,10,0,3"/></DataTemplate>
          </GroupStyle.HeaderTemplate>
        </GroupStyle>
      </ListView.GroupStyle>
      <ListView.View>
        <GridView>
          <GridViewColumn Width="34">
            <GridViewColumn.CellTemplate><DataTemplate><CheckBox IsChecked="{Binding Checked, Mode=TwoWay}" Tag="check"/></DataTemplate></GridViewColumn.CellTemplate>
          </GridViewColumn>
          <GridViewColumn Header="Tweak" Width="300">
            <GridViewColumn.CellTemplate><DataTemplate><TextBlock Text="{Binding Name}" TextWrapping="Wrap" FontWeight="SemiBold"/></DataTemplate></GridViewColumn.CellTemplate>
          </GridViewColumn>
          <GridViewColumn Header="Risk" Width="50" DisplayMemberBinding="{Binding Risk}"/>
          <GridViewColumn Header="Status" Width="95">
            <GridViewColumn.CellTemplate>
              <DataTemplate>
                <TextBlock x:Name="st" Text="{Binding Status}"/>
                <DataTemplate.Triggers>
                  <DataTrigger Binding="{Binding Status}" Value="Applied"><Setter TargetName="st" Property="Foreground" Value="#107C10"/><Setter TargetName="st" Property="FontWeight" Value="SemiBold"/></DataTrigger>
                  <DataTrigger Binding="{Binding Status}" Value="N/A"><Setter TargetName="st" Property="Foreground" Value="#999"/></DataTrigger>
                  <DataTrigger Binding="{Binding Status}" Value="Not installed"><Setter TargetName="st" Property="Foreground" Value="#999"/></DataTrigger>
                </DataTemplate.Triggers>
              </DataTemplate>
            </GridViewColumn.CellTemplate>
          </GridViewColumn>
          <GridViewColumn Header="Needs" Width="70" DisplayMemberBinding="{Binding Needs}"/>
          <GridViewColumn Header="Description" Width="450">
            <GridViewColumn.CellTemplate><DataTemplate><TextBlock Text="{Binding Description}" TextWrapping="Wrap" Foreground="#333"/></DataTemplate></GridViewColumn.CellTemplate>
          </GridViewColumn>
          <GridViewColumn Width="90">
            <GridViewColumn.CellTemplate><DataTemplate><Button Content="Restore" Tag="restore" Padding="8,2" Margin="0" IsEnabled="{Binding CanRestore}"/></DataTemplate></GridViewColumn.CellTemplate>
          </GridViewColumn>
        </GridView>
      </ListView.View>
    </ListView>

    <StackPanel Grid.Row="4" Margin="0,10,0,8">
      <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
        <CheckBox x:Name="chkRp" Content="Create restore point" IsChecked="True" Margin="0,0,16,0" VerticalAlignment="Center"/>
        <CheckBox x:Name="chkDefault" Content="Also apply to new user accounts" Margin="0,0,16,0" VerticalAlignment="Center"/>
        <CheckBox x:Name="chkConfirm" Content="Ask before each change" Margin="0,0,16,0" VerticalAlignment="Center"/>
        <CheckBox x:Name="chkForce" Content="Re-apply even if already set" Margin="0,0,16,0" VerticalAlignment="Center"/>
        <CheckBox x:Name="chkDry" Content="Dry run (preview only)" VerticalAlignment="Center"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal">
        <Button x:Name="btnApply" Content="Apply checked" FontWeight="Bold" Background="#0B5CAD" Foreground="White"/>
        <Button x:Name="btnRestoreChecked" Content="Restore checked"/>
        <Button x:Name="btnRestoreAll" Content="Restore all WinTune changed"/>
        <Button x:Name="btnAll" Content="Check all"/>
        <Button x:Name="btnNone" Content="Uncheck all"/>
        <Button x:Name="btnRefresh" Content="Refresh status"/>
        <Button x:Name="btnRestartExplorer" Content="Restart Explorer"/>
      </StackPanel>
      <TextBlock x:Name="txtSummary" Margin="2,8,0,0" FontWeight="SemiBold" Foreground="#555"/>
    </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="  Network tools  ">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="pnlNet" Margin="14">
            <StackPanel.Resources>
              <Style TargetType="Button" BasedOn="{StaticResource AccentButton}"><Setter Property="MinWidth" Value="152"/><Setter Property="Margin" Value="0,0,8,8"/></Style>
            </StackPanel.Resources>
            <TextBlock Text="Run common network-administration commands. Output appears in the log below. WinTune is already running as administrator." Foreground="{StaticResource MutedBrush}" TextWrapping="Wrap" Margin="0,0,0,12"/>
            <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
              <TextBlock Text="Target host (ping / traceroute / nslookup / test):" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBox x:Name="txtNetTarget" Text="8.8.8.8" Width="220" Height="26" VerticalContentAlignment="Center"/>
            </StackPanel>

            <TextBlock Text="SHOW CONFIGURATION" Style="{StaticResource SectionHead}"/>
            <WrapPanel>
              <Button Content="IP config (all)" Tag="ipconfig"/>
              <Button Content="Network adapters" Tag="adapters"/>
              <Button Content="IP configuration" Tag="ipconfiguration"/>
              <Button Content="MAC addresses" Tag="getmac"/>
              <Button Content="ARP table" Tag="arp"/>
              <Button Content="Routing table" Tag="route"/>
              <Button Content="Active connections" Tag="netstat"/>
              <Button Content="DNS cache" Tag="displaydns"/>
              <Button Content="Public IP" Tag="publicip"/>
            </WrapPanel>

            <TextBlock Text="DHCP / DNS" Style="{StaticResource SectionHead}"/>
            <WrapPanel>
              <Button Content="Release IP" Tag="release"/>
              <Button Content="Renew IP" Tag="renew"/>
              <Button Content="Release + Renew" Tag="releaserenew"/>
              <Button Content="Flush DNS" Tag="flushdns"/>
              <Button Content="Register DNS" Tag="registerdns"/>
            </WrapPanel>

            <TextBlock Text="CONNECTIVITY TESTS" Style="{StaticResource SectionHead}"/>
            <WrapPanel>
              <Button Content="Ping" Tag="ping"/>
              <Button Content="Traceroute" Tag="tracert"/>
              <Button Content="nslookup" Tag="nslookup"/>
              <Button Content="Test-NetConnection" Tag="testconn"/>
            </WrapPanel>

            <TextBlock Text="WI-FI" Style="{StaticResource SectionHead}"/>
            <WrapPanel>
              <Button Content="Wi-Fi profiles" Tag="wifiprofiles"/>
              <Button Content="Wi-Fi status" Tag="wifiinterfaces"/>
              <Button Content="Show saved Wi-Fi passwords" Tag="wifipasswords" MinWidth="230"/>
            </WrapPanel>

            <TextBlock Text="REPAIR  (may require a reboot)" Style="{StaticResource SectionHead}" Foreground="#C62828"/>
            <WrapPanel>
              <Button Content="Reset Winsock" Tag="winsock"/>
              <Button Content="Reset TCP/IP stack" Tag="ipreset"/>
              <Button Content="Full network repair" Tag="fullrepair"/>
            </WrapPanel>

            <TextBlock Text="OPEN" Style="{StaticResource SectionHead}"/>
            <WrapPanel>
              <Button Content="Network Connections" Tag="ncpa"/>
              <Button Content="Windows Firewall" Tag="firewall"/>
            </WrapPanel>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
    </TabControl>

    <TextBox Grid.Row="1" x:Name="txtLog" IsReadOnly="True" FontFamily="Consolas" FontSize="12"
             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#1E1E1E" Foreground="#DDD" Padding="6"/>
  </Grid>
</Window>
'@

function Show-WinTuneGui {
    $script:win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
    foreach ($n in 'cmbTemplate','btnSaveTpl','btnDelTpl','btnExport','btnOpenTpl','txtTplDesc','lv','chkRp','chkDry','chkDefault','chkConfirm',
                   'chkForce','txtSearch','chkHideNA','chkRisk','btnApply','btnRestoreChecked','btnRestoreAll','btnAll','btnNone',
                   'btnRefresh','btnRestartExplorer','txtSummary','txtLog','txtNetTarget','pnlNet','tabs') {
        Set-Variable -Scope Script -Name $n -Value $script:win.FindName($n)
    }

    # window / taskbar icon - from the embedded bytes in the exe, else the source .ico
    try {
        $icoBytes = if ($script:EmbeddedIcon) { [Convert]::FromBase64String($script:EmbeddedIcon) }
                    elseif ($script:AppRoot -and (Test-Path (Join-Path $script:AppRoot 'assets\wintune.ico'))) { [IO.File]::ReadAllBytes((Join-Path $script:AppRoot 'assets\wintune.ico')) }
        if ($icoBytes) {
            $ms = New-Object IO.MemoryStream (, $icoBytes)
            $script:win.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, 'None', 'OnLoad')
        }
    } catch {}

    $os = Get-CimInstance Win32_OperatingSystem
    $disp = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
    $script:win.Title = "WinTune  -  $($os.Caption) $disp (build $script:Build)"

    $script:LogSink = {
        param($line)
        $script:txtLog.AppendText($line + [Environment]::NewLine)
        $script:txtLog.ScrollToEnd()
        Update-Ui
    }

    # rows
    $script:rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[WinTuneRow]'
    foreach ($t in Get-Catalog) {
        $r = New-Object WinTuneRow
        $r.Id = $t.Id; $r.Name = $t.Name; $r.Category = $t.Category; $r.Risk = $t.Risk
        $r.Description = $t.Desc; $r.Reversible = (Test-Reversible $t)
        $r.Needs = switch ("$($t.After)") { 'explorer' { 'Explorer' } 'signout' { 'Sign out' } 'reboot' { 'Restart' } default { '' } }
        if (-not $r.Reversible) { $r.Description += '  (one-way)' }
        $script:rows.Add($r)
    }
    $script:view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:rows)
    $script:view.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription 'Category'))
    $script:view.Filter = {
        param($item)
        if ($script:chkHideNA.IsChecked -and $item.Status -eq 'N/A') { return $false }
        if ($script:chkRisk.IsChecked -and $item.Risk -ne 'low') { return $false }
        $q = $script:txtSearch.Text
        if ([string]::IsNullOrWhiteSpace($q)) { return $true }
        $q = [regex]::Escape($q.Trim())
        ($item.Name -match $q) -or ($item.Description -match $q) -or ($item.Category -match $q) -or ($item.Id -match $q)
    }
    $script:lv.ItemsSource = $script:view
    $script:txtSearch.Add_TextChanged({ $script:view.Refresh() })
    $script:chkHideNA.Add_Click({ $script:view.Refresh() })
    $script:chkRisk.Add_Click({ $script:view.Refresh() })

    # per-row Restore buttons (bubbling Click event from the cell template)
    $script:lv.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
        param($s, $e)
        $src = $e.OriginalSource
        if ($src.Tag -ne 'restore') { return }
        $row = $src.DataContext
        if (Confirm-Act "Restore '$($row.Name)' to its original state?") { Start-Run 'Restore' @($row.Id) }
    })

    $script:cmbTemplate.Add_SelectionChanged({ Select-Template })
    $script:btnSaveTpl.Add_Click({ Save-CurrentTemplate })
    $script:btnDelTpl.Add_Click({
        $t = $script:cmbTemplate.SelectedItem; if (-not $t) { return }
        if ($t.BuiltIn) { [System.Windows.MessageBox]::Show('Built-in templates cannot be deleted.', 'WinTune') | Out-Null; return }
        if ([System.Windows.MessageBox]::Show("Delete template '$($t.Name)'?", 'WinTune', 'YesNo') -eq 'Yes') {
            Remove-Template $t.File; Load-Templates
        }
    })
    $script:btnExport.Add_Click({
        $ids = @($script:rows | Where-Object { $_.Checked -and $_.Status -ne 'N/A' } | ForEach-Object { $_.Id })
        if (-not $ids) { [System.Windows.MessageBox]::Show('Check the tweaks to include in the deployment script first.', 'WinTune') | Out-Null; return }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = 'PowerShell script (*.ps1)|*.ps1'; $dlg.FileName = 'WinTune-Deploy.ps1'; $dlg.Title = 'Export deployment script'
        if ($dlg.ShowDialog()) {
            try {
                Export-DeployScript -TweakIds $ids -Path $dlg.FileName -Name 'WinTune deployment' -SeedNewUsers:([bool]$script:chkDefault.IsChecked) | Out-Null
                [System.Windows.MessageBox]::Show("Saved a self-contained $($ids.Count)-tweak script:`n$($dlg.FileName)`n`nRun it elevated on any PC, or call it from SetupComplete.cmd / a first-logon task to configure new installations. No WinTune install needed on the target.", 'WinTune') | Out-Null
            } catch { [System.Windows.MessageBox]::Show("$_", 'WinTune', 'OK', 'Error') | Out-Null }
        }
    })
    $script:btnOpenTpl.Add_Click({ Start-Process explorer.exe $script:TemplateDir })
    $script:btnAll.Add_Click({ foreach ($r in $script:rows) { if ($r.Status -ne 'N/A') { $r.Checked = $true } } })
    $script:btnNone.Add_Click({ foreach ($r in $script:rows) { $r.Checked = $false } })
    $script:btnRefresh.Add_Click({ Refresh-Status })
    $script:btnRestartExplorer.Add_Click({
        if (Confirm-Act 'Restart Windows Explorer now? The taskbar will flicker briefly.') { Restart-Explorer }
    })
    # Network tools tab: one bubbling handler dispatches on each button's Tag
    $script:pnlNet.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
        param($s, $e)
        $tag = "$($e.OriginalSource.Tag)"
        if ($tag) { Invoke-NetAction $tag }
    })

    $script:btnApply.Add_Click({
        $ids = @($script:rows | Where-Object { $_.Checked -and $_.Status -ne 'N/A' } | ForEach-Object { $_.Id })
        if (-not $ids) { return }
        $dry = [bool]$script:chkDry.IsChecked
        $msg = if ($dry) { "Preview $($ids.Count) tweak(s)? Nothing will be changed." } else { "Apply $($ids.Count) tweak(s)?`n`nOriginal values are recorded so each can be restored individually." }
        if (Confirm-Act $msg) { Start-Run 'Apply' $ids }
    })
    $script:btnRestoreChecked.Add_Click({
        $ids = @($script:rows | Where-Object { $_.Checked -and $_.CanRestore } | ForEach-Object { $_.Id })
        if (-not $ids) { [System.Windows.MessageBox]::Show('None of the checked tweaks are applied / restorable.', 'WinTune') | Out-Null; return }
        if (Confirm-Act "Restore $($ids.Count) checked tweak(s)?") { Start-Run 'Restore' $ids }
    })
    $script:btnRestoreAll.Add_Click({
        $ids = @((Read-State).Keys)
        if (-not $ids) { [System.Windows.MessageBox]::Show('WinTune has no recorded changes.', 'WinTune') | Out-Null; return }
        if (Confirm-Act "Restore all $($ids.Count) change(s) WinTune has recorded?" 'Warning') { Start-Run 'Restore' $ids }
    })

    $script:win.Add_ContentRendered({
        Write-Log "WinTune started. State: $script:StateFile"
        Load-Templates
        Refresh-Status
    })
    $script:win.ShowDialog() | Out-Null
}

function Update-Ui { $script:win.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background) }

# Only prompts when "Ask before each change" is ticked; otherwise proceeds silently.
function Confirm-Act { param([string]$Message, [string]$Icon = 'Question')
    if (-not $script:chkConfirm.IsChecked) { return $true }
    [System.Windows.MessageBox]::Show($Message, 'WinTune', 'YesNo', $Icon) -eq 'Yes'
}

# -------------------------------------------------------------------- Network tools tab
function Confirm-Reboot { param([string]$Message)
    [System.Windows.MessageBox]::Show("$Message`n`nProceed?", 'WinTune - Network', 'YesNo', 'Warning') -eq 'Yes'
}

# Runs a network command and writes its raw output to the shared log pane (and the log file).
function Invoke-NetCmd {
    param([string]$Title, [scriptblock]$Action)
    $stamp = Get-Date -Format 'HH:mm:ss'
    $script:txtLog.AppendText("`r`n===== [$stamp] $Title =====`r`n"); $script:txtLog.ScrollToEnd()
    $script:win.Cursor = 'Wait'; Update-Ui
    $text = ''
    try { $text = (& $Action 2>&1 | Out-String).TrimEnd() } catch { $text = "error: $($_.Exception.Message)" }
    if (-not $text) { $text = '(done)' }
    $script:txtLog.AppendText($text + "`r`n"); $script:txtLog.ScrollToEnd()
    $script:win.Cursor = $null
    try { Add-Content -Path (Join-Path $script:LogDir ((Get-Date -Format 'yyyyMMdd') + '.log')) -Value "[$Title]`r`n$text" -ErrorAction Stop } catch {}
}

function Get-WifiPasswords {
    $names = @((netsh wlan show profiles) | Where-Object { $_ -match 'All User Profile\s*:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() })
    if (-not $names) { return 'No saved Wi-Fi profiles found.' }
    $lines = foreach ($n in $names) {
        $info = netsh wlan show profile name="$n" key=clear
        $key = ($info | Where-Object { $_ -match 'Key Content\s*:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1)
        '{0,-32} {1}' -f $n, $(if ($key) { $key } else { '(open network / no stored key)' })
    }
    "Saved Wi-Fi networks and passwords:`r`n" + ($lines -join "`r`n")
}

function Invoke-NetAction {
    param([string]$Tag)
    $t = $script:txtNetTarget.Text.Trim(); if (-not $t) { $t = '8.8.8.8' }
    switch ($Tag) {
        'ipconfig'       { Invoke-NetCmd 'ipconfig /all' { ipconfig /all } }
        'adapters'       { Invoke-NetCmd 'Network adapters' { Get-NetAdapter | Sort-Object Name | Format-Table Name, Status, LinkSpeed, MacAddress, InterfaceDescription -AutoSize | Out-String -Width 200 } }
        'ipconfiguration'{ Invoke-NetCmd 'IP configuration' { Get-NetIPConfiguration | Out-String } }
        'getmac'         { Invoke-NetCmd 'MAC addresses' { getmac /v /fo list } }
        'arp'            { Invoke-NetCmd 'ARP table' { arp -a } }
        'route'          { Invoke-NetCmd 'Routing table' { route print } }
        'netstat'        { Invoke-NetCmd 'Active connections' { netstat -ano } }
        'displaydns'     { Invoke-NetCmd 'DNS resolver cache' { ipconfig /displaydns } }
        'publicip'       { Invoke-NetCmd 'Public IP address' { try { 'Public IP: ' + (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 8) } catch { 'Could not reach api.ipify.org (no internet, or blocked).' } } }
        'release'        { Invoke-NetCmd 'Release IP (ipconfig /release)' { ipconfig /release } }
        'renew'          { Invoke-NetCmd 'Renew IP (ipconfig /renew)' { ipconfig /renew } }
        'releaserenew'   { Invoke-NetCmd 'Release + Renew' { ipconfig /release; ipconfig /renew } }
        'flushdns'       { Invoke-NetCmd 'Flush DNS cache' { ipconfig /flushdns } }
        'registerdns'    { Invoke-NetCmd 'Register DNS' { ipconfig /registerdns } }
        'ping'           { Invoke-NetCmd "Ping $t" { $h = $script:txtNetTarget.Text.Trim(); if (-not $h) { $h = '8.8.8.8' }; ping -n 4 $h } }
        'tracert'        { Invoke-NetCmd "Traceroute $t" { $h = $script:txtNetTarget.Text.Trim(); if (-not $h) { $h = '8.8.8.8' }; tracert -d -h 20 -w 1000 $h } }
        'nslookup'       { Invoke-NetCmd "nslookup $t" { $h = $script:txtNetTarget.Text.Trim(); if (-not $h) { $h = '8.8.8.8' }; nslookup $h } }
        'testconn'       { Invoke-NetCmd "Test-NetConnection $t" { $h = $script:txtNetTarget.Text.Trim(); if (-not $h) { $h = '8.8.8.8' }; Test-NetConnection $h -InformationLevel Detailed | Out-String } }
        'wifiprofiles'   { Invoke-NetCmd 'Wi-Fi profiles' { netsh wlan show profiles } }
        'wifiinterfaces' { Invoke-NetCmd 'Wi-Fi status' { netsh wlan show interfaces } }
        'wifipasswords'  { Invoke-NetCmd 'Saved Wi-Fi passwords' { Get-WifiPasswords } }
        'ncpa'           { Invoke-NetCmd 'Open Network Connections' { Start-Process ncpa.cpl; 'Opened Network Connections.' } }
        'firewall'       { Invoke-NetCmd 'Open Windows Firewall' { Start-Process wf.msc; 'Opened Windows Defender Firewall.' } }
        'winsock'        { if (Confirm-Reboot 'Reset the Winsock catalog? Restart the PC afterwards to finish.') { Invoke-NetCmd 'Reset Winsock' { netsh winsock reset } } }
        'ipreset'        { if (Confirm-Reboot 'Reset the TCP/IP stack? Restart the PC afterwards to finish.') { Invoke-NetCmd 'Reset TCP/IP' { netsh int ip reset } } }
        'fullrepair'     { if (Confirm-Reboot 'Run full network repair: release/renew, flush DNS, reset Winsock and TCP/IP. Restart the PC afterwards to finish.') { Invoke-NetCmd 'Full network repair' { ipconfig /release; ipconfig /renew; ipconfig /flushdns; netsh winsock reset; netsh int ip reset; 'Done. Restart the PC to finish.' } } }
        default          { Write-Log "Unknown network action '$Tag'" 'WARN' }
    }
}

function Load-Templates {
    $script:templates = @(Get-Templates)
    $script:cmbTemplate.ItemsSource = $script:templates
    if ($script:templates.Count) { $script:cmbTemplate.SelectedIndex = 0 }
}

function Select-Template {
    $t = $script:cmbTemplate.SelectedItem
    if (-not $t) { return }
    $script:txtTplDesc.Text = $t.Description
    foreach ($r in $script:rows) { $r.Checked = ($t.Tweaks -contains $r.Id) -and $r.Status -ne 'N/A' }
}

function Save-CurrentTemplate {
    $ids = @($script:rows | Where-Object Checked | ForEach-Object { $_.Id })
    if (-not $ids) { [System.Windows.MessageBox]::Show('Check the tweaks you want in the template first.', 'WinTune') | Out-Null; return }
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Name for the new template ($($ids.Count) tweaks):", 'Save template', 'My template')
    if (-not $name) { return }
    $desc = [Microsoft.VisualBasic.Interaction]::InputBox('Short description (optional):', 'Save template', '')
    try {
        Save-Template -Name $name -Description $desc -TweakIds $ids | Out-Null
        Load-Templates
        $script:cmbTemplate.SelectedItem = $script:templates | Where-Object Name -eq $name | Select-Object -First 1
    } catch { [System.Windows.MessageBox]::Show("$_", 'WinTune', 'OK', 'Error') | Out-Null }
}

function Refresh-Status {
    $script:win.Cursor = 'Wait'; Update-Ui
    Reset-Cache
    $state = Read-State
    $byId = @{}; foreach ($t in Get-Catalog) { $byId[$t.Id] = $t }   # index once, not a scan per row
    $i = 0
    foreach ($r in $script:rows) {
        $r.Status = Get-TweakStatus $byId[$r.Id] $state
        $r.CanRestore = $r.Reversible -and ($state.Contains($r.Id) -or $r.Status -eq 'Applied')
        if ((++$i % 12) -eq 0) { Update-Ui }   # pump the UI in batches instead of every row
    }
    if ($script:view) { $script:view.Refresh() }
    $script:win.Cursor = $null
}

function Start-Run {
    param([string]$Action, [string[]]$Ids)
    $script:win.IsEnabled = $false; $script:win.Cursor = 'Wait'
    try {
        Invoke-WinTune -Action $Action -Ids $Ids -DryRun:([bool]$script:chkDry.IsChecked) -NoRestorePoint:(-not $script:chkRp.IsChecked) -DefaultProfile:([bool]$script:chkDefault.IsChecked) -Force:([bool]$script:chkForce.IsChecked) -OnProgress {
            param($i, $n, $t) $script:win.Title = "WinTune - $Action $i/$n : $($t.Name)"; Update-Ui
        } | Out-Null
        $s = $script:LastSummary
        if ($s) {
            $verb = if ($s.Action -eq 'Apply') { if ($s.DryRun) { 'previewed' } else { 'applied' } } else { 'restored' }
            $t = "Last run: $($s.Total) selected - $($s.Succeeded) $verb"
            if ($s.AlreadySet) { $t += ", $($s.AlreadySet) already set" }
            if ($s.Failed)     { $t += ", $($s.Failed) failed" }
            if ($s.Skipped)    { $t += ", $($s.Skipped) skipped" }
            $script:txtSummary.Text = $t
            $script:txtSummary.Foreground = if ($s.Failed) { 'DarkRed' } else { '#107C10' }
        }
    } finally {
        $script:win.Title = 'WinTune - Windows 11 debloat & tune'
        $script:win.IsEnabled = $true; $script:win.Cursor = $null
        Refresh-Status
    }
}
