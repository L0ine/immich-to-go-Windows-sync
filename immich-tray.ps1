Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Paths & Config ---
$scriptPath = $PSScriptRoot
if (-not $scriptPath) { $scriptPath = Get-Location }
Set-Location -Path $scriptPath
$configFile = Join-Path $scriptPath "config.json"
$immichExe = Join-Path $scriptPath "immich-go.exe"

# Cleanup old logs
Get-ChildItem -Path $scriptPath -Filter "*.log" | Remove-Item -Force -ErrorAction SilentlyContinue

function Get-Config {
    if (Test-Path $configFile) {
        try { return Get-Content $configFile -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Save-Config ($cfg) {
    $cfg | ConvertTo-Json -Depth 2 | Set-Content $configFile
}

$global:currentConfig = Get-Config
if (-not $global:currentConfig) {
    $global:currentConfig = @{
        ServerUrl       = "http://your-immich-ip:8089"
        ApiKey          = "YOUR_API_KEY_HERE"
        SourceFolder    = "C:\path\to\your\photos"
        IntervalMinutes = 10
    }
}

# --- Actions ---
function Stop-Syncs {
    Get-Process -Name "immich-go" -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Show-Notification ($title, $msg) {
    if ($global:notifyIcon) {
        $global:notifyIcon.ShowBalloonTip(3000, $title, $msg, "Info")
    }
}

# --- Backup Execution ---
$global:lastSyncTime = [DateTime]::MinValue
$global:syncLock = New-Object Object

function Run-Backup {
    param($silent = $false)
    
    # Simple Debounce for Real-Time triggers
    $now = Get-Date
    if ($silent -and ($now - $global:lastSyncTime).TotalSeconds -lt 10) { return }
    $global:lastSyncTime = $now

    $cfg = $global:currentConfig
    if (-not (Test-Path $immichExe)) { return }
    $argString = "upload from-folder --server=`"$($cfg.ServerUrl)`" --api-key=`"$($cfg.ApiKey)`" --recursive `"$($cfg.SourceFolder)`""
    
    if ($silent) {
        Show-Notification "Immich Backup" "Hintergrund-Sync gestartet..."
        try { 
            # Use ArgumentList array to avoid quoting issues
            $procArgs = @("upload", "from-folder", "--server=$($cfg.ServerUrl)", "--api-key=$($cfg.ApiKey)", "--recursive", "$($cfg.SourceFolder)")
            Start-Process "$immichExe" -ArgumentList $procArgs -WindowStyle Hidden -WorkingDirectory $scriptPath
        }
        catch {
            Show-Notification "Immich Backup" "Fehler beim Hintergrund-Sync."
        }
    }
    else {
        $psArgs = @("-NoExit", "-Command", "Set-Location -Path '$scriptPath'; & '.\immich-go.exe' $argString; Write-Host '`nBackup completed. Press any key to close...'; `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')")
        try { Start-Process powershell.exe -ArgumentList $psArgs -WorkingDirectory $scriptPath } catch {}
    }
}

# --- FileSystemWatcher (Real-Time) ---
function Start-Watcher {
    if ($global:watcher) { 
        $global:watcher.EnableRaisingEvents = $false
        $global:watcher.Dispose()
    }
    
    if (-not (Test-Path $global:currentConfig.SourceFolder)) { return }

    $global:watcher = New-Object System.IO.FileSystemWatcher
    $global:watcher.Path = $global:currentConfig.SourceFolder
    $global:watcher.IncludeSubdirectories = $true
    $global:watcher.EnableRaisingEvents = $true

    $action = { Run-Backup -silent $true }
    
    Register-ObjectEvent $global:watcher "Created" -Action $action | Out-Null
    Register-ObjectEvent $global:watcher "Changed" -Action $action | Out-Null
    Register-ObjectEvent $global:watcher "Deleted" -Action $action | Out-Null
    Register-ObjectEvent $global:watcher "Renamed" -Action $action | Out-Null
}

# --- GUI: Stable Standard Settings ---
function Show-Settings {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Immich Backup Settings"
    $form.Size = New-Object System.Drawing.Size(450, 320)
    $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"; $form.Font = [System.Drawing.SystemFonts]::DefaultFont

    $lblX = 20; $txtX = 140; $w = 260; $gap = 35; $y = 20

    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = "Server URL:"; $l1.Location = "$lblX, $($y+3)"; $l1.AutoSize = $true; $form.Controls.Add($l1)
    $t1 = New-Object System.Windows.Forms.TextBox; $t1.Text = $global:currentConfig.ServerUrl; $t1.Location = "$txtX, $y"; $t1.Width = $w; $form.Controls.Add($t1)
    $y += $gap

    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = "API Key:"; $l2.Location = "$lblX, $($y+3)"; $l2.AutoSize = $true; $form.Controls.Add($l2)
    $t2 = New-Object System.Windows.Forms.TextBox; $t2.Text = $global:currentConfig.ApiKey; $t2.Location = "$txtX, $y"; $t2.Width = $w; $form.Controls.Add($t2)
    $y += $gap

    $l3 = New-Object System.Windows.Forms.Label; $l3.Text = "Source Folder:"; $l3.Location = "$lblX, $($y+3)"; $l3.AutoSize = $true; $form.Controls.Add($l3)
    $t3 = New-Object System.Windows.Forms.TextBox; $t3.Text = $global:currentConfig.SourceFolder; $t3.Location = "$txtX, $y"; $t3.Width = $w - 40; $form.Controls.Add($t3)
    $bb = New-Object System.Windows.Forms.Button; $bb.Text = "..."; $bb.Location = "$($txtX + $w - 35), $y"; $bb.Size = "35, 23"
    $bb.Add_Click({
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            if (Test-Path $t3.Text) { $dlg.SelectedPath = $t3.Text }
            if ($dlg.ShowDialog() -eq "OK") { $t3.Text = $dlg.SelectedPath }
        })
    $form.Controls.Add($bb)
    $y += $gap

    $l4 = New-Object System.Windows.Forms.Label; $l4.Text = "Interval (min):"; $l4.Location = "$lblX, $($y+3)"; $l4.AutoSize = $true; $form.Controls.Add($l4)
    $n1 = New-Object System.Windows.Forms.NumericUpDown; $n1.Minimum = 1; $n1.Maximum = 1440; $n1.Value = $global:currentConfig.IntervalMinutes; $n1.Location = "$txtX, $y"; $form.Controls.Add($n1)
    $y += 60

    $bs = New-Object System.Windows.Forms.Button; $bs.Text = "Save"; $bs.Location = "120, $y"; $bs.Width = 90
    $bs.Add_Click({
            $newCfg = @{ ServerUrl = $t1.Text; ApiKey = $t2.Text; SourceFolder = $t3.Text; IntervalMinutes = [int]$n1.Value }
            $global:currentConfig = $newCfg
            Save-Config $newCfg
            $global:timer.Interval = $newCfg.IntervalMinutes * 60000
            Start-Watcher # Restart watcher with new path
            $form.Close()
            [System.Windows.Forms.MessageBox]::Show("Settings saved!", "Success", "OK", "Information")
        })
    $form.Controls.Add($bs)

    $bc = New-Object System.Windows.Forms.Button; $bc.Text = "Cancel"; $bc.Location = "230, $y"; $bc.Width = 90
    $bc.Add_Click({ $form.Close() })
    $form.Controls.Add($bc)

    $form.ShowDialog()
}

function Stop-App {
    Stop-Syncs
    if ($global:watcher) { $global:watcher.Dispose() }
    $global:timer.Stop()
    $global:notifyIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
}

# --- Tray Icon ---
function Get-TrayIcon {
    $bmp = New-Object System.Drawing.Bitmap 16, 16
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(66, 133, 244))
    $g.FillEllipse($brush, 0, 0, 15, 15)
    $g.FillEllipse([System.Drawing.Brushes]::White, 5, 5, 6, 6)
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    return $icon
}

$global:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$global:notifyIcon.Icon = Get-TrayIcon
$global:notifyIcon.Text = "Immich-Go Auto Backup"
$global:notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenu
$m1 = New-Object System.Windows.Forms.MenuItem("Run Sync (Visible)", { Run-Backup -silent $false })
$m2 = New-Object System.Windows.Forms.MenuItem("Run Sync (Background)", { Run-Backup -silent $true })
$ms = New-Object System.Windows.Forms.MenuItem("Stop Current Syncs", { Stop-Syncs })
$me = New-Object System.Windows.Forms.MenuItem("Settings", { Show-Settings })
$mx = New-Object System.Windows.Forms.MenuItem("Exit", { Stop-App })

$contextMenu.MenuItems.AddRange(@($m1, $m2, "-", $ms, "-", $me, $mx))
$global:notifyIcon.ContextMenu = $contextMenu

$global:timer = New-Object System.Timers.Timer
$global:timer.Interval = $global:currentConfig.IntervalMinutes * 60000 
$global:timer.AutoReset = $true
$global:timer.Elapsed.Add_Handler({ Run-Backup -silent $true }) 
$global:timer.Start()

Start-Watcher

# Launch initial sync with a slight delay and notification
Start-Sleep -Seconds 2
Run-Backup -silent $true

[System.Windows.Forms.Application]::Run()
