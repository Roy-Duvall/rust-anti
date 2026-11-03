
Add-Type -AssemblyName System.Windows.Forms

function Create-SymbolicLink {
    param (
        [string]$LinkPath,
        [string]$TargetPath
    )

    try {
        # Validate paths
        if (-not (Test-Path $TargetPath -PathType Container)) {
            [System.Windows.Forms.MessageBox]::Show("Target path does not exist or is not a directory.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return $false
        }

        # Check if link already exists
        if (Test-Path $LinkPath) {
            $confirmOverwrite = [System.Windows.Forms.MessageBox]::Show("The link path already exists. Do you want to overwrite?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($confirmOverwrite -eq 'No') {
                return $false
            }
        }

        # Create symbolic link
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error creating symbolic link: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Show-SymbolicLinkDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Symbolic Link Creator'
    $form.Size = New-Object System.Drawing.Size(500, 300)
    $form.StartPosition = 'CenterScreen'

    # Link Path Label and Textbox
    $linkPathLabel = New-Object System.Windows.Forms.Label
    $linkPathLabel.Location = New-Object System.Drawing.Point(10, 20)
    $linkPathLabel.Size = New-Object System.Drawing.Size(100, 20)
    $linkPathLabel.Text = 'Link Path:'
    $form.Controls.Add($linkPathLabel)

    $linkPathTextBox = New-Object System.Windows.Forms.TextBox
    $linkPathTextBox.Location = New-Object System.Drawing.Point(120, 20)
    $linkPathTextBox.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($linkPathTextBox)

    $linkPathBrowseButton = New-Object System.Windows.Forms.Button
    $linkPathBrowseButton.Location = New-Object System.Drawing.Point(430, 20)
    $linkPathBrowseButton.Size = New-Object System.Drawing.Size(40, 20)
    $linkPathBrowseButton.Text = '...'
    $form.Controls.Add($linkPathBrowseButton)

    # Target Path Label and Textbox
    $targetPathLabel = New-Object System.Windows.Forms.Label
    $targetPathLabel.Location = New-Object System.Drawing.Point(10, 60)
    $targetPathLabel.Size = New-Object System.Drawing.Size(100, 20)
    $targetPathLabel.Text = 'Target Path:'
    $form.Controls.Add($targetPathLabel)

    $targetPathTextBox = New-Object System.Windows.Forms.TextBox
    $targetPathTextBox.Location = New-Object System.Drawing.Point(120, 60)
    $targetPathTextBox.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($targetPathTextBox)

    $targetPathBrowseButton = New-Object System.Windows.Forms.Button
    $targetPathBrowseButton.Location = New-Object System.Drawing.Point(430, 60)
    $targetPathBrowseButton.Size = New-Object System.Drawing.Size(40, 20)
    $targetPathBrowseButton.Text = '...'
    $form.Controls.Add($targetPathBrowseButton)

    # Browse Button Event Handlers
    $linkPathBrowseButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select Link Location"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $linkPathTextBox.Text = $folderBrowser.SelectedPath
        }
    })

    $targetPathBrowseButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select Target Directory"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $targetPathTextBox.Text = $folderBrowser.SelectedPath
        }
    })

    # Create Link Button
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(200, 100)
    $createButton.Size = New-Object System.Drawing.Size(100, 30)
    $createButton.Text = 'Create Link'
    $form.Controls.Add($createButton)

    # Result Label
    $resultLabel = New-Object System.Windows.Forms.Label
    $resultLabel.Location = New-Object System.Drawing.Point(10, 140)
    $resultLabel.Size = New-Object System.Drawing.Size(480, 50)
    $resultLabel.Text = ''
    $form.Controls.Add($resultLabel)

    # Create Link Event Handler
    $createButton.Add_Click({
        $linkPath = $linkPathTextBox.Text
        $targetPath = $targetPathTextBox.Text

        if ([string]::IsNullOrWhiteSpace($linkPath) -or [string]::IsNullOrWhiteSpace($targetPath)) {
            $resultLabel.Text = "Please specify both link and target paths."
            return
        }

        $result = Create-SymbolicLink -LinkPath $linkPath -TargetPath $targetPath

        if ($result) {
            $resultLabel.Text = "Symbolic link created successfully from $linkPath to $targetPath."
            # Optionally, clear the textboxes after successful creation
            $linkPathTextBox.Clear()
            $targetPathTextBox.Clear()
        }
        else {
            $resultLabel.Text = "Failed to create symbolic link."
        }
    })

    $form.ShowDialog()
}

# Run the symbolic link creator dialog
Show-SymbolicLinkDialog
