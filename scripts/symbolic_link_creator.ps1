[CmdletBinding()]
param(
    [string]$TargetPath,
    [string]$LinkPath,
    [switch]$Force,
    [switch]$UseGui
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ArgumentName
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$ArgumentName is required."
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Show-Usage {
    $message = @"
Symbolic Link Creator

Usage:
  pwsh ./symbolic_link_creator.ps1 -TargetPath "C:\source\folder" -LinkPath "D:\links\folder" [-Force]
  pwsh ./symbolic_link_creator.ps1 -UseGui

Parameters:
  -TargetPath   Existing file or directory to link to.
  -LinkPath     Destination path for the new symbolic link.
  -Force        Allows replacement of an existing path after explicit approval.
  -UseGui       Opens a simple Windows form to choose the source and link locations.

Notes:
  - The file or directory at the target path must already exist.
  - The link parent directory must already exist.
  - Existing items are never overwritten unless -Force is specified.
  - On Windows, creating symbolic links usually requires Administrator rights or Developer Mode.
"@

    Write-Host $message
}

function New-SymbolicLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$LinkPath,

        [switch]$Force
    )

    $resolvedTarget = Resolve-FullPath -Path $TargetPath -ArgumentName 'TargetPath'
    $resolvedLink = Resolve-FullPath -Path $LinkPath -ArgumentName 'LinkPath'

    if (-not (Test-Path -LiteralPath $resolvedTarget)) {
        throw "The target path '$resolvedTarget' does not exist."
    }

    if ($resolvedTarget -eq $resolvedLink) {
        throw 'The target path and the link path must be different.'
    }

    $linkParent = Split-Path -Parent $resolvedLink
    if ([string]::IsNullOrWhiteSpace($linkParent)) {
        $linkParent = (Get-Location).Path
    }

    if (-not (Test-Path -LiteralPath $linkParent)) {
        throw "The parent folder for the link does not exist: '$linkParent'"
    }

    $targetItem = Get-Item -LiteralPath $resolvedTarget -ErrorAction Stop
    $linkAlreadyExists = Test-Path -LiteralPath $resolvedLink

    if ($linkAlreadyExists) {
        if (-not $Force) {
            $response = Read-Host "The path '$resolvedLink' already exists. Overwrite it? [Y/N]"
            if ($response -notmatch '^(Y|YES)$') {
                return [pscustomobject]@{
                    Created = $false
                    TargetPath = $resolvedTarget
                    LinkPath = $resolvedLink
                    Message = 'The link was not created because the destination already existed.'
                }
            }
        }

        try {
            Remove-Item -LiteralPath $resolvedLink -Recurse -Force -ErrorAction Stop
        }
        catch {
            throw "Unable to remove the existing item at '$resolvedLink': $($_.Exception.Message)"
        }
    }

    try {
        $createdLink = New-Item -ItemType SymbolicLink -Path $resolvedLink -Target $resolvedTarget -ErrorAction Stop
        $linkType = if ($targetItem.PSIsContainer) { 'Directory' } else { 'File' }

        return [pscustomobject]@{
            Created = $true
            TargetPath = $resolvedTarget
            LinkPath = $resolvedLink
            LinkType = $linkType
            Item = $createdLink
            Message = "Created symbolic link: $resolvedLink -> $resolvedTarget"
        }
    }
    catch {
        throw "Unable to create the symbolic link: $($_.Exception.Message)"
    }
}

