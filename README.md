# Set-YubiKeyStaticOTP

A PowerShell GUI wrapper for securely setting a static OTP (one-time password) on a YubiKey slot using Yubico's `ykman` command-line tool.

---

## 📖 Full Description

**Set-YubiKeyStaticOTP** is a Windows PowerShell script that provides a graphical user interface (GUI) for setting a static OTP/password onto YubiKey slot 2 using the Yubico `ykman` CLI.

This script is designed for administrators and security professionals who need a simple, controlled way to program static passwords onto YubiKeys without having to use complex CLI parameters.

The GUI allows you to:
- Paste or type your password securely.
- Write the static OTP to YubiKey slot 2.
- View connected YubiKey device information.
- Handle Smart Card service status checks (important for smart card capabilities).
- Clear clipboard contents for better hygiene after use.
- Clear sensitive password variables from memory after writing.
- Detect missing `ykman` installation and assist users in installing it.

The script uses Windows Forms to create a clean, fixed-size interface, real-time logging, and improves user experience and error handling compared to direct CLI usage.

---

## ⚠️ Important Security Notice

Saving a **static OTP** or **static password** onto a YubiKey carries inherent security risks:

- **Static OTPs are triggered by a long press and are not PIN-protected.**  
  Anyone with physical possession of the YubiKey could trigger the OTP without needing to know a PIN or password.

- **Lost or stolen YubiKeys storing static credentials could lead to unauthorized access**, especially if the static value can be tied back to a user account or system.

- **Mitigation best practices**:
  - Always ensure accounts protected by static OTPs **also require Multi-Factor Authentication (MFA)** wherever possible.
  - **Regularly rotate passwords and OTPs** associated with YubiKeys used for static authentication.
  - **Physically secure** YubiKeys that store static credentials.
  - Avoid using static OTPs for high-risk, highly privileged, or externally exposed accounts.

> While these mitigations reduce the risk, **the risk cannot be eliminated entirely**.

---

## ✨ Features

- Securely sets static OTP on YubiKey slot 2
- GUI-based interface with real-time logging
- Device info retrieval for YubiKeys
- Clipboard paste and clearing functions
- Secure memory clearing of sensitive variables
- Smart Card service status check and warning
- Handles multiple errors gracefully
- Automatically detects and assists with missing `ykman`
- Prevents form resizing for consistent UX

---

## 🚀 Requirements

- **Windows** 10/11 (PowerShell 5.1 or newer, or PowerShell 7+)
- **YubiKey Manager CLI (`ykman`)** installed and in the system PATH
  - Download: [Yubico YubiKey Manager Releases](https://github.com/Yubico/yubikey-manager/releases)

---

## 🛠 Installation

1. Install YubiKey Manager (`ykman`) from Yubico's GitHub releases.
2. Download this repository or the script file: `Set-YubiKeyslot2OTPGUIv1.2.ps1`
3. Launch PowerShell as Administrator (if needed) and run:
   ```powershell
   .\Set-YubiKeyslot2OTPGUIv1.2.ps1

