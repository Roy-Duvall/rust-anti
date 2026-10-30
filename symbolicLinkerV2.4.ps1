# Symbolic Link Creator GUI
# Version 2.4 - Added Overwrite Control
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
    $form.Text = 'Symbolic Link Creator v2.4'
    $form.Size = New-Object System.Drawing.Size(650, 650)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::WhiteSmoke

    # Source Selection Group
    $sourceGroup = New-Object System.Windows.Forms.GroupBox
    $sourceGroup.Location = New-Object System.Drawing.Point(20, 20)
    $sourceGroup.Size = New-Object System.Drawing.Size(600, 120)
    $sourceGroup.Text = 'Source Selection'
    $form.Controls.Add($sourceGroup)

    $sourceTypeLabel = New-Object System.Windows.Forms.Label
    $sourceTypeLabel.Location = New-Object System.Drawing.Point(20, 30)
    $sourceTypeLabel.Size = New-Object System.Drawing.Size(100, 20)
    $sourceTypeLabel.Text = 'Source Type:'
    $sourceGroup.Controls.Add($sourceTypeLabel)

    $sourceTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $sourceTypeComboBox.Location = New-Object System.Drawing.Point(20, 50)
    $sourceTypeComboBox.Size = New-Object System.Drawing.Size(200, 25)
    $sourceTypeComboBox.DropDownStyle = 'DropDownList'
    $sourceTypeComboBox.Items.AddRange(@('File', 'Directory'))
    $sourceTypeComboBox.SelectedIndex = 0
    $sourceGroup.Controls.Add($sourceTypeComboBox)

    $sourceTextBox = New-Object System.Windows.Forms.TextBox
    $sourceTextBox.Location = New-Object System.Drawing.Point(240, 50)
    $sourceTextBox.Size = New-Object System.Drawing.Size(300, 25)
    $sourceGroup.Controls.Add($sourceTextBox)

    $sourceBrowseButton = New-Object System.Windows.Forms.Button
    $sourceBrowseButton.Location = New-Object System.Drawing.Point(550, 48)
    $sourceBrowseButton.Size = New-Object System.Drawing.Size(40, 27)
    $sourceBrowseButton.Text = '...'
    $sourceGroup.Controls.Add($sourceBrowseButton)

    # Destination Selection Group
    $destGroup = New-Object System.Windows.Forms.GroupBox
    $destGroup.Location = New-Object System.Drawing.Point(20, 160)
    $destGroup.Size = New-Object System.Drawing.Size(600, 100)
    $destGroup.Text = 'Destination Selection'
    $form.Controls.Add($destGroup)

    $destLabel = New-Object System.Windows.Forms.Label
    $destLabel.Location = New-Object System.Drawing.Point(20, 30)
    $destLabel.Size = New-Object System.Drawing.Size(150, 20)
    $destLabel.Text = 'Destination Folder:'
    $destGroup.Controls.Add($destLabel)

    $destTextBox = New-Object System.Windows.Forms.TextBox
    $destTextBox.Location = New-Object System.Drawing.Point(20, 50)
    $destTextBox.Size = New-Object System.Drawing.Size(450, 25)
    $destGroup.Controls.Add($destTextBox)

    $destBrowseButton = New-Object System.Windows.Forms.Button
    $destBrowseButton.Location = New-Object System.Drawing.Point(480, 48)
    $destBrowseButton.Size = New-Object System.Drawing.Size(100, 27)
    $destBrowseButton.Text = 'Browse'
    $destGroup.Controls.Add($destBrowseButton)

    # Options Group
    $optionsGroup = New-Object System.Windows.Forms.GroupBox
    $optionsGroup.Location = New-Object System.Drawing.Point(20, 280)
    $optionsGroup.Size = New-Object System.Drawing.Size(600, 140)
    $optionsGroup.Text = 'Options'
    $form.Controls.Add($optionsGroup)

    $recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
    $recursiveCheckBox.Location = New-Object System.Drawing.Point(20, 30)
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(550, 25)
    $recursiveCheckBox.Text = 'Recurse: Include all subdirectories and their files'
    $recursiveCheckBox.Enabled = $false
    $optionsGroup.Controls.Add($recursiveCheckBox)

    $overwriteCheckBox = New-Object System.Windows.Forms.CheckBox
    $overwriteCheckBox.Location = New-Object System.Drawing.Point(20, 60)
    $overwriteCheckBox.Size = New-Object System.Drawing.Size(550, 25)
    $overwriteCheckBox.Text = 'Overwrite existing symbolic links (if unchecked, existing links will be skipped)'
    $overwriteCheckBox.Checked = $false
    $optionsGroup.Controls.Add($overwriteCheckBox)

    $helpLabel = New-Object System.Windows.Forms.Label
    $helpLabel.Location = New-Object System.Drawing.Point(40, 90)
    $helpLabel.Size = New-Object System.Drawing.Size(540, 40)
    $helpLabel.Text = 'Recurse OFF: Links only top-level files in selected directory' + [Environment]::NewLine + 
                      'Recurse ON: Links all files in all subdirectories' + [Environment]::NewLine +
                      'Overwrite: Replace existing symlinks or skip them'
    $helpLabel.ForeColor = [System.Drawing.Color]::Gray
    $optionsGroup.Controls.Add($helpLabel)

    # Preview Area
    $previewGroup = New-Object System.Windows.Forms.GroupBox
    $previewGroup.Location = New-Object System.Drawing.Point(20, 440)
    $previewGroup.Size = New-Object System.Drawing.Size(600, 90)
    $previewGroup.Text = 'Preview'
    $form.Controls.Add($previewGroup)

    $previewTextBox = New-Object System.Windows.Forms.TextBox
    $previewTextBox.Location = New-Object System.Drawing.Point(15, 25)
    $previewTextBox.Size = New-Object System.Drawing.Size(570, 55)
    $previewTextBox.Multiline = $true
    $previewTextBox.ReadOnly = $true
    $previewTextBox.ScrollBars = 'Vertical'
    $previewGroup.Controls.Add($previewTextBox)

    # Action Buttons
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(20, 550)
    $createButton.Size = New-Object System.Drawing.Size(180, 35)
    $createButton.Text = 'Create Symbolic Link(s)'
    $createButton.Enabled = $false
    $createButton.BackColor = [System.Drawing.Color]::LightGreen
    $form.Controls.Add($createButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(420, 550)
    $closeButton.Size = New-Object System.Drawing.Size(180, 35)
    $closeButton.Text = 'Close'
    $closeButton.BackColor = [System.Drawing.Color]::LightCoral
    $form.Controls.Add($closeButton)

    # --- Event Handlers and Logic ---

    # Enable/Disable recursive checkbox based on source type
    $sourceTypeComboBox.Add_SelectedIndexChanged({
        if ($sourceTypeComboBox.SelectedItem -eq 'Directory') {
            $recursiveCheckBox.Enabled = $true
        } else {
            $recursiveCheckBox.Enabled = $false
            $recursiveCheckBox.Checked = $false
        }
        Update-LinkPreview
    })

    function Update-LinkPreview {
        if ($sourceTextBox.Text -and $destTextBox.Text) {
            if ($sourceTypeComboBox.SelectedItem -eq 'Directory') {
                if ($recursiveCheckBox.Checked) {
                    $previewTextBox.Text = "Mode: Recursive Directory`r`n" +
                                          "Will create symbolic links for ALL files in:`r`n" +
                                          "$($sourceTextBox.Text)`r`n" +
                                          "Into: $($destTextBox.Text)"
                } else {
                    $previewTextBox.Text = "Mode: Top-Level Files Only`r`n" +
                                          "Will create symbolic links for files in:`r`n" +
                                          "$($sourceTextBox.Text)`r`n" +
                                          "Into: $($destTextBox.Text)"
                }
            } else {
                $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text)
                $destPath = Join-Path $destTextBox.Text $sourceName
                $previewTextBox.Text = "Mode: Single File`r`n" +
                                      "Source: $($sourceTextBox.Text)`r`n" +
                                      "Destination: $destPath"
            }
            $createButton.Enabled = $true
        } else {
            $previewTextBox.Text = ''
            $createButton.Enabled = $false
        }
    }

    $sourceBrowseButton.Add_Click({
        if ($sourceTypeComboBox.SelectedItem -eq 'File') {
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = "Select Source File"
            if (Test-Path $sourceTextBox.Text) { 
                $dialog.InitialDirectory = Split-Path $sourceTextBox.Text 
            }
            if ($dialog.ShowDialog() -eq 'OK') { 
                $sourceTextBox.Text = $dialog.FileName 
            }
        } else {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select Source Directory"
            $dialog.RootFolder = 'MyComputer'
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
        $dialog.Description = "Select Destination Directory"
        $dialog.RootFolder = 'MyComputer'
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
            $dst = $destTextBox.Text.TrimEnd('\')
            $overwrite = $overwriteCheckBox.Checked
            
            # Validate paths
            if (-not (Test-Path $src)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Source path does not exist.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                return
            }

            if (-not (Test-Path $dst)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Destination directory does not exist.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                return
            }

            $fileCount = 0
            $dirCount = 0
            $skippedCount = 0

            if ($sourceTypeComboBox.SelectedItem -eq 'Directory') {
                if ($recursiveCheckBox.Checked) {
                    # RECURSIVE MODE: Replicate entire directory structure with file symlinks
                    Get-ChildItem -Path $src -Recurse | ForEach-Object {
                        $relative = $_.FullName.Substring($src.Length).TrimStart('\')
                        $target = Join-Path $dst $relative
                        
                        if ($_.PSIsContainer) {
                            if (-not (Test-Path $target)) { 
                                New-Item -ItemType Directory -Path $target -Force | Out-Null
                                $dirCount++
                            }
                        } else {
                            $parentDir = Split-Path $target
                            if (-not (Test-Path $parentDir)) { 
                                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null 
                            }
                            
                            # Check if target exists and is a symlink
                            if (Test-Path $target) {
                                $item = Get-Item $target -Force
                                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                                    # It's a symlink
                                    if ($overwrite) {
                                        Remove-Item -Path $target -Force
                                        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                        $fileCount++
                                    } else {
                                        $skippedCount++
                                    }
                                } else {
                                    # Regular file exists - skip
                                    $skippedCount++
                                }
                            } else {
                                New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                $fileCount++
                            }
                        }
                    }
                    [System.Windows.Forms.MessageBox]::Show(
                        "Recursive symbolic links operation completed!`n`n" +
                        "Directories created: $dirCount`n" +
                        "File symlinks created: $fileCount`n" +
                        "Skipped (already exist): $skippedCount",
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                } else {
                    # NON-RECURSIVE MODE: Create symlinks ONLY for top-level files
                    Get-ChildItem -Path $src -File | ForEach-Object {
                        $target = Join-Path $dst $_.Name
                        
                        # Check if target exists and is a symlink
                        if (Test-Path $target) {
                            $item = Get-Item $target -Force
                            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                                # It's a symlink
                                if ($overwrite) {
                                    Remove-Item -Path $target -Force
                                    New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                    $fileCount++
                                } else {
                                    $skippedCount++
                                }
                            } else {
                                # Regular file exists - skip
                                $skippedCount++
                            }
                        } else {
                            New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                            $fileCount++
                        }
                    }
                    [System.Windows.Forms.MessageBox]::Show(
                        "Top-level file symbolic links operation completed!`n`n" +
                        "File symlinks created: $fileCount`n" +
                        "Skipped (already exist): $skippedCount",
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                }
            } else {
                # SINGLE FILE MODE: Create one symlink
                $target = Join-Path $dst ([System.IO.Path]::GetFileName($src))
                
                if (Test-Path $target) {
                    $item = Get-Item $target -Force
                    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                        # It's a symlink
                        if ($overwrite) {
                            Remove-Item -Path $target -Force
                            New-Item -ItemType SymbolicLink -Path $target -Target $src -Force | Out-Null
                            [System.Windows.Forms.MessageBox]::Show(
                                "Symbolic link replaced successfully!",
                                "Success",
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            ) | Out-Null
                        } else {
                            [System.Windows.Forms.MessageBox]::Show(
                                "Symbolic link already exists and overwrite is disabled.",
                                "Skipped",
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            ) | Out-Null
                        }
                    } else {
                        [System.Windows.Forms.MessageBox]::Show(
                            "A regular file already exists at destination.`nCannot overwrite regular files.",
                            "Error",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Warning
                        ) | Out-Null
                    }
                } else {
                    New-Item -ItemType SymbolicLink -Path $target -Target $src -Force | Out-Null
                    [System.Windows.Forms.MessageBox]::Show(
                        "Symbolic link created successfully!",
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error creating symbolic link(s):`n`n$($_.Exception.Message)",
                "Operation Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $sourceTextBox.Add_TextChanged({ Update-LinkPreview })
    $destTextBox.Add_TextChanged({ Update-LinkPreview })
    $recursiveCheckBox.Add_CheckedChanged({ Update-LinkPreview })
    $closeButton.Add_Click({ $form.Close() })
    
    $form.ShowDialog() | Out-Null
}

Show-SymbolicLinkCreatorGUI