function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Symbolic Link Creator'
    $form.Size = New-Object System.Drawing.Size(560, 260)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $targetLabel = New-Object System.Windows.Forms.Label
    $targetLabel.Text = 'Target path:'
    $targetLabel.Location = New-Object System.Drawing.Point(12, 18)
    $targetLabel.Size = New-Object System.Drawing.Size(90, 24)
    $form.Controls.Add($targetLabel)

    $targetTextBox = New-Object System.Windows.Forms.TextBox
    $targetTextBox.Location = New-Object System.Drawing.Point(110, 15)
    $targetTextBox.Size = New-Object System.Drawing.Size(320, 24)
    $targetTextBox.ReadOnly = $true
    $form.Controls.Add($targetTextBox)

    $targetBrowse = New-Object System.Windows.Forms.Button
    $targetBrowse.Text = 'Browse...'
    $targetBrowse.Location = New-Object System.Drawing.Point(440, 12)
    $targetBrowse.Size = New-Object System.Drawing.Size(95, 30)
    $targetBrowse.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select a target file or folder'
        $dialog.CheckFileExists = $false
        $dialog.CheckPathExists = $true
        $dialog.InitialDirectory = [System.Environment]::GetFolderPath('MyDocuments')
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $targetTextBox.Text = $dialog.FileName
        }
    })
    $form.Controls.Add($targetBrowse)

    $linkLabel = New-Object System.Windows.Forms.Label
    $linkLabel.Text = 'Link path:'
    $linkLabel.Location = New-Object System.Drawing.Point(12, 58)
    $linkLabel.Size = New-Object System.Drawing.Size(90, 24)
    $form.Controls.Add($linkLabel)

    $linkTextBox = New-Object System.Windows.Forms.TextBox
    $linkTextBox.Location = New-Object System.Drawing.Point(110, 55)
    $linkTextBox.Size = New-Object System.Drawing.Size(320, 24)
    $form.Controls.Add($linkTextBox)

    $linkBrowse = New-Object System.Windows.Forms.Button
    $linkBrowse.Text = 'Browse...'
    $linkBrowse.Location = New-Object System.Drawing.Point(440, 52)
    $linkBrowse.Size = New-Object System.Drawing.Size(95, 30)
    $linkBrowse.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the folder for the new link'
        $dialog.ShowNewFolderButton = $true
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $linkTextBox.Text = Join-Path -Path $dialog.SelectedPath -ChildPath 'new-link'
        }
    })
    $form.Controls.Add($linkBrowse)

    $forceCheckBox = New-Object System.Windows.Forms.CheckBox
    $forceCheckBox.Text = 'Overwrite existing link if it already exists'
    $forceCheckBox.Location = New-Object System.Drawing.Point(115, 95)
    $forceCheckBox.Size = New-Object System.Drawing.Size(260, 24)
    $form.Controls.Add($forceCheckBox)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = ''
    $statusLabel.Location = New-Object System.Drawing.Point(12, 128)
    $statusLabel.Size = New-Object System.Drawing.Size(520, 48)
    $statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $statusLabel.AutoEllipsis = $true
    $form.Controls.Add($statusLabel)

    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Text = 'Create Link'
    $createButton.Location = New-Object System.Drawing.Point(315, 185)
    $createButton.Size = New-Object System.Drawing.Size(110, 30)
    $createButton.Add_Click({
        try {
            $targetValue = $targetTextBox.Text.Trim()
            $linkValue = $linkTextBox.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($targetValue) -or [string]::IsNullOrWhiteSpace($linkValue)) {
                throw 'Both a target path and a link path are required.'
            }

            $result = New-SymbolicLink -TargetPath $targetValue -LinkPath $linkValue -Force:$forceCheckBox.Checked
            $statusLabel.Text = $result.Message
            $statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
        }
        catch {
            $statusLabel.Text = $_.Exception.Message
            $statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
        }
    })
    $form.Controls.Add($createButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Close'
    $closeButton.Location = New-Object System.Drawing.Point(435, 185)
    $closeButton.Size = New-Object System.Drawing.Size(90, 30)
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    $form.ShowDialog()
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $PSBoundParameters.ContainsKey('TargetPath') -and -not $PSBoundParameters.ContainsKey('LinkPath') -and ($UseGui -or [Environment]::UserInteractive)) {
        Show-Gui
        exit 0
    }

    if (-not $PSBoundParameters.ContainsKey('TargetPath') -or -not $PSBoundParameters.ContainsKey('LinkPath')) {
        Show-Usage
        exit 1
    }

    try {
        $result = New-SymbolicLink -TargetPath $TargetPath -LinkPath $LinkPath -Force:$Force
        if ($result.Created) {
            Write-Host $result.Message
            exit 0
        }

        Write-Host $result.Message
        exit 0
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
