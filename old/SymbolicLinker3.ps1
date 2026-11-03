# Symbolic Link Creator GUI
# Version 1.6 - Adds elevation check and improved recursive directory handling

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Elevation check (must be admin to use New-Item -ItemType SymbolicLink) ---
$windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $windowsPrincipal.IsInRole($adminRole)) {
    [System.Windows.Forms.MessageBox]::Show(
        "This script must be run as Administrator to create symbolic links.`n`nRight-click PowerShell and select 'Run as administrator', then run this script again.",
        "Administrator Rights Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}

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
    $recursiveCheckBox.Size = New-Object System.Drawing.Size(520, 25)
    $recursiveCheckBox.Text = 'If source is a directory, replicate subfolders and create links for all files (recursive)'
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

    # --- Helper: Update preview text ---
    function Update-LinkPreview {
        if ($sourceTextBox.Text -and $destTextBox.Text) {
            $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text.TrimEnd('\'))
            if (-not $sourceName) {
                $sourceName = [System.IO.Path]::GetFileName($sourceTextBox.Text)
            }

            if ($recursiveCheckBox.Checked -and $sourceTypeComboBox.SelectedItem -eq 'Directory') {
                $previewTextBox.Text = "Recursive symbolic links preview:`nSource root: $($sourceTextBox.Text)`nDestination root: $($destTextBox.Text)`nAll subfolders will be created and files linked."
            }
            else {
                $destPath = Join-Path $destTextBox.Text $sourceName
                $previewTextBox.Text = "Symbolic Link Preview:`nSource: $($sourceTextBox.Text)`nDestination: $destPath"
            }

            $createButton.Enabled = $true
        }
        else {
            $previewTextBox.Text = ''
            $createButton.Enabled = $false
        }
    }

    # Event Handlers
    $sourceTypeComboBox.Add_SelectedIndexChanged({
        $sourceTextBox.Text = ''      # Clear previous selection
        Update-LinkPreview
    })

    $sourceBrowseButton.Add_Click({
        if ($sourceTypeComboBox.SelectedItem -eq 'File') {
            $sourceDialog = New-Object System.Windows.Forms.OpenFileDialog
            $sourceDialog.Multiselect = $false

            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.FileName
                Update-LinkPreview
            }
        }
        else {
            $sourceDialog = New-Object System.Windows.Forms.FolderBrowserDialog

            if ($sourceDialog.ShowDialog() -eq 'OK') {
                $sourceTextBox.Text = $sourceDialog.SelectedPath
                Update-LinkPreview
            }
        }
    })

    $destBrowseButton.Add_Click({
        $destDialog = New-Object System.Windows.Forms.FolderBrowserDialog

        if ($destDialog.ShowDialog() -eq 'OK') {
            $destTextBox.Text = $destDialog.SelectedPath
            Update-LinkPreview
        }
    })

    # Validation for text boxes
    $sourceTextBox.Add_TextChanged({ Update-LinkPreview })
    $destTextBox.Add_TextChanged({ Update-LinkPreview })
    $recursiveCheckBox.Add_CheckedChanged({ Update-LinkPreview })

    # --- Main creation logic ---
    $createButton.Add_Click({
        try {
            $sourcePath = $sourceTextBox.Text.Trim()
            $destRoot  = $destTextBox.Text.Trim()

            if (-not (Test-Path $sourcePath)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Source path does not exist.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                return
            }

            if (-not (Test-Path $destRoot)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Destination directory does not exist.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                return
            }

            $isDirectorySource = Test-Path -Path $sourcePath -PathType Container

            if ($recursiveCheckBox.Checked -and $isDirectorySource) {
                # Replicate directory tree and create file links
                $sourceRoot = (Resolve-Path $sourcePath).Path.TrimEnd('\')

                # Create the top-level directory under destination (if not present)
                $topName = [System.IO.Path]::GetFileName($sourceRoot)
                $destRootForSource = Join-Path $destRoot $topName
                if (-not (Test-Path $destRootForSource)) {
                    New-Item -ItemType Directory -Path $destRootForSource | Out-Null
                }

                # Create subdirectories
                Get-ChildItem -Path $sourceRoot -Recurse -Directory | ForEach-Object {
                    $relativeDir = $_.FullName.Substring($sourceRoot.Length).TrimStart('\')
                    $targetDir   = Join-Path $destRootForSource $relativeDir

                    if (-not (Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir | Out-Null
                    }
                }

                # Create file symlinks
                Get-ChildItem -Path $sourceRoot -Recurse -File | ForEach-Object {
                    $relativeFile = $_.FullName.Substring($sourceRoot.Length).TrimStart('\')
                    $targetPath   = Join-Path $destRootForSource $relativeFile
                    $targetDir    = Split-Path $targetPath

                    if (-not (Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir | Out-Null
                    }

                    if (Test-Path $targetPath) {
                        # Skip existing targets to avoid overwrite
                        return
                    }

                    New-Item -ItemType SymbolicLink -Path $targetPath -Target $_.FullName | Out-Null
                }
            }
            else {
                # Single link for file or directory
                $sourceName = [System.IO.Path]::GetFileName($sourcePath.TrimEnd('\'))
                if (-not $sourceName) {
                    $sourceName = [System.IO.Path]::GetFileName($sourcePath)
                }

                $fullDestPath = Join-Path $destRoot $sourceName

                if (Test-Path $fullDestPath) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Destination '$fullDestPath' already exists. Delete or rename it, then try again.",
                        "Destination Exists",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    ) | Out-Null
                    return
                }

                New-Item -ItemType SymbolicLink -Path $fullDestPath -Target $sourcePath | Out-Null
            }

            [System.Windows.Forms.MessageBox]::Show(
                "Symbolic link(s) created successfully!",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null

            $continueButton.Enabled = $true
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error creating symbolic link: $($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
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

    $closeButton.Add_Click({ $form.Close() })

    $form.ShowDialog() | Out-Null
}

# Run the GUI
Show-SymbolicLinkCreatorGUI
