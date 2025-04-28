<#
.SCRIPTNAME    Set-YubiKeyslot2OTPGUIv1.2.ps1
.DESCRIPTION   GUI wrapper for setting a static OTP on a YubiKey slot via ykman, passing the PIN via stdin, with real-time log updates. 
.VERSION       1.2.0
.AUTHOR        Michael Mercer https://github.com/sgtmons/Set-YubiKeyStaticOTP
.LASTUPDATED   2025-04-26

.NOTES
- v0.5.0: Credit Kelly Seay for the initial script
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
- v1.1.3: Info Button handler bug & General Improvements 
    • If $infoOutput was text it was fine. But if YubiKey was missing & $YkmanPath info throws an ErrorRecord. This was failing because $infoOutput was not a string
    • Added Global Error trap for any uncaught fatal errors and added no YubiKey detected Windows Popup for Info button click handler.
- v1.1.4: General Improvements
    • Added Smart Card service status check—warn in log box if it’s disabled on start.
- v1.2: UI Improvements & Security enhancement
    • Added Clear Clipboard Button
	• Added Past Password Button    
    • Added Clear password variable securely
- Known Issues 1: 
    • The random char string -:6usM+mU2` o[_ will not save. It adds a -1 to the end.
    • Static OTP values that end with an underscore character (_) may result in an **unexpected trailing "-l" or similar keystroke** being output by the YubiKey. For example, -:6usM+mU2` o[_ will not save. It adds a -1 to the end.
    • This is likely caused by the YubiKey's keyboard emulation not properly releasing the Shift key when `_` is typed last (since `_` is Shift + `-` on US keyboards).
    • Workaround: Avoid using _ or ` or ´ as the **final character** in static OTP values.
- Known Issue 2:
    • If you have multiple Yubi Keys plugged in you will get an error when trying to do anything. "ERROR: Multiple YubiKeys detected. Use --device SERIAL to specify which one to use."
    • The use case for this was one yubikey. I might eventually have it pull all yubikey serials and have an input box for the user to specify. 
    • Workaround: Just unplug all but one yubikey or if you need to work with multiple keys you can simply use ykman directly! 
#>


# Define ykman parameters
$YkmanPath      = "ykman"
$OtpSlot        = 2
$KeyboardLayout = "US"

# Set error action preference
$ErrorActionPreference = "Stop"

# Global error trap for any uncaught fatal errors
trap {
    [System.Windows.Forms.MessageBox]::Show(
        "An unexpected error occurred:`n$($_.Exception.Message)",
        "Fatal Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# Input sanitization
if ($KeyboardLayout -notmatch '^[a-zA-Z]+$') {
    throw "Invalid keyboard layout specified."
}
if ($OtpSlot -notin 1, 2) {
    throw "Invalid OTP slot. Must be 1 or 2."
}

# Ensure ykman is available
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

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Build form
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
$versionLabel.Text = "Version 1.2"
$versionLabel.AutoSize = $true
$versionLabel.Font = New-Object System.Drawing.Font('Segoe UI',8,[System.Drawing.FontStyle]::Italic)
$versionLabel.ForeColor = [System.Drawing.Color]::Gray
$versionLabel.Location = New-Object System.Drawing.Point(500,10)
$form.Controls.Add($versionLabel)

# Static OTP input box
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

# Paste Password button
$pasteButton = New-Object System.Windows.Forms.Button
$pasteButton.Text = "Paste Password"
$pasteButton.Location = New-Object System.Drawing.Point(120,90)
$pasteButton.Size = New-Object System.Drawing.Size(120,23)
$form.Controls.Add($pasteButton)

# Clear Clipboard button
$clearClipboardButton = New-Object System.Windows.Forms.Button
$clearClipboardButton.Text = "Clear Clipboard"
$clearClipboardButton.Location = New-Object System.Drawing.Point(250,90)
$clearClipboardButton.Size = New-Object System.Drawing.Size(120,23)
$form.Controls.Add($clearClipboardButton)

# Info button
$infoButton = New-Object System.Windows.Forms.Button
$infoButton.Text = "Device Info"
$infoButton.Location = New-Object System.Drawing.Point(380,90)
$infoButton.Size = New-Object System.Drawing.Size(100,23)
$form.Controls.Add($infoButton)

# Exit button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(490,90)
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

# Smart Card service check
try {
    $scSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='SCardSvr'" -ErrorAction SilentlyContinue
    if ($scSvc -and $scSvc.StartMode -eq 'Disabled') {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Smart Card service (SCardSvr) is disabled. Please set its Startup Type to Manual (Trigger Start) default.`r`n")
    }
} catch {
    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Failed to check Smart Card service status: $($_.Exception.Message)`r`n")
}

# Save button click handler
$saveButton.Add_Click({
    $logBox.Clear()
    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Saving password to slot $OtpSlot...`r`n")
    [System.Windows.Forms.Application]::DoEvents()

    $staticOTP = $passwordBox.Text.Trim()
    if (-not $staticOTP) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter the admin password before saving.",
            "Input Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    try {
        $ykmanList = & $YkmanPath list 2>$null
        if (-not $ykmanList) {
            [System.Windows.Forms.MessageBox]::Show(
                "No YubiKey detected. Please insert one and try again.",
                "Device Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to check YubiKey presence. Is 'ykman' installed and in PATH?",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    $saveButton.Enabled = $false

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $YkmanPath
    $startInfo.Arguments = "otp static --keyboard-layout $KeyboardLayout --force $OtpSlot"
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false

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
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Static password saved successfully.`r`n")
        } else {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ykman exited with code $($proc.ExitCode).`r`n")
        }

        if ($stdout) { $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $stdout`r`n") }
        if ($stderr) { $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $stderr`r`n") }
    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Error: $($_.Exception.Message)`r`n")
    }
    # Clear password variable securely
if ($staticOTP) {
    try {
        # Overwrite $staticOTP contents manually
        [System.Text.StringBuilder]$secureWipe = New-Object System.Text.StringBuilder($staticOTP.Length)
        $staticOTP.ToCharArray() | ForEach-Object { [void]$secureWipe.Append('X') }
        $staticOTP = $secureWipe.ToString()
    } catch {
        # If wiping fails, at least null it
        $staticOTP = $null
    }
}
    $passwordBox.Clear()
    $saveButton.Enabled = $true
})

# Paste Password button click handler
$pasteButton.Add_Click({
    try {
        $passwordBox.Text = [System.Windows.Forms.Clipboard]::GetText()
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Password pasted from clipboard.`r`n")
    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Failed to paste password: $($_.Exception.Message)`r`n")
    }
})

# Clear Clipboard button click handler
$clearClipboardButton.Add_Click({
    try {
        [System.Windows.Forms.Clipboard]::Clear()
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Clipboard cleared by user.`r`n")
    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Failed to clear clipboard (might be locked by another app): $($_.Exception.Message)`r`n")
    }
})

# Info button click handler
$infoButton.Add_Click({
    $logBox.Clear()
    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Fetching YubiKey device info...`r`n")
    [System.Windows.Forms.Application]::DoEvents()
    $logBox.SelectionStart = 0
    $logBox.ScrollToCaret()

    try {
        $ykmanList = & $YkmanPath list 2>$null
        if (-not $ykmanList) {
            [System.Windows.Forms.MessageBox]::Show(
                "No YubiKey detected. Please insert a YubiKey first.",
                "Device Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        $infoOutput = (& $YkmanPath info 2>&1) | Out-String
        if ($LASTEXITCODE -eq 0) {
            $infoOutput -split "`n" | ForEach-Object { $logBox.AppendText($_.TrimEnd() + "`r`n") }
            $logBox.SelectionStart = $logBox.GetFirstCharIndexFromLine(0)
            $logBox.ScrollToCaret()
        } else {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Failed to retrieve device info.`r`n")
            $logBox.AppendText($infoOutput + "`r`n")
        }
    } catch {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Error retrieving device info: $($_.Exception.Message)`r`n")
    }
})

# Exit button click handler
$exitButton.Add_Click({ $form.Close() })

# Show form
[void]$form.ShowDialog()
