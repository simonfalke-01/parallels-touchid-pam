# Install Guide

This guide reproduces the Parallels Touch ID PAM bridge on a fresh Linux VM.

For Kali KDE Plasma 6, use [KALI.md](KALI.md). For multi-VM macOS behavior, use [MULTI_VM.md](MULTI_VM.md).

## Requirements

On macOS:

- A Mac with Touch ID configured.
- Parallels Desktop with a shared folder visible to the Linux VM.
- Xcode Command Line Tools, for `swiftc`:

  ```bash
  xcode-select --install
  ```

On the Linux VM:

- A PAM-based system.
- Parallels shared folders mounted under `/media/psf/...` or another shared location.
- `python3`, `openssl`, `gcc`, `pam_exec`, and `sudo`.

Fedora:

```bash
sudo dnf install gcc glibc-devel openssl python3
```

Kali/Debian:

```bash
sudo apt update
sudo apt install -y python3 gcc libc6-dev openssl sudo polkitd pkexec
```

## 1. Put the Project in a Shared Folder

The bridge uses files under the project directory for request/response exchange. That directory must be visible to both the VM and macOS.

If this repo lives in VM home as `~/parallels-touchid-pam`, copy it to a Parallels shared folder first:

```bash
rsync -a --delete ~/parallels-touchid-pam/ /media/psf/iCloud/parallels-touchid-pam/
cd /media/psf/iCloud/parallels-touchid-pam
```

Use whatever shared folder exists on the target machine. The exact macOS path must point to the same files.

## 2. Install VM Side and `sudo`

Generic Linux:

```bash
./linux/install-linux-sudo.sh
```

Kali convenience wrapper:

```bash
./kali/install-kali-sudo.sh
```

Existing Fedora-specific wrapper:

```bash
./fedora/install-fedora-sudo.sh
```

The generic Linux installer:

- Installs `/usr/local/libexec/parallels-touchid-pam.py`.
- Builds and installs `/usr/local/libexec/parallels-touchid-pam` as a setuid-root wrapper.
- Creates `/etc/parallels-touchid-pam/secret` as a root-only HMAC secret.
- Creates `/etc/parallels-touchid-pam/config`.
- Creates runtime directories under `./bridges/<vm-id>/`.
- Creates `./provisioning/parallels-touchid-pam.env` for one-time macOS helper setup.
- Adds a `sudo` PAM hook.

Touch ID remains disabled until the macOS helper imports and removes the provisioning file.

## 3. Install macOS Helper

Open macOS Terminal in the matching shared-folder path.

For iCloud, the path may be:

```bash
cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs/parallels-touchid-pam"
```

Then run:

```bash
./macos/install-macos-helper.sh
```

This script:

- Compiles `macos/ParallelsTouchIDHelper.swift`.
- Installs the binary under `~/Library/Application Support/ParallelsTouchIDPAM/`.
- Imports the VM config into `~/Library/Application Support/ParallelsTouchIDPAM/config.d/<vm-id>.env`.
- Installs and starts `~/Library/LaunchAgents/com.parallels-touchid-pam.helper.plist`.
- Removes the one-time provisioning file from the shared folder.

Run the macOS installer once from each VM's shared-folder copy to add more VMs.

## 4. Test `sudo`

Back in the VM:

```bash
sudo -k
sudo true
```

Expected result:

- macOS shows a Touch ID prompt.
- `sudo true` exits successfully.
- Logs show `service='sudo'`.

Generic Linux logs:

```bash
journalctl -t parallels-touchid-pam --since "5 minutes ago" --no-pager
```

Original Fedora-specific logs:

```bash
journalctl -t fedora-touchid-pam --since "5 minutes ago" --no-pager
```

## 5. Enable Graphical System Prompts

Enable polkit:

```bash
./linux/enable-polkit.sh
```

Test with:

```bash
pkexec true
```

Expected log:

```text
accepted touchid user='YOUR_USER' service='polkit-1'
```

## 6. Enable KDE Lock/Unlock

```bash
./linux/enable-kde-lock.sh
```

This covers:

- `/etc/pam.d/kde`
- `/etc/pam.d/kscreensaver`
- `/etc/pam.d/kcheckpass`

KDE Plasma uses PAM service `kde` for KScreenLocker by default.

Test:

```bash
loginctl lock-session
```

Unlock the session. Expected log:

```text
accepted touchid user='YOUR_USER' service='kde'
```

## 7. Enable SDDM Login

```bash
./linux/enable-sddm-login.sh
```

Test requires logout or reboot. Keep password fallback available.

Touch ID login does not pass your VM password to the session. KWallet may ask for the password after login.

## 8. Status Check

```bash
./linux/status.sh
```

It prints:

- Helper/heartbeat status.
- Installed file modes.
- PAM services with hooks.
- Recent auth logs.
