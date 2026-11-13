# Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

# Version history:
# v1.0 Initial release

class SymbolicLinkCreator {
    [void] CreateGUI() {
        $form = [System.Windows.Window]::new()
        $form.Title = "Symbolic Link Creator"
        $form.Width = 400
        $form.Height = 300

        # Source Selection Label and Button
        $sourceLabel = [System.Windows.Controls.Label]::new()
        $sourceLabel.Content = "Select Source (File or Directory):"
        $sourceLabel.HorizontalAlignment = 'Left'
        $sourceLabel.Margin = [System.Windows.Thickness]::new(10, 10, 0, 0)

        $sourceButton = [System.Windows.Controls.Button]::new()
        $sourceButton.Content = "Browse..."
        $sourceButton.HorizontalAlignment = 'Left'
        $sourceButton.Margin = [System.Windows.Thickness]::new(10, 35, 0, 0)
        $sourceButton.Add_Click({$this.SelectSource($form, $sourceTextBox)})

        $sourceTextBox = [System.Windows.Controls.TextBox]::new()
        $sourceTextBox.IsReadOnly = $true
        $sourceTextBox.HorizontalAlignment = 'Left'
        $sourceTextBox.Margin = [System.Windows.Thickness]::new(10, 60, 0, 0)
        $sourceTextBox.Width = 375

        # Target Selection Label and Button
        $targetLabel = [System.Windows.Controls.Label]::new()
        $targetLabel.Content = "Select Target Directory:"
        $targetLabel.HorizontalAlignment = 'Left'
        $targetLabel.Margin = [System.Windows.Thickness]::new(10, 90, 0, 0)

        $targetButton = [System.Windows.Controls.Button]::new()
        $targetButton.Content = "Browse..."
        $targetButton.HorizontalAlignment = 'Left'
        $targetButton.Margin = [System.Windows.Thickness]::new(10, 115, 0, 0)
        $targetButton.Add_Click({$this.SelectTarget($form, $targetTextBox)})

        $targetTextBox = [System.Windows.Controls.TextBox]::new()
        $targetTextBox.IsReadOnly = $true
        $targetTextBox.HorizontalAlignment = 'Left'
        $targetTextBox.Margin = [System.Windows.Thickness]::new(10, 140, 0, 0)
        $targetTextBox.Width = 375

        # Create Link Button
        $createButton = [System.Windows.Controls.Button]::new()
        $createButton.Content = "Create Symbolic Link"
        $createButton.HorizontalAlignment = 'Left'
        $createButton.Margin = [System.Windows.Thickness]::new(10, 170, 0, 0)
        $createButton.Add_Click({$this.CreateSymbolicLink($form, $sourceTextBox.Text, $targetTextBox.Text)})

        # Continue Button
        $continueButton = [System.Windows.Controls.Button]::new()
        $continueButton.Content = "Continue"
        $continueButton.HorizontalAlignment = 'Left'
        $continueButton.Margin = [System.Windows.Thickness]::new(10, 200, 0, 0)
        $continueButton.Add_Click({$form.Close()})

        # Cancel Button
        $cancelButton = [System.Windows.Controls.Button]::new()
        $cancelButton.Content = "Cancel"
        $cancelButton.HorizontalAlignment = 'Right'
        $cancelButton.Margin = [System.Windows.Thickness]::new(0, 200, 10, 0)
        $cancelButton.Add_Click({$form.Close()})

        # StackPanel to hold controls
        $stackPanel = [System.Windows.Controls.StackPanel]::new()
        $stackPanel.Children.Add($sourceLabel)
        $stackPanel.Children.Add($sourceButton)
        $stackPanel.Children.Add($sourceTextBox)
        $stackPanel.Children.Add($targetLabel)
        $stackPanel.Children.Add($targetButton)
        $stackPanel.Children.Add($targetTextBox)
        $stackPanel.Children.Add($createButton)
        $stackPanel.Children.Add($continueButton)
        $stackPanel.Children.Add($cancelButton)

        $form.Content = $stackPanel
        $form.ShowDialog()
    }

    [void] SelectSource([System.Windows.Window] $form, [System.Windows.Controls.TextBox] $textBox) {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.SelectedPath = "C:\"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $textBox.Text = $dialog.SelectedPath
        }
    }

    [void] SelectTarget([System.Windows.Window] $form, [System.Windows.Controls.TextBox] $textBox) {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.SelectedPath = "C:\"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $textBox.Text = $dialog.SelectedPath
        }
    }

    [void] CreateSymbolicLink([System.Windows.Window] $form, [string] $source, [string] $target) {
        try {
            $sourceItem = Get-Item -Path $source -ErrorAction Stop
            $linkName = Join-Path -Path $target -ChildPath $sourceItem.Name

            if (Test-Path -Path $linkName) {
                $result = [System.Windows.MessageBox]::Show("Link already exists. Overwrite?", "Overwrite?", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    Remove-Item -Path $linkName -Force
                } else {
                    return
                }
            }

            New-Item -ItemType SymbolicLink -Path $linkName -Target $source

            [System.Windows.MessageBox]::Show("Symbolic link created successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Error: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }

    [void] Run() {
        $this.CreateGUI()
    }
}

# Execute the application
$creator = [SymbolicLinkCreator]::new()
$creator.Run()
