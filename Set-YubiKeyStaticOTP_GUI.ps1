<#
.SCRIPTNAME    Set-YubiKeyStaticOTP_GUI.ps1
.DESCRIPTION   GUI wrapper for setting a static OTP on a YubiKey slot via ykman, passing the PIN via stdin, with real-time log updates.
.VERSION       1.1.2
.AUTHOR        Michael Mercer mmercer@ocvibe.com
.LASTUPDATED   2025-04-29

.NOTES
- v0.5.0: Credit Kelly Seay (kseay@ocvibe.com) for the initial script
- v1.0.0: Initial version with GUI for setting a static OTP using ykman
- v1.1.0: Security enhancements:
    • Removed nested PowerShell execution
    • Validated YubiKey presence before writing
    • Cleared password variable from memory
    • Input validation for slot and keyboard layout
    • Check for ykman presence in system PATH
- v1.1.1: Added check for ykman and error handling:
    • Displays error message and opens download page if ykman is not installed
- v1.1.2: UI/UX improvements:
    • Fixed Device Info formatting for better log display
    • Increased log output box height for readability
    • Disabled form resizing and maximize button (FixedDialog)
    • Even spacing and sizing of Save, Device Info, and Exit buttons
#>

# Define ykman parameters
$YkmanPath      = "ykman"
$OtpSlot        = 2
$KeyboardLayout = "US"

# Set error action preference
$ErrorActionPreference = "Stop"

# Input sanitization
if ($KeyboardLayout -notmatch '^[a-zA-Z]+$') {
    throw "Invalid keyboard layout specified."
}
if ($OtpSlot -notin 1, 2) {
    throw "Invalid OTP slot. Must be 1 or 2."
}

# Ensure ykman is available v3
if (-not (Get-Command $YkmanPath -ErrorAction SilentlyContinue)) {
    $url = "https://github.com/Yubico/yubikey-manager/releases"
    Set-Clipboard -Value $url
    Start-Process $url
    [System.Windows.Forms.MessageBox]::Show(
        "YubiKey Manager (ykman) was not found in your system PATH." + [Environment]::NewLine +
        "Please download and install it from:" + [Environment]::NewLine + [Environment]::NewLine +
        $url + [Environment]::NewLine + [Environment]::NewLine +
        "(This link has been copied to your clipboard and opened in your browser.)",
        "ykman Not Found",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    return
}

# Load necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Build the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Save Static Password to YubiKey"
$form.Size = New-Object System.Drawing.Size(620,460)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

# Instruction label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Paste your admin password and click Save."
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10,10)
$label.Font = New-Object System.Drawing.Font('Segoe UI',12)
$form.Controls.Add($label)

# Version label
$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "Version 1.1.2"
$versionLabel.AutoSize = $true
$versionLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$versionLabel.ForeColor = [System.Drawing.Color]::Gray
$versionLabel.Location = New-Object System.Drawing.Point(500,10)
$form.Controls.Add($versionLabel)

# Static OTP input
$passwordBox = New-Object System.Windows.Forms.TextBox
$passwordBox.Location = New-Object System.Drawing.Point(10,45)
$passwordBox.Size = New-Object System.Drawing.Size(580,30)
$passwordBox.UseSystemPasswordChar = $true
$form.Controls.Add($passwordBox)

# Save button
$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save"
$saveButton.Location = New-Object System.Drawing.Point(10,90)
$saveButton.Size = New-Object System.Drawing.Size(100,23)
$form.Controls.Add($saveButton)

# Info button
$infoButton = New-Object System.Windows.Forms.Button
$infoButton.Text = "Device Info"
$infoButton.Location = New-Object System.Drawing.Point(120,90)
$infoButton.Size = New-Object System.Drawing.Size(100,23)
$form.Controls.Add($infoButton)

# Exit button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(230,90)
$exitButton.Size = New-Object System.Drawing.Size(100,23)
$form.Controls.Add($exitButton)


# Configure Enter/Esc
$form.AcceptButton = $saveButton
$form.CancelButton = $exitButton

# Log output box
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(10,140)
$logBox.Size = New-Object System.Drawing.Size(580,260)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::Black
$logBox.ForeColor = [System.Drawing.Color]::White
$logBox.Font = New-Object System.Drawing.Font('Consolas',10)
$form.Controls.Add($logBox)

# Save button click handler
$saveButton.Add_Click({
    $logBox.Clear()
    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Saving password to slot $OtpSlot...`r`n")
    [System.Windows.Forms.Application]::DoEvents()

    $staticOTP = $passwordBox.Text
    if (-not $staticOTP) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter the admin password before saving.",
            "Input Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Check if a YubiKey is present
    try {
        $ykmanList = & $YkmanPath list 2>$null
        if (-not $ykmanList) {
            [System.Windows.Forms.MessageBox]::Show("No YubiKey detected. Please insert one and try again.","Device Not Found",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Unable to check YubiKey presence. Is 'ykman' installed and in PATH?","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $saveButton.Enabled = $false

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $YkmanPath
    $startInfo.Arguments = "otp static --keyboard-layout $KeyboardLayout --force $OtpSlot"
    $startInfo.RedirectStandardInput  = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError  = $true
    $startInfo.UseShellExecute        = $false

    try {
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $startInfo
        $proc.Start() | Out-Null
        $proc.StandardInput.WriteLine($staticOTP)
        $proc.StandardInput.Close()

        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($proc.ExitCode -eq 0) {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ✅ Static password saved successfully.`r`n")
        } else {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ❌ ykman exited with code $($proc.ExitCode).`r`n")
        }

        if ($stdout) {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] " + $stdout.Trim() + "`r`n")
        }
        if ($stderr) {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] " + $stderr.Trim() + "`r`n")
        }

    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Error invoking ykman: $($_.Exception.Message)`r`n")
    }

    # Clear sensitive input
    $passwordBox.Clear()
    $staticOTP = $null
    $saveButton.Enabled = $true
})

# Info button click handler
$infoButton.Add_Click({
    $logBox.Clear()
    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Retrieving YubiKey device info...`r`n")
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $infoOutput = & $YkmanPath info 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Split the output by line to retain formatting and append each line with proper newlines
            $infoOutput -split "`n" | ForEach-Object {
                $logBox.AppendText($_.TrimEnd() + "`r`n")
            }
        } else {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ❌ Failed to retrieve device info.`r`n")
            $logBox.AppendText($infoOutput + "`r`n")
        }
    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Error retrieving device info: $($_.Exception.Message)`r`n")
    }
})


# Exit button handler
$exitButton.Add_Click({ $form.Close() })

# Show the form
[void]$form.ShowDialog()
