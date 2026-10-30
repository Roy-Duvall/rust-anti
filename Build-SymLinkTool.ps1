<#
    .SYNOPSIS
        SymLink Tool Builder
    .DESCRIPTION
        Automates the creation of the SymLink Creator EXE.
        1. Writes the source code to a temporary file.
        2. Checks/Installs the PS2EXE module.
        3. Compiles the script into a standalone EXE with Admin Manifest.
    .VERSION
        1.1
#>

# -----------------------------------------------------------------------------
# 1. DEFINING THE SOURCE CODE
# -----------------------------------------------------------------------------
$sourceCode = @'
<#
    .SYNOPSIS
        SymLink Creator GUI
    .DESCRIPTION
        A GUI tool to create Symbolic Links for files or directories.
        Supports single item creation or batch processing.
    .VERSION
        1.0
#>

# Require Admin rights check (Double check for the EXE wrapper)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("This tool requires Administrator privileges to create Symbolic Links.`nThe application will now close.", "Permission Denied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# High DPI Awareness
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
} catch {}

# --- GLOBAL STATE ---
$Script:SourcePath = $null
$Script:DestDir = $null

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$timestamp] [$Type] $Message`r`n")
    $txtLog.ScrollToCaret()
}

function Update-Preview {
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
    param ([string]$SourceItem, [string]$TargetDirectory)
    $itemName = Split-Path $SourceItem -Leaf
    $targetPath = Join-Path -Path $TargetDirectory -ChildPath $itemName
    
    if (Test-Path $targetPath) {
        $msg = "The symbolic link '$itemName' already exists.`nTarget: $targetPath`n`nDo you want to OVERWRITE or SKIP?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Duplicate", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Log "Skipped duplicate: $itemName" "WARN"
            return
        } else {
            try {
                Remove-Item -Path $targetPath -Force -Recurse -ErrorAction Stop
                Write-Log "Removed existing item: $itemName" "INFO"
            } catch {
                Write-Log "Failed to remove '$itemName': $($_.Exception.Message)" "ERROR"
                return
            }
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $SourceItem -Force -ErrorAction Stop | Out-Null
        Write-Log "Created Link: $itemName" "SUCCESS"
    } catch {
        Write-Log "FAILED '$itemName'. Error: $($_.Exception.Message)" "ERROR"
    }
}

