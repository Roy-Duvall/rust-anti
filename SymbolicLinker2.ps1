
# Symbolic Link Creator GUI
# Version 1.5
# Comprehensive PowerShell GUI for Creating Symbolic Links

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-SymbolicLinkCreatorGUI {
    # Main Form Configuration
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Symbolic Link Creator'
    $form.Size = New-Object System.Drawing.Size(650, 600)
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
    $sourceTypeLabel.Size = New-Object System.Drawing.Size(200, 20)
    $sourceTypeLabel.Text = 'Select Source Type:'
    $sourceGroup.Controls.Add($sourceTypeLabel)

    $sourceTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $sourceTypeComboBox.Location = New-Object System.Drawing.Point(20, 50)
    $sourceTypeComboBox.Size = New-Object System.Drawing.Size(200, 25)
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
    $sourceBrowseButton.Size = New-Object System.Drawing.Size(50, 25)
    $sourceBrowseButton.Text = '...'
    $sourceGroup.Controls.Add($sourceBrowseButton)

    # Destination Selection Group
    $destGroup = New-Object System.Windows.Forms.GroupBox
    $destGroup.Location = New-Object System.Drawing.Point(20, 160)
    $destGroup.Size = New-Object System.Drawing.Size(600, 120)
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
    $destBrowseButton.Size = New-Object System.Drawing.Size(100, 25)
    $destBrowseButton.Text = 'Browse'
    $destGroup.Controls.Add($destBrowseButton)

    # Options Group
    $optionsGroup = New-Object System.Windows.Forms.GroupBox
    $optionsGroup.Location = New-Object System.Drawing.Point(20, 300)
    $optionsGroup.Size = New-Object System.Drawing.Size(600, 100)
    $optionsGroup.Text = 'Link Creation Options'
    $form.Controls.Add($optionsGroup)

    $recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
    $recursiveCheckBox.Location = New-Object System.Drawing.Point(20, 30)
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(400, 25)
    $recursiveCheckBox.Text = 'Create symbolic links for all objects in selected source directory'
    $optionsGroup.Controls.Add($recursiveCheckBox)

    # Preview Area
    $previewGroup = New-Object System.Windows.Forms.GroupBox
    $previewGroup.Location = New-Object System.Drawing.Point(20, 420)
    $previewGroup.Size = New-Object System.Drawing.Size(600, 100)
    $previewGroup.Text = 'Link Preview'
    $form.Controls.Add($previewGroup)

    $previewTextBox = New-Object System.Windows.Forms.TextBox
    $previewTextBox.Location = New-Object System.Drawing.Point(20, 30)
    $previewTextBox.Size = New-Object System.Drawing.Size(560, 60)
    $previewTextBox.Multiline = $true
    $previewTextBox.ReadOnly = $true
    $previewGroup.Controls.Add($previewTextBox)

    # Action Buttons
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(20, 530)
    $createButton.Size = New-Object System.Drawing.Size(180, 30)
    $createButton.Text = 'Create Symbolic Link'
    $createButton.Enabled = $false
    $form.Controls.Add($createButton)

    $continueButton = New-Object System.Windows.Forms.Button
    $continueButton.Location = New-Object System.Drawing.Point(220, 530)
    $continueButton.Size = New-Object System.Drawing.Size(180, 30)
    $continueButton.Text = 'Continue'
    $continueButton.Enabled = $false
    $form.Controls.Add($continueButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(420, 530)
    $closeButton.Size = New-Object System.Drawing.Size(180, 30)
    $closeButton.Text = 'Close'
    $form.Controls.Add($closeButton)

    # Event Handlers
    $sourceTypeComboBox.Add_SelectedIndexChanged({
        $sourceTextBox.Text = '' # Clear previous selection
    })

    $sourceBrowseButton.Add_Click({
        if ($sourceTypeComboBox.SelectedItem -eq 'File') {
            $sourceDialog = New-Object System.Windows.Forms.OpenFileDialog
            $sourceDialog.InitialDirectory = "ThisPC"
            $sourceDialog.Multiselect = $false
            
            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.FileName
                Update-LinkPreview
            }
        } else {
            $sourceDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $sourceDialog.RootFolder = 'MyComputer'
            
            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.SelectedPath
                Update-LinkPreview
            }
        }
    })

    $destBrowseButton.Add_Click({
        $destDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $destDialog.RootFolder = 'MyComputer'
        
        if ($destDialog.ShowDialog() -eq 'OK') {
            $destTextBox.Text = $destDialog.SelectedPath
            Update-LinkPreview
        }
    })

    function Update-LinkPreview {
        if ($sourceTextBox.Text -and $destTextBox.Text) {
            $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text)
            $destPath = Join-Path $destTextBox.Text $sourceName
            $previewTextBox.Text = "Symbolic Link Preview:`nSource: $($sourceTextBox.Text)`nDestination: $destPath"
            $createButton.Enabled = $true
        }
    }

    # Validation for text boxes
    $sourceTextBox.Add_TextChanged({
        Update-LinkPreview
    })

    $destTextBox.Add_TextChanged({
        Update-LinkPreview
    })

    $createButton.Add_Click({
        try {
            $sourcePath = $sourceTextBox.Text
            $destPath = $destTextBox.Text
            $sourceName = [System.IO.Path]::GetFileName($sourcePath)

            # Validate paths before creating symbolic link
            if (-not (Test-Path $sourcePath)) {
                [System.Windows.Forms.MessageBox]::Show("Source path does not exist.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }

            if (-not (Test-Path $destPath)) {
                [System.Windows.Forms.MessageBox]::Show("Destination directory does not exist.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }

            if ($recursiveCheckBox.Checked) {
                # Recursive symbolic link creation for directory
                if (Test-Path -PathType Container $sourcePath) {
                    Get-ChildItem $sourcePath -Recurse | ForEach-Object {
                        $relativePath = $_.FullName.Substring($sourcePath.Length + 1)
                        $targetDestPath = Join-Path $destPath $relativePath

                        # Directly link files/folders to the destination, maintaining relative structure
                        if ($_.PSIsContainer) {
                            $targetDestDir = Split-Path $targetDestPath
                            if (-not (Test-Path $targetDestDir)) {
                                New-Item -ItemType Directory -Path $targetDestDir | Out-Null
                            }
                            New-Item -ItemType Directory -Path $targetDestPath | Out-Null
                        } else {
                            $targetDestDir = Split-Path $targetDestPath
                            if (-not (Test-Path $targetDestDir)) {
                                New-Item -ItemType Directory -Path $targetDestDir | Out-Null
                            }
                            New-Item -ItemType SymbolicLink -Path $targetDestPath -Target $_.FullName
                        }
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Recursive mode only works with directories.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
            } else {
                # Single file/directory symbolic link directly in destination
                $fullDestPath = Join-Path $destPath $sourceName
                New-Item -ItemType SymbolicLink -Path $fullDestPath -Target $sourcePath
            }

            [System.Windows.Forms.MessageBox]::Show("Symbolic link(s) created successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $continueButton.Enabled = $true
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error creating symbolic link: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
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
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
}

# Run the GUI
Show-SymbolicLinkCreatorGUI
