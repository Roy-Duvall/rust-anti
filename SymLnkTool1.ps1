<#
    .SYNOPSIS
        SymLink Creator GUI
    .DESCRIPTION
        A GUI tool to create Symbolic Links for files or directories.
        Supports single item creation or batch processing of a source directory.
        Includes conflict resolution (Overwrite/Skip) and robust error logging.
    .VERSION
        1.0
    .AUTHOR
        AI Expert
    .DATE
        2023-10-26
#>

# -----------------------------------------------------------------------------
# 1. ENVIRONMENT SETUP & PRE-CHECKS
# -----------------------------------------------------------------------------
# Require Admin rights to create SymLinks
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("This script requires Administrator privileges to create Symbolic Links.`nPlease right-click and 'Run as Administrator'.", "Permission Denied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# High DPI Awareness (Prevents blurry fonts on Win11)
try {
    $SetDpiAwareness = @"
    using System.Runtime.InteropServices;
    public class DpiAwareness {
        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();
    }
"@
    Add-Type -TypeDefinition $SetDpiAwareness -ErrorAction SilentlyContinue
    [DpiAwareness]::SetProcessDPIAware() | Out-Null
} catch {
    # Fallback if PInvoke fails, script continues
}

# -----------------------------------------------------------------------------
# 2. GLOBAL STATE & LOGIC FUNCTIONS
# -----------------------------------------------------------------------------

# State Variables
$Script:SourcePath = $null
$Script:DestDir = $null
$Script:IsBatch = $false

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    $txtLog.AppendText("$logEntry`r`n")
    $txtLog.ScrollToCaret()
}

function Update-Preview {
    # Updates the UI label showing where the link will be created
    if ([string]::IsNullOrWhiteSpace($Script:SourcePath) -or [string]::IsNullOrWhiteSpace($Script:DestDir)) {
        $lblPreviewPath.Text = "Waiting for selection..."
        return
    }

    try {
        $itemName = Split-Path $Script:SourcePath -Leaf
        $previewPath = Join-Path -Path $Script:DestDir -ChildPath $itemName
        
        if ($chkBatch.Checked) {
             $parentDir = Split-Path $Script:SourcePath -Parent
             $lblPreviewPath.Text = "BATCH MODE: All items in '$parentDir' -> '$Script:DestDir'"
        } else {
             $lblPreviewPath.Text = $previewPath
        }
    } catch {
        $lblPreviewPath.Text = "Error calculating path."
    }
}

