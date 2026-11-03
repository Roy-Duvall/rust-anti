# Symbolic Link Creator GUI
# Version 2.8 - VALIDATED "This PC" Browse Defaults & Saved Path Templates (1-9)
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
    $form.Text = 'Symbolic Link Creator v2.8 - with Editable Templates'
    $form.Size = New-Object System.Drawing.Size(760, 840)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::WhiteSmoke
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    # --- Template Configuration Persistence ---
    $configDir = Join-Path $env:APPDATA "SymbolicLinkCreator"
    $configFile = Join-Path $configDir "templates.json"
    
    $defaultTemplates = @(
        "", "", "", "", "", "", "", "", ""
    )

    function Get-SavedTemplates {
        if (Test-Path $configFile) {
            try {
                $raw = Get-Content $configFile -Raw -ErrorAction SilentlyContinue
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $json = $raw | ConvertFrom-Json
                    if ($json -and $json.Count -eq 9) {
                        return [string[]]$json
                    }
                }
            } catch {}
        }
        return $defaultTemplates
    }

    function Save-SavedTemplates {
        param([string[]]$templatesToSave)
        try {
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            $templatesToSave | ConvertTo-Json | Set-Content $configFile -Encoding UTF8 -Force
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error saving templates: $($_.Exception.Message)",
                "Save Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }

    $currentTemplates = Get-SavedTemplates

    # Source Selection Group
    $sourceGroup = New-Object System.Windows.Forms.GroupBox
    $sourceGroup.Location = New-Object System.Drawing.Point(20, 15)
    $sourceGroup.Size = New-Object System.Drawing.Size(700, 100)
    $sourceGroup.Text = 'Source Selection'
    $form.Controls.Add($sourceGroup)

    $sourceTypeLabel = New-Object System.Windows.Forms.Label
    $sourceTypeLabel.Location = New-Object System.Drawing.Point(20, 25)
    $sourceTypeLabel.Size = New-Object System.Drawing.Size(100, 20)
    $sourceTypeLabel.Text = 'Source Type:'
    $sourceGroup.Controls.Add($sourceTypeLabel)

    $sourceTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $sourceTypeComboBox.Location = New-Object System.Drawing.Point(20, 48)
    $sourceTypeComboBox.Size = New-Object System.Drawing.Size(150, 25)
    $sourceTypeComboBox.DropDownStyle = 'DropDownList'
    $sourceTypeComboBox.Items.AddRange(@('File', 'Directory'))
    $sourceTypeComboBox.SelectedIndex = 1
    $sourceGroup.Controls.Add($sourceTypeComboBox)

    $sourceTextBox = New-Object System.Windows.Forms.TextBox
    $sourceTextBox.Location = New-Object System.Drawing.Point(180, 48)
    $sourceTextBox.Size = New-Object System.Drawing.Size(440, 25)
    $sourceGroup.Controls.Add($sourceTextBox)

    $sourceBrowseButton = New-Object System.Windows.Forms.Button
    $sourceBrowseButton.Location = New-Object System.Drawing.Point(630, 46)
    $sourceBrowseButton.Size = New-Object System.Drawing.Size(50, 27)
    $sourceBrowseButton.Text = '...'
    $sourceGroup.Controls.Add($sourceBrowseButton)

    # Destination Selection Group
    $destGroup = New-Object System.Windows.Forms.GroupBox
    $destGroup.Location = New-Object System.Drawing.Point(20, 120)
    $destGroup.Size = New-Object System.Drawing.Size(700, 80)
    $destGroup.Text = 'Destination Selection'
    $form.Controls.Add($destGroup)

    $destLabel = New-Object System.Windows.Forms.Label
    $destLabel.Location = New-Object System.Drawing.Point(20, 22)
    $destLabel.Size = New-Object System.Drawing.Size(150, 20)
    $destLabel.Text = 'Destination Folder:'
    $destGroup.Controls.Add($destLabel)

    $destTextBox = New-Object System.Windows.Forms.TextBox
    $destTextBox.Location = New-Object System.Drawing.Point(20, 42)
    $destTextBox.Size = New-Object System.Drawing.Size(600, 25)
    $destGroup.Controls.Add($destTextBox)

    $destBrowseButton = New-Object System.Windows.Forms.Button
    $destBrowseButton.Location = New-Object System.Drawing.Point(630, 40)
    $destBrowseButton.Size = New-Object System.Drawing.Size(50, 27)
    $destBrowseButton.Text = 'Browse'
    $destGroup.Controls.Add($destBrowseButton)

    # --- Saved Path Templates Section (1 - 9) ---
    $templateGroup = New-Object System.Windows.Forms.GroupBox
    $templateGroup.Location = New-Object System.Drawing.Point(20, 210)
    $templateGroup.Size = New-Object System.Drawing.Size(700, 335)
    $templateGroup.Text = 'Saved Path Templates (1 - 9)'
    $form.Controls.Add($templateGroup)

    $templateTextBoxes = @()

    for ($i = 0; $i -lt 9; $i++) {
        $y = 25 + ($i * 29)
        
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Location = New-Object System.Drawing.Point(12, $y + 3)
        $lbl.Size = New-Object System.Drawing.Size(26, 20)
        $lbl.Text = "#$($i+1):"
        $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
        $templateGroup.Controls.Add($lbl)

        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Location = New-Object System.Drawing.Point(40, $y)
        $txt.Size = New-Object System.Drawing.Size(325, 23)
        $txt.Text = $currentTemplates[$i]
        $templateGroup.Controls.Add($txt)
        $templateTextBoxes += $txt

        # Browse Template Button
        $btnBrowseTpl = New-Object System.Windows.Forms.Button
        $btnBrowseTpl.Location = New-Object System.Drawing.Point(370, $y - 1)
        $btnBrowseTpl.Size = New-Object System.Drawing.Size(35, 25)
        $btnBrowseTpl.Text = "..."
        $btnBrowseTpl.Tag = $i
        $btnBrowseTpl.Add_Click({
            $index = $this.Tag
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = "Select Folder for Template #$($index+1)"
            $dlg.RootFolder = [System.Environment+SpecialFolder]::MyComputer
            if (-not [string]::IsNullOrWhiteSpace($templateTextBoxes[$index].Text)) {
                if (Test-Path $templateTextBoxes[$index].Text -ErrorAction SilentlyContinue) {
                    $dlg.SelectedPath = $templateTextBoxes[$index].Text
                }
            }
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $templateTextBoxes[$index].Text = $dlg.SelectedPath
            }
        })
        $templateGroup.Controls.Add($btnBrowseTpl)

        # Copy from Source
        $btnFromSrc = New-Object System.Windows.Forms.Button
        $btnFromSrc.Location = New-Object System.Drawing.Point(410, $y - 1)
        $btnFromSrc.Size = New-Object System.Drawing.Size(65, 25)
        $btnFromSrc.Text = "+ From Src"
        $btnFromSrc.Tag = $i
        $btnFromSrc.Add_Click({
            $index = $this.Tag
            if ([string]::IsNullOrWhiteSpace($sourceTextBox.Text)) {
                [System.Windows.Forms.MessageBox]::Show("Source field is currently empty.", "Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } else {
                $templateTextBoxes[$index].Text = $sourceTextBox.Text
            }
        })
        $templateGroup.Controls.Add($btnFromSrc)

        # Copy from Dest
        $btnFromDst = New-Object System.Windows.Forms.Button
        $btnFromDst.Location = New-Object System.Drawing.Point(480, $y - 1)
        $btnFromDst.Size = New-Object System.Drawing.Size(65, 25)
        $btnFromDst.Text = "+ From Dst"
        $btnFromDst.Tag = $i
        $btnFromDst.Add_Click({
            $index = $this.Tag
            if ([string]::IsNullOrWhiteSpace($destTextBox.Text)) {
                [System.Windows.Forms.MessageBox]::Show("Destination field is currently empty.", "Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } else {
                $templateTextBoxes[$index].Text = $destTextBox.Text
            }
        })
        $templateGroup.Controls.Add($btnFromDst)

        # Send to Source
        $btnToSrc = New-Object System.Windows.Forms.Button
        $btnToSrc.Location = New-Object System.Drawing.Point(550, $y - 1)
        $btnToSrc.Size = New-Object System.Drawing.Size(65, 25)
        $btnToSrc.Text = "-> Source"
        $btnToSrc.Tag = $i
        $btnToSrc.BackColor = [System.Drawing.Color]::AliceBlue
        $btnToSrc.Add_Click({
            $index = $this.Tag
            $pathVal = $templateTextBoxes[$index].Text
            if (-not [string]::IsNullOrWhiteSpace($pathVal)) {
                $sourceTextBox.Text = $pathVal
                if (Test-Path $pathVal -PathType Container) {
                    $sourceTypeComboBox.SelectedItem = 'Directory'
                } elseif (Test-Path $pathVal -PathType Leaf) {
                    $sourceTypeComboBox.SelectedItem = 'File'
                }
            }
        })
        $templateGroup.Controls.Add($btnToSrc)

        # Send to Dest
        $btnToDst = New-Object System.Windows.Forms.Button
        $btnToDst.Location = New-Object System.Drawing.Point(620, $y - 1)
        $btnToDst.Size = New-Object System.Drawing.Size(65, 25)
        $btnToDst.Text = "-> Dest"
        $btnToDst.Tag = $i
        $btnToDst.BackColor = [System.Drawing.Color]::AliceBlue
        $btnToDst.Add_Click({
            $index = $this.Tag
            $pathVal = $templateTextBoxes[$index].Text
            if (-not [string]::IsNullOrWhiteSpace($pathVal)) {
                $destTextBox.Text = $pathVal
            }
        })
        $templateGroup.Controls.Add($btnToDst)
    }

    # Save Templates Button
    $saveTemplatesBtn = New-Object System.Windows.Forms.Button
    $saveTemplatesBtn.Location = New-Object System.Drawing.Point(540, 290)
    $saveTemplatesBtn.Size = New-Object System.Drawing.Size(145, 30)
    $saveTemplatesBtn.Text = "Save All Templates"
    $saveTemplatesBtn.BackColor = [System.Drawing.Color]::LightYellow
    $saveTemplatesBtn.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $saveTemplatesBtn.Add_Click({
        $updated = @()
        foreach ($tBox in $templateTextBoxes) {
            $updated += $tBox.Text.Trim()
        }
        Save-SavedTemplates -templatesToSave $updated
        [System.Windows.Forms.MessageBox]::Show("All 9 template paths saved successfully!", "Templates Saved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    })
    $templateGroup.Controls.Add($saveTemplatesBtn)

    # Options Group
    $optionsGroup = New-Object System.Windows.Forms.GroupBox
    $optionsGroup.Location = New-Object System.Drawing.Point(20, 550)
    $optionsGroup.Size = New-Object System.Drawing.Size(700, 110)
    $optionsGroup.Text = 'Options'
    $form.Controls.Add($optionsGroup)

    $recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
    $recursiveCheckBox.Location = New-Object System.Drawing.Point(20, 25)
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(650, 25)
    $recursiveCheckBox.Text = 'Recurse: Include all subdirectories and their files'
    $recursiveCheckBox.Enabled = $true
    $optionsGroup.Controls.Add($recursiveCheckBox)

    $overwriteCheckBox = New-Object System.Windows.Forms.CheckBox
    $overwriteCheckBox.Location = New-Object System.Drawing.Point(20, 50)
    $overwriteCheckBox.Size = New-Object System.Drawing.Size(650, 25)
    $overwriteCheckBox.Text = 'Overwrite existing symbolic links (if unchecked, existing links will be skipped)'
    $overwriteCheckBox.Checked = $false
    $optionsGroup.Controls.Add($overwriteCheckBox)

    $helpLabel = New-Object System.Windows.Forms.Label
    $helpLabel.Location = New-Object System.Drawing.Point(40, 75)
    $helpLabel.Size = New-Object System.Drawing.Size(630, 30)
    $helpLabel.Text = 'Recurse OFF: Links top-level files | Recurse ON: Links all nested files | Overwrite: Replaces existing symlinks'
    $helpLabel.ForeColor = [System.Drawing.Color]::Gray
    $optionsGroup.Controls.Add($helpLabel)

    # Preview Area
    $previewGroup = New-Object System.Windows.Forms.GroupBox
    $previewGroup.Location = New-Object System.Drawing.Point(20, 665)
    $previewGroup.Size = New-Object System.Drawing.Size(700, 80)
    $previewGroup.Text = 'Preview'
    $form.Controls.Add($previewGroup)

    $previewTextBox = New-Object System.Windows.Forms.TextBox
    $previewTextBox.Location = New-Object System.Drawing.Point(15, 22)
    $previewTextBox.Size = New-Object System.Drawing.Size(670, 50)
    $previewTextBox.Multiline = $true
    $previewTextBox.ReadOnly = $true
    $previewTextBox.ScrollBars = 'Vertical'
    $previewGroup.Controls.Add($previewTextBox)

    # Action Buttons
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(20, 755)
    $createButton.Size = New-Object System.Drawing.Size(200, 35)
    $createButton.Text = 'Create Symbolic Link(s)'
    $createButton.Enabled = $true
    $createButton.BackColor = [System.Drawing.Color]::LightGreen
    $createButton.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($createButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(520, 755)
    $closeButton.Size = New-Object System.Drawing.Size(200, 35)
    $closeButton.Text = 'Close'
    $closeButton.BackColor = [System.Drawing.Color]::LightCoral
    $form.Controls.Add($closeButton)

    # --- Event Handlers and Logic ---

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
                    $previewTextBox.Text = "Mode: Recursive Directory`r`nWill create symbolic links for ALL files in:`r`n$($sourceTextBox.Text)`r`nInto: $($destTextBox.Text)"
                } else {
                    $previewTextBox.Text = "Mode: Top-Level Files Only`r`nWill create symbolic links for files in:`r`n$($sourceTextBox.Text)`r`nInto: $($destTextBox.Text)"
                }
            } else {
                $previewTextBox.Text = "Mode: Single File`r`nWill create symbolic link for:`r`n$($sourceTextBox.Text)`r`nInto: $($destTextBox.Text)"
            }
        } else {
            $previewTextBox.Text = "Please select both a Source and a Destination directory/file."
        }
    }

    # SOURCE BROWSE
    $sourceBrowseButton.Add_Click({
        try {
            if ($sourceTypeComboBox.SelectedItem -eq 'File') {
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Title = "Select Source File"
                $dialog.InitialDirectory = [System.Environment]::GetFolderPath('MyComputer')
                if (-not [string]::IsNullOrWhiteSpace($sourceTextBox.Text)) {
                    if (Test-Path $sourceTextBox.Text -ErrorAction SilentlyContinue) {
                        $dialog.InitialDirectory = Split-Path $sourceTextBox.Text -Parent
                    }
                }
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                    $sourceTextBox.Text = $dialog.FileName 
                    Update-LinkPreview
                }
            } else {
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $dialog.Description = "Select Source Directory"
                $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer
                if (-not [string]::IsNullOrWhiteSpace($sourceTextBox.Text)) {
                    if (Test-Path $sourceTextBox.Text -ErrorAction SilentlyContinue) { 
                        $dialog.SelectedPath = $sourceTextBox.Text 
                    }
                }
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                    $sourceTextBox.Text = $dialog.SelectedPath 
                    Update-LinkPreview
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening browse dialog: $($_.Exception.Message)", "Browse Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })

    # DESTINATION BROWSE
    $destBrowseButton.Add_Click({
        try {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select Destination Directory"
            $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer
            if (-not [string]::IsNullOrWhiteSpace($destTextBox.Text)) {
                if (Test-Path $destTextBox.Text -ErrorAction SilentlyContinue) { 
                    $dialog.SelectedPath = $destTextBox.Text 
                }
            }
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                $destTextBox.Text = $dialog.SelectedPath 
                Update-LinkPreview
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error opening browse dialog: $($_.Exception.Message)", "Browse Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })

    $createButton.Add_Click({
        try {
            $src = $sourceTextBox.Text.TrimEnd('\')
            $dst = $destTextBox.Text.TrimEnd('\')
            $overwrite = $overwriteCheckBox.Checked

            if (-not (Test-Path $src)) {
                [System.Windows.Forms.MessageBox]::Show("Source path does not exist.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                return
            }

            if (-not (Test-Path $dst)) {
                [System.Windows.Forms.MessageBox]::Show("Destination directory does not exist.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                return
            }

            $fileCount = 0
            $dirCount = 0
            $skippedCount = 0

            if ($sourceTypeComboBox.SelectedItem -eq 'Directory') {
                if ($recursiveCheckBox.Checked) {
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

                            if (Test-Path $target) {
                                $item = Get-Item $target -Force
                                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                                    if ($overwrite) {
                                        Remove-Item -Path $target -Force
                                        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                        $fileCount++
                                    } else {
                                        $skippedCount++
                                    }
                                } else {
                                    $skippedCount++
                                }
                            } else {
                                New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                $fileCount++
                            }
                        }
                    }
                    [System.Windows.Forms.MessageBox]::Show("Recursive symbolic links operation completed!`n`nDirectories created: $dirCount`nFile symlinks created: $fileCount`nSkipped: $skippedCount", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                } else {
                    Get-ChildItem -Path $src -File | ForEach-Object {
                        $target = Join-Path $dst $_.Name
                        if (Test-Path $target) {
                            $item = Get-Item $target -Force
                            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                                if ($overwrite) {
                                    Remove-Item -Path $target -Force
                                    New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                                    $fileCount++
                                } else {
                                    $skippedCount++
                                }
                            } else {
                                $skippedCount++
                            }
                        } else {
                            New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
                            $fileCount++
                        }
                    }
                    [System.Windows.Forms.MessageBox]::Show("Top-level file symbolic links operation completed!`n`nFile symlinks created: $fileCount`nSkipped: $skippedCount", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                }
            } else {
                $target = Join-Path $dst ([System.IO.Path]::GetFileName($src))
                if (Test-Path $target) {
                    $item = Get-Item $target -Force
                    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                        if ($overwrite) {
                            Remove-Item -Path $target -Force
                            New-Item -ItemType SymbolicLink -Path $target -Target $src -Force | Out-Null
                            [System.Windows.Forms.MessageBox]::Show("Symbolic link replaced successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                        } else {
                            [System.Windows.Forms.MessageBox]::Show("Symbolic link already exists and overwrite is disabled.", "Skipped", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                        }
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("A regular file already exists at destination.`nCannot overwrite regular files.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                    }
                } else {
                    New-Item -ItemType SymbolicLink -Path $target -Target $src -Force | Out-Null
                    [System.Windows.Forms.MessageBox]::Show("Symbolic link created successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error creating symbolic link(s):`n`n$($_.Exception.Message)", "Operation Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })

    $sourceTextBox.Add_TextChanged({ Update-LinkPreview })
    $destTextBox.Add_TextChanged({ Update-LinkPreview })
    $recursiveCheckBox.Add_CheckedChanged({ Update-LinkPreview })
    
    # Auto-save templates when form closes
    $form.Add_FormClosing({
        $updated = @()
        foreach ($tBox in $templateTextBoxes) {
            $updated += $tBox.Text.Trim()
        }
        Save-SavedTemplates -templatesToSave $updated
    })

    $closeButton.Add_Click({ $form.Close() })

    $form.ShowDialog() | Out-Null
}

Show-SymbolicLinkCreatorGUI
