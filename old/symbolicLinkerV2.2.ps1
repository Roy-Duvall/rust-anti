# Symbolic Link Creator GUI
# Version 2.2 - Fixed Parser Errors & Enhanced Logic
# Comprehensive PowerShell GUI for Creating Symbolic Links

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Elevation check ---
$windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $windowsPrincipal.IsInRole($adminRole)) {
    [System.Windows.Forms.MessageBox]::Show(
        "This script must be run as Administrator to create symbolic links.`n`nPlease right-click PowerShell and select 'Run as administrator'.",
        "Admin Rights Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}

function Show-SymbolicLinkCreatorGUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Symbolic Link Creator v2.2'
    $form.Size = New-Object System.Drawing.Size(650, 600)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::WhiteSmoke

    # Source Selection Group
    $sourceGroup = New-Object System.Windows.Forms.GroupBox
    $sourceGroup.Location = New-Object System.Drawing.Point(20, 20)
    $sourceGroup.Size = New-Object System.Drawing.Size(600, 120)
    $sourceGroup.Text = 'Source Selection'
    $form.Controls.Add($sourceGroup)

    $sourceTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $sourceTypeComboBox.Location = New-Object System.Drawing.Point(20, 50)
    $sourceTypeComboBox.Size = New-Object System.Drawing.Size(200, 25)
    $sourceTypeComboBox.Items.AddRange(@('File', 'Directory'))
    $sourceTypeComboBox.SelectedIndex = 0
    $sourceGroup.Controls.Add($sourceTypeComboBox)

    $sourceTextBox = New-Object System.Windows.Forms.TextBox
    $sourceTextBox.Location = New-Object System.Drawing.Point(240, 50)
    $sourceTextBox.Size = New-Object System.Drawing.Size(300, 25)
    $sourceGroup.Controls.Add($sourceTextBox)

    $sourceBrowseButton = New-Object System.Windows.Forms.Button
    $sourceBrowseButton.Location = New-Object System.Drawing.Point(550, 48)
    $sourceBrowseButton.Size = New-Object System.Drawing.Size(40, 25)
    $sourceBrowseButton.Text = '...'
    $sourceGroup.Controls.Add($sourceBrowseButton)

    # Destination Selection Group
    $destGroup = New-Object System.Windows.Forms.GroupBox
    $destGroup.Location = New-Object System.Drawing.Point(20, 160)
    $destGroup.Size = New-Object System.Drawing.Size(600, 100)
    $destGroup.Text = 'Destination Selection'
    $form.Controls.Add($destGroup)

    $destTextBox = New-Object System.Windows.Forms.TextBox
    $destTextBox.Location = New-Object System.Drawing.Point(20, 50)
    $destTextBox.Size = New-Object System.Drawing.Size(450, 25)
    $destGroup.Controls.Add($destTextBox)

    $destBrowseButton = New-Object System.Windows.Forms.Button
    $destBrowseButton.Location = New-Object System.Drawing.Point(480, 48)
    $destBrowseButton.Size = New-Object System.Drawing.Size(100, 25)
    $destBrowseButton.Text = 'Browse'
    $destGroup.Controls.Add($destBrowseButton)

    # Options Group
    $optionsGroup = New-Object System.Windows.Forms.GroupBox
    $optionsGroup.Location = New-Object System.Drawing.Point(20, 280)
    $optionsGroup.Size = New-Object System.Drawing.Size(600, 80)
    $optionsGroup.Text = 'Options'
    $form.Controls.Add($optionsGroup)

    $recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
    $recursiveCheckBox.Location = New-Object System.Drawing.Point(20, 30)
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(550, 25)
    $recursiveCheckBox.Text = 'Recurse: Replicate subordinate structure/contents into destination'
    $optionsGroup.Controls.Add($recursiveCheckBox)

    # Preview & Action Buttons
    $previewTextBox = New-Object System.Windows.Forms.TextBox
    $previewTextBox.Location = New-Object System.Drawing.Point(40, 400)
    $previewTextBox.Size = New-Object System.Drawing.Size(560, 80)
    $previewTextBox.Multiline = $true
    $previewTextBox.ReadOnly = $true
    $form.Controls.Add($previewTextBox)

    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(20, 510)
    $createButton.Size = New-Object System.Drawing.Size(180, 30)
    $createButton.Text = 'Create Symbolic Link'
    $createButton.Enabled = $false
    $form.Controls.Add($createButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(420, 510)
    $closeButton.Size = New-Object System.Drawing.Size(180, 30)
    $closeButton.Text = 'Close'
    $form.Controls.Add($closeButton)

    # --- Logical Operations ---
    function Update-LinkPreview {
        if ($sourceTextBox.Text -and $destTextBox.Text) {
            if ($recursiveCheckBox.Checked -and $sourceTypeComboBox.SelectedItem -eq 'Directory') {
                $previewTextBox.Text = "Mode: Recursive Contents`r`nSource Contents: $($sourceTextBox.Text)`r`nDestination: $($destTextBox.Text)"
            } else {
                $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text)
                $destPath = Join-Path $destTextBox.Text $sourceName
                $previewTextBox.Text = "Mode: Single Item`r`nSource: $($sourceTextBox.Text)`r`nDestination: $destPath"
            }
            $createButton.Enabled = $true
        } else {
            $createButton.Enabled = $false
        }
    }

    $sourceBrowseButton.Add_Click({
        if ($sourceTypeComboBox.SelectedItem -eq 'File') {
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            # Start from existing path if valid, otherwise default
            if (Test-Path $sourceTextBox.Text) { 
                $dialog.InitialDirectory = Split-Path $sourceTextBox.Text 
            }
            if ($dialog.ShowDialog() -eq 'OK') { 
                $sourceTextBox.Text = $dialog.FileName 
            }
        } else {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.RootFolder = 'MyComputer'
            # Start from existing path if valid
            if (Test-Path $sourceTextBox.Text) { 
                $dialog.SelectedPath = $sourceTextBox.Text 
            }
            if ($dialog.ShowDialog() -eq 'OK') { 
                $sourceTextBox.Text = $dialog.SelectedPath 
            }
        }
        Update-LinkPreview
    })

    $destBrowseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.RootFolder = 'MyComputer'
        # Start from existing path if valid
        if (Test-Path $destTextBox.Text) { 
            $dialog.SelectedPath = $destTextBox.Text 
        }
        if ($dialog.ShowDialog() -eq 'OK') { 
            $destTextBox.Text = $dialog.SelectedPath 
        }
        Update-LinkPreview
    })

    $createButton.Add_Click({
        try {
            $src = $sourceTextBox.Text.TrimEnd('\')
            $dst = $destTextBox.Text
            
            if ($recursiveCheckBox.Checked -and (Test-Path $src -PathType Container)) {
                # Replicate subordinate structure ONLY (contents go directly into destination)
                Get-ChildItem -Path $src -Recurse | ForEach-Object {
                    $relative = $_.FullName.Substring($src.Length).TrimStart('\')
                    $target = Join-Path $dst $relative
                    
                    if ($_.PSIsContainer) {
                        if (-not (Test-Path $target)) { 
                            New-Item -ItemType Directory -Path $target | Out-Null 
                        }
                    } else {
                        $parentDir = Split-Path $target
                        if (-not (Test-Path $parentDir)) { 
                            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null 
                        }
                        if (-not (Test-Path $target)) { 
                            New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName | Out-Null 
                        }
                    }
                }
                [System.Windows.Forms.MessageBox]::Show("Recursive symbolic links created successfully!", "Success")
            } else {
                # Standard single file/directory link
                $target = Join-Path $dst ([System.IO.Path]::GetFileName($src))
                New-Item -ItemType SymbolicLink -Path $target -Target $src | Out-Null
                [System.Windows.Forms.MessageBox]::Show("Symbolic link created successfully!", "Success")
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Operation Failed")
        }
    })

    $sourceTextBox.Add_TextChanged({ Update-LinkPreview })
    $destTextBox.Add_TextChanged({ Update-LinkPreview })
    $recursiveCheckBox.Add_CheckedChanged({ Update-LinkPreview })
    $closeButton.Add_Click({ $form.Close() })
    
    $form.ShowDialog() | Out-Null
}

Show-SymbolicLinkCreatorGUI