function Create-LinkItem {
    param (
        [string]$SourceItem,
        [string]$TargetDirectory
    )

    $itemName = Split-Path $SourceItem -Leaf
    $targetPath = Join-Path -Path $TargetDirectory -ChildPath $itemName
    
    # Determine type of source
    if (Test-Path $SourceItem -PathType Container) {
        $itemType = "Directory"
    } else {
        $itemType = "File"
    }

    # Check existence
    if (Test-Path $targetPath) {
        # Conflict Resolution
        $msg = "The symbolic link '$itemName' already exists in the destination.`nTarget: $targetPath`n`nDo you want to OVERWRITE it or SKIP?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Duplicate Detected", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Log "Skipped duplicate: $itemName" "WARN"
            return
        } else {
            # User chose Overwrite
            try {
                Remove-Item -Path $targetPath -Force -Recurse -ErrorAction Stop
                Write-Log "Removed existing item: $itemName" "INFO"
            } catch {
                Write-Log "Failed to remove existing item '$itemName': $($_.Exception.Message)" "ERROR"
                return
            }
        }
    }

    # Create the link
    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $SourceItem -Force -ErrorAction Stop | Out-Null
        Write-Log "Created SymLink: $itemName -> $SourceItem" "SUCCESS"
    } catch {
        Write-Log "FAILED to create link for '$itemName'. Error: $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error creating link for $itemName`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Start-ProcessFlow {
    # Validation
    if ([string]::IsNullOrWhiteSpace($Script:SourcePath) -or -not (Test-Path $Script:SourcePath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid source object.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($Script:DestDir) -or -not (Test-Path $Script:DestDir)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid destination directory.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $btnExecute.Enabled = $false
    $btnExit.Enabled = $false
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor

    Write-Log "--- Starting Operation ---" "INFO"

    if ($chkBatch.Checked) {
        # BATCH MODE
        # Get the directory of the selected object
        $parentDir = Split-Path $Script:SourcePath -Parent
        
        # If the user selected a root drive (e.g. C:\), handle carefully
        if ([string]::IsNullOrEmpty($parentDir)) { $parentDir = $Script:SourcePath }

        Write-Log "Batch Mode: Processing children of $parentDir" "INFO"

        try {
            $items = Get-ChildItem -Path $parentDir -ErrorAction Stop
            foreach ($item in $items) {
                Create-LinkItem -SourceItem $item.FullName -TargetDirectory $Script:DestDir
                # Keep UI responsive
                [System.Windows.Forms.Application]::DoEvents()
            }
        } catch {
            Write-Log "Error enumerating directory: $($_.Exception.Message)" "ERROR"
        }

    } else {
        # SINGLE MODE
        Create-LinkItem -SourceItem $Script:SourcePath -TargetDirectory $Script:DestDir
    }

    Write-Log "--- Operation Complete ---" "INFO"
    
    # Ask to continue
    $continueParams = [System.Windows.Forms.MessageBox]::Show("Operation completed. Do you want to create more links?", "Finished", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    
    if ($continueParams -eq [System.Windows.Forms.DialogResult]::No) {
        $form.Close()
    } else {
        # Reset Logic for next run? Or keep settings? Usually keep settings is friendlier.
        Write-Log "Ready for next operation..." "INFO"
    }

    $btnExecute.Enabled = $true
    $btnExit.Enabled = $true
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
}

# -----------------------------------------------------------------------------
# 3. GUI CONSTRUCTION
# -----------------------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "SymLink Creator (v1.0)"
$form.Size = New-Object System.Drawing.Size(600, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# -- Group: Source --
$grpSource = New-Object System.Windows.Forms.GroupBox
$grpSource.Location = New-Object System.Drawing.Point(10, 10)
$grpSource.Size = New-Object System.Drawing.Size(560, 110)
$grpSource.Text = "1. Select Source Object (File or Folder)"
$form.Controls.Add($grpSource)

$lblSourceType = New-Object System.Windows.Forms.Label
$lblSourceType.Location = New-Object System.Drawing.Point(15, 25)
$lblSourceType.Size = New-Object System.Drawing.Size(100, 20)
$lblSourceType.Text = "Selection Type:"
$grpSource.Controls.Add($lblSourceType)

$rbFile = New-Object System.Windows.Forms.RadioButton
$rbFile.Location = New-Object System.Drawing.Point(120, 22)
$rbFile.Size = New-Object System.Drawing.Size(60, 20)
$rbFile.Text = "File"
$rbFile.Checked = $true
$grpSource.Controls.Add($rbFile)

$rbFolder = New-Object System.Windows.Forms.RadioButton
$rbFolder.Location = New-Object System.Drawing.Point(190, 22)
$rbFolder.Size = New-Object System.Drawing.Size(80, 20)
$rbFolder.Text = "Folder"
$grpSource.Controls.Add($rbFolder)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(15, 55)
$txtSource.Size = New-Object System.Drawing.Size(440, 25)
$txtSource.ReadOnly = $true
$grpSource.Controls.Add($txtSource)

$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Location = New-Object System.Drawing.Point(465, 53)
$btnBrowseSource.Size = New-Object System.Drawing.Size(80, 27)
$btnBrowseSource.Text = "Browse..."
$grpSource.Controls.Add($btnBrowseSource)

# -- Group: Destination --
$grpDest = New-Object System.Windows.Forms.GroupBox
$grpDest.Location = New-Object System.Drawing.Point(10, 130)
$grpDest.Size = New-Object System.Drawing.Size(560, 80)
$grpDest.Text = "2. Select Destination Directory (For Link)"
$form.Controls.Add($grpDest)

$txtDest = New-Object System.Windows.Forms.TextBox
$txtDest.Location = New-Object System.Drawing.Point(15, 30)
$txtDest.Size = New-Object System.Drawing.Size(440, 25)
$txtDest.ReadOnly = $true
$grpDest.Controls.Add($txtDest)

$btnBrowseDest = New-Object System.Windows.Forms.Button
$btnBrowseDest.Location = New-Object System.Drawing.Point(465, 28)
$btnBrowseDest.Size = New-Object System.Drawing.Size(80, 27)
$btnBrowseDest.Text = "Browse..."
$grpDest.Controls.Add($btnBrowseDest)

# -- Options --
$chkBatch = New-Object System.Windows.Forms.CheckBox
$chkBatch.Location = New-Object System.Drawing.Point(25, 220)
$chkBatch.Size = New-Object System.Drawing.Size(500, 25)
$chkBatch.Text = "Batch Mode: Create symlinks for ALL objects in the Source's directory?"
$chkBatch.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($chkBatch)

# -- Preview Area --
$lblPreviewTitle = New-Object System.Windows.Forms.Label
$lblPreviewTitle.Location = New-Object System.Drawing.Point(25, 255)
$lblPreviewTitle.Size = New-Object System.Drawing.Size(150, 20)
$lblPreviewTitle.Text = "Resulting Path:"
$lblPreviewTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblPreviewTitle)

$lblPreviewPath = New-Object System.Windows.Forms.Label
$lblPreviewPath.Location = New-Object System.Drawing.Point(25, 275)
$lblPreviewPath.Size = New-Object System.Drawing.Size(530, 40)
$lblPreviewPath.Text = "..."
$lblPreviewPath.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblPreviewPath)

# -- Log Area --
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(25, 320)
$txtLog.Size = New-Object System.Drawing.Size(530, 180)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.Color]::WhiteSmoke
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

# -- Actions --
$btnExecute = New-Object System.Windows.Forms.Button
$btnExecute.Location = New-Object System.Drawing.Point(340, 515)
$btnExecute.Size = New-Object System.Drawing.Size(120, 35)
$btnExecute.Text = "Create Link(s)"
$btnExecute.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($btnExecute)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Location = New-Object System.Drawing.Point(470, 515)
$btnExit.Size = New-Object System.Drawing.Size(85, 35)
$btnExit.Text = "Exit"
$form.Controls.Add($btnExit)

# -----------------------------------------------------------------------------
# 4. EVENT HANDLERS
# -----------------------------------------------------------------------------

$btnBrowseSource_Click = {
    if ($rbFile.Checked) {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = "Select Source File"
        $ofd.InitialDirectory = [System.Environment+SpecialFolder]::MyComputer
        if ($ofd.ShowDialog() -eq "OK") {
            $Script:SourcePath = $ofd.FileName
            $txtSource.Text = $Script:SourcePath
            Update-Preview
        }
    } else {
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Select Source Folder"
        $fbd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
        if ($fbd.ShowDialog() -eq "OK") {
            $Script:SourcePath = $fbd.SelectedPath
            $txtSource.Text = $Script:SourcePath
            Update-Preview
        }
    }
}

$btnBrowseDest_Click = {
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Select Destination Directory for the SymLink"
    $fbd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    
    if ($fbd.ShowDialog() -eq "OK") {
        $Script:DestDir = $fbd.SelectedPath
        $txtDest.Text = $Script:DestDir
        Update-Preview
    }
}

$chkBatch_CheckedChanged = {
    Update-Preview
}

# Bind Events
$btnBrowseSource.Add_Click($btnBrowseSource_Click)
$btnBrowseDest.Add_Click($btnBrowseDest_Click)
$btnExecute.Add_Click({ Start-ProcessFlow })
$chkBatch.Add_Click($chkBatch_CheckedChanged)
$btnExit.Add_Click({ $form.Close() })

# Handle Radio Button Toggle (Clear previous selection if type changes)
$rbFile.Add_CheckedChanged({ 
    if ($rbFile.Checked) { 
        $Script:SourcePath = $null; $txtSource.Text = ""; Update-Preview 
    } 
})
$rbFolder.Add_CheckedChanged({ 
    if ($rbFolder.Checked) { 
        $Script:SourcePath = $null; $txtSource.Text = ""; Update-Preview 
    } 
})

# -----------------------------------------------------------------------------
# 5. EXECUTION
# -----------------------------------------------------------------------------
Write-Log "Application Started."
$form.ShowDialog() | Out-Null
$form.Dispose()