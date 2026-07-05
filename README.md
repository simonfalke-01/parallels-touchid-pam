# Fedora Touch ID PAM Bridge for Parallels

Use macOS Touch ID to approve Fedora PAM authentication inside a Parallels VM.

This project is a host-to-guest authentication bridge. It does not expose the Mac fingerprint reader as a Linux fingerprint device. Fedora writes a signed authentication request into a Parallels shared folder, a macOS LaunchAgent prompts Touch ID with Apple LocalAuthentication, and Fedora accepts a signed response through PAM.

Validated locally on:

- Fedora 44 KDE/Plasma under Parallels on macOS
- `sudo`
- KDE polkit desktop authorization prompts
- KDE lock/unlock
- SDDM login hook installed, but login requires logout/reboot to test

## Important

The install must run from a directory visible to both Fedora and macOS, such as a Parallels shared folder. This repository can live in `~/fedora-touchid-pam` as the source copy, but for installation copy it to a shared path first unless your Fedora home is also mounted on macOS.

Example Fedora shared path:

```bash
/media/psf/iCloud/fedora-touchid-pam
```

Example macOS path for the same iCloud shared folder:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/fedora-touchid-pam
```

## Quick Install

From Fedora, in the shared-folder copy:

```bash
./fedora/install-fedora-sudo.sh
```

From macOS Terminal, in the same shared-folder copy:

```bash
./macos/install-macos-helper.sh
```

Back in Fedora:

```bash
sudo -k
sudo true
./fedora/enable-fedora-polkit.sh
pkexec true
./fedora/enable-fedora-kde-lock.sh
loginctl lock-session
./fedora/enable-fedora-sddm-login.sh
```

Full setup docs are in [docs/INSTALL.md](docs/INSTALL.md).

## Rollback

Run these from Fedora:

```bash
./fedora/disable-fedora-sddm-login.sh
./fedora/disable-fedora-kde-lock.sh
./fedora/disable-fedora-polkit.sh
./fedora/disable-fedora-sudo.sh
```

Run this from macOS:

```bash
./macos/uninstall-macos-helper.sh
```

More detail is in [docs/ROLLBACK.md](docs/ROLLBACK.md).

## Repo Layout

- `fedora/fedora-touchid-pam`: Fedora PAM helper written in Python.
- `fedora/fedora-touchid-pam-wrapper.c`: setuid-root wrapper needed for PAM callers that run as the desktop user.
- `fedora/install-fedora-sudo.sh`: installs the Fedora helper, root HMAC secret, bridge config, and initial `sudo` PAM hook.
- `fedora/enable-fedora-polkit.sh`: enables KDE/system graphical authorization prompts.
- `fedora/enable-fedora-kde-lock.sh`: enables KDE lock/unlock.
- `fedora/enable-fedora-sddm-login.sh`: enables SDDM login.
- `macos/FedoraTouchIDHelper.swift`: macOS Touch ID helper.
- `macos/install-macos-helper.sh`: compiles and installs the macOS LaunchAgent.
- `docs/`: installation, architecture, security, troubleshooting, and rollback notes.

## Limitations

- KWallet is not unlocked by Touch ID because no Fedora password is supplied.
- Touch ID login to SDDM should work through PAM, but KWallet may prompt afterward.
- If the macOS helper is not running or Touch ID is denied, Fedora falls back to normal password authentication.
- The bridge trusts the macOS account running the LaunchAgent. If that session is compromised, this bridge is compromised too.