function Start-ProcessFlow {
    if ([string]::IsNullOrWhiteSpace($Script:SourcePath) -or -not (Test-Path $Script:SourcePath)) {
        [System.Windows.Forms.MessageBox]::Show("Invalid Source.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning); return
    }
    if ([string]::IsNullOrWhiteSpace($Script:DestDir) -or -not (Test-Path $Script:DestDir)) {
        [System.Windows.Forms.MessageBox]::Show("Invalid Destination.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning); return
    }

    $btnExecute.Enabled = $false; $btnExit.Enabled = $false
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
    Write-Log "--- Operation Started ---" "INFO"

    if ($chkBatch.Checked) {
        $parentDir = Split-Path $Script:SourcePath -Parent
        if ([string]::IsNullOrEmpty($parentDir)) { $parentDir = $Script:SourcePath }
        try {
            $items = Get-ChildItem -Path $parentDir -ErrorAction Stop
            foreach ($item in $items) {
                Create-LinkItem -SourceItem $item.FullName -TargetDirectory $Script:DestDir
                [System.Windows.Forms.Application]::DoEvents()
            }
        } catch { Write-Log "Batch Error: $($_.Exception.Message)" "ERROR" }
    } else {
        Create-LinkItem -SourceItem $Script:SourcePath -TargetDirectory $Script:DestDir
    }

    Write-Log "--- Operation Complete ---" "INFO"
    $ans = [System.Windows.Forms.MessageBox]::Show("Completed. Create more links?", "Finished", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($ans -eq [System.Windows.Forms.DialogResult]::No) { $form.Close() }

    $btnExecute.Enabled = $true; $btnExit.Enabled = $true
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
}

# --- GUI SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "SymLink Creator"; $form.Size = New-Object System.Drawing.Size(600, 600)
$form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false

$grpSource = New-Object System.Windows.Forms.GroupBox; $grpSource.Location = "10, 10"; $grpSource.Size = "560, 110"; $grpSource.Text = "1. Source Object"
$form.Controls.Add($grpSource)

$rbFile = New-Object System.Windows.Forms.RadioButton; $rbFile.Location = "120, 22"; $rbFile.Text = "File"; $rbFile.Checked = $true; $grpSource.Controls.Add($rbFile)
$rbFolder = New-Object System.Windows.Forms.RadioButton; $rbFolder.Location = "190, 22"; $rbFolder.Text = "Folder"; $grpSource.Controls.Add($rbFolder)
$txtSource = New-Object System.Windows.Forms.TextBox; $txtSource.Location = "15, 55"; $txtSource.Size = "440, 25"; $txtSource.ReadOnly = $true; $grpSource.Controls.Add($txtSource)
$btnBrowseSource = New-Object System.Windows.Forms.Button; $btnBrowseSource.Location = "465, 53"; $btnBrowseSource.Text = "Browse..."; $grpSource.Controls.Add($btnBrowseSource)

$grpDest = New-Object System.Windows.Forms.GroupBox; $grpDest.Location = "10, 130"; $grpDest.Size = "560, 80"; $grpDest.Text = "2. Destination Directory"
$form.Controls.Add($grpDest)
$txtDest = New-Object System.Windows.Forms.TextBox; $txtDest.Location = "15, 30"; $txtDest.Size = "440, 25"; $txtDest.ReadOnly = $true; $grpDest.Controls.Add($txtDest)
$btnBrowseDest = New-Object System.Windows.Forms.Button; $btnBrowseDest.Location = "465, 28"; $btnBrowseDest.Text = "Browse..."; $grpDest.Controls.Add($btnBrowseDest)

$chkBatch = New-Object System.Windows.Forms.CheckBox; $chkBatch.Location = "25, 220"; $chkBatch.Size = "500, 25"; $chkBatch.Text = "Batch Mode: Create links for ALL items in Source directory"; $form.Controls.Add($chkBatch)

$lblPreviewPath = New-Object System.Windows.Forms.Label; $lblPreviewPath.Location = "25, 275"; $lblPreviewPath.Size = "530, 40"; $lblPreviewPath.Text = "..."; $form.Controls.Add($lblPreviewPath)

$txtLog = New-Object System.Windows.Forms.TextBox; $txtLog.Location = "25, 320"; $txtLog.Size = "530, 180"; $txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true; $form.Controls.Add($txtLog)

$btnExecute = New-Object System.Windows.Forms.Button; $btnExecute.Location = "340, 515"; $btnExecute.Size = "120, 35"; $btnExecute.Text = "Create Link(s)"; $btnExecute.BackColor = [System.Drawing.Color]::LightGreen; $form.Controls.Add($btnExecute)
$btnExit = New-Object System.Windows.Forms.Button; $btnExit.Location = "470, 515"; $btnExit.Size = "85, 35"; $btnExit.Text = "Exit"; $form.Controls.Add($btnExit)

$btnBrowseSource.Add_Click({
    if ($rbFile.Checked) {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog; $ofd.InitialDirectory = [System.Environment+SpecialFolder]::MyComputer
        if ($ofd.ShowDialog() -eq "OK") { $Script:SourcePath = $ofd.FileName; $txtSource.Text = $Script:SourcePath; Update-Preview }
    } else {
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
        if ($fbd.ShowDialog() -eq "OK") { $Script:SourcePath = $fbd.SelectedPath; $txtSource.Text = $Script:SourcePath; Update-Preview }
    }
})
$btnBrowseDest.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    if ($fbd.ShowDialog() -eq "OK") { $Script:DestDir = $fbd.SelectedPath; $txtDest.Text = $Script:DestDir; Update-Preview }
})
$btnExecute.Add_Click({ Start-ProcessFlow }); $chkBatch.Add_Click({ Update-Preview }); $btnExit.Add_Click({ $form.Close() })
$rbFile.Add_CheckedChanged({ if($rbFile.Checked){$Script:SourcePath=$null;$txtSource.Text="";Update-Preview}}); $rbFolder.Add_CheckedChanged({ if($rbFolder.Checked){$Script:SourcePath=$null;$txtSource.Text="";Update-Preview}})

$form.ShowDialog() | Out-Null
$form.Dispose()
'@

# -----------------------------------------------------------------------------
# 2. ENVIRONMENT PREP
# -----------------------------------------------------------------------------
Write-Host "--- SymLink Tool Builder ---" -ForegroundColor Cyan

# 2.1 Define paths
$currentDir = Get-Location
$sourceFile = Join-Path $currentDir "SymLinkTempSource.ps1"
$exeFile    = Join-Path $currentDir "SymLinkCreator.exe"

# 2.2 Save source code
Write-Host "Saving source code to $sourceFile..."
Set-Content -Path $sourceFile -Value $sourceCode -Encoding UTF8

# 2.3 Check for PS2EXE module
Write-Host "Checking for compiler module (ps2exe)..."
if (-not (Get-Module -ListAvailable -Name "ps2exe")) {
    Write-Host "PS2EXE not found. Installing from PSGallery (Scope: CurrentUser)..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to install ps2exe. Ensure you have internet access and NuGet provider installed."
        exit
    }
    Write-Host "Module installed successfully." -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 3. COMPILATION
# -----------------------------------------------------------------------------
Write-Host "Compiling EXE..." -ForegroundColor Cyan
Write-Host "Settings: NoConsole (GUI Mode), RequireAdmin (UAC Prompt)" -ForegroundColor Gray

try {
    # Invoke-PS2EXE parameters:
    # -noConsole: Hides the black terminal window
    # -requireAdmin: Edits the EXE manifest to force "Run as Administrator" prompt
    # -title: Sets metadata title
    
    Invoke-PS2EXE -InputFile $sourceFile `
                  -OutputFile $exeFile `
                  -NoConsole `
                  -RequireAdmin `
                  -Title "SymLink Creator" `
                  -Version "1.0.0.0" `
                  -Verbose
                  
    Write-Host "------------------------------------------------" -ForegroundColor Green
    Write-Host "SUCCESS! Executable created at:" -ForegroundColor Green
    Write-Host "$exeFile" -ForegroundColor White
    Write-Host "------------------------------------------------" -ForegroundColor Green
} catch {
    Write-Error "Compilation failed: $($_.Exception.Message)"
} finally {
    # Cleanup source file
    if (Test-Path $sourceFile) {
        Remove-Item $sourceFile -Force
    }
}

Read-Host "Press Enter to exit"