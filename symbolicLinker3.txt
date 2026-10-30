# Symbolic Link Creator GUI
# Version 2.0 - Enhanced with Admin Check and Improved Recursive Linking
# Comprehensive PowerShell GUI for Creating Symbolic Links

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Administrator Check
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "This application requires Administrator privileges to create symbolic links.`n`n" +
        "Please right-click on PowerShell and select 'Run as Administrator', then run this script again.",
        "Administrator Rights Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    exit
}
#endregion

function Show-SymbolicLinkCreatorGUI {
    # Main Form Configuration
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Symbolic Link Creator v2.0'
    $form.Size = New-Object System.Drawing.Size(650, 600)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::WhiteSmoke
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    # Source Selection Group
    $sourceGroup = New-Object System.Windows.Forms.GroupBox
    $sourceGroup.Location = New-Object System.Drawing.Point(20, 20)
    $sourceGroup.Size = New-Object System.Drawing.Size(600, 120)
    $sourceGroup.Text = 'Source Selection'
    $form.Controls.Add($sourceGroup)

    $sourceTypeLabel = New-Object System.Windows.Forms.Label
    $sourceTypeLabel.Location = New-Object System.Drawing.Point(20, 30)
    $sourceTypeLabel.Size = New-Object System.Drawing.Size(200, 20)
    $sourceTypeLabel.Text = 'Select Source Type:'
    $sourceGroup.Controls.Add($sourceTypeLabel)

    $sourceTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $sourceTypeComboBox.Location = New-Object System.Drawing.Point(20, 50)
    $sourceTypeComboBox.Size = New-Object System.Drawing.Size(200, 25)
    $sourceTypeComboBox.DropDownStyle = 'DropDownList'
    $sourceTypeComboBox.Items.AddRange(@('File', 'Directory'))
    $sourceTypeComboBox.SelectedIndex = 0
    $sourceGroup.Controls.Add($sourceTypeComboBox)

    $sourceLabel = New-Object System.Windows.Forms.Label
    $sourceLabel.Location = New-Object System.Drawing.Point(240, 30)
    $sourceLabel.Size = New-Object System.Drawing.Size(200, 20)
    $sourceLabel.Text = 'Select Source Object:'
    $sourceGroup.Controls.Add($sourceLabel)

    $sourceTextBox = New-Object System.Windows.Forms.TextBox
    $sourceTextBox.Location = New-Object System.Drawing.Point(240, 50)
    $sourceTextBox.Size = New-Object System.Drawing.Size(300, 25)
    $sourceGroup.Controls.Add($sourceTextBox)

    $sourceBrowseButton = New-Object System.Windows.Forms.Button
    $sourceBrowseButton.Location = New-Object System.Drawing.Point(550, 48)
    $sourceBrowseButton.Size = New-Object System.Drawing.Size(30, 27)
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
    $destLabel.Size = New-Object System.Drawing.Size(200, 20)
    $destLabel.Text = 'Select Destination Directory:'
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
    $optionsGroup.Size = New-Object System.Drawing.Size(600, 110)
    $optionsGroup.Text = 'Link Creation Options'
    $form.Controls.Add($optionsGroup)

    $recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
    $recursiveCheckBox.Location = New-Object System.Drawing.Point(20, 30)
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(560, 25)
    $recursiveCheckBox.Text = 'Recursive: Replicate directory structure and create symbolic links for all files'
    $recursiveCheckBox.Enabled = $false
    $optionsGroup.Controls.Add($recursiveCheckBox)

    $recursiveHelpLabel = New-Object System.Windows.Forms.Label
    $recursiveHelpLabel.Location = New-Object System.Drawing.Point(40, 55)
    $recursiveHelpLabel.Size = New-Object System.Drawing.Size(540, 40)
    $recursiveHelpLabel.Text = 'When enabled, subdirectories will be created as normal folders, and all files will be created as symbolic links, preserving the original directory structure.'
    $recursiveHelpLabel.ForeColor = [System.Drawing.Color]::Gray
    $optionsGroup.Controls.Add($recursiveHelpLabel)

    # Preview Area
    $previewGroup = New-Object System.Windows.Forms.GroupBox
    $previewGroup.Location = New-Object System.Drawing.Point(20, 410)
    $previewGroup.Size = New-Object System.Drawing.Size(600, 100)
    $previewGroup.Text = 'Link Preview'
    $form.Controls.Add($previewGroup)

    $previewTextBox = New-Object System.Windows.Forms.TextBox
    $previewTextBox.Location = New-Object System.Drawing.Point(20, 30)
    $previewTextBox.Size = New-Object System.Drawing.Size(560, 60)
    $previewTextBox.Multiline = $true
    $previewTextBox.ReadOnly = $true
    $previewTextBox.ScrollBars = 'Vertical'
    $previewTextBox.BackColor = [System.Drawing.Color]::WhiteSmoke
    $previewGroup.Controls.Add($previewTextBox)

    # Action Buttons
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(20, 525)
    $createButton.Size = New-Object System.Drawing.Size(180, 35)
    $createButton.Text = 'Create Symbolic Link'
    $createButton.Enabled = $false
    $createButton.BackColor = [System.Drawing.Color]::LightGreen
    $form.Controls.Add($createButton)

    $continueButton = New-Object System.Windows.Forms.Button
    $continueButton.Location = New-Object System.Drawing.Point(220, 525)
    $continueButton.Size = New-Object System.Drawing.Size(180, 35)
    $continueButton.Text = 'Continue'
    $continueButton.Enabled = $false
    $form.Controls.Add($continueButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(420, 525)
    $closeButton.Size = New-Object System.Drawing.Size(180, 35)
    $closeButton.Text = 'Close'
    $closeButton.BackColor = [System.Drawing.Color]::LightCoral
    $form.Controls.Add($closeButton)

    #region Event Handlers

    # Enable/Disable recursive checkbox based on source type
    $sourceTypeComboBox.Add_SelectedIndexChanged({
        $sourceTextBox.Text = ''
        $recursiveCheckBox.Checked = $false

        if ($sourceTypeComboBox.SelectedItem -eq 'Directory') {
            $recursiveCheckBox.Enabled = $true
        } else {
            $recursiveCheckBox.Enabled = $false
        }
        Update-LinkPreview
    })

    $sourceBrowseButton.Add_Click({
        if ($sourceTypeComboBox.SelectedItem -eq 'File') {
            $sourceDialog = New-Object System.Windows.Forms.OpenFileDialog
            $sourceDialog.Title = "Select Source File"
            $sourceDialog.Multiselect = $false

            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.FileName
                Update-LinkPreview
            }
        } else {
            $sourceDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $sourceDialog.Description = "Select Source Directory"
            $sourceDialog.ShowNewFolderButton = $false

            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.SelectedPath
                Update-LinkPreview
            }
        }
    })

    $destBrowseButton.Add_Click({
        $destDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $destDialog.Description = "Select Destination Directory"
        $destDialog.ShowNewFolderButton = $true

        if ($destDialog.ShowDialog() -eq 'OK') {
            $destTextBox.Text = $destDialog.SelectedPath
            Update-LinkPreview
        }
    })

    function Update-LinkPreview {
        if ($sourceTextBox.Text -and $destTextBox.Text) {
            $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text.TrimEnd('\'))

            if ($recursiveCheckBox.Checked -and $sourceTypeComboBox.SelectedItem -eq 'Directory') {
                $destPath = Join-Path $destTextBox.Text $sourceName
                $previewTextBox.Text = "Recursive Mode:`r`nSource: $($sourceTextBox.Text)`r`nDestination Root: $destPath`r`n`r`nAll subdirectories will be created as folders.`r`nAll files will be created as symbolic links."
            } else {
                $destPath = Join-Path $destTextBox.Text $sourceName
                $previewTextBox.Text = "Single Link Mode:`r`nSource: $($sourceTextBox.Text)`r`nDestination: $destPath"
            }

            $createButton.Enabled = $true
        } else {
            $previewTextBox.Text = ''
            $createButton.Enabled = $false
        }
    }

    # Update preview when text changes
    $sourceTextBox.Add_TextChanged({ Update-LinkPreview })
    $destTextBox.Add_TextChanged({ Update-LinkPreview })
    $recursiveCheckBox.Add_CheckedChanged({ Update-LinkPreview })

    # Main creation logic
    $createButton.Add_Click({
        try {
            $sourcePath = $sourceTextBox.Text.Trim().TrimEnd('\')
            $destRoot = $destTextBox.Text.Trim().TrimEnd('\')

            # Validate source path
            if (-not (Test-Path $sourcePath)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Source path does not exist:`r`n$sourcePath",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }

            # Validate destination path
            if (-not (Test-Path $destRoot)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Destination directory does not exist:`r`n$destRoot",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }

            $isDirectorySource = Test-Path -Path $sourcePath -PathType Container

            if ($recursiveCheckBox.Checked -and $isDirectorySource) {
                # Recursive mode: replicate directory structure with file symlinks

                $sourceName = [System.IO.Path]::GetFileName($sourcePath)
                $destBase = Join-Path $destRoot $sourceName

                # Check if destination already exists
                if (Test-Path $destBase) {
                    $result = [System.Windows.Forms.MessageBox]::Show(
                        "Destination directory already exists:`r`n$destBase`r`n`r`nDo you want to continue? (Files may be overwritten)",
                        "Warning",
                        [System.Windows.Forms.MessageBoxButtons]::YesNo,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    if ($result -eq 'No') {
                        return
                    }
                } else {
                    # Create base destination directory
                    New-Item -ItemType Directory -Path $destBase -Force | Out-Null
                }

                $fileCount = 0
                $dirCount = 0
                $errorCount = 0

                # Create all subdirectories first
                Get-ChildItem -Path $sourcePath -Recurse -Directory | ForEach-Object {
                    $relativePath = $_.FullName.Substring($sourcePath.Length).TrimStart('\')
                    $targetDir = Join-Path $destBase $relativePath

                    try {
                        if (-not (Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                            $dirCount++
                        }
                    } catch {
                        $errorCount++
                        Write-Warning "Failed to create directory: $targetDir"
                    }
                }

                # Create symbolic links for all files
                Get-ChildItem -Path $sourcePath -Recurse -File | ForEach-Object {
                    $relativePath = $_.FullName.Substring($sourcePath.Length).TrimStart('\')
                    $targetPath = Join-Path $destBase $relativePath

                    try {
                        # Remove existing file/link if present
                        if (Test-Path $targetPath) {
                            Remove-Item -Path $targetPath -Force
                        }

                        New-Item -ItemType SymbolicLink -Path $targetPath -Target $_.FullName -Force | Out-Null
                        $fileCount++
                    } catch {
                        $errorCount++
                        Write-Warning "Failed to create symlink: $targetPath"
                    }
                }

                # Show completion message
                $message = "Recursive symbolic link creation completed!`r`n`r`n"
                $message += "Directories created: $dirCount`r`n"
                $message += "File symlinks created: $fileCount`r`n"
                if ($errorCount -gt 0) {
                    $message += "Errors encountered: $errorCount`r`n"
                }

                [System.Windows.Forms.MessageBox]::Show(
                    $message,
                    "Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )

            } else {
                # Single link mode
                $sourceName = [System.IO.Path]::GetFileName($sourcePath)
                $fullDestPath = Join-Path $destRoot $sourceName

                # Check if destination already exists
                if (Test-Path $fullDestPath) {
                    $result = [System.Windows.Forms.MessageBox]::Show(
                        "Destination already exists:`r`n$fullDestPath`r`n`r`nDo you want to replace it?",
                        "Warning",
                        [System.Windows.Forms.MessageBoxButtons]::YesNo,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    if ($result -eq 'No') {
                        return
                    }
                    Remove-Item -Path $fullDestPath -Force -Recurse
                }

                New-Item -ItemType SymbolicLink -Path $fullDestPath -Target $sourcePath -Force | Out-Null

                [System.Windows.Forms.MessageBox]::Show(
                    "Symbolic link created successfully!`r`n`r`nSource: $sourcePath`r`nDestination: $fullDestPath",
                    "Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }

            $continueButton.Enabled = $true

        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error creating symbolic link:`r`n`r`n$($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    $continueButton.Add_Click({
        # Reset form for next operation
        $sourceTextBox.Text = ''
        $destTextBox.Text = ''
        $previewTextBox.Text = ''
        $createButton.Enabled = $false
        $continueButton.Enabled = $false
        $recursiveCheckBox.Checked = $false
        $sourceTypeComboBox.SelectedIndex = 0
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    #endregion

    # Show the form
    $form.Add_Shown({$form.Activate()})
    [void]$form.ShowDialog()
}

# Run the GUI
Show-SymbolicLinkCreatorGUI
