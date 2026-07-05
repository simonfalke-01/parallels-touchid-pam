# Parallels Touch ID PAM Bridge

Use macOS Touch ID to approve Linux PAM authentication inside Parallels VMs.

This project is a host-to-guest authentication bridge. It does not expose the Mac fingerprint reader as a Linux fingerprint device. A Linux VM writes a signed authentication request into a Parallels shared folder, a macOS LaunchAgent prompts Touch ID with Apple LocalAuthentication, and the VM accepts a signed response through PAM.

The macOS side is now generic and multi-VM:

- LaunchAgent label: `com.parallels-touchid-pam.helper`
- App support path: `~/Library/Application Support/ParallelsTouchIDPAM`
- Per-VM configs: `~/Library/Application Support/ParallelsTouchIDPAM/config.d/*.env`
- Generic VM bridge directories: `bridges/<vm-id>/` under the shared project copy

Validated locally on:

- Fedora 44 KDE/Plasma under Parallels on macOS
- `sudo`
- KDE polkit desktop authorization prompts
- KDE lock/unlock
- SDDM login hook installed, but login requires logout/reboot to test

Designed for Kali KDE Plasma 6 as well, using the generic `linux/` scripts or the convenience wrappers in `kali/`.

## Important

The install must run from a directory visible to both the Linux VM and macOS, such as a Parallels shared folder. This repository can live in `~/fedora-touchid-pam` as the source copy, but for installation copy it to a shared path first unless the VM home directory is also mounted on macOS.

Example VM shared path:

```bash
/media/psf/iCloud/fedora-touchid-pam
```

Example macOS path for the same iCloud shared folder:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/fedora-touchid-pam
```

## Quick Install: Generic Linux VM

From the Linux VM, in the shared-folder copy:

```bash
./linux/install-linux-sudo.sh
```

From macOS Terminal, in the same shared-folder copy:

```bash
./macos/install-macos-helper.sh
```

Back in the Linux VM:

```bash
sudo -k
sudo true
./linux/enable-polkit.sh
pkexec true
./linux/enable-kde-lock.sh
loginctl lock-session
./linux/enable-sddm-login.sh
```

Full setup docs are in [docs/INSTALL.md](docs/INSTALL.md).

For Kali Plasma 6, see [docs/KALI.md](docs/KALI.md).

For adding multiple VMs to one macOS helper, see [docs/MULTI_VM.md](docs/MULTI_VM.md).

## Rollback

Run these from the Linux VM:

```bash
./linux/disable-sddm-login.sh
./linux/disable-kde-lock.sh
./linux/disable-polkit.sh
./linux/disable-sudo.sh
```

Run this from macOS:

```bash
./macos/uninstall-macos-helper.sh
```

More detail is in [docs/ROLLBACK.md](docs/ROLLBACK.md).

## Repo Layout

- `linux/`: generic Debian/Kali/Fedora-style Linux PAM helper and scripts.
- `fedora/`: original Fedora-specific scripts used for the first VM.
- `kali/`: Kali KDE Plasma 6 convenience wrappers.
- `macos/ParallelsTouchIDHelper.swift`: multi-VM macOS Touch ID helper.
- `macos/install-macos-helper.sh`: compiles and installs the macOS LaunchAgent.
- `docs/`: installation, architecture, security, troubleshooting, and rollback notes.

## Limitations

- KWallet is not unlocked by Touch ID because no VM password is supplied.
- Touch ID login to SDDM should work through PAM, but KWallet may prompt afterward.
- If the macOS helper is not running or Touch ID is denied, the VM falls back to normal password authentication.
- The bridge trusts the macOS account running the LaunchAgent. If that session is compromised, this bridge is compromised too.
